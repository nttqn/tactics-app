import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Progress that is worth keeping across devices, as one JSON document for
/// a cloud save slot, and the rules for merging two copies of it.
///
/// Merging never loses anything: the further campaign, the better best
/// days, every achievement, every daily result, every custom map and the
/// larger lifetime totals all win.
class CloudProgress {
  static const _completed = 'campaign_completed';
  static const _bestDays = 'campaign_best_days';
  static const _achievements = 'achievements';
  static const _daily = 'daily_results';
  static const _maps = 'custom_maps';
  static const _points = 'conquest_points';
  static const _wins = 'battles_won';

  static const version = 1;

  static Map<String, dynamic> export(SharedPreferences prefs) => {
    'v': version,
    _completed: prefs.getInt(_completed) ?? 0,
    _bestDays: prefs.getStringList(_bestDays) ?? const <String>[],
    _achievements: prefs.getStringList(_achievements) ?? const <String>[],
    _daily: prefs.getStringList(_daily) ?? const <String>[],
    _maps: prefs.getStringList(_maps) ?? const <String>[],
    _points: prefs.getInt(_points) ?? 0,
    _wins: prefs.getInt(_wins) ?? 0,
  };

  /// [a] and [b] combined so neither side's progress is lost.
  static Map<String, dynamic> merge(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    int maxInt(String key) => max((a[key] as int?) ?? 0, (b[key] as int?) ?? 0);
    List<String> list(Map<String, dynamic> m, String key) =>
        ((m[key] as List?) ?? const []).cast<String>();

    // Best days per mission: the smaller non-empty value.
    final bestA = list(a, _bestDays), bestB = list(b, _bestDays);
    String better(int i) {
      final x = i < bestA.length ? int.tryParse(bestA[i]) : null;
      final y = i < bestB.length ? int.tryParse(bestB[i]) : null;
      if (x == null || y == null) return (x ?? y)?.toString() ?? '';
      return '${min(x, y)}';
    }

    final best = [
      for (var i = 0; i < max(bestA.length, bestB.length); i++) better(i),
    ];

    // Daily results "date:days": the smaller days per date.
    final daily = <String, int>{};
    for (final entry in [...list(a, _daily), ...list(b, _daily)]) {
      final parts = entry.split(':');
      final days = parts.length == 2 ? int.tryParse(parts[1]) : null;
      if (days == null) continue;
      final previous = daily[parts[0]];
      if (previous == null || days < previous) daily[parts[0]] = days;
    }

    return {
      'v': version,
      _completed: maxInt(_completed),
      _bestDays: best,
      _achievements: {
        ...list(a, _achievements),
        ...list(b, _achievements),
      }.toList(),
      _daily: [for (final e in daily.entries) '${e.key}:${e.value}'],
      // Maps are whole JSON documents; identical ones collapse.
      _maps: {...list(a, _maps), ...list(b, _maps)}.toList(),
      _points: maxInt(_points),
      _wins: maxInt(_wins),
    };
  }

  static Future<void> apply(
    SharedPreferences prefs,
    Map<String, dynamic> data,
  ) async {
    List<String> list(String key) =>
        ((data[key] as List?) ?? const []).cast<String>();
    await prefs.setInt(_completed, (data[_completed] as int?) ?? 0);
    await prefs.setStringList(_bestDays, list(_bestDays));
    await prefs.setStringList(_achievements, list(_achievements));
    await prefs.setStringList(_daily, list(_daily));
    await prefs.setStringList(_maps, list(_maps));
    await prefs.setInt(_points, (data[_points] as int?) ?? 0);
    await prefs.setInt(_wins, (data[_wins] as int?) ?? 0);
  }

  /// Parses a cloud copy; null if it is missing, damaged or from a newer
  /// version of the game.
  static Map<String, dynamic>? decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      return (data['v'] as int?) == version ? data : null;
    } catch (_) {
      return null;
    }
  }
}
