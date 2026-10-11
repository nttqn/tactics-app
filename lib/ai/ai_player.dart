import 'dart:collection';
import 'dart:math';

import '../core/actions.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/rules.dart';

enum AiLevel { easy, normal, hard }

/// Utility-based opponent. Each call to [nextAction] scores every action of
/// every ready unit and returns the single best one, so the caller can pace
/// and animate the turn one action at a time. Scores are roughly in gold.
class AiPlayer {
  AiPlayer(this.level, {Random? random}) : _random = random ?? Random();

  final AiLevel level;
  final Random _random;

  static const _unreachable = 1 << 20;

  /// Random jitter added to every score; makes weaker levels sloppy.
  double get _noise => switch (level) {
    AiLevel.easy => 60,
    AiLevel.normal => 8,
    AiLevel.hard => 2,
  };

  /// How much expected enemy damage next turn weighs against a tile.
  double get _caution => switch (level) {
    AiLevel.easy => 0,
    AiLevel.normal => 0.15,
    AiLevel.hard => 0.35,
  };

  GameAction nextAction(GameState s) {
    final me = s.currentPlayer;
    final ready = [
      for (final u in s.unitsOf(me))
        if (!u.acted) u,
    ];
    if (ready.isEmpty) return _chooseBuild(s, me) ?? const EndTurnAction();
    if (s.canUsePower && _wantsPower(s, me, ready)) {
      return const UsePowerAction();
    }

    final objectives = _assignObjectives(s, me, ready);
    final threats = _caution == 0 ? const <_Threat>[] : _threats(s, me);
    _guardTile = level == AiLevel.easy ? null : _hqToGuard(s, me);
    UnitAction? best;
    var bestScore = double.negativeInfinity;
    void consider(UnitAction action, double score) {
      score += _random.nextDouble() * _noise;
      if (score > bestScore) {
        bestScore = score;
        best = action;
      }
    }

    for (final unit in ready) {
      final objective = objectives[unit.id];
      final distTo = objective == null
          ? null
          : _distances(s, objective, unit.type.moveClass, reverse: true);
      for (final to in s.reachable(unit).destinations) {
        final position = _positional(s, unit, to, distTo, threats);
        consider(UnitAction(unit.id, to, ActionKind.wait), position);
        if (s.canCaptureAt(unit, to)) {
          consider(
            UnitAction(unit.id, to, ActionKind.capture),
            position + _captureValue(s, unit, to),
          );
        }
        for (final target in s.attackTargets(unit, to)) {
          consider(
            UnitAction(unit.id, to, ActionKind.attack, target.pos),
            position * 0.5 + _attackValue(s, unit, to, target),
          );
        }
        for (final ally in s.healTargets(unit, to)) {
          final restored = min(UnitType.healAmount, 100 - ally.hp);
          consider(
            UnitAction(unit.id, to, ActionKind.heal, ally.pos),
            position + restored / 100 * ally.type.cost * 1.1,
          );
        }
      }
    }
    return best!;
  }

  /// Fire the commander power at the start of a turn when it will pay off.
  bool _wantsPower(GameState s, int me, List<Unit> ready) {
    if (s.commanders[me] == Commander.warden) {
      final missing = s
          .unitsOf(me)
          .fold<int>(0, (sum, u) => sum + min(30, 100 - u.hp));
      return missing >= 90;
    }
    return ready.length >= 2;
  }

  /// Our HQ, when an enemy that can capture it is close. A unit standing on
  /// the HQ makes it impossible to take.
  Pos? _guardTile;

  Pos? _hqToGuard(GameState s, int me) {
    for (final entry in s.owners.entries) {
      if (entry.value != me || s.terrainAt(entry.key) != Terrain.hq) continue;
      final hq = entry.key;
      final threatened = s
          .unitsOf(1 - me)
          .any((e) => e.type.canCapture && e.pos.distanceTo(hq) <= 5);
      return threatened ? hq : null;
    }
    return null;
  }

  double _captureValue(GameState s, Unit unit, Pos to) {
    final remaining =
        (to == unit.pos ? s.capture[to] : null) ?? GameState.capturePoints;
    final completes = remaining - unit.displayHp <= 0;
    if (s.terrainAt(to) == Terrain.hq) return completes ? 1e6 : 400;
    return completes ? 300 : 150;
  }

