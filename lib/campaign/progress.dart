import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'campaign.dart';

/// Campaign progress saved on the device.
class Progress extends ChangeNotifier {
  Progress._(this._prefs);

  static const _completedKey = 'campaign_completed';
  static const _bestDaysKey = 'campaign_best_days';

  final SharedPreferences _prefs;

  static Future<Progress> load() async =>
      Progress._(await SharedPreferences.getInstance());

  /// How many missions have been cleared; mission index [completed] is the
  /// furthest one unlocked.
  int get completed => _prefs.getInt(_completedKey) ?? 0;

  bool isUnlocked(int index) => index <= completed;

  /// Fewest days the mission was won in, or null if never won.
  int? bestDays(int index) {
    final all = _prefs.getStringList(_bestDaysKey) ?? const [];
    return index < all.length ? int.tryParse(all[index]) : null;
  }

  Future<void> recordWin(int index, int days) async {
    final all = List.generate(
      campaign.length,
      (i) => bestDays(i)?.toString() ?? '',
    );
    final previous = bestDays(index);
    if (previous == null || days < previous) all[index] = '$days';
    await _prefs.setStringList(_bestDaysKey, all);
    if (index + 1 > completed) await _prefs.setInt(_completedKey, index + 1);
    notifyListeners();
  }
}
