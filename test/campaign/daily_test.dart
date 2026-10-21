import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tactics_app/ai/ai_player.dart';
import 'package:tactics_app/campaign/daily.dart';
import 'package:tactics_app/core/game_state.dart';

void main() {
  test('the same date always gives the same battle, other dates differ', () {
    final a = DailyChallenge.forDate(DateTime(2026, 10, 21));
    final b = DailyChallenge.forDate(DateTime(2026, 10, 21, 23, 59));
    expect(a.key, '2026-10-21');
    expect(b.setup(), a.setup());
    final terrains = {
      for (var d = 1; d <= 14; d++)
        (DailyChallenge.forDate(DateTime(2026, 11, d)).setup()['terrain']
                as List)
            .join(),
    };
    expect(terrains.length, greaterThan(10));
  });

  test('every day of a year produces a playable, fair match', () {
    var fog = 0;
    for (var d = 0; d < 365; d++) {
      final c = DailyChallenge.forDate(
        DateTime(2027, 1, 1).add(Duration(days: d)),
      );
      final s = GameState.fromMap(c.setup());
      expect(s.unitsOf(0).length, s.unitsOf(1).length);
      expect(s.buildingCount(0), s.buildingCount(1));
      if (c.fog) fog++;
      expect(DailyChallenge.fromKey(c.key).key, c.key);
    }
    // Roughly one day in three.
    expect(fog, inInclusiveRange(80, 160));
  });

  test('weekends are played against the hard computer', () {
    expect(DailyChallenge.forDate(DateTime(2026, 10, 24)).level, AiLevel.hard);
    expect(
      DailyChallenge.forDate(DateTime(2026, 10, 21)).level,
      AiLevel.normal,
    );
  });

  test(
    'streaks count consecutive wins and survive until the day ends',
    () async {
      SharedPreferences.setMockInitialValues({});
      final record = await DailyRecord.load();
      final today = DateTime(2026, 10, 21);
      String key(int back) =>
          DailyChallenge.forDate(today.subtract(Duration(days: back))).key;
      await record.recordWin(key(3), 12);
      await record.recordWin(key(2), 10);
      await record.recordWin(key(1), 9);
      // Today not played yet: the run up to yesterday still counts.
      expect(record.streak(today), 3);
      await record.recordWin(key(0), 14);
      expect(record.streak(today), 4);
      // A slower win does not replace the best.
      await record.recordWin(key(0), 20);
      expect(record.best(key(0)), 14);
      // A missed day breaks the streak.
      expect(record.streak(today.add(const Duration(days: 2))), 0);
      expect((await DailyRecord.load()).wins, 4);
    },
  );
}
