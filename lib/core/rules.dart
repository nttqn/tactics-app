import 'actions.dart';
import 'game_state.dart';
import 'models.dart';

/// Result of a movement search from a unit's tile.
class MoveMap {
  final Pos origin;

  /// Movement cost to every tile the unit can pass through.
  final Map<Pos, int> cost;
  final Map<Pos, Pos> _prev;

  /// Tiles the unit may end its move on (includes [origin]).
  final Set<Pos> destinations;

  MoveMap._(this.origin, this.cost, this._prev, this.destinations);

  /// Tiles from [origin] to [to], inclusive.
  List<Pos> pathTo(Pos to) {
    final path = [to];
    var p = to;
    while (p != origin) {
      p = _prev[p]!;
      path.add(p);
    }
    return path.reversed.toList();
  }
}

class CombatForecast {
  final int damage;

  /// 0 when the defender dies or cannot strike back.
  final int counter;
  const CombatForecast(this.damage, this.counter);
}

extension GameRules on GameState {
  /// Tiles [player] can see. Everything when fog of war is off.
  Set<Pos> visibleTo(int player) => visionCache.putIfAbsent(player, () {
    final seen = <Pos>{};
    void look(Pos centre, int radius) {
      for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          final p = Pos(centre.x + dx, centre.y + dy);
          if (dx.abs() + dy.abs() <= radius && inBounds(p)) seen.add(p);
        }
      }
    }

