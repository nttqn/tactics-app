import 'models.dart';

class Unit {
  static const maxRank = 3;

  final int id;
  final UnitType type;
  final int owner;
  Pos pos;

  /// 1..100. Shown to the player as [displayHp] (1..10).
  int hp;

  /// True once the unit has taken its action this turn.
  bool acted;

  /// Veterancy, 0..[maxRank]; each kill adds one and every rank adds 10%
  /// damage.
  int rank;

  Unit({
    required this.id,
    required this.type,
    required this.owner,
    required this.pos,
    this.hp = 100,
    this.acted = false,
    this.rank = 0,
  });

  int get displayHp => (hp + 9) ~/ 10;

  Unit copy() => Unit(
    id: id,
    type: type,
    owner: owner,
    pos: pos,
    hp: hp,
    acted: acted,
    rank: rank,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'owner': owner,
    'x': pos.x,
    'y': pos.y,
    'hp': hp,
    'acted': acted,
    'rank': rank,
  };

  factory Unit.fromJson(Map<String, dynamic> j) => Unit(
    id: j['id'] as int,
    type: UnitType.values.byName(j['type'] as String),
    owner: j['owner'] as int,
    pos: Pos(j['x'] as int, j['y'] as int),
    hp: j['hp'] as int,
    acted: j['acted'] as bool,
    rank: (j['rank'] as int?) ?? 0,
  );
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

  /// When true, each side only sees what its units and buildings see.
  final bool fog;

  /// Each side's leader, or null for a match without commander powers.
  final List<Commander?> commanders;

  /// Commander meters, 0..[Commander.maxCharge].
  final List<int> charge;

  /// Whether a side's power is in effect for the rest of its turn.
  final List<bool> powerActive;
  int currentPlayer;
  int turn;
  int? winner;
  int nextUnitId;

  /// Tiles each player can see; filled lazily by the rules and cleared on
  /// every change.
  final Map<int, Set<Pos>> visionCache = {};

  GameState({
    required this.width,
    required this.height,
    required this.terrain,
    required this.owners,
    required this.capture,
    required this.units,
    required this.funds,
    this.fog = false,
    List<Commander?>? commanders,
    List<int>? charge,
    List<bool>? powerActive,
    this.currentPlayer = 0,
    this.turn = 1,
    this.winner,
    this.nextUnitId = 0,
  }) : commanders = commanders ?? [null, null],
       charge = charge ?? [0, 0],
       powerActive = powerActive ?? [false, false];

  /// Builds a fresh match from decoded map JSON:
  /// ```json
  /// {"terrain": ["h.f", "~=~", "..h"],
  ///  "owners": {"0": [[2,2]], "1": [[0,0]]},
  ///  "units": [{"type": "infantry", "owner": 0, "x": 1, "y": 2}],
  ///  "funds": [0, 0], "fog": false, "commanders": ["warden", "bold"]}
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
      fog: (json['fog'] as bool?) ?? false,
      commanders: _commanders(json['commanders']),
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

  static List<Commander?> _commanders(Object? json) {
    final list = (json as List?) ?? const [null, null];
    return [
      for (var i = 0; i < 2; i++)
        i < list.length && list[i] != null
            ? Commander.values.byName(list[i] as String)
            : null,
    ];
  }

  /// Everything needed to resume this match later with [GameState.fromSave].
  Map<String, dynamic> toSave() => {
    'width': width,
    'terrain': [
      for (var y = 0; y < height; y++)
        [for (var x = 0; x < width; x++) terrainAt(Pos(x, y)).symbol].join(),
    ],
    'owners': [
      for (final e in owners.entries) [e.key.x, e.key.y, e.value],
    ],
    'capture': [
      for (final e in capture.entries) [e.key.x, e.key.y, e.value],
    ],
    'units': [for (final u in units) u.toJson()],
    'funds': funds,
    'fog': fog,
    'commanders': [for (final c in commanders) c?.name],
    'charge': charge,
    'powerActive': powerActive,
    'currentPlayer': currentPlayer,
    'turn': turn,
    'winner': winner,
    'nextUnitId': nextUnitId,
  };

  factory GameState.fromSave(Map<String, dynamic> j) {
    final rows = (j['terrain'] as List).cast<String>();
    Map<Pos, int> tiles(Object? list) => {
      for (final t in (list as List).cast<List>())
        Pos(t[0] as int, t[1] as int): t[2] as int,
    };
    return GameState(
      width: rows.first.length,
      height: rows.length,
      terrain: [
        for (final row in rows)
          for (var x = 0; x < row.length; x++) Terrain.fromSymbol(row[x]),
      ],
      owners: tiles(j['owners']),
      capture: tiles(j['capture']),
      units: [
        for (final u in (j['units'] as List).cast<Map<String, dynamic>>())
          Unit.fromJson(u),
      ],
      funds: (j['funds'] as List).cast<int>().toList(),
      fog: j['fog'] as bool,
      commanders: _commanders(j['commanders']),
      charge: (j['charge'] as List).cast<int>().toList(),
      powerActive: (j['powerActive'] as List).cast<bool>().toList(),
      currentPlayer: j['currentPlayer'] as int,
      turn: j['turn'] as int,
      winner: j['winner'] as int?,
      nextUnitId: j['nextUnitId'] as int,
    );
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
    visionCache.clear();
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
    fog: fog,
    commanders: List.of(commanders),
    charge: List.of(charge),
    powerActive: List.of(powerActive),
    currentPlayer: currentPlayer,
    turn: turn,
    winner: winner,
    nextUnitId: nextUnitId,
  );
}
