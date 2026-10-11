import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  const Achievement(this.id, this.title, this.description);
}

const achievements = [
  Achievement('first_blood', 'First Blood', 'Defeat an enemy unit.'),
  Achievement('castle', 'Castle Stormer', 'Win by capturing the enemy castle.'),
  Achievement('total_war', 'Total War', 'Win by defeating every enemy unit.'),
  Achievement('landlord', 'Landlord', 'Hold 8 buildings at once.'),
  Achievement('veteran', 'Veteran', 'Raise a unit to the third rank.'),
  Achievement('medic', 'Field Medic', 'Heal an ally with a monk.'),
  Achievement('unleashed', 'Unleashed', 'Use a commander power.'),
  Achievement('blitz', 'Blitz', 'Win a battle by day 8.'),
  Achievement('mist', 'Through the Mist', 'Win a battle under fog of war.'),
  Achievement(
    'tactician',
    'Tactician',
    'Beat the Hard computer outside the campaign.',
  ),
  Achievement(
    'cartographer',
    'Cartographer',
    'Win a battle on a map you made.',
  ),
  Achievement('halfway', 'Half the Realm', 'Win campaign mission 10.'),
  Achievement('champion', 'Champion', 'Win the whole campaign.'),
  Achievement(
    'flawless',
    'Flawless General',
    'Earn three stars on every mission.',
  ),
];

/// Unlocked achievements, saved on the device. Screens listen to
/// [justUnlocked] to announce new ones.
class AchievementService {
  AchievementService._();
  static final instance = AchievementService._();

  static const _key = 'achievements';

  final Set<String> unlocked = {};

  /// The most recent batch of newly unlocked achievements.
  final ValueNotifier<List<Achievement>> justUnlocked = ValueNotifier(const []);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    unlocked
      ..clear()
      ..addAll(prefs.getStringList(_key) ?? const []);
  }

  /// Marks [ids] as earned; announces and returns the ones that are new.
  Future<List<Achievement>> unlock(Iterable<String> ids) async {
    final fresh = [
      for (final a in achievements)
        if (ids.contains(a.id) && !unlocked.contains(a.id)) a,
    ];
    if (fresh.isEmpty) return fresh;
    unlocked.addAll(fresh.map((a) => a.id));
    justUnlocked.value = fresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, unlocked.toList());
    return fresh;
  }
}
