import 'models.dart';

class Unit {
  final int id;
  final UnitType type;
  final int owner;
  Pos pos;

  /// 1..100. Shown to the player as [displayHp] (1..10).
  int hp;

  /// True once the unit has taken its action this turn.
  bool acted;

  Unit({
    required this.id,
    required this.type,
    required this.owner,
    required this.pos,
    this.hp = 100,
    this.acted = false,
  });

  int get displayHp => (hp + 9) ~/ 10;

  Unit copy() =>
      Unit(id: id, type: type, owner: owner, pos: pos, hp: hp, acted: acted);
}

/// Full state of a two-player match. Mutated only through `apply` in
/// rules.dart; use [copy] to branch (AI search, undo).
class GameState {
  static const maxHp = 100;
  static const incomePerBuilding = 100;
  static const healPerTurn = 20;
  static const capturePoints = 20;

  final int width, height;
  final List<Terrain> terrain;

  /// Owner of each building tile. Absent = neutral.
  final Map<Pos, int> owners;

  /// Remaining capture points of buildings currently being captured.
  final Map<Pos, int> capture;
  final List<Unit> units;
  final List<int> funds;
  int currentPlayer;
  int turn;
  int? winner;
  int nextUnitId;

  GameState({
    required this.width,
    required this.height,
    required this.terrain,
    required this.owners,
    required this.capture,
    required this.units,
    required this.funds,
    this.currentPlayer = 0,
    this.turn = 1,
    this.winner,
    this.nextUnitId = 0,
  });

  /// Builds a fresh match from decoded map JSON:
  /// ```json
  /// {"terrain": ["h.f", "~=~", "..h"],
  ///  "owners": {"0": [[2,2]], "1": [[0,0]]},
  ///  "units": [{"type": "infantry", "owner": 0, "x": 1, "y": 2}],
  ///  "funds": [0, 0]}
  /// ```
  factory GameState.fromMap(Map<String, dynamic> json) {
    final rows = (json['terrain'] as List).cast<String>();
    if (rows.isEmpty || rows.any((r) => r.length != rows.first.length)) {
      throw const FormatException(
        'Terrain rows must be non-empty and equal length',
      );
    }
    final width = rows.first.length;
    final terrain = [
      for (final row in rows)
        for (var x = 0; x < width; x++) Terrain.fromSymbol(row[x]),
    ];
    final state = GameState(
      width: width,
      height: rows.length,
      terrain: terrain,
      owners: {},
      capture: {},
      units: [],
      funds: ((json['funds'] as List?)?.cast<int>() ?? [0, 0]).toList(),
    );
    final owners = (json['owners'] as Map?) ?? const {};
    owners.forEach((player, tiles) {
      for (final t in tiles as List) {
        final p = Pos(t[0] as int, t[1] as int);
        if (!state.inBounds(p) || !state.terrainAt(p).isBuilding) {
          throw FormatException('Owner entry $p is not a building');
        }
        state.owners[p] = int.parse(player as String);
      }
    });
    for (final u in (json['units'] as List?) ?? const []) {
      final p = Pos(u['x'] as int, u['y'] as int);
      final type = UnitType.values.byName(u['type'] as String);
      if (!state.inBounds(p) ||
          state.terrainAt(p).moveCost(type.moveClass) == null ||
          state.unitAt(p) != null) {
        throw FormatException('Unit cannot be placed at $p');
      }
      state.units.add(
        Unit(
          id: state.nextUnitId++,
          type: type,
          owner: u['owner'] as int,
          pos: p,
          hp: (u['hp'] as int?) ?? maxHp,
        ),
      );
    }
    state.beginTurn();
    return state;
  }

  bool inBounds(Pos p) => p.x >= 0 && p.y >= 0 && p.x < width && p.y < height;

  Terrain terrainAt(Pos p) => terrain[p.y * width + p.x];

  Unit? unitAt(Pos p) {
    for (final u in units) {
      if (u.pos == p) return u;
    }
    return null;
  }

  Unit? unitById(int id) {
    for (final u in units) {
      if (u.id == id) return u;
    }
    return null;
  }

  Iterable<Unit> unitsOf(int player) => units.where((u) => u.owner == player);

  int buildingCount(int player) =>
      owners.values.where((o) => o == player).length;

  /// Start-of-turn upkeep for [currentPlayer]: income, healing on owned
  /// buildings, and readying units.
  void beginTurn() {
    funds[currentPlayer] += incomePerBuilding * buildingCount(currentPlayer);
    for (final u in unitsOf(currentPlayer)) {
      u.acted = false;
      if (owners[u.pos] == currentPlayer && u.hp < maxHp) {
        u.hp = (u.hp + healPerTurn).clamp(0, maxHp);
      }
    }
  }

  GameState copy() => GameState(
    width: width,
    height: height,
    terrain: terrain,
    owners: Map.of(owners),
    capture: Map.of(capture),
    units: [for (final u in units) u.copy()],
    funds: List.of(funds),
    currentPlayer: currentPlayer,
    turn: turn,
    winner: winner,
    nextUnitId: nextUnitId,
  );
}
