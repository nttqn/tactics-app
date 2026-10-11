import 'models.dart';

/// What a unit does after (optionally) moving.
enum ActionKind { wait, attack, capture, heal }

sealed class GameAction {
  const GameAction();
}

/// Move [unitId] to [to] (its own tile to stay put), then perform [kind].
/// A unit's whole turn is one atomic action, which keeps AI and undo simple.
class UnitAction extends GameAction {
  final int unitId;
  final Pos to;
  final ActionKind kind;

  /// Tile of the enemy to attack or ally to heal; required for those kinds.
  final Pos? target;

  const UnitAction(this.unitId, this.to, this.kind, [this.target]);

  @override
  String toString() =>
      'UnitAction(#$unitId -> $to ${kind.name}${target == null ? '' : ' $target'})';
}

class BuildAction extends GameAction {
  final Pos at;
  final UnitType type;
  const BuildAction(this.at, this.type);

  @override
  String toString() => 'BuildAction(${type.name} at $at)';
}

/// Unleashes the current player's commander power.
class UsePowerAction extends GameAction {
  const UsePowerAction();

  @override
  String toString() => 'UsePowerAction()';
}

class EndTurnAction extends GameAction {
  const EndTurnAction();

  @override
  String toString() => 'EndTurnAction()';
}

/// Things that happened while applying an action, in order, for the renderer
/// to animate.
sealed class GameEvent {
  const GameEvent();
}

class UnitMoved extends GameEvent {
  final int unitId;
  final List<Pos> path;
  const UnitMoved(this.unitId, this.path);
}

class UnitDamaged extends GameEvent {
  final int attackerId;
  final int defenderId;
  final int damage;
  final bool isCounter;
  const UnitDamaged(
    this.attackerId,
    this.defenderId,
    this.damage, {
    this.isCounter = false,
  });
}

class UnitDied extends GameEvent {
  final int unitId;
  final Pos at;
  final int owner;
  const UnitDied(this.unitId, this.at, this.owner);
}

class CaptureProgressed extends GameEvent {
  final Pos at;
  final int remaining;
  const CaptureProgressed(this.at, this.remaining);
}

class BuildingCaptured extends GameEvent {
  final Pos at;
  final int owner;
  const BuildingCaptured(this.at, this.owner);
}

class UnitBuilt extends GameEvent {
  final int unitId;
  const UnitBuilt(this.unitId);
}

class TurnStarted extends GameEvent {
  final int player;
  const TurnStarted(this.player);
}

class GameOver extends GameEvent {
  final int winner;
  const GameOver(this.winner);
}

class UnitHealed extends GameEvent {
  final int healerId;
  final int unitId;
  final int amount;
  const UnitHealed(this.healerId, this.unitId, this.amount);
}

/// A unit made a kill and gained a rank.
class UnitPromoted extends GameEvent {
  final int unitId;
  final int rank;
  const UnitPromoted(this.unitId, this.rank);
}

class PowerUsed extends GameEvent {
  final int player;
  final Commander commander;
  const PowerUsed(this.player, this.commander);
}

/// A move through fog ran into a hidden enemy and stopped short.
class Ambushed extends GameEvent {
  final int unitId;
  final Pos stoppedAt;
  final Pos enemyAt;
  const Ambushed(this.unitId, this.stoppedAt, this.enemyAt);
}
