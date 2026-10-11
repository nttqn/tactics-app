import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

import '../ai/ai_player.dart';
import '../core/actions.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/rules.dart';
import '../game/board_component.dart';
import '../game/game_controller.dart';
import '../game/tactics_game.dart';
import '../services/achievements.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';

const _playerNames = ['Blue', 'Red'];

extension on UnitType {
  String get label => name[0].toUpperCase() + name.substring(1);
}

/// A full match: status bar, board and a context panel for the current
/// selection. Two players share the device.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.mapJson,
    this.aiLevel,
    this.onPlayerWin,
    this.nextBuilder,
    this.tutorial = false,
    this.missionIndex,
    this.resumeFrom,
    this.label = 'Battle',
  });

  /// Campaign mission being played, for the save slot.
  final int? missionIndex;

  /// A saved match to continue instead of starting [mapJson] fresh.
  final GameState? resumeFrom;

  /// Names the match on the home screen's Continue button.
  final String label;

  /// Shows a coaching line under the board that follows what the player is
  /// doing. Used for the first campaign mission.
  final bool tutorial;

  final Map<String, dynamic> mapJson;

  /// Difficulty of the computer opponent, or null for two players.
  final AiLevel? aiLevel;

  /// Called once with the day count when the human beats the computer.
  final void Function(int days)? onPlayerWin;

  /// Screen offered as "Next" after such a win.
  final WidgetBuilder? nextBuilder;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final _controller = GameController(
    widget.mapJson,
    ai: widget.aiLevel == null ? null : AiPlayer(widget.aiLevel!),
    resumeFrom: widget.resumeFrom,
  );
  late final _game = TacticsGame(_controller);

  /// Hides the board between turns of a two-player match under fog, so the
  /// next player does not see the other side's view.
  bool _curtain = false;
  bool _resultReported = false;
  Phase _lastPhase = Phase.idle;
  bool _soundPlayed = false;

  bool get _playerWon =>
      widget.aiLevel != null && _controller.state.winner == 0;

  @override
  void initState() {
    super.initState();
    SoundService.instance.startGameMusic();
    _controller.eventListeners.add(_playEventSound);
    _controller.eventListeners.add(_onEvents);
    _controller.start();
    AchievementService.instance.load();
    AchievementService.instance.justUnlocked.addListener(_announce);
    _controller.addListener(() {
      // Stepping deeper into a selection clicks, backing out of it thuds;
      // applied actions have already made their own sound.
      final phase = _controller.phase;
      if (_soundPlayed) {
        _soundPlayed = false;
      } else if (phase.index > _lastPhase.index) {
        SoundService.instance.play(SoundEffect.click);
      } else if (phase.index < _lastPhase.index) {
        SoundService.instance.play(SoundEffect.back);
      }
      _lastPhase = phase;
      if (_controller.state.winner == null) {
        _resultReported = false;
      } else if (!_resultReported) {
        _resultReported = true;
        if (_playerWon) widget.onPlayerWin?.call(_controller.state.turn);
      }
    });
  }

  /// Achievements only count for the human against the computer.
  void _trackAchievements(List<GameEvent> events) {
    if (widget.aiLevel == null) return;
    final s = _controller.state;
    bool mine(int unitId) => s.unitById(unitId)?.owner == 0;
    final earned = <String>[
      if (events.any((e) => e is UnitDied && e.owner == 1)) 'first_blood',
      if (s.buildingCount(0) >= 8) 'landlord',
      if (events.any((e) => e is UnitPromoted && e.rank == 3 && mine(e.unitId)))
        'veteran',
      if (events.any(
        (e) => e is UnitHealed && e.healerId >= 0 && mine(e.healerId),
      ))
        'medic',
      if (events.any((e) => e is PowerUsed && e.player == 0)) 'unleashed',
      if (s.winner == 0) ...[
        if (events.any((e) => e is BuildingCaptured)) 'castle',
        if (s.unitsOf(1).isEmpty) 'total_war',
        if (s.turn <= 8) 'blitz',
        if (s.fog) 'mist',
        if (widget.aiLevel == AiLevel.hard && widget.missionIndex == null)
          'tactician',
        if (widget.mapJson['custom'] == true) 'cartographer',
      ],
    ];
    if (earned.isNotEmpty) AchievementService.instance.unlock(earned);
  }

  void _announce() {
    if (!mounted) return;
    for (final a in AchievementService.instance.justUnlocked.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Achievement unlocked: ${a.title}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onEvents(List<GameEvent> events) {
    _trackAchievements(events);
    final s = _controller.state;
    if (s.winner != null) {
      SaveService.clear();
    } else {
      SaveService.save(
        SavedMatch(
          setup: widget.mapJson,
          state: s,
          level: widget.aiLevel,
          mission: widget.missionIndex,
          label: widget.label,
        ),
      );
    }
    if (widget.aiLevel == null &&
        s.fog &&
        events.any((e) => e is TurnStarted)) {
      _curtain = true;
    }
  }

  Future<void> _confirmPower() async {
    final commander =
        _controller.state.commanders[_controller.state.currentPlayer]!;
    final use = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(commander.power),
        content: Text('${commander.title}: ${commander.description}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Unleash'),
          ),
        ],
      ),
    );
    if (use == true) _controller.usePower();
  }

  void _playEventSound(List<GameEvent> events) {
    _soundPlayed = true;
    final SoundEffect effect;
    if (events.any((e) => e is GameOver)) {
      effect = widget.aiLevel == null || _playerWon
          ? SoundEffect.win
          : SoundEffect.hit;
    } else if (events.any((e) => e is UnitDamaged)) {
      effect = SoundEffect.hit;
    } else {
      effect = SoundEffect.click;
    }
    SoundService.instance.play(effect);
  }

  @override
  void dispose() {
    AchievementService.instance.justUnlocked.removeListener(_announce);
    SoundService.instance.playMenuMusic();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Back never leaves a match in progress; it toggles the pause overlay.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _controller.togglePause();
      },
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Stack(
              children: [
                Column(
                  children: [
                    DecoratedBox(
                      decoration: hudDecoration(trimOnTop: false),
                      child: _statusBar(),
                    ),
                    Expanded(child: GameWidget(game: _game)),
                    if (widget.tutorial) _tutorialStrip(),
                    Container(
                      height: 112,
                      decoration: hudDecoration(trimOnTop: true),
                      child: _panel(),
                    ),
                  ],
                ),
                if (_curtain) _curtainOverlay(),
                if (_controller.paused) _pauseOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The coaching line for the current situation, or null for none.
  String? _tutorialTip() {
    final c = _controller;
    final s = c.state;
    if (s.winner != null || c.aiTurn) return null;
    switch (c.phase) {
      case Phase.moving:
        return 'Blue tiles show where this unit can go; red marks enemies '
            'it could strike. Tap a blue tile. A grey village is a good goal.';
      case Phase.menu:
        if (c.canCapture) {
          return 'Capture claims this building. It takes two turns, and '
              'every building you own pays gold each day.';
        }
        return c.targets.isNotEmpty
            ? 'Attack strikes an enemy in reach. Wait ends the move here.'
            : 'Wait ends the move here. Stop on a building to capture it, '
                  'or beside an enemy to attack.';
      case Phase.targeting:
        return 'The panel shows the damage you deal and take back. '
            'Forests, mountains and buildings protect whoever stands there.';
      case Phase.building:
        return 'Spend gold to recruit. A new unit can act from your next '
            'turn.';
      case Phase.idle:
        final mine = s.unitsOf(s.currentPlayer);
        if (s.turn == 1 && mine.every((u) => !u.acted)) {
          return 'Welcome, commander. Tap one of your blue shields to give '
              'it orders.';
        }
        if (mine.any((u) => !u.acted)) {
          return 'Each unit acts once per turn. Tap another shield, or '
              'your striped tent to recruit.';
        }
        return 'Press End turn when you are done. Win by capturing the red '
            'castle or defeating every red unit.';
    }
  }

  // Fixed height so the board does not resize as tips come and go.
  Widget _tutorialStrip() => Container(
    height: 58,
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: parchment,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: goldDark, width: 2),
    ),
    child: Text(
      _tutorialTip() ?? '',
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, color: Color(0xFF3A2A1C)),
    ),
  );

  Widget _statusBar() {
    final s = _controller.state;
    Widget funds(int player) {
      final commander = s.commanders[player];
      final ready =
          player == s.currentPlayer &&
          player == _controller.viewer &&
          _controller.canUsePower;
      final badge = commander == null
          ? Icon(Icons.circle, size: 12, color: playerColors[player])
          : SizedBox.square(
              dimension: 30,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: s.charge[player] / Commander.maxCharge,
                    strokeWidth: 3,
                    color: ready
                        ? const Color(0xFFFFD54F)
                        : playerColors[player],
                    backgroundColor: const Color(0x33FFFFFF),
                  ),
                  Text(
                    commander.title[0],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ready ? const Color(0xFFFFD54F) : null,
                    ),
                  ),
                ],
              ),
            );
      return InkWell(
        onTap: ready ? _confirmPower : null,
        borderRadius: BorderRadius.circular(20),
        child: Tooltip(
          message: commander == null
              ? ''
              : '${commander.title} · ${commander.power}: '
                    '${s.charge[player]}%',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              badge,
              const SizedBox(width: 4),
              Text('${s.funds[player]}g', style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          funds(0),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                s.winner != null
                    ? widget.aiLevel == null
                          ? '${_playerNames[s.winner!]} wins'
                          : _playerWon
                          ? 'Victory on day ${s.turn}'
                          : 'Defeated on day ${s.turn}'
                    : _controller.aiTurn
                    ? 'Day ${s.turn} · ${_playerNames[1]} is moving…'
                    : 'Day ${s.turn} · ${_playerNames[s.currentPlayer]} to move',
                style: TextStyle(
                  fontFamily: displayFont,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color.lerp(
                    playerColors[s.winner ?? s.currentPlayer],
                    Colors.white,
                    0.35,
                  ),
                ),
              ),
            ),
          ),
          funds(1),
          IconButton(
            tooltip: 'Pause',
            icon: const Icon(Icons.pause),
            onPressed: _controller.togglePause,
          ),
        ],
      ),
    );
  }

  Widget _button(String label, VoidCallback? onPressed, {bool primary = true}) {
    final child = FittedBox(fit: BoxFit.scaleDown, child: Text(label));
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          height: 52,
          child: primary
              ? FilledButton(onPressed: onPressed, child: child)
              : OutlinedButton(onPressed: onPressed, child: child),
        ),
      ),
    );
  }

  Widget _hint(String text) => Expanded(
    flex: 2,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
    ),
  );

  Widget _panel() {
    final c = _controller;
    final s = c.state;
    final List<Widget> children;
    if (s.winner != null) {
      final next = _playerWon ? widget.nextBuilder : null;
      children = [
        if (next != null)
          _button(
            'Next',
            () => Navigator.of(
              context,
            ).pushReplacement(MaterialPageRoute<void>(builder: next)),
          ),
        _button('Play again', c.restart, primary: next == null),
        _button('Menu', () => Navigator.of(context).pop(), primary: false),
      ];
    } else if (c.aiTurn) {
      children = [_hint('The enemy is taking its turn.')];
    } else {
      switch (c.phase) {
        case Phase.idle:
          children = [
            _hint('Tap one of your units, or your barracks to recruit.'),
            if (c.canUndo) _button('Undo', c.undo, primary: false),
            if (c.canUsePower)
              _button(s.commanders[s.currentPlayer]!.power, _confirmPower),
            _button('End turn', c.endTurn),
          ];
        case Phase.moving:
          final u = c.selected!;
          children = [
            _hint(
              '${u.type.label}${u.rank > 0 ? ' ${'★' * u.rank}' : ''} · '
              'HP ${u.displayHp}/10 · Move ${s.moveRange(u)}\n'
              'Tap a blue tile to move there.',
            ),
            _button('Cancel', c.cancel, primary: false),
          ];
        case Phase.menu:
          children = [
            if (c.selected!.type.canHeal)
              _button('Heal', c.healTargets.isEmpty ? null : c.chooseHeal)
            else
              _button('Attack', c.targets.isEmpty ? null : c.chooseAttack),
            _button('Capture', c.canCapture ? c.chooseCapture : null),
            _button('Wait', c.chooseWait),
            _button('Back', c.cancel, primary: false),
          ];
        case Phase.targeting:
          final f = c.forecast;
          final lethal = f != null && f.damage >= s.unitAt(c.target!)!.hp;
          children = [
            _hint(
              c.healing
                  ? c.target == null
                        ? 'Tap a wounded ally marked in green.'
                        : 'Restore up to ${formatHp(UnitType.healAmount)} HP.'
                  : f == null
                  ? 'Tap an enemy marked in red.'
                  : lethal
                  ? 'Deal ${formatHp(f.damage)} · defeats the enemy'
                  : 'Deal ${formatHp(f.damage)} · take ${formatHp(f.counter)}',
            ),
            c.healing
                ? _button('Heal', c.target == null ? null : c.confirmAttack)
                : _button('Attack', f == null ? null : c.confirmAttack),
            _button('Back', c.cancel, primary: false),
          ];
        case Phase.building:
          return _buildPanel();
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: children),
    );
  }

  Widget _buildPanel() {
    final c = _controller;
    final funds = c.state.funds[c.state.currentPlayer];
    final occupied = c.state.unitAt(c.buildAt!) != null;
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      children: [
        for (final type in UnitType.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonal(
              onPressed: occupied || type.cost > funds
                  ? null
                  : () => c.build(type),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(type.label),
                  Text('${type.cost}g'),
                  Text(
                    'Move ${type.move} · Range '
                    '${type.minRange == type.maxRange ? type.maxRange : '${type.minRange}-${type.maxRange}'}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton(onPressed: c.cancel, child: const Text('Close')),
      ],
    );
  }

  Widget _soundToggle(
    ValueListenable<bool> enabled,
    IconData on,
    IconData off,
    String tooltip,
    VoidCallback toggle,
  ) => ValueListenableBuilder(
    valueListenable: enabled,
    builder: (context, value, _) => IconButton(
      tooltip: tooltip,
      iconSize: 32,
      icon: Icon(value ? on : off),
      onPressed: toggle,
    ),
  );

  Widget _curtainOverlay() {
    final player = _controller.state.currentPlayer;
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _curtain = false),
        child: ColoredBox(
          color: const Color(0xFF10131C),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_playerNames[player]}\'s turn',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: playerColors[player],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Pass the device, then tap to continue.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pauseOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xCC000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paused',
                style: TextStyle(
                  fontFamily: displayFont,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: gold,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _controller.togglePause,
                child: const Text('Resume'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  SaveService.clear();
                  _controller.restart();
                },
                child: const Text('Restart'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Quit to menu'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _soundToggle(
                    SoundService.instance.musicEnabled,
                    Icons.music_note,
                    Icons.music_off,
                    'Music',
                    SoundService.instance.toggleMusic,
                  ),
                  _soundToggle(
                    SoundService.instance.sfxEnabled,
                    Icons.volume_up,
                    Icons.volume_off,
                    'Sound effects',
                    SoundService.instance.toggleSfx,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
