import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart' as pgs;
import 'package:shared_preferences/shared_preferences.dart';

import '../campaign/conquest.dart';
import '../campaign/daily.dart';
import '../campaign/progress.dart';
import 'achievements.dart';
import 'cloud_progress.dart';

/// Google Play Games: sign-in, leaderboards, achievements and a cloud copy
/// of the player's progress (Saved Games). Android only.
///
/// Nothing here ever blocks play. Every platform call has a timeout as well
/// as a try/catch: with no native handler (tests, or a device without Play
/// Services) the plugin's future can simply never complete. Until the player
/// is signed in every call is a no-op, so tests never reach the plugin.
class PlayGames {
  PlayGames._();

  // From Play Console. The Play Games project id they belong to is in
  // android/app/src/main/res/values/games_ids.xml. Empty = not created yet,
  // and that board or achievement is skipped.
  static const _dailyBoard = 'CgkI3ZDhpIMaEAIQAg';
  static const _conquestBoard = 'CgkI3ZDhpIMaEAIQAw';
  static const _starsBoard = 'CgkI3ZDhpIMaEAIQBA';

  static const _achievementIds = <String, String>{
    'first_blood': '',
    'castle': '',
    'total_war': '',
    'landlord': '',
    'veteran': '',
    'medic': '',
    'unleashed': '',
    'blitz': '',
    'mist': '',
    'tactician': '',
    'cartographer': '',
    'halfway': '',
    'devoted': '',
    'seasoned': '',
    'warmonger': '',
    'legend': '',
    'champion': '',
    'flawless': '',
  };

  /// Achievements created as incremental in Play Console, with their step
  /// counts; they track lifetime wins against the computer.
  static const _winSteps = {'seasoned': 10, 'warmonger': 50, 'legend': 100};

  static const _saveName = 'progress';
  static const _timeout = Duration(seconds: 12);

  /// True once sign-in succeeded.
  static final signedIn = ValueNotifier(false);

  /// Bumped when progress from the cloud was merged into this device, so
  /// open screens can reload.
  static final cloudMerged = ValueNotifier(0);

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether Play Games buttons are worth showing on this platform.
  static bool get available => _supported;

  static Timer? _pending;
  static Future<void>? _syncing;

  /// Signs in and brings this device, the cloud and Play Games up to date.
  /// Called once at launch; not awaited.
  static Future<void> start() async {
    if (!_supported || signedIn.value) return;
    try {
      await pgs.GameAuth.signIn().timeout(_timeout);
    } catch (_) {
      // No account, no network, not set up: play on without Play Games.
      return;
    }
    signedIn.value = true;
    await _sync();
  }

  /// After a win or any other change worth keeping. Several recorders run
  /// at the end of a battle, so this waits for them to settle.
  static void progressChanged() {
    if (!signedIn.value) return;
    _pending?.cancel();
    _pending = Timer(const Duration(seconds: 2), _sync);
  }

  /// Reports achievements the moment they are earned.
  static void unlocked(Iterable<String> ids) {
    if (!signedIn.value) return;
    for (final id in ids) {
      if (!_winSteps.containsKey(id)) _call(_unlock(id));
    }
  }

  /// Opens the Play Games leaderboard list; false if it could not.
  static Future<bool> showLeaderboards() =>
      _show(() => pgs.Leaderboards.showLeaderboards());

  /// Opens the Play Games achievement list; false if it could not.
  static Future<bool> showAchievements() =>
      _show(() => pgs.Achievements.showAchievements());

  static Future<bool> _show(Future<Object?> Function() open) async {
    if (!_supported) return false;
    try {
      if (!signedIn.value) {
        await pgs.GameAuth.signIn().timeout(_timeout);
        signedIn.value = true;
        progressChanged();
      }
      await open().timeout(_timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _sync() => _syncing ??= () async {
    try {
      await _syncCloud();
      await _submitAll();
    } finally {
      _syncing = null;
    }
  }();

  /// Merges the cloud copy into this device and writes the result back.
  /// Never writes unless the cloud copy was read (or there is none): saving
  /// over a copy that only failed to load would lose another device's
  /// progress.
  static Future<void> _syncCloud() async {
    try {
      final saves = await pgs.SaveGame.getSavedGames(
        forceRefresh: true,
        ignoreImages: true,
      ).timeout(_timeout);
      if (saves == null) return;
      Map<String, dynamic>? cloud;
      if (saves.any((s) => s.name == _saveName)) {
        final text = await pgs.SaveGame.loadGame(
          name: _saveName,
        ).timeout(_timeout);
        cloud = CloudProgress.decode(text);
        // A copy this version cannot read (damaged, or from a newer game)
        // is left alone.
        if (cloud == null) return;
      }
      final prefs = await SharedPreferences.getInstance();
      final local = CloudProgress.export(prefs);
      final merged = cloud == null ? local : CloudProgress.merge(local, cloud);
      if (cloud != null && jsonEncode(merged) != jsonEncode(local)) {
        await CloudProgress.apply(prefs, merged);
        await AchievementService.instance.load();
        cloudMerged.value++;
      }
      if (cloud == null || jsonEncode(merged) != jsonEncode(cloud)) {
        final points = (merged['conquest_points'] as int?) ?? 0;
        await pgs.SaveGame.saveGame(
          data: jsonEncode(merged),
          name: _saveName,
          description: '${rankTitle(points)} · $points',
        ).timeout(_timeout);
      }
    } catch (_) {}
  }

  /// Scores and achievements from this device's records. Play Games keeps
  /// the best score and ignores repeats, so sending everything is safe.
  static Future<void> _submitAll() async {
    final conquest = await Conquest.load();
    final progress = await Progress.load();
    final daily = await DailyRecord.load();
    final todayBest = daily.best(DailyChallenge.today().key);
    await Future.wait([
      _submit(_conquestBoard, conquest.points),
      _submit(_starsBoard, progress.totalStars),
      if (todayBest != null) _submit(_dailyBoard, todayBest),
      for (final MapEntry(key: id, value: steps) in _winSteps.entries)
        _setSteps(id, conquest.wins < steps ? conquest.wins : steps),
      for (final id in AchievementService.instance.unlocked)
        if (!_winSteps.containsKey(id)) _unlock(id),
    ]);
  }

  static Future<void> _submit(String board, int value) async {
    if (board.isEmpty || value <= 0) return;
    await _call(
      pgs.Leaderboards.submitScore(
        score: pgs.Score(androidLeaderboardID: board, value: value),
      ),
    );
  }

  static Future<void> _unlock(String id) async {
    final androidId = _achievementIds[id] ?? '';
    if (androidId.isEmpty) return;
    await _call(
      pgs.Achievements.unlock(
        achievement: pgs.Achievement(androidID: androidId),
      ),
    );
  }

  static Future<void> _setSteps(String id, int steps) async {
    final androidId = _achievementIds[id] ?? '';
    if (androidId.isEmpty || steps <= 0) return;
    await _call(
      pgs.Achievements.setSteps(
        achievement: pgs.Achievement(androidID: androidId, steps: steps),
      ),
    );
  }

  static Future<void> _call(Future<Object?> call) async {
    try {
      await call.timeout(_timeout);
    } catch (_) {}
  }
}
