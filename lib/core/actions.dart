import 'models.dart';

/// What a unit does after (optionally) moving.
enum ActionKind { wait, attack, capture }

sealed class GameAction {
  const GameAction();
}

/// Move [unitId] to [to] (its own tile to stay put), then perform [kind].
/// A unit's whole turn is one atomic action, which keeps AI and undo simple.
class UnitAction extends GameAction {
  final int unitId;
  final Pos to;
  final ActionKind kind;

  /// Tile of the enemy to attack; required when [kind] is attack.
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
  const UnitDamaged(this.attackerId, this.defenderId, this.damage, {this.isCounter = false});
}

class UnitDied extends GameEvent {
  final int unitId;
  final Pos at;
  const UnitDied(this.unitId, this.at);
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
