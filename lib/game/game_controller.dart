import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../ai/ai_player.dart';
import '../services/settings.dart';
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
    GameState? resumeFrom,
  }) : state = resumeFrom ?? GameState.fromMap(mapJson);

  /// Kicks off the computer if a resumed match was saved during its turn.
  void start() => _scheduleAi();

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

  /// Whether the targeting phase picks an ally to heal rather than an enemy.
  bool healing = false;

  /// Whose eyes the board is drawn through under fog of war: the human
  /// against the computer, or whoever is moving in a two-player match.
  int get viewer => ai != null ? 0 : state.currentPlayer;

  /// Called synchronously with the events of every applied action.
  final eventListeners = <void Function(List<GameEvent> events)>[];

  /// Snapshots taken before each of the player's actions this turn.
  final _history = <GameState>[];

  /// Undo is off under fog: taking back a move would reveal what it saw.
  bool get canUndo =>
      _history.isNotEmpty &&
      !paused &&
      !aiTurn &&
      !state.fog &&
      state.winner == null;

  /// Under fog, undo is offered in exchange for watching an ad.
  bool get canUndoWithAd =>
      _history.isNotEmpty &&
      !paused &&
      !aiTurn &&
      state.fog &&
      state.winner == null;

  bool get canUsePower => !paused && !aiTurn && state.canUsePower;

  /// What the hard computer would do now in the player's place, shown on
  /// the board until the player taps or acts.
  GameAction? hintAction;

  bool get canHint => !paused && !aiTurn && state.winner == null;

  void showHint() {
    if (!canHint) return;
    hintAction = AiPlayer(
      AiLevel.hard,
      random: Random(state.turn),
    ).nextAction(state.copy());
    notifyListeners();
  }

  /// Takes back the player's latest action of the current turn. [rewarded]
  /// allows it under fog once the player has watched an ad.
  void undo({bool rewarded = false}) {
    if (!canUndo && !(rewarded && canUndoWithAd)) return;
    state = _history.removeLast();
    _clear();
    notifyListeners();
  }

  List<Pos> get previewPath =>
      destination == null ? const [] : moves!.pathTo(destination!);

  List<Unit> get targets => selected == null || destination == null
      ? const []
      : state.attackTargets(selected!, destination!);

  List<Unit> get healTargets => selected == null || destination == null
      ? const []
      : state.healTargets(selected!, destination!);

  /// Units the targeting phase can pick from.
  List<Unit> get currentTargets => healing ? healTargets : targets;

  bool get canCapture =>
      selected != null &&
      destination != null &&
      state.canCaptureAt(selected!, destination!);

  CombatForecast? get forecast => target == null || healing
      ? null
      : state.forecast(selected!, destination!, state.unitAt(target!)!);

  void tapTile(Pos p) {
    if (paused || aiTurn || state.winner != null || !state.inBounds(p)) return;
    hintAction = null;
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
        if (!currentTargets.any((t) => t.pos == p)) {
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

  void chooseAttack() => _target(healing: false);

  void chooseHeal() => _target(healing: true);

  void _target({required bool healing}) {
    this.healing = healing;
    final options = currentTargets;
    if (options.isEmpty) return;
    // With a single enemy in range there is nothing to pick.
    target = options.length == 1 ? options.first.pos : null;
    phase = Phase.targeting;
    notifyListeners();
  }

  void confirmAttack() {
    if (target == null) return;
    _apply(
      UnitAction(
        selected!.id,
        destination!,
        healing ? ActionKind.heal : ActionKind.attack,
        target,
      ),
    );
  }

  void usePower() {
    if (canUsePower) _apply(const UsePowerAction());
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
    final delay = aiDelay ~/ Settings.speed.value;
    _aiTimer = Timer(delay, () {
      if (aiTurn && !paused) _perform(ai!.nextAction(state));
    });
  }

  void _clear() {
    hintAction = null;
    phase = Phase.idle;
    selected = null;
    moves = null;
    threatened = const {};
    destination = null;
    target = null;
    buildAt = null;
    healing = false;
  }
}