    for (final u in unitsOf(player)) {
      // High ground lets ground units see one tile farther.
      final onPeak =
          terrainAt(u.pos) == Terrain.mountain &&
          u.type.moveClass != MoveClass.flying;
      look(u.pos, u.type.vision + (onPeak ? 1 : 0));
    }
    owners.forEach((p, owner) {
      if (owner == player) look(p, 1);
    });
    return seen;
  });

  bool isVisible(int player, Pos p) => !fog || visibleTo(player).contains(p);

  bool _powerOn(int player, Commander commander) =>
      powerActive[player] && commanders[player] == commander;

  int moveRange(Unit unit) =>
      unit.type.move + (_powerOn(unit.owner, Commander.swift) ? 2 : 0);

  /// Where [unit] can go this turn. Friendly units can be passed through but
  /// not stopped on; enemy units block. Under fog, enemies the player cannot
  /// see do not block here; running into one ambushes the move in [apply].
  MoveMap reachable(Unit unit) {
    final occupied = {for (final u in units) u.pos: u};
    bool blocking(Unit other) =>
        other.owner != unit.owner && isVisible(unit.owner, other.pos);
    final move = moveRange(unit);
    final cost = <Pos, int>{unit.pos: 0};
    final prev = <Pos, Pos>{};
    // Bucket queue: every step costs at least 1, so tiles are only ever
    // pushed into later buckets.
    final buckets = List.generate(move + 1, (_) => <Pos>[]);
    buckets[0].add(unit.pos);
    for (var c = 0; c <= move; c++) {
      for (final p in buckets[c]) {
        if (cost[p] != c) continue;
        for (final n in p.neighbors) {
          if (!inBounds(n)) continue;
          final step = terrainAt(n).moveCost(unit.type.moveClass);
          if (step == null || c + step > move) continue;
          final other = occupied[n];
          if (other != null && blocking(other)) continue;
          final known = cost[n];
          if (known != null && known <= c + step) continue;
          cost[n] = c + step;
          prev[n] = p;
          buckets[c + step].add(n);
        }
      }
    }
    final destinations = {
      for (final p in cost.keys)
        if (p == unit.pos ||
            occupied[p] == null ||
            (occupied[p]!.owner != unit.owner && !blocking(occupied[p]!)))
          p,
    };
    return MoveMap._(unit.pos, cost, prev, destinations);
  }

  /// Whether [unit], standing on [from] this turn, may attack [target].
  bool canAttack(Unit unit, Pos from, Unit target) {
    if (target.owner == unit.owner) return false;
    if (unit.type.siege && from != unit.pos) return false;
    if (!isVisible(unit.owner, target.pos)) return false;
    if (unit.type.baseDamage(target.type) == 0) return false;
    final d = from.distanceTo(target.pos);
    return d >= unit.type.minRange && d <= unit.type.maxRange;
  }

  List<Unit> attackTargets(Unit unit, Pos from) => [
    for (final t in units)
      if (canAttack(unit, from, t)) t,
  ];

  /// Whether [unit], standing on [from], may heal the ally [target].
  bool canHeal(Unit unit, Pos from, Unit target) =>
      unit.type.canHeal &&
      target.owner == unit.owner &&
      target.id != unit.id &&
      target.hp < GameState.maxHp &&
      from.distanceTo(target.pos) == 1;

  List<Unit> healTargets(Unit unit, Pos from) => [
    for (final t in units)
      if (canHeal(unit, from, t)) t,
  ];

  bool get canUsePower =>
      winner == null &&
      commanders[currentPlayer] != null &&
      charge[currentPlayer] >= Commander.maxCharge &&
      !powerActive[currentPlayer];

  bool canCaptureAt(Unit unit, Pos at) =>
      unit.type.canCapture &&
      terrainAt(at).isBuilding &&
      owners[at] != unit.owner;

  /// Damage (in HP, 0..100) [attacker], at [attackerHp], deals to
  /// [defender] where it stands. Veteran ranks and the Fury power add to it.
  int damageTo(Unit attacker, int attackerHp, Unit defender) {
    final stars = defender.type.moveClass == MoveClass.flying
        ? 0
        : terrainAt(defender.pos).defense;
    final displayHp = (attackerHp + 9) ~/ 10;
    final bonus =
        100 +
        10 * attacker.rank +
        (_powerOn(attacker.owner, Commander.bold) ? 30 : 0);
    return attacker.type.baseDamage(defender.type) *
        displayHp *
        (100 - 10 * stars) *
        bonus ~/
        100000;
  }

  /// Outcome of [attacker] striking [defender] from [from], without mutating.
  CombatForecast forecast(Unit attacker, Pos from, Unit defender) {
    final damage = damageTo(attacker, attacker.hp, defender);
    final defenderHp = defender.hp - damage;
    if (defenderHp <= 0) return CombatForecast(damage, 0);
    final d = from.distanceTo(defender.pos);
    final canCounter =
        !defender.type.siege &&
        d >= defender.type.minRange &&
        d <= defender.type.maxRange;
    if (!canCounter) return CombatForecast(damage, 0);
    // The counter is computed against the attacker's destination tile.
    final moved = attacker.copy()..pos = from;
    return CombatForecast(damage, damageTo(defender, defenderHp, moved));
  }

  List<UnitType> buildableAt(Pos at) {
    if (terrainAt(at) != Terrain.barracks ||
        owners[at] != currentPlayer ||
        unitAt(at) != null) {
      return const [];
    }
    return [
      for (final t in UnitType.values)
        if (t.cost <= funds[currentPlayer]) t,
    ];
  }

  /// Every action the current player may take right now.
  List<GameAction> legalActions() {
    if (winner != null) return const [];
    final actions = <GameAction>[];
    for (final unit in unitsOf(currentPlayer)) {
      if (unit.acted) continue;
      for (final to in reachable(unit).destinations) {
        actions.add(UnitAction(unit.id, to, ActionKind.wait));
        if (canCaptureAt(unit, to)) {
          actions.add(UnitAction(unit.id, to, ActionKind.capture));
        }
        for (final t in attackTargets(unit, to)) {
          actions.add(UnitAction(unit.id, to, ActionKind.attack, t.pos));
        }
        for (final t in healTargets(unit, to)) {
          actions.add(UnitAction(unit.id, to, ActionKind.heal, t.pos));
        }
      }
    }
    if (canUsePower) actions.add(const UsePowerAction());
    owners.forEach((at, owner) {
      if (owner != currentPlayer) return;
      for (final type in buildableAt(at)) {
        actions.add(BuildAction(at, type));
      }
    });
    actions.add(const EndTurnAction());
    return actions;
  }

  /// Validates and performs [action]. Throws [ArgumentError] if it is illegal,
  /// leaving the state untouched.
  List<GameEvent> apply(GameAction action) {
    if (winner != null) throw StateError('Game is over');
    visionCache.clear();
    final events = <GameEvent>[];
    switch (action) {
      case UnitAction():
        _applyUnitAction(action, events);
      case BuildAction():
        if (!inBounds(action.at) ||
            !buildableAt(action.at).contains(action.type)) {
          throw ArgumentError('Cannot build: $action');
        }
        funds[currentPlayer] -= action.type.cost;
        final unit = Unit(
          id: nextUnitId++,
          type: action.type,
          owner: currentPlayer,
          pos: action.at,
          acted: true,
        );
        units.add(unit);
        events.add(UnitBuilt(unit.id));
      case UsePowerAction():
        if (!canUsePower) throw ArgumentError('Power is not ready');
        final commander = commanders[currentPlayer]!;
        charge[currentPlayer] = 0;
        powerActive[currentPlayer] = true;
        events.add(PowerUsed(currentPlayer, commander));
        if (commander == Commander.warden) {
          for (final u in unitsOf(currentPlayer)) {
            final amount = (GameState.maxHp - u.hp).clamp(0, 30);
            if (amount == 0) continue;
            u.hp += amount;
            events.add(UnitHealed(-1, u.id, amount));
          }
        }
      case EndTurnAction():
        powerActive[currentPlayer] = false;
        currentPlayer = 1 - currentPlayer;
        if (currentPlayer == 0) turn++;
        beginTurn();
        events.add(TurnStarted(currentPlayer));
    }
    visionCache.clear();
    if (winner != null) events.add(GameOver(winner!));
    return events;
  }

  void _applyUnitAction(UnitAction action, List<GameEvent> events) {
    final unit = unitById(action.unitId);
    if (unit == null || unit.owner != currentPlayer || unit.acted) {
      throw ArgumentError('Unit cannot act: $action');
    }
    final moves = reachable(unit);
    if (!moves.destinations.contains(action.to)) {
      throw ArgumentError('Unreachable destination: $action');
    }
    Unit? target;
    switch (action.kind) {
      case ActionKind.wait:
        break;
      case ActionKind.attack:
        target = action.target == null ? null : unitAt(action.target!);
        if (target == null || !canAttack(unit, action.to, target)) {
          throw ArgumentError('Invalid attack: $action');
        }
      case ActionKind.capture:
        if (!canCaptureAt(unit, action.to)) {
          throw ArgumentError('Invalid capture: $action');
        }
      case ActionKind.heal:
        target = action.target == null ? null : unitAt(action.target!);
        if (target == null || !canHeal(unit, action.to, target)) {
          throw ArgumentError('Invalid heal: $action');
        }
    }

    if (action.to != unit.pos) {
      var path = moves.pathTo(action.to);
      Pos? ambusher;
      for (var i = 1; i < path.length; i++) {
        final other = unitAt(path[i]);
        if (other == null || other.owner == unit.owner) continue;
        // A hidden enemy blocks the way: stop on the last free tile before it.
        ambusher = path[i];
        var j = i - 1;
        while (j > 0 && unitAt(path[j]) != null) {
          j--;
        }
        path = path.sublist(0, j + 1);
        break;
      }
      if (path.length > 1) {
        // Leaving a half-captured building abandons the capture.
        capture.remove(unit.pos);
        events.add(UnitMoved(unit.id, path));
        unit.pos = path.last;
      }
      if (ambusher != null) {
        unit.acted = true;
        events.add(Ambushed(unit.id, unit.pos, ambusher));
        return;
      }
    }
    unit.acted = true;

    if (action.kind == ActionKind.heal) {
      final amount = (GameState.maxHp - target!.hp).clamp(
        0,
        UnitType.healAmount,
      );
      target.hp += amount;
      events.add(UnitHealed(unit.id, target.id, amount));
      return;
    }

    if (target != null) {
      final result = forecast(unit, unit.pos, target);
      _damage(unit, target, result.damage, events, isCounter: false);
      if (result.counter > 0) {
        _damage(target, unit, result.counter, events, isCounter: true);
      }
      for (var p = 0; p < 2; p++) {
        if (unitsOf(p).isEmpty) winner = 1 - p;
      }
    } else if (action.kind == ActionKind.capture) {
      final remaining =
          (capture[unit.pos] ?? GameState.capturePoints) - unit.displayHp;
      if (remaining > 0) {
        capture[unit.pos] = remaining;
        events.add(CaptureProgressed(unit.pos, remaining));
      } else {
        capture.remove(unit.pos);
        owners[unit.pos] = unit.owner;
        events.add(BuildingCaptured(unit.pos, unit.owner));
        if (terrainAt(unit.pos) == Terrain.hq) winner = unit.owner;
      }
    }
  }

  void _damage(
    Unit from,
    Unit to,
    int amount,
    List<GameEvent> events, {
    required bool isCounter,
  }) {
    // Fighting charges both commanders; the side taking the beating more.
    final dealt = amount.clamp(0, to.hp);
    _addCharge(from.owner, dealt * 2 ~/ 5);
    _addCharge(to.owner, dealt * 3 ~/ 5);
    to.hp -= amount;
    events.add(UnitDamaged(from.id, to.id, amount, isCounter: isCounter));
    if (to.hp <= 0) {
      units.remove(to);
      capture.remove(to.pos);
      events.add(UnitDied(to.id, to.pos, to.owner));
      if (from.rank < Unit.maxRank) {
        from.rank++;
        events.add(UnitPromoted(from.id, from.rank));
      }
    }
  }
}

extension on GameState {
  void _addCharge(int player, int amount) {
    if (commanders[player] == null) return;
    charge[player] = (charge[player] + amount).clamp(0, Commander.maxCharge);
  }
}
