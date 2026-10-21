import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/ai_player.dart';
import '../core/map_generator.dart';
import '../core/models.dart';

/// One battle per calendar day, identical for every player: the date alone
/// decides the map, the enemy's skill, both commanders and fog.
class DailyChallenge {
  DailyChallenge._(this.key, this.seed);

  factory DailyChallenge.forDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return DailyChallenge._(
      '${date.year}-${two(date.month)}-${two(date.day)}',
      date.year * 10000 + date.month * 100 + date.day,
    );
  }

  factory DailyChallenge.today() => DailyChallenge.forDate(DateTime.now());

  /// The challenge stored under [key] (yyyy-mm-dd).
  factory DailyChallenge.fromKey(String key) {
    final [y, m, d] = key.split('-').map(int.parse).toList();
    return DailyChallenge.forDate(DateTime(y, m, d));
  }

  /// Calendar date as yyyy-mm-dd; also the key results are stored under.
  final String key;
  final int seed;

  /// A number in 0..range-1 derived from the date and [salt]. Park-Miller
  /// steps keep every product below 2^53, so the result is the same on
  /// every platform.
  int _pick(int salt, int range) {
    var state = (seed * 31 + salt * 7919) % 2147483646 + 1;
    for (var i = 0; i < 3; i++) {
      state = state * 48271 % 2147483647;
    }
    return state % range;
  }

  static const _sizes = [(7, 10), (8, 10), (8, 12)];
  static const _extras = [
    UnitType.spearman,
    UnitType.archer,
    UnitType.knight,
    UnitType.monk,
  ];

  /// Weekends are harder.
  AiLevel get level {
    final weekday = DateTime(
      seed ~/ 10000,
      seed ~/ 100 % 100,
      seed % 100,
    ).weekday;
    return weekday >= DateTime.friday ? AiLevel.hard : AiLevel.normal;
  }

  bool get fog => _pick(1, 3) == 0;

  Commander get playerCommander =>
      Commander.values[_pick(2, Commander.values.length)];

  Commander get enemyCommander =>
      Commander.values[_pick(3, Commander.values.length)];

  MapSpec get spec {
    final (width, height) = _sizes[_pick(4, _sizes.length)];
    final army = [UnitType.infantry, UnitType.infantry, _extras[_pick(5, 4)]];
    return MapSpec(
      seed: seed,
      width: width,
      height: height,
      bridges: _pick(6, 4),
      citiesPerSide: 2 + _pick(7, 3),
      forest: 8 + _pick(8, 17),
      mountain: 4 + _pick(9, 13),
      units: [army, army],
    );
  }

  /// Map JSON plus match setup, ready for a GameScreen.
  Map<String, dynamic> setup() => {
    ...generateMap(spec),
    'fog': fog,
    'commanders': [playerCommander.name, enemyCommander.name],
  };
}

/// Daily challenge results saved on the device.
class DailyRecord extends ChangeNotifier {
  DailyRecord._(this._prefs);

  static const _key = 'daily_results';

  final SharedPreferences _prefs;

  static Future<DailyRecord> load() async =>
      DailyRecord._(await SharedPreferences.getInstance());

  Map<String, int> get _results => {
    for (final entry in _prefs.getStringList(_key) ?? const <String>[])
      if (entry.split(':') case [final date, final days])
        date: ?int.tryParse(days),
  };

  /// Fewest days the challenge for [key] was won in, or null.
  int? best(String key) => _results[key];

  int get wins => _results.length;

  /// Consecutive days won up to [today], counting from yesterday when today
  /// has not been won yet so the streak survives until the day is over.
  int streak(DateTime today) {
    final results = _results;
    var day = DateTime(today.year, today.month, today.day);
    if (!results.containsKey(DailyChallenge.forDate(day).key)) {
      day = day.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (results.containsKey(DailyChallenge.forDate(day).key)) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  Future<void> recordWin(String key, int days) async {
    final results = _results;
    final previous = results[key];
    if (previous != null && previous <= days) return;
    results[key] = days;
    await _prefs.setStringList(_key, [
      for (final e in results.entries) '${e.key}:${e.value}',
    ]);
    notifyListeners();
  }
}
