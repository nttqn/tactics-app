import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ai/ai_player.dart';
import '../core/actions.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/rules.dart';

/// Where the player is in the select -> move -> act flow.
enum Phase { idle, moving, menu, targeting, building }

/// Turns taps and button presses into [GameAction]s. Holds no rendering
/// code; the board and the HUD both listen to it.
class GameController extends ChangeNotifier {
  GameController(
    this.mapJson, {
    this.ai,
    this.aiDelay = const Duration(milliseconds: 600),
  }) : state = GameState.fromMap(mapJson);

  /// Plays the second side when set; otherwise two humans share the device.
  final AiPlayer? ai;

  /// Pause between AI actions so the player can follow them.
  final Duration aiDelay;
  Timer? _aiTimer;

  bool get aiTurn =>
      ai != null && state.currentPlayer == 1 && state.winner == null;

  final Map<String, dynamic> mapJson;
  GameState state;
  Phase phase = Phase.idle;
  bool paused = false;

  Unit? selected;
  MoveMap? moves;

  /// Enemy tiles the selected unit could hit from somewhere it can reach.
  Set<Pos> threatened = const {};
  Pos? destination;
  Pos? target;
  Pos? buildAt;

  /// Called synchronously with the events of every applied action.
  final eventListeners = <void Function(List<GameEvent> events)>[];

  /// Snapshots taken before each of the player's actions this turn.
  final _history = <GameState>[];

  bool get canUndo =>
      _history.isNotEmpty && !paused && !aiTurn && state.winner == null;

  /// Takes back the player's latest action of the current turn.
  void undo() {
    if (!canUndo) return;
    state = _history.removeLast();
    _clear();
    notifyListeners();
  }

  List<Pos> get previewPath =>
      destination == null ? const [] : moves!.pathTo(destination!);

  List<Unit> get targets => selected == null || destination == null
      ? const []
      : state.attackTargets(selected!, destination!);

  bool get canCapture =>
      selected != null &&
      destination != null &&
      state.canCaptureAt(selected!, destination!);

  CombatForecast? get forecast => target == null
      ? null
      : state.forecast(selected!, destination!, state.unitAt(target!)!);

  void tapTile(Pos p) {
    if (paused || aiTurn || state.winner != null || !state.inBounds(p)) return;
    switch (phase) {
      case Phase.idle:
        _tapIdle(p);
      case Phase.moving:
        if (moves!.destinations.contains(p)) {
          destination = p;
          phase = Phase.menu;
        } else {
          _clear();
          _tapIdle(p);
        }
      case Phase.menu:
        if (moves!.destinations.contains(p)) {
          destination = p;
        } else {
          destination = null;
          phase = Phase.moving;
        }
      case Phase.targeting:
        if (!targets.any((t) => t.pos == p)) {
          target = null;
          phase = Phase.menu;
        } else if (target == p) {
          confirmAttack();
          return;
        } else {
          target = p;
        }
      case Phase.building:
        _clear();
    }
    notifyListeners();
  }

  void _tapIdle(Pos p) {
    final unit = state.unitAt(p);
    if (unit != null) {
      if (unit.owner != state.currentPlayer || unit.acted) return;
      selected = unit;
      moves = state.reachable(unit);
      threatened = {
        for (final from in moves!.destinations)
          for (final t in state.attackTargets(unit, from)) t.pos,
      };
      phase = Phase.moving;
    } else if (state.terrainAt(p) == Terrain.barracks &&
        state.owners[p] == state.currentPlayer) {
      buildAt = p;
      phase = Phase.building;
    }
  }

  void chooseWait() =>
      _apply(UnitAction(selected!.id, destination!, ActionKind.wait));

  void chooseCapture() =>
      _apply(UnitAction(selected!.id, destination!, ActionKind.capture));

  void chooseAttack() {
    final options = targets;
    if (options.isEmpty) return;
    // With a single enemy in range there is nothing to pick.
    target = options.length == 1 ? options.first.pos : null;
    phase = Phase.targeting;
    notifyListeners();
  }

  void confirmAttack() {
    if (target == null) return;
    _apply(UnitAction(selected!.id, destination!, ActionKind.attack, target));
  }

  void build(UnitType type) => _apply(BuildAction(buildAt!, type));

  void endTurn() => _apply(const EndTurnAction());

  /// Steps one level back in the selection flow.
  void cancel() {
    switch (phase) {
      case Phase.targeting:
        target = null;
        phase = Phase.menu;
      case Phase.menu:
        destination = null;
        phase = Phase.moving;
      case Phase.idle || Phase.moving || Phase.building:
        _clear();
    }
    notifyListeners();
  }

  void togglePause() {
    paused = !paused;
    notifyListeners();
    _scheduleAi();
  }

  void restart() {
    _aiTimer?.cancel();
    _history.clear();
    state = GameState.fromMap(mapJson);
    paused = false;
    _clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    super.dispose();
  }

  /// A player-initiated action; ignored while input is locked.
  void _apply(GameAction action) {
    if (paused || aiTurn || state.winner != null) return;
    if (action is EndTurnAction) {
      _history.clear();
    } else {
      _history.add(state.copy());
    }
    _perform(action);
    if (state.winner != null) _history.clear();
  }

  void _perform(GameAction action) {
    final events = state.apply(action);
    _clear();
    for (final listener in eventListeners) {
      listener(events);
    }
    notifyListeners();
    _scheduleAi();
  }

  void _scheduleAi() {
    _aiTimer?.cancel();
    if (!aiTurn || paused) return;
    _aiTimer = Timer(aiDelay, () {
      if (aiTurn && !paused) _perform(ai!.nextAction(state));
    });
  }

  void _clear() {
    phase = Phase.idle;
    selected = null;
    moves = null;
    threatened = const {};
    destination = null;
    target = null;
    buildAt = null;
  }
}