  double _attackValue(GameState s, Unit unit, Pos from, Unit target) {
    final f = s.forecast(unit, from, target);
    final kills = f.damage >= target.hp;
    final dealt = min(f.damage, target.hp) / 100 * target.type.cost;
    final taken = level == AiLevel.easy
        ? 0.0
        : min(f.counter, unit.hp) / 100 * unit.type.cost;
    var value = dealt * 1.2 - taken;
    if (kills) value += 30;
    // Stopping a capture is worth far more than the unit itself, most of
    // all on our own HQ.
    if (s.capture.containsKey(target.pos)) {
      final stake = s.terrainAt(target.pos) == Terrain.hq ? 600.0 : 150.0;
      value += kills ? stake : stake * f.damage / target.hp / 2;
    }
    return value;
  }

  double _positional(
    GameState s,
    Unit unit,
    Pos to,
    List<int>? distTo,
    List<_Threat> threats,
  ) {
    final terrain = s.terrainAt(to);
    var value = 0.0;
    if (distTo != null) {
      var d = distTo[to.y * s.width + to.x];
      if (d >= _unreachable) d = 40;
      // Ranged units want to stand at firing distance, not next to it.
      if (unit.type.maxRange > 1) d = (d - unit.type.maxRange).abs();
      value -= d * 8;
    }
    if (unit.type.moveClass != MoveClass.flying) value += terrain.defense * 2;
    // Keep our own barracks free so it can recruit.
    if (terrain == Terrain.barracks && s.owners[to] == unit.owner) value -= 25;
    if (to == _guardTile) value += 200;
    if (threats.isNotEmpty) {
      final moved = unit.copy()..pos = to;
      var damage = 0;
      for (final t in threats) {
        if (t.tiles.contains(to)) {
          damage += s.damageTo(t.unit, t.unit.hp, moved);
        }
      }
      value -= min(damage, unit.hp) / 100 * unit.type.cost * _caution;
    }
    return value;
  }

  /// Where each ready unit should be heading: an unowned building for
  /// capturers (one unit per building), the juiciest enemy for the rest.
  Map<int, Pos> _assignObjectives(GameState s, int me, List<Unit> ready) {
    final result = <int, Pos>{};
    final claimed = {
      for (final u in s.unitsOf(me))
        if (u.acted && s.canCaptureAt(u, u.pos)) u.pos,
    };
    final buildings = [
      for (var y = 0; y < s.height; y++)
        for (var x = 0; x < s.width; x++)
          if (s.terrainAt(Pos(x, y)).isBuilding && s.owners[Pos(x, y)] != me)
            Pos(x, y),
    ];
    final myHq = s.owners.entries
        .where((e) => e.value == me && s.terrainAt(e.key) == Terrain.hq)
        .map((e) => e.key)
        .firstOrNull;

    for (final unit in ready) {
      final dist = _distances(s, unit.pos, unit.type.moveClass, reverse: false);
      int distTo(Pos p) {
        final d = dist[p.y * s.width + p.x];
        if (d < _unreachable) return d;
        // Standing next to an impassable tile is as close as we can get.
        var best = _unreachable;
        for (final n in p.neighbors) {
          if (s.inBounds(n)) best = min(best, dist[n.y * s.width + n.x] + 1);
        }
        return best;
      }

      if (unit.type.canCapture) {
        Pos? pick;
        var pickDist = _unreachable;
        for (final b in buildings) {
          if (claimed.contains(b)) continue;
          final d = distTo(b);
          if (d < pickDist) {
            pickDist = d;
            pick = b;
          }
        }
        if (pick != null) {
          claimed.add(pick);
          result[unit.id] = pick;
          continue;
        }
      }

      if (unit.type.canHeal) {
        // Healers trail the most battered ally.
        Unit? patient;
        for (final ally in s.unitsOf(me)) {
          if (ally.id == unit.id || ally.type.canHeal) continue;
          if (patient == null || ally.hp < patient.hp) patient = ally;
        }
        if (patient != null) result[unit.id] = patient.pos;
        continue;
      }

      Pos? pick;
      var pickValue = 0.0;
      for (final enemy in s.unitsOf(1 - me)) {
        final d = distTo(enemy.pos);
        if (d >= _unreachable) continue;
        var value =
            (unit.type.baseDamage(enemy.type) + 10) * enemy.type.cost / 100;
        if (enemy.type.canCapture &&
            myHq != null &&
            enemy.pos.distanceTo(myHq) <= 4) {
          value *= 3;
        }
        value /= d + 4;
        if (value > pickValue) {
          pickValue = value;
          pick = enemy.pos;
        }
      }
      if (pick != null) result[unit.id] = pick;
    }
    return result;
  }

