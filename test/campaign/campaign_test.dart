import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tactics_app/ai/ai_player.dart';
import 'package:tactics_app/campaign/campaign.dart';
import 'package:tactics_app/core/game_state.dart';
import 'package:tactics_app/core/map_generator.dart';
import 'package:tactics_app/core/models.dart';
import 'package:tactics_app/core/rules.dart';

void main() {
  test('generation is deterministic and rotationally symmetric', () {
    for (var seed = 0; seed < 60; seed++) {
      final spec = MapSpec(seed: seed, bridges: seed % 4);
      final map = generateMap(spec);
      expect(generateMap(spec), map);
      final s = GameState.fromMap(map);
      for (var y = 0; y < s.height; y++) {
        for (var x = 0; x < s.width; x++) {
          expect(
            s.terrainAt(Pos(x, y)),
            s.terrainAt(Pos(s.width - 1 - x, s.height - 1 - y)),
          );
        }
      }
      expect(s.buildingCount(0), 2);
      expect(s.buildingCount(1), 2);
    }
  });

  test('a fixed seed keeps producing the same map', () {
    // Guards saved campaign progress against generator drift.
    expect(generateMap(campaign.first.spec)['terrain'], _missionOneTerrain);
  });

  test('every mission can be won by the computer playing blue', () {
    const games = 6, maxDays = 60;
    final report = StringBuffer();
    for (var m = 0; m < campaign.length; m++) {
      final mission = campaign[m];
      final map = generateMap(mission.spec);
      var wins = 0, days = 0;
      for (var seed = 0; seed < games; seed++) {
        final s = GameState.fromMap(map);
        final players = [
          AiPlayer(AiLevel.hard, random: Random(seed)),
          AiPlayer(mission.level, random: Random(seed + 77)),
        ];
        while (s.winner == null && s.turn <= maxDays) {
          s.apply(players[s.currentPlayer].nextAction(s));
        }
        if (s.winner == 0) {
          wins++;
          days += s.turn;
        }
      }
      report.writeln(
        '${m + 1}. ${mission.name}: $wins/$games'
        '${wins > 0 ? ', avg ${days ~/ wins} days' : ''}',
      );
      expect(wins, greaterThan(0), reason: 'mission ${m + 1} looks unwinnable');
    }
    // ignore: avoid_print
    print(report);
  });
}

const _missionOneTerrain = [
  '..h...',
  '.f....',
  '...b..',
  '....c.',
  '.c....',
  '..b...',
  '....f.',
  '...h..',
];
