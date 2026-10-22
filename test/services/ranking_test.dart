import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tactics_app/ai/ai_player.dart';
import 'package:tactics_app/campaign/conquest.dart';
import 'package:tactics_app/campaign/daily.dart';
import 'package:tactics_app/services/cloud_progress.dart';

void main() {
  test('conquest points reward skill, fog, speed and the daily', () {
    expect(Conquest.pointsFor(level: AiLevel.easy, fog: false, days: 20), 1);
    expect(Conquest.pointsFor(level: AiLevel.hard, fog: true, days: 9), 8);
    expect(
      Conquest.pointsFor(
        level: AiLevel.normal,
        fog: false,
        days: 15,
        daily: true,
      ),
      5,
    );
  });

  test('titles climb with points', () async {
    SharedPreferences.setMockInitialValues({});
    final c = await Conquest.load();
    expect(rankTitle(c.points), 'Squire');
    expect(pointsToNextRank(0), 15);
    for (var i = 0; i < 3; i++) {
      await c.recordWin(level: AiLevel.hard, fog: false, days: 9);
    }
    expect(c.points, 18);
    expect(c.wins, 3);
    expect(rankTitle(c.points), 'Knight');
    expect(pointsToNextRank(600), isNull);
  });

  test(
    'the daily day turns over at Pacific midnight, daylight time or not',
    () {
      // 2026-10-22 06:59 UTC = 23:59 PDT on the 21st.
      expect(
        DailyChallenge.pacificToday(DateTime.utc(2026, 10, 22, 6, 59)),
        DateTime(2026, 10, 21),
      );
      expect(
        DailyChallenge.pacificToday(DateTime.utc(2026, 10, 22, 7, 0)),
        DateTime(2026, 10, 22),
      );
      // In January (PST) the change happens an hour later in UTC.
      expect(
        DailyChallenge.pacificToday(DateTime.utc(2027, 1, 15, 7, 30)),
        DateTime(2027, 1, 14),
      );
      expect(
        DailyChallenge.pacificToday(DateTime.utc(2027, 1, 15, 8, 0)),
        DateTime(2027, 1, 15),
      );
    },
  );

  test('merging two devices never loses progress', () {
    final phone = {
      'v': 1,
      'campaign_completed': 5,
      'campaign_best_days': ['9', '14', '', '20'],
      'achievements': ['blitz', 'mist'],
      'daily_results': ['2026-10-20:12', '2026-10-21:15'],
      'custom_maps': ['{"name":"A"}'],
      'conquest_points': 40,
      'battles_won': 9,
    };
    final tablet = {
      'v': 1,
      'campaign_completed': 3,
      'campaign_best_days': ['7', '18', '11'],
      'achievements': ['blitz', 'castle'],
      'daily_results': ['2026-10-21:10', '2026-10-22:13'],
      'custom_maps': ['{"name":"B"}', '{"name":"A"}'],
      'conquest_points': 55,
      'battles_won': 7,
    };
    final m = CloudProgress.merge(phone, tablet);
    expect(m['campaign_completed'], 5);
    expect(m['campaign_best_days'], ['7', '14', '11', '20']);
    expect((m['achievements'] as List).toSet(), {'blitz', 'mist', 'castle'});
    expect((m['daily_results'] as List).toSet(), {
      '2026-10-20:12',
      '2026-10-21:10',
      '2026-10-22:13',
    });
    expect((m['custom_maps'] as List).length, 2);
    expect(m['conquest_points'], 55);
    expect(m['battles_won'], 9);
    expect(
      CloudProgress.merge(m, m)['campaign_best_days'],
      m['campaign_best_days'],
    );
  });

  test('a cloud copy round-trips through prefs', () async {
    SharedPreferences.setMockInitialValues({
      'campaign_completed': 2,
      'achievements': ['first_blood'],
      'conquest_points': 7,
    });
    final prefs = await SharedPreferences.getInstance();
    final data = CloudProgress.export(prefs);
    expect(CloudProgress.decode('not json'), isNull);
    SharedPreferences.setMockInitialValues({});
    final fresh = await SharedPreferences.getInstance();
    await CloudProgress.apply(fresh, data);
    expect(fresh.getInt('campaign_completed'), 2);
    expect(fresh.getStringList('achievements'), ['first_blood']);
    expect(fresh.getInt('conquest_points'), 7);
  });
}
