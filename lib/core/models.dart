/// Static game data: grid positions, terrain and unit types.
///
/// Everything under lib/core is plain Dart with no Flutter/Flame imports so
/// the rules can be unit-tested and simulated headlessly (AI self-play).
library;

class Pos {
  final int x, y;
  const Pos(this.x, this.y);

  int distanceTo(Pos o) => (x - o.x).abs() + (y - o.y).abs();

  List<Pos> get neighbors => [
    Pos(x, y - 1),
    Pos(x + 1, y),
    Pos(x, y + 1),
    Pos(x - 1, y),
  ];

  @override
  bool operator ==(Object other) =>
      other is Pos && other.x == x && other.y == y;

  @override
  int get hashCode => x * 1000 + y;

  @override
  String toString() => '($x,$y)';
}

enum MoveClass { foot, mounted, flying }

enum Terrain {
  plain('.', defense: 1, footCost: 1, mountedCost: 1),
  forest('f', defense: 2, footCost: 2, mountedCost: 3),
  mountain('^', defense: 4, footCost: 3, mountedCost: null),
  water('~', defense: 0, footCost: null, mountedCost: null),
  bridge('=', defense: 0, footCost: 1, mountedCost: 1),
  city('c', defense: 3, footCost: 1, mountedCost: 1),
  barracks('b', defense: 3, footCost: 1, mountedCost: 1),
  hq('h', defense: 4, footCost: 1, mountedCost: 1);

  const Terrain(
    this.symbol, {
    required this.defense,
    required this.footCost,
    required this.mountedCost,
  });

  /// Character used in map files.
  final String symbol;

  /// Each point reduces incoming damage by 10% (ignored by flying units).
  final int defense;
  final int? footCost;
  final int? mountedCost;

  /// Movement points to enter this tile, or null if impassable.
  int? moveCost(MoveClass c) => switch (c) {
    MoveClass.foot => footCost,
    MoveClass.mounted => mountedCost,
    MoveClass.flying => 1,
  };

  /// Buildings can be owned, give income and heal their owner's units.
  bool get isBuilding => this == city || this == barracks || this == hq;

  static Terrain fromSymbol(String s) => values.firstWhere(
    (t) => t.symbol == s,
    orElse: () => throw FormatException('Unknown terrain symbol "$s"'),
  );
}

enum UnitType {
  infantry(
    cost: 100,
    move: 3,
    moveClass: MoveClass.foot,
    vision: 2,
    canCapture: true,
  ),
  spearman(
    cost: 200,
    move: 3,
    moveClass: MoveClass.foot,
    vision: 2,
    canCapture: true,
  ),
  archer(
    cost: 300,
    move: 3,
    moveClass: MoveClass.foot,
    vision: 3,
    minRange: 2,
    maxRange: 2,
  ),
  knight(cost: 500, move: 5, moveClass: MoveClass.mounted, vision: 3),
  catapult(
    cost: 600,
    move: 3,
    moveClass: MoveClass.mounted,
    vision: 2,
    minRange: 2,
    maxRange: 4,
    siege: true,
  ),
  griffin(cost: 800, move: 6, moveClass: MoveClass.flying, vision: 4),
  monk(cost: 300, move: 4, moveClass: MoveClass.foot, vision: 2, canHeal: true);

  const UnitType({
    required this.cost,
    required this.move,
    required this.moveClass,
    required this.vision,
    this.minRange = 1,
    this.maxRange = 1,
    this.canCapture = false,
    this.canHeal = false,
    this.siege = false,
  });

  final int cost;
  final int move;
  final MoveClass moveClass;

  /// How far the unit sees through fog of war.
  final int vision;
  final int minRange;
  final int maxRange;
  final bool canCapture;

  /// Can restore HP to an adjacent ally instead of attacking.
  final bool canHeal;

  /// Siege units cannot move and attack in the same turn and never counter.
  final bool siege;

  /// HP a healer restores (out of 100).
  static const healAmount = 30;

  // Rows = attacker, columns = defender, in enum order. Percent of a full
  // unit's HP dealt by a full-HP attacker on 0-defense terrain.
  static const _damage = [
    // inf spear arch knight cata griffin monk
    [55, 45, 65, 20, 35, 10, 60], // infantry
    [60, 50, 70, 75, 50, 15, 65], // spearman
    [60, 55, 50, 40, 45, 85, 70], // archer
    [80, 45, 90, 50, 80, 30, 85], // knight
    [85, 80, 85, 65, 60, 0, 80], // catapult
    [70, 65, 60, 60, 85, 50, 75], // griffin
    [0, 0, 0, 0, 0, 0, 0], // monk
  ];

  int baseDamage(UnitType defender) => _damage[index][defender.index];

  bool get canAttack => _damage[index].any((d) => d > 0);
}

/// A side's leader. Fighting charges the commander's meter; when it is full
/// the player may unleash the commander's power once.
enum Commander {
  warden('Aldric the Warden', 'Rally', 'All your units recover 3 HP.'),
  bold('Brenna the Bold', 'Fury', 'Your units deal 30% more damage this turn.'),
  swift(
    'Corvin the Swift',
    'Forced March',
    'Your units move 2 tiles farther this turn.',
  );

  const Commander(this.title, this.power, this.description);

  final String title;
  final String power;
  final String description;

  static const maxCharge = 100;
}
