import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/play_games.dart';
import 'editable_map.dart';

/// The player's own maps, saved on the device.
class MapStore extends ChangeNotifier {
  MapStore._(this._prefs, this.maps);

  static const _key = 'custom_maps';

  final SharedPreferences _prefs;
  final List<EditableMap> maps;

  static Future<MapStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final maps = <EditableMap>[];
    for (final text in prefs.getStringList(_key) ?? const <String>[]) {
      try {
        maps.add(
          EditableMap.fromJson(jsonDecode(text) as Map<String, dynamic>),
        );
      } catch (_) {
        // Skip an entry that can no longer be read rather than lose the rest.
      }
    }
    return MapStore._(prefs, maps);
  }

  /// Writes the current [maps] (including in-place edits) to storage.
  Future<void> persist() async {
    PlayGames.progressChanged();
    await _prefs.setStringList(_key, [
      for (final map in maps) jsonEncode(map.toJson()),
    ]);
    notifyListeners();
  }

  Future<void> add(EditableMap map) {
    maps.add(map);
    return persist();
  }

  Future<void> removeAt(int index) {
    maps.removeAt(index);
    return persist();
  }
}
