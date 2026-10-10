import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tactics_app/ai/ai_player.dart';
import 'package:tactics_app/core/actions.dart';
import 'package:tactics_app/core/models.dart';
import 'package:tactics_app/game/game_controller.dart';

GameController duel() => GameController({
  'terrain': ['....'],
  'units': [
    {'type': 'infantry', 'owner': 0, 'x': 0, 'y': 0},
    {'type': 'infantry', 'owner': 1, 'x': 3, 'y': 0},
  ],
});

void main() {
  test('select, move, attack and confirm', () {
    final c = duel();
    final seen = <GameEvent>[];
    c.eventListeners.add(seen.addAll);

    c.tapTile(const Pos(0, 0));
    expect(c.phase, Phase.moving);
    expect(c.threatened, {const Pos(3, 0)});

    c.tapTile(const Pos(2, 0));
    expect(c.phase, Phase.menu);
    expect(c.previewPath, hasLength(3));
    expect(c.canCapture, isFalse);
    // Nothing is committed until the action is chosen.
    expect(c.state.unitById(0)!.pos, const Pos(0, 0));

    c.chooseAttack();
    expect(c.phase, Phase.targeting);
    expect(c.target, const Pos(3, 0));
    expect(c.forecast!.damage, 49);

    c.confirmAttack();
    expect(c.phase, Phase.idle);
    expect(c.state.unitById(0)!.pos, const Pos(2, 0));
    expect(c.state.unitById(1)!.hp, 51);
    expect(seen.whereType<UnitDamaged>(), hasLength(2));
  });

  test('undo takes back actions of the current turn only', () {
    final c = duel();
    expect(c.canUndo, isFalse);
    c.tapTile(const Pos(0, 0));
    c.tapTile(const Pos(2, 0));
    c.chooseAttack();
    c.confirmAttack();
    expect(c.canUndo, isTrue);

    c.undo();
    expect(c.state.unitById(0)!.pos, const Pos(0, 0));
    expect(c.state.unitById(0)!.acted, isFalse);
    expect(c.state.unitById(1)!.hp, 100);
    expect(c.canUndo, isFalse);

    c.tapTile(const Pos(0, 0));
    c.tapTile(const Pos(1, 0));
    c.chooseWait();
    c.endTurn();
    expect(c.canUndo, isFalse);
  });

  test('cancel steps back one level at a time', () {
    final c = duel();
    c.tapTile(const Pos(0, 0));
    c.tapTile(const Pos(2, 0));
    c.chooseAttack();
    c.cancel();
    expect(c.phase, Phase.menu);
    c.cancel();
    expect(c.phase, Phase.moving);
    c.cancel();
    expect(c.phase, Phase.idle);
    expect(c.selected, isNull);
  });

  test('enemy and spent units cannot be selected', () {
    final c = duel();
    c.tapTile(const Pos(3, 0));
    expect(c.phase, Phase.idle);

    c.tapTile(const Pos(0, 0));
    c.tapTile(const Pos(1, 0));
    c.chooseWait();
    c.tapTile(const Pos(1, 0));
    expect(c.phase, Phase.idle);

    c.endTurn();
    expect(c.state.currentPlayer, 1);
    c.tapTile(const Pos(3, 0));
    expect(c.phase, Phase.moving);
  });

  test('recruiting from an owned barracks', () {
    final c = GameController({
      'terrain': ['b...'],
      'owners': {
        '0': [
          [0, 0],
        ],
      },
      'units': [
        {'type': 'infantry', 'owner': 1, 'x': 3, 'y': 0},
      ],
      'funds': [200, 0],
    });
    c.tapTile(const Pos(0, 0));
    expect(c.phase, Phase.building);
    c.build(UnitType.spearman);
    expect(c.phase, Phase.idle);
    expect(c.state.unitAt(const Pos(0, 0))!.type, UnitType.spearman);
    expect(c.state.funds[0], 100);
  });

  test('the computer plays its whole turn and hands control back', () async {
    final c = GameController(
      {
        'terrain': ['......'],
        'units': [
          {'type': 'infantry', 'owner': 0, 'x': 0, 'y': 0},
          {'type': 'infantry', 'owner': 1, 'x': 5, 'y': 0},
        ],
      },
      ai: AiPlayer(AiLevel.normal, random: Random(1)),
      aiDelay: Duration.zero,
    );
    addTearDown(c.dispose);
    c.endTurn();
    expect(c.aiTurn, isTrue);
    // Input is locked while the computer moves.
    c.tapTile(const Pos(0, 0));
    expect(c.phase, Phase.idle);
    c.endTurn();
    expect(c.state.currentPlayer, 1);

    while (c.aiTurn) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(c.state.currentPlayer, 0);
    expect(c.state.turn, 2);
    expect(c.state.unitById(1)!.pos, isNot(const Pos(5, 0)));
  });

  test('pausing holds the computer until resumed', () async {
    final c = GameController(
      duel().mapJson,
      ai: AiPlayer(AiLevel.easy, random: Random(1)),
      aiDelay: Duration.zero,
    );
    addTearDown(c.dispose);
    c.endTurn();
    c.togglePause();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.aiTurn, isTrue);
    c.togglePause();
    while (c.aiTurn) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(c.state.currentPlayer, 0);
  });

  test('taps are ignored while paused and restart resets the match', () {
    final c = duel();
    c.togglePause();
    c.tapTile(const Pos(0, 0));
    expect(c.phase, Phase.idle);
    c.togglePause();
    c.endTurn();
    c.restart();
    expect(c.state.currentPlayer, 0);
    expect(c.state.turn, 1);
  });
}
