import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tactics_app/core/actions.dart';
import 'package:tactics_app/core/game_state.dart';
import 'package:tactics_app/core/models.dart';
import 'package:tactics_app/core/rules.dart';

Map<String, dynamic> u(String type, int owner, int x, int y, {int? hp}) => {
  'type': type,
  'owner': owner,
  'x': x,
  'y': y,
  'hp': ?hp,
};

GameState state(
  List<String> rows,
  List<Map<String, dynamic>> units, {
  bool fog = false,
  List<String?>? commanders,
}) => GameState.fromMap({
  'terrain': rows,
  'units': units,
  'fog': fog,
  'commanders': ?commanders,
});

void main() {
  group('monk', () {
    test('heals an adjacent ally and cannot attack', () {
      final s = state(
        ['.....'],
        [
          u('monk', 0, 0, 0),
          u('knight', 0, 2, 0, hp: 40),
          u('infantry', 1, 4, 0),
        ],
      );
      final monk = s.unitById(0)!;
      expect(s.attackTargets(monk, const Pos(1, 0)), isEmpty);
      final events = s.apply(
        const UnitAction(0, Pos(1, 0), ActionKind.heal, Pos(2, 0)),
      );
      expect(s.unitById(1)!.hp, 70);
      expect(events.whereType<UnitHealed>().single.amount, 30);
    });

    test('cannot heal enemies, itself, or healthy allies', () {
      final s = state(
        ['....'],
        [
          u('monk', 0, 0, 0, hp: 50),
          u('infantry', 0, 1, 0),
          u('infantry', 1, 2, 0, hp: 20),
        ],
      );
      final monk = s.unitById(0)!;
      expect(s.healTargets(monk, const Pos(0, 0)), isEmpty);
      expect(
        () =>
            s.apply(const UnitAction(0, Pos(0, 0), ActionKind.heal, Pos(1, 0))),
        throwsArgumentError,
      );
    });
  });

  test('a kill promotes the attacker, and rank adds damage', () {
    final s = state(
      ['......'],
      [
        u('knight', 0, 0, 0),
        u('infantry', 1, 2, 0, hp: 30),
        u('infantry', 1, 5, 0),
      ],
    );
    final events = s.apply(
      const UnitAction(0, Pos(1, 0), ActionKind.attack, Pos(2, 0)),
    );
    expect(events.whereType<UnitPromoted>().single.rank, 1);
    final knight = s.unitById(0)!;
    final target = s.unitById(2)!;
    // 80 base x 10 HP x 90% plains = 72, +10% for rank 1 = 79.
    expect(s.damageTo(knight, knight.hp, target), 79);
  });

  group('commander powers', () {
    test('fighting charges both meters, more for the side hit', () {
      final s = state(
        ['....'],
        [u('infantry', 0, 0, 0), u('infantry', 1, 2, 0)],
        commanders: ['warden', 'bold'],
      );
      s.apply(const UnitAction(0, Pos(1, 0), ActionKind.attack, Pos(2, 0)));
      // Blue deals 49 and takes 29; red the reverse.
      expect(s.charge[0], 49 * 2 ~/ 5 + 29 * 3 ~/ 5);
      expect(s.charge[1], 49 * 3 ~/ 5 + 29 * 2 ~/ 5);
    });

    test('Rally heals every unit and empties the meter', () {
      final s = state(
        ['....'],
        [
          u('infantry', 0, 0, 0, hp: 40),
          u('archer', 0, 1, 0, hp: 90),
          u('infantry', 1, 3, 0),
        ],
        commanders: ['warden', null],
      );
      expect(s.canUsePower, isFalse);
      s.charge[0] = Commander.maxCharge;
      expect(s.legalActions(), contains(isA<UsePowerAction>()));
      s.apply(const UsePowerAction());
      expect(s.unitById(0)!.hp, 70);
      expect(s.unitById(1)!.hp, 100);
      expect(s.charge[0], 0);
      expect(s.canUsePower, isFalse);
    });

    test('Fury adds damage for the rest of the turn only', () {
      final s = state(
        ['....'],
        [u('infantry', 0, 0, 0), u('infantry', 1, 3, 0)],
        commanders: ['bold', null],
      );
      final blue = s.unitById(0)!, red = s.unitById(1)!;
      expect(s.damageTo(blue, 100, red), 49);
      s.charge[0] = Commander.maxCharge;
      s.apply(const UsePowerAction());
      expect(s.damageTo(blue, 100, red), 64);
      s.apply(const EndTurnAction());
      expect(s.damageTo(blue, 100, red), 49);
    });

    test('Forced March adds two tiles of movement', () {
      final s = state(
        ['.........'],
        [u('infantry', 0, 0, 0), u('infantry', 1, 8, 0)],
        commanders: ['swift', null],
      );
      final blue = s.unitById(0)!;
      expect(
        s
            .reachable(blue)
            .destinations
            .map((p) => p.x)
            .reduce((a, b) => a > b ? a : b),
        3,
      );
      s.charge[0] = Commander.maxCharge;
      s.apply(const UsePowerAction());
      expect(
        s
            .reachable(blue)
            .destinations
            .map((p) => p.x)
            .reduce((a, b) => a > b ? a : b),
        5,
      );
    });

    test('without a commander the meter never fills', () {
      final s = state(
        ['....'],
        [u('infantry', 0, 0, 0), u('infantry', 1, 2, 0)],
      );
      s.apply(const UnitAction(0, Pos(1, 0), ActionKind.attack, Pos(2, 0)));
      expect(s.charge, [0, 0]);
    });
  });

  group('fog of war', () {
    test('units see by their vision range, buildings see next door', () {
      final s = state(
        ['c........'],
        [u('infantry', 0, 4, 0), u('infantry', 1, 8, 0)],
        fog: true,
      );
      final seen = s.visibleTo(0);
      expect(seen.contains(const Pos(6, 0)), isTrue);
      expect(seen.contains(const Pos(7, 0)), isFalse);
      // The neutral village is not ours, so it gives no sight.
      expect(seen.contains(const Pos(0, 0)), isFalse);
    });

    test('hidden enemies cannot be attacked', () {
      final s = state(
        ['.....'],
        [u('archer', 0, 0, 0), u('infantry', 1, 4, 0)],
        fog: true,
      );
      final archer = s.unitById(0)!;
      // Archer vision 3 does not reach x=4.
      expect(s.attackTargets(archer, const Pos(2, 0)), isEmpty);
    });

    test('walking into a hidden enemy stops the move short', () {
      final s = state(
        ['.......'],
        [u('knight', 0, 0, 0), u('infantry', 1, 4, 0)],
        fog: true,
      );
      // Knight vision 3 cannot see x=4, so x=5 looks reachable.
      expect(
        s.reachable(s.unitById(0)!).destinations,
        contains(const Pos(5, 0)),
      );
      final events = s.apply(const UnitAction(0, Pos(5, 0), ActionKind.wait));
      expect(s.unitById(0)!.pos, const Pos(3, 0));
      expect(s.unitById(0)!.acted, isTrue);
      final ambush = events.whereType<Ambushed>().single;
      expect(ambush.enemyAt, const Pos(4, 0));
    });

    test('without fog everything is visible', () {
      final s = state(
        ['.........'],
        [u('infantry', 0, 0, 0), u('infantry', 1, 8, 0)],
      );
      expect(s.isVisible(0, const Pos(8, 0)), isTrue);
    });
  });

  test('a saved match resumes exactly where it was', () {
    final s = state(
      ['h.c..', '.....', '..b.h'],
      [u('infantry', 0, 1, 0), u('knight', 1, 3, 2, hp: 60)],
      fog: true,
      commanders: ['bold', 'swift'],
    );
    s.owners[const Pos(4, 2)] = 1;
    s.apply(const UnitAction(0, Pos(2, 0), ActionKind.capture));
    s.charge[1] = 55;
    s.unitById(0)!.rank = 2;

    final restored = GameState.fromSave(
      jsonDecode(jsonEncode(s.toSave())) as Map<String, dynamic>,
    );
    expect(jsonEncode(restored.toSave()), jsonEncode(s.toSave()));
    expect(restored.capture[const Pos(2, 0)], 10);
    expect(restored.unitById(0)!.acted, isTrue);
    expect(restored.commanders, [Commander.bold, Commander.swift]);
    restored.apply(const EndTurnAction());
    expect(restored.currentPlayer, 1);
  });
}
