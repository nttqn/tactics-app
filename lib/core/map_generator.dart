import 'dart:collection';

import 'models.dart';

/// Recipe for a generated battlefield. The same spec always produces the
/// same map, on every platform and SDK version.
class MapSpec {
  final int seed;
  final int width;

  /// Must be even: the map is its own 180-degree rotation.
  final int height;

  /// Crossings over the central river; 0 means no river.
  final int bridges;
  final int citiesPerSide;

  /// Percent of open tiles turned into forest / mountain.
  final int forest;
  final int mountain;

  /// Starting gold and armies, indexed by player.
  final List<int> funds;
  final List<List<UnitType>> units;

  const MapSpec({
    required this.seed,
    this.width = 8,
    this.height = 12,
    this.bridges = 2,
    this.citiesPerSide = 3,
    this.forest = 14,
    this.mountain = 8,
    this.funds = const [0, 0],
    this.units = const [
      [UnitType.infantry, UnitType.infantry],
      [UnitType.infantry, UnitType.infantry],
    ],
  });
}

/// Park-Miller generator. dart:math's seeded Random is not guaranteed stable
/// across SDK releases, which would silently reshuffle every saved level.
class _Rng {
  int _state;
  _Rng(int seed) : _state = (seed * 7919 + 104729) % 2147483646 + 1 {
    for (var i = 0; i < 4; i++) {
      next(10);
    }
  }

  int next(int max) {
    _state = _state * 48271 % 2147483647;
    return _state % max;
  }
}

/// Builds map JSON (the format `GameState.fromMap` reads) from [spec].
Map<String, dynamic> generateMap(MapSpec spec) {
  assert(spec.height.isEven && spec.height >= 6 && spec.width >= 5);
  for (var attempt = 0; attempt < 200; attempt++) {
    final map = _tryGenerate(spec, _Rng(spec.seed * 211 + attempt));
    if (map != null) return map;
  }
  throw StateError('Could not generate a playable map for seed ${spec.seed}');
}

Map<String, dynamic>? _tryGenerate(MapSpec spec, _Rng rng) {
  final w = spec.width, h = spec.height, half = h ~/ 2;
  final grid = List.generate(h, (_) => List.filled(w, Terrain.plain));
  Pos mirror(Pos p) => Pos(w - 1 - p.x, h - 1 - p.y);
  bool inBounds(Pos p) => p.x >= 0 && p.y >= 0 && p.x < w && p.y < h;
  Terrain at(Pos p) => grid[p.y][p.x];

  // Rows the far side may decorate; the river takes the middle two.
  final rows = spec.bridges > 0 ? half - 1 : half;
  if (spec.bridges > 0) {
    final columns = <int>{};
    if (spec.bridges.isOdd && w.isOdd) columns.add(w ~/ 2);
    var guard = 0;
    while (columns.length < spec.bridges && guard++ < 100) {
      final x = rng.next(w ~/ 2);
      columns
        ..add(x)
        ..add(w - 1 - x);
    }
    for (var x = 0; x < w; x++) {
      grid[half - 1][x] = columns.contains(x) ? Terrain.bridge : Terrain.water;
    }
  }

  Pos randomTile() => Pos(rng.next(w), rng.next(rows));

  final hq = Pos(rng.next(w), 0);
  grid[hq.y][hq.x] = Terrain.hq;

  Pos? place(Terrain terrain, bool Function(Pos) ok) {
    for (var i = 0; i < 300; i++) {
      final p = randomTile();
      if (at(p) == Terrain.plain && ok(p)) {
        grid[p.y][p.x] = terrain;
        return p;
      }
    }
    return null;
  }

  final barracks = place(Terrain.barracks, (p) {
    final d = p.distanceTo(hq);
    return d >= 2 && d <= 3;
  });
  if (barracks == null) return null;

  final cities = <Pos>[];
  for (var i = 0; i < spec.citiesPerSide; i++) {
    final city = place(
      Terrain.city,
      (p) =>
          p.distanceTo(hq) >= 2 &&
          p.distanceTo(barracks) >= 2 &&
          cities.every((c) => c.distanceTo(p) >= 2),
    );
    if (city == null) return null;
    cities.add(city);
  }

  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < w; x++) {
      final p = Pos(x, y);
      if (at(p) != Terrain.plain) continue;
      // Leave room to deploy around the HQ and barracks.
      if (p.distanceTo(hq) <= 1 || p.distanceTo(barracks) <= 1) continue;
      final roll = rng.next(100);
      if (roll < spec.forest) {
        grid[y][x] = Terrain.forest;
      } else if (roll < spec.forest + spec.mountain) {
        grid[y][x] = Terrain.mountain;
      }
    }
  }

  for (var y = 0; y < half; y++) {
    for (var x = 0; x < w; x++) {
      final m = mirror(Pos(x, y));
      grid[m.y][m.x] = grid[y][x];
    }
  }

  // Every building must be reachable on foot from both HQs.
  final reached = <Pos>{hq};
  final queue = Queue<Pos>()..add(hq);
  while (queue.isNotEmpty) {
    for (final n in queue.removeFirst().neighbors) {
      if (inBounds(n) && at(n).footCost != null && reached.add(n)) queue.add(n);
    }
  }
  for (final b in [barracks, ...cities]) {
    if (!reached.contains(b) || !reached.contains(mirror(b))) return null;
  }
  if (!reached.contains(mirror(hq))) return null;

  // Deploy each army on the open tiles nearest its HQ. Slots are computed
  // once on the far side and mirrored so both players get the same layout.
  final slots =
      [
        for (var y = 0; y < rows; y++)
          for (var x = 0; x < w; x++)
            if (grid[y][x] == Terrain.plain) Pos(x, y),
      ]..sort((a, b) {
        final d = a.distanceTo(hq).compareTo(b.distanceTo(hq));
        return d != 0 ? d : (a.y * w + a.x).compareTo(b.y * w + b.x);
      });
  if (slots.length < spec.units[0].length ||
      slots.length < spec.units[1].length) {
    return null;
  }

  final units = <Map<String, dynamic>>[];
  for (var player = 0; player < 2; player++) {
    for (var i = 0; i < spec.units[player].length; i++) {
      final p = player == 1 ? slots[i] : mirror(slots[i]);
      units.add({
        'type': spec.units[player][i].name,
        'owner': player,
        'x': p.x,
        'y': p.y,
      });
    }
  }

  List<int> xy(Pos p) => [p.x, p.y];
  return {
    'terrain': [for (final row in grid) row.map((t) => t.symbol).join()],
    'owners': {
      '0': [xy(mirror(hq)), xy(mirror(barracks))],
      '1': [xy(hq), xy(barracks)],
    },
    'units': units,
    'funds': spec.funds,
  };
}
