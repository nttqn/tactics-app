import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../ai/ai_player.dart';
import '../core/game_state.dart';

/// The one unfinished match the player can continue from the home screen.
class SavedMatch {
  /// Map JSON plus setup (commanders, fog) the match started from, so it can
  /// be restarted.
  final Map<String, dynamic> setup;
  final GameState state;
  final AiLevel? level;

  /// Campaign mission index, or null outside the campaign.
  final int? mission;

  /// Shown on the Continue button, e.g. "Mission 3 · Twin Bridges".
  final String label;

  const SavedMatch({
    required this.setup,
    required this.state,
    required this.level,
    required this.mission,
    required this.label,
  });
}

class SaveService {
  static const _key = 'saved_match';
  static const _version = 1;

  static Future<void> save(SavedMatch match) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'v': _version,
        'setup': match.setup,
        'state': match.state.toSave(),
        'level': match.level?.name,
        'mission': match.mission,
        'label': match.label,
      }),
    );
  }

  /// Null when nothing is saved or the save cannot be read any more.
  static Future<SavedMatch?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_key);
    if (text == null) return null;
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      if (j['v'] != _version) return null;
      final level = j['level'] as String?;
      return SavedMatch(
        setup: j['setup'] as Map<String, dynamic>,
        state: GameState.fromSave(j['state'] as Map<String, dynamic>),
        level: level == null ? null : AiLevel.values.byName(level),
        mission: j['mission'] as int?,
        label: j['label'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
