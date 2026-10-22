import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/ai_player.dart';
import '../l10n.dart';

/// Lifetime record across every battle won against the computer: conquest
/// points (the ranking) and the number of victories.
class Conquest extends ChangeNotifier {
  Conquest._(this._prefs);

  static const pointsKey = 'conquest_points';
  static const winsKey = 'battles_won';

  final SharedPreferences _prefs;

  static Future<Conquest> load() async =>
      Conquest._(await SharedPreferences.getInstance());

  int get points => _prefs.getInt(pointsKey) ?? 0;
  int get wins => _prefs.getInt(winsKey) ?? 0;

  /// Points for one victory: harder opponents, fog and quick wins pay more,
  /// and the daily challenge pays a bonus for showing up.
  static int pointsFor({
    required AiLevel level,
    required bool fog,
    required int days,
    bool daily = false,
  }) =>
      switch (level) {
        AiLevel.easy => 1,
        AiLevel.normal => 3,
        AiLevel.hard => 5,
      } +
      (fog ? 2 : 0) +
      (days <= 10 ? 1 : 0) +
      (daily ? 2 : 0);

  /// Records a victory; returns the points it earned.
  Future<int> recordWin({
    required AiLevel level,
    required bool fog,
    required int days,
    bool daily = false,
  }) async {
    final earned = pointsFor(level: level, fog: fog, days: days, daily: daily);
    await _prefs.setInt(pointsKey, points + earned);
    await _prefs.setInt(winsKey, wins + 1);
    notifyListeners();
    return earned;
  }
}

/// Titles earned with conquest points, lowest first.
const _ranks = [
  (0, 'Squire', 'Cận vệ'),
  (15, 'Knight', 'Hiệp sĩ'),
  (50, 'Baron', 'Nam tước'),
  (120, 'Count', 'Bá tước'),
  (250, 'Duke', 'Công tước'),
  (500, 'Marchlord', 'Lãnh chúa biên ải'),
];

/// The title held with [points].
String rankTitle(int points) {
  var title = _ranks.first;
  for (final r in _ranks) {
    if (points >= r.$1) title = r;
  }
  return tr(title.$2, title.$3);
}

/// Points still needed for the next title, or null at the top.
int? pointsToNextRank(int points) {
  for (final r in _ranks) {
    if (r.$1 > points) return r.$1 - points;
  }
  return null;
}