  /// Movement cost between [origin] and every tile, ignoring units.
  /// With [reverse], the cost of travelling from each tile to [origin].
  List<int> _distances(
    GameState s,
    Pos origin,
    MoveClass moveClass, {
    required bool reverse,
  }) {
    final dist = List.filled(s.width * s.height, _unreachable);
    dist[origin.y * s.width + origin.x] = 0;
    final queue = Queue<Pos>()..add(origin);
    while (queue.isNotEmpty) {
      final p = queue.removeFirst();
      final d = dist[p.y * s.width + p.x];
      for (final n in p.neighbors) {
        if (!s.inBounds(n)) continue;
        final enter = s.terrainAt(n).moveCost(moveClass);
        if (enter == null) continue;
        final step = reverse ? s.terrainAt(p).moveCost(moveClass) ?? 1 : enter;
        final i = n.y * s.width + n.x;
        if (d + step < dist[i]) {
          dist[i] = d + step;
          queue.add(n);
        }
      }
    }
    return dist;
  }

  /// For each enemy, the tiles it could strike on its next turn.
  List<_Threat> _threats(GameState s, int me) {
    final result = <_Threat>[];
    for (final enemy in s.unitsOf(1 - me)) {
      final from = enemy.type.siege
          ? {enemy.pos}
          : s.reachable(enemy).destinations;
      final tiles = <Pos>{};
      final range = enemy.type.maxRange;
      for (final p in from) {
        for (var dy = -range; dy <= range; dy++) {
          for (var dx = -range; dx <= range; dx++) {
            final d = dx.abs() + dy.abs();
            if (d < enemy.type.minRange || d > range) continue;
            tiles.add(Pos(p.x + dx, p.y + dy));
          }
        }
      }
      result.add(_Threat(enemy, tiles));
    }
    return result;
  }

  GameAction? _chooseBuild(GameState s, int me) {
    final funds = s.funds[me];
    final mine = s.unitsOf(me).toList();
    final enemies = s.unitsOf(1 - me).toList();
    final capturers = mine.where((u) => u.type.canCapture).length;
    var neutral = 0;
    for (var y = 0; y < s.height; y++) {
      for (var x = 0; x < s.width; x++) {
        final p = Pos(x, y);
        if (s.terrainAt(p).isBuilding && s.owners[p] == null) neutral++;
      }
    }

    // How well a type trades against the current enemy army. Not per gold:
    // recruiting is limited by barracks slots, so quality beats thrift.
    final scores = <UnitType, double>{};
    for (final t in UnitType.values) {
      var total = 0.0;
      for (final e in enemies) {
        total += t.baseDamage(e.type) - 0.5 * e.type.baseDamage(t);
      }
      final owned = mine.where((u) => u.type == t).length;
      // A healer is worth one slot once there is an army to patch up.
      final support = t.canHeal
          ? (mine.length >= 4 && owned == 0 ? 45 : -50)
          : 0;
      scores[t] =
          (enemies.isEmpty ? 0 : total / enemies.length) +
          t.move * 3 -
          8 * owned +
          support +
          _random.nextDouble() * _noise / 4;
    }
    double matchup(UnitType t) => scores[t]!;

    for (final entry in s.owners.entries) {
      if (entry.value != me) continue;
      final options = s.buildableAt(entry.key);
      if (options.isEmpty) continue;
      if (level == AiLevel.easy) {
        return BuildAction(entry.key, options[_random.nextInt(options.length)]);
      }
      if (capturers == 0 || (neutral > 0 && capturers < 3)) {
        return BuildAction(entry.key, UnitType.infantry);
      }
      final ranked = UnitType.values.toList()
        ..sort((a, b) => matchup(b).compareTo(matchup(a)));
      final wanted = ranked.first;
      if (wanted.cost <= funds) return BuildAction(entry.key, wanted);
      // Save up for the right unit when we can afford the wait.
      final income = GameState.incomePerBuilding * s.buildingCount(me);
      if (wanted.cost <= funds + income && mine.length >= enemies.length) {
        return null;
      }
      return BuildAction(entry.key, ranked.firstWhere((t) => t.cost <= funds));
    }
    return null;
  }
}

class _Threat {
  final Unit unit;
  final Set<Pos> tiles;
  const _Threat(this.unit, this.tiles);
}
