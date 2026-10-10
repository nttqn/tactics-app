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
  /// Where [unit] can go this turn. Friendly units can be passed through but
  /// not stopped on; enemy units block.
  MoveMap reachable(Unit unit) {
    final occupied = {for (final u in units) u.pos: u};
    final move = unit.type.move;
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
          if (other != null && other.owner != unit.owner) continue;
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
        if (p == unit.pos || !occupied.containsKey(p)) p,
    };
    return MoveMap._(unit.pos, cost, prev, destinations);
  }

  /// Whether [unit], standing on [from] this turn, may attack [target].
  bool canAttack(Unit unit, Pos from, Unit target) {
    if (target.owner == unit.owner) return false;
    if (unit.type.siege && from != unit.pos) return false;
    if (unit.type.baseDamage(target.type) == 0) return false;
    final d = from.distanceTo(target.pos);
    return d >= unit.type.minRange && d <= unit.type.maxRange;
  }

  List<Unit> attackTargets(Unit unit, Pos from) => [
    for (final t in units)
      if (canAttack(unit, from, t)) t,
  ];

  bool canCaptureAt(Unit unit, Pos at) =>
      unit.type.canCapture &&
      terrainAt(at).isBuilding &&
      owners[at] != unit.owner;

  /// Damage (in HP, 0..100) an [attackerType] at [attackerHp] deals to
  /// [defender] where it stands.
  int damageTo(UnitType attackerType, int attackerHp, Unit defender) {
    final stars = defender.type.moveClass == MoveClass.flying
        ? 0
        : terrainAt(defender.pos).defense;
    final displayHp = (attackerHp + 9) ~/ 10;
    return attackerType.baseDamage(defender.type) *
        displayHp *
        (100 - 10 * stars) ~/
        1000;
  }

  /// Outcome of [attacker] striking [defender] from [from], without mutating.
  CombatForecast forecast(Unit attacker, Pos from, Unit defender) {
    final damage = damageTo(attacker.type, attacker.hp, defender);
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
    return CombatForecast(damage, damageTo(defender.type, defenderHp, moved));
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
      }
    }
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
      case EndTurnAction():
        currentPlayer = 1 - currentPlayer;
        if (currentPlayer == 0) turn++;
        beginTurn();
        events.add(TurnStarted(currentPlayer));
    }
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
    }

    if (action.to != unit.pos) {
      // Leaving a half-captured building abandons the capture.
      capture.remove(unit.pos);
      events.add(UnitMoved(unit.id, moves.pathTo(action.to)));
      unit.pos = action.to;
    }
    unit.acted = true;

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
    to.hp -= amount;
    events.add(UnitDamaged(from.id, to.id, amount, isCounter: isCounter));
    if (to.hp <= 0) {
      units.remove(to);
      capture.remove(to.pos);
      events.add(UnitDied(to.id, to.pos));
    }
  }
}
