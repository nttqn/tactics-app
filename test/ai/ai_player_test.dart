import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tactics_app/ai/ai_player.dart';
import 'package:tactics_app/core/actions.dart';
import 'package:tactics_app/core/game_state.dart';
import 'package:tactics_app/core/models.dart';
import 'package:tactics_app/core/rules.dart';

const maxDays = 60;

/// Plays [blue] against [red] to the end. Returns the winner, or null if
/// nobody has won by [maxDays].
int? play(Map<String, dynamic> map, AiPlayer blue, AiPlayer red) {
  final s = GameState.fromMap(map);
  final players = [blue, red];
  while (s.winner == null && s.turn <= maxDays) {
    s.apply(players[s.currentPlayer].nextAction(s));
  }
  return s.winner;
}

void main() {
  final map =
      jsonDecode(File('assets/maps/skirmish_01.json').readAsStringSync())
          as Map<String, dynamic>;

  GameState state(List<String> rows, List<Map<String, dynamic>> units) =>
      GameState.fromMap({'terrain': rows, 'units': units});

  test('finishes off a unit it can kill', () {
    final s = state(
      ['....'],
      [
        {'type': 'infantry', 'owner': 0, 'x': 0, 'y': 0},
        {'type': 'infantry', 'owner': 1, 'x': 2, 'y': 0, 'hp': 20},
      ],
    );
    final action = AiPlayer(AiLevel.hard, random: Random(1)).nextAction(s);
    expect(action, isA<UnitAction>());
    expect((action as UnitAction).kind, ActionKind.attack);
  });

  test('walks to a free building and captures it', () {
    final s = state(
      ['...c..'],
      [
        {'type': 'infantry', 'owner': 0, 'x': 0, 'y': 0},
        {'type': 'infantry', 'owner': 1, 'x': 5, 'y': 0, 'hp': 10},
      ],
    );
    final action =
        AiPlayer(AiLevel.normal, random: Random(1)).nextAction(s) as UnitAction;
    expect(action.to, const Pos(3, 0));
    expect(action.kind, ActionKind.capture);
  });

  test('every level plays whole games using only legal actions', () {
    for (final level in AiLevel.values) {
      for (var seed = 0; seed < 5; seed++) {
        // apply() throws on any illegal action.
        play(
          map,
          AiPlayer(level, random: Random(seed)),
          AiPlayer(level, random: Random(seed + 100)),
        );
      }
    }
  });

  test('stronger levels beat weaker ones from either side', () {
    const games = 20;
    int wins(AiLevel strong, AiLevel weak) {
      var won = 0;
      for (var seed = 0; seed < games; seed++) {
        final a = AiPlayer(strong, random: Random(seed));
        final b = AiPlayer(weak, random: Random(seed + 1000));
        // Alternate sides so first-move advantage cancels out.
        final strongSide = seed.isEven ? 0 : 1;
        final winner = strongSide == 0 ? play(map, a, b) : play(map, b, a);
        if (winner == strongSide) won++;
      }
      return won;
    }

    final normalVsEasy = wins(AiLevel.normal, AiLevel.easy);
    final hardVsEasy = wins(AiLevel.hard, AiLevel.easy);
    final hardVsNormal = wins(AiLevel.hard, AiLevel.normal);
    // ignore: avoid_print
    print(
      'wins out of $games: normal>easy $normalVsEasy, '
      'hard>easy $hardVsEasy, hard>normal $hardVsNormal',
    );
    expect(normalVsEasy, greaterThanOrEqualTo(16));
    expect(hardVsEasy, greaterThanOrEqualTo(16));
    expect(hardVsNormal, greaterThanOrEqualTo(10));
  });

  test('mirror matches end decisively', () {
    var blue = 0, red = 0, unfinished = 0;
    for (var seed = 0; seed < 30; seed++) {
      final winner = play(
        map,
        AiPlayer(AiLevel.normal, random: Random(seed)),
        AiPlayer(AiLevel.normal, random: Random(seed + 500)),
      );
      if (winner == 0) {
        blue++;
      } else if (winner == 1) {
        red++;
      } else {
        unfinished++;
      }
    }
    // ignore: avoid_print
    print('normal mirror: blue $blue, red $red, unfinished $unfinished');
    expect(unfinished, lessThanOrEqualTo(6));
  });
}
