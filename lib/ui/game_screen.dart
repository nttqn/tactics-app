import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ai/ai_player.dart';
import '../core/actions.dart';
import '../core/models.dart';
import '../game/board_component.dart';
import '../game/game_controller.dart';
import '../game/tactics_game.dart';
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
  });

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
  );
  late final _game = TacticsGame(_controller);
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
        backgroundColor: const Color(0xFF1B1F2A),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Stack(
              children: [
                Column(
                  children: [
                    _statusBar(),
                    Expanded(child: GameWidget(game: _game)),
                    SizedBox(height: 112, child: _panel()),
                  ],
                ),
                if (_controller.paused) _pauseOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBar() {
    final s = _controller.state;
    Widget funds(int player) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 12, color: playerColors[player]),
        const SizedBox(width: 4),
        Text('${s.funds[player]}g', style: const TextStyle(fontSize: 16)),
      ],
    );
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: playerColors[s.winner ?? s.currentPlayer],
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
            _button('End turn', c.endTurn),
          ];
        case Phase.moving:
          final u = c.selected!;
          children = [
            _hint(
              '${u.type.label} · HP ${u.displayHp}/10 · Move ${u.type.move}\n'
              'Tap a blue tile to move there.',
            ),
            _button('Cancel', c.cancel, primary: false),
          ];
        case Phase.menu:
          children = [
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
              f == null
                  ? 'Tap an enemy marked in red.'
                  : lethal
                  ? 'Deal ${formatHp(f.damage)} · defeats the enemy'
                  : 'Deal ${formatHp(f.damage)} · take ${formatHp(f.counter)}',
            ),
            _button('Attack', f == null ? null : c.confirmAttack),
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
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _controller.togglePause,
                child: const Text('Resume'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _controller.restart,
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
