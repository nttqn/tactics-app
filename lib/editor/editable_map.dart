import 'dart:collection';
import 'dart:convert';

import '../core/game_state.dart';
import '../core/models.dart';

typedef PlacedUnit = ({UnitType type, int owner});

/// A map being edited. Every edit keeps it loadable by `GameState.fromMap`
/// (no units on tiles they cannot stand on, owners only on buildings);
/// [problems] reports what still stops it from being a fair, playable match.
class EditableMap {
  static const sizes = [(6, 8), (7, 10), (8, 10), (8, 12)];
  static const _codePrefix = 'TAC1:';

  String name;
  final int width, height;
  final List<List<Terrain>> _grid;
  final Map<Pos, int> owners;
  final Map<Pos, PlacedUnit> units;

  EditableMap._(
    this.name,
    this.width,
    this.height,
    this._grid,
    this.owners,
    this.units,
  );

  factory EditableMap.blank(String name, int width, int height) =>
      EditableMap._(
        name,
        width,
        height,
        List.generate(height, (_) => List.filled(width, Terrain.plain)),
        {},
        {},
      );

  /// Throws [FormatException] if [json] is not a usable map.
  factory EditableMap.fromJson(Map<String, dynamic> json) {
    final GameState s;
    try {
      s = GameState.fromMap(json);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Not a map: $e');
    }
    if (s.width < 5 || s.width > 8 || s.height < 6 || s.height > 12) {
      throw const FormatException('Unsupported map size');
    }
    return EditableMap._(
      (json['name'] as String?) ?? 'Untitled',
      s.width,
      s.height,
      [
        for (var y = 0; y < s.height; y++)
          [for (var x = 0; x < s.width; x++) s.terrainAt(Pos(x, y))],
      ],
      Map.of(s.owners),
      {for (final u in s.units) u.pos: (type: u.type, owner: u.owner)},
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'terrain': [for (final row in _grid) row.map((t) => t.symbol).join()],
    'owners': {
      for (var player = 0; player < 2; player++)
        '$player': [
          for (final e in owners.entries)
            if (e.value == player) [e.key.x, e.key.y],
        ],
    },
    'units': [
      for (final e in units.entries)
        {
          'type': e.value.type.name,
          'owner': e.value.owner,
          'x': e.key.x,
          'y': e.key.y,
        },
    ],
    'funds': [0, 0],
  };

  /// A text code for sharing the map through the clipboard.
  String toCode() =>
      _codePrefix + base64Url.encode(utf8.encode(jsonEncode(toJson())));

  /// Returns null if [code] is not a valid map code.
  static EditableMap? fromCode(String code) {
    final text = code.trim();
    if (!text.startsWith(_codePrefix)) return null;
    try {
      final json = jsonDecode(
        utf8.decode(base64Url.decode(text.substring(_codePrefix.length))),
      );
      return EditableMap.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  bool inBounds(Pos p) => p.x >= 0 && p.y >= 0 && p.x < width && p.y < height;

  Terrain terrainAt(Pos p) => _grid[p.y][p.x];

  /// The tile a half-turn around the centre; the other player's side.
  Pos mirrorOf(Pos p) => Pos(width - 1 - p.x, height - 1 - p.y);

  /// Paints [terrain] at [p]. With [mirror], the opposite tile gets the same
  /// terrain for the other player, which keeps the map fair.
  void paintTerrain(Pos p, Terrain terrain, int? owner, {bool mirror = false}) {
    // A castle always belongs to someone.
    if (terrain == Terrain.hq) owner ??= 0;
    _setTerrain(p, terrain, owner);
    final m = mirrorOf(p);
    if (mirror && m != p) {
      _setTerrain(m, terrain, owner == null ? null : 1 - owner);
    }
  }

  void _setTerrain(Pos p, Terrain terrain, int? owner) {
    if (terrain == Terrain.hq) {
      // One castle per player: placing a new one moves it.
      for (final old in owners.keys.toList()) {
        if (old != p && owners[old] == owner && terrainAt(old) == Terrain.hq) {
          _grid[old.y][old.x] = Terrain.plain;
          owners.remove(old);
        }
      }
    }
    _grid[p.y][p.x] = terrain;
    if (terrain.isBuilding && owner != null) {
      owners[p] = owner;
    } else {
      owners.remove(p);
    }
    final unit = units[p];
    if (unit != null && terrain.moveCost(unit.type.moveClass) == null) {
      units.remove(p);
    }
  }

  /// Places a unit, replacing any already there. Ignored on tiles the unit
  /// cannot stand on.
  void placeUnit(Pos p, UnitType type, int owner, {bool mirror = false}) {
    void place(Pos at, int player) {
      if (terrainAt(at).moveCost(type.moveClass) == null) return;
      units[at] = (type: type, owner: player);
    }

    place(p, owner);
    final m = mirrorOf(p);
    if (mirror && m != p) place(m, 1 - owner);
  }

  /// Removes the unit at [p], or clears the tile to grass if there is none.
  void erase(Pos p, {bool mirror = false}) {
    void clear(Pos at) {
      if (units.remove(at) == null) _setTerrain(at, Terrain.plain, null);
    }

    clear(p);
    final m = mirrorOf(p);
    if (mirror && m != p) clear(m);
  }

  /// Human-readable reasons the map cannot be played yet; empty when ready.
  List<String> problems() {
    const names = ['Blue', 'Red'];
    final result = <String>[];
    final castles = <Pos?>[null, null];
    for (var player = 0; player < 2; player++) {
      final own = [
        for (final e in owners.entries)
          if (e.value == player && terrainAt(e.key) == Terrain.hq) e.key,
      ];
      if (own.length == 1) {
        castles[player] = own.first;
      } else {
        result.add('${names[player]} needs a castle.');
      }
      final hasArmy =
          units.values.any((u) => u.owner == player) ||
          owners.entries.any(
            (e) => e.value == player && terrainAt(e.key) == Terrain.barracks,
          );
      if (!hasArmy) {
        result.add('${names[player]} needs a unit or a tent to recruit from.');
      }
    }
    final from = castles[0], to = castles[1];
    if (from != null && to != null) {
      final reached = {from};
      final queue = Queue<Pos>()..add(from);
      while (queue.isNotEmpty) {
        for (final n in queue.removeFirst().neighbors) {
          if (inBounds(n) && terrainAt(n).footCost != null && reached.add(n)) {
            queue.add(n);
          }
        }
      }
      if (!reached.contains(to)) {
        result.add('The castles must be connected by land or a bridge.');
      }
    }
    return result;
  }
}
