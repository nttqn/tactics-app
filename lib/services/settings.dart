import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small player preferences that are not tied to sound.
class Settings {
  Settings._();

  static const _speedKey = 'battle_speed';
  static const speeds = [1, 2, 4];

  /// How fast the computer's turns and battle animations play: 1, 2 or 4.
  static final ValueNotifier<int> speed = ValueNotifier(1);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_speedKey) ?? 1;
    speed.value = speeds.contains(saved) ? saved : 1;
  }

  /// Steps through x1, x2, x4 and back.
  static Future<void> cycleSpeed() async {
    final i = speeds.indexOf(speed.value);
    speed.value = speeds[(i + 1) % speeds.length];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_speedKey, speed.value);
  }
}
