import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

import '../ai/ai_player.dart';
import '../campaign/conquest.dart';
import '../core/actions.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/rules.dart';
import '../game/board_component.dart';
import '../game/game_controller.dart';
import '../game/tactics_game.dart';
import '../services/achievements.dart';
import '../services/play_games.dart';
import '../services/ads_service.dart';
import '../services/save_service.dart';
import '../services/settings.dart';
import '../services/sound_service.dart';
import '../l10n.dart';

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
    this.dailyKey,
    this.resumeFrom,
    this.label = 'Battle',
  });

  /// Campaign mission being played, for the save slot.
  final int? missionIndex;

  /// Date key when this is a daily challenge, for the save slot.
  final String? dailyKey;

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
          content: Text(
            tr('Achievement unlocked: ', 'Đạt thành tích: ') + a.name,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Conquest points, lifetime wins and the achievements that count them.
  Future<void> _recordVictory() async {
    final s = _controller.state;
    final conquest = await Conquest.load();
    final earned = await conquest.recordWin(
      level: widget.aiLevel!,
      fog: s.fog,
      days: s.turn,
      daily: widget.dailyKey != null,
    );
    AchievementService.instance.unlock([
      if (conquest.wins >= 10) 'seasoned',
      if (conquest.wins >= 50) 'warmonger',
      if (conquest.wins >= 100) 'legend',
    ]);
    PlayGames.progressChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            '+$earned conquest points · ${rankTitle(conquest.points)}',
            '+$earned điểm chinh phạt · ${rankTitle(conquest.points)}',
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onEvents(List<GameEvent> events) {
    _trackAchievements(events);
    if (widget.aiLevel != null && events.any((e) => e is GameOver)) {
      if (_controller.state.winner == 0) _recordVictory();
    }
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
          daily: widget.dailyKey,
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
        title: Text(commander.powerName),
        content: Text('${commander.displayName}: ${commander.powerText}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(tr('Not now', 'Để sau')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(tr('Unleash', 'Tung chiêu')),
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
          : SoundEffect.defeat;
    } else if (events.any((e) => e is UnitDamaged)) {
      effect = SoundEffect.attack;
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
            listenable: Listenable.merge([
              _controller,
              AdsService.instance.rewardedReady,
            ]),
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
        return tr(
          'Blue tiles show where this unit can go; red marks enemies '
              'it could strike. Tap a blue tile. A grey village is a good goal.',
          'Ô xanh là nơi quân này đi được; ô đỏ là địch nó có thể đánh. '
              'Chạm một ô xanh. Ngôi làng xám là mục tiêu tốt.',
        );
      case Phase.menu:
        if (c.canCapture) {
          return tr(
            'Capture claims this building. It takes two turns, and '
                'every building you own pays gold each day.',
            'Chiếm để lấy công trình này. Mất hai lượt, và mỗi công trình '
                'của bạn nộp vàng mỗi ngày.',
          );
        }
        return c.targets.isNotEmpty
            ? tr(
                'Attack strikes an enemy in reach. Wait ends the move here.',
                'Tấn công đánh địch trong tầm. Chờ là dừng nước đi tại đây.',
              )
            : tr(
                'Wait ends the move here. Stop on a building to capture it, '
                    'or beside an enemy to attack.',
                'Chờ là dừng nước đi tại đây. Dừng trên công trình để chiếm, '
                    'hoặc cạnh địch để tấn công.',
              );
      case Phase.targeting:
        return tr(
          'The panel shows the damage you deal and take back. '
              'Forests, mountains and buildings protect whoever stands there.',
          'Bảng dưới cho biết sát thương bạn gây ra và nhận lại. '
              'Rừng, núi và công trình che chắn cho quân đứng trên đó.',
        );
      case Phase.building:
        return tr(
          'Spend gold to recruit. A new unit can act from your next turn.',
          'Dùng vàng để chiêu mộ. Quân mới hành động được từ lượt sau.',
        );
      case Phase.idle:
        final mine = s.unitsOf(s.currentPlayer);
        if (s.turn == 1 && mine.every((u) => !u.acted)) {
          return tr(
            'Welcome, commander. Tap one of your blue units to give it orders.',
            'Chào chỉ huy. Chạm một quân xanh của bạn để ra lệnh.',
          );
        }
        if (mine.any((u) => !u.acted)) {
          return tr(
            'Each unit acts once per turn. Tap another unit, or your striped '
                'tent to recruit.',
            'Mỗi quân hành động một lần mỗi lượt. Chạm quân khác, hoặc lều '
                'sọc của bạn để chiêu mộ.',
          );
        }
        return tr(
          'Press End turn when you are done. Win by capturing the red '
              'castle or defeating every red unit.',
          'Xong thì bấm Hết lượt. Thắng bằng cách chiếm lâu đài đỏ '
              'hoặc tiêu diệt mọi quân đỏ.',
        );
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
                    commander.shortName[0],
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
              : '${commander.displayName} · ${commander.powerName}: '
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  s.winner != null
                      ? widget.aiLevel == null
                            ? tr(
                                '${playerName(s.winner!)} wins',
                                '${playerName(s.winner!)} thắng',
                              )
                            : _playerWon
                            ? tr(
                                'Victory on day ${s.turn}',
                                'Chiến thắng ngày ${s.turn}',
                              )
                            : tr(
                                'Defeated on day ${s.turn}',
                                'Thất bại ngày ${s.turn}',
                              )
                      : _controller.aiTurn
                      ? tr(
                          'Day ${s.turn} · ${playerName(1)} is moving…',
                          'Ngày ${s.turn} · ${playerName(1)} đang đi…',
                        )
                      : tr(
                          'Day ${s.turn} · ${playerName(s.currentPlayer)} to move',
                          'Ngày ${s.turn} · lượt ${playerName(s.currentPlayer)}',
                        ),
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
          ),
          funds(1),
          IconButton(
            tooltip: tr('Pause', 'Tạm dừng'),
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

  /// Runs [reward] if the player watches a rewarded ad to the end.
  Future<void> _afterAd(VoidCallback reward) async {
    final earned = await AdsService.instance.showRewarded();
    if (!mounted) return;
    if (earned) {
      reward();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'The ad did not finish, so no reward.',
              'Quảng cáo chưa xem hết nên không có thưởng.',
            ),
          ),
        ),
      );
    }
  }

  String _describeHint(GameAction action) {
    final s = _controller.state;
    switch (action) {
      case UnitAction():
        final unit = s.unitById(action.unitId)!;
        final moved = action.to != unit.pos;
        final name = unit.type.label;
        final where = moved
            ? tr(
                'Move your $name to the marked tile',
                'Đưa $name tới ô được đánh dấu',
              )
            : tr('Keep your $name where it is', 'Giữ $name tại chỗ');
        final target = action.target == null ? null : s.unitAt(action.target!);
        return switch (action.kind) {
          ActionKind.attack => tr(
            'Hint: $where and attack the ${target!.type.label}.',
            'Gợi ý: $where rồi tấn công ${target.type.label}.',
          ),
          ActionKind.heal => tr(
            'Hint: $where and heal the ${target!.type.label}.',
            'Gợi ý: $where rồi hồi máu cho ${target.type.label}.',
          ),
          ActionKind.capture => tr(
            'Hint: $where and capture the building.',
            'Gợi ý: $where rồi chiếm công trình.',
          ),
          ActionKind.wait => tr(
            'Hint: $where and wait.',
            'Gợi ý: $where rồi chờ.',
          ),
        };
      case BuildAction():
        return tr(
          'Hint: recruit a ${action.type.label} at your tent.',
          'Gợi ý: chiêu mộ ${action.type.label} tại lều trại.',
        );
      case UsePowerAction():
        final power = s.commanders[s.currentPlayer]!.powerName;
        return tr(
          'Hint: unleash $power now.',
          'Gợi ý: tung chiêu $power ngay.',
        );
      case EndTurnAction():
        return tr(
          'Hint: nothing more worth doing. End your turn.',
          'Gợi ý: không còn nước nào đáng đi. Hãy hết lượt.',
        );
    }
  }

  Widget _panel() {
    final adReady = AdsService.instance.rewardedReady.value;
    final c = _controller;
    final s = c.state;
    final List<Widget> children;
    if (s.winner != null) {
      final next = _playerWon ? widget.nextBuilder : null;
      children = [
        if (next != null)
          _button(tr('Next', 'Màn tiếp'), () {
            AdsService.instance.maybeShowInterstitial();
            Navigator.of(
              context,
            ).pushReplacement(MaterialPageRoute<void>(builder: next));
          }),
        _button(tr('Play again', 'Chơi lại'), () {
          AdsService.instance.maybeShowInterstitial();
          c.restart();
        }, primary: next == null),
        _button(tr('Menu', 'Về menu'), () {
          AdsService.instance.maybeShowInterstitial();
          Navigator.of(context).pop();
        }, primary: false),
      ];
    } else if (c.aiTurn) {
      children = [
        _hint(
          tr('The enemy is taking its turn.', 'Địch đang đi lượt của chúng.'),
        ),
        ValueListenableBuilder(
          valueListenable: Settings.speed,
          builder: (context, speed, _) => _button(
            tr('Speed x$speed', 'Tốc độ x$speed'),
            Settings.cycleSpeed,
            primary: false,
          ),
        ),
      ];
    } else {
      switch (c.phase) {
        case Phase.idle:
          children = [
            _hint(
              c.hintAction == null
                  ? tr(
                      'Tap one of your units, or your tent to recruit.',
                      'Chạm quân của bạn, hoặc lều trại để chiêu mộ.',
                    )
                  : _describeHint(c.hintAction!),
            ),
            if (adReady && c.canHint && c.hintAction == null)
              _button(
                tr('Hint (ad)', 'Gợi ý (QC)'),
                () => _afterAd(c.showHint),
                primary: false,
              ),
            if (c.canUndo)
              _button(tr('Undo', 'Hoàn tác'), c.undo, primary: false)
            else if (adReady && c.canUndoWithAd)
              _button(
                tr('Undo (ad)', 'Hoàn tác (QC)'),
                () => _afterAd(() => c.undo(rewarded: true)),
                primary: false,
              ),
            if (c.canUsePower)
              _button(s.commanders[s.currentPlayer]!.powerName, _confirmPower),
            _button(tr('End turn', 'Hết lượt'), c.endTurn),
          ];
        case Phase.moving:
          final u = c.selected!;
          children = [
            _hint(
              '${u.type.label}${u.rank > 0 ? ' ${'★' * u.rank}' : ''} · '
              '${tr('HP', 'Máu')} ${u.displayHp}/10 · '
              '${tr('Move', 'Đi')} ${s.moveRange(u)}\n'
              '${tr('Tap a blue tile to move there.', 'Chạm ô xanh để đi tới đó.')}',
            ),
            _button(tr('Cancel', 'Hủy'), c.cancel, primary: false),
          ];
        case Phase.menu:
          children = [
            if (c.selected!.type.canHeal)
              _button(
                tr('Heal', 'Hồi máu'),
                c.healTargets.isEmpty ? null : c.chooseHeal,
              )
            else
              _button(
                tr('Attack', 'Tấn công'),
                c.targets.isEmpty ? null : c.chooseAttack,
              ),
            _button(
              tr('Capture', 'Chiếm'),
              c.canCapture ? c.chooseCapture : null,
            ),
            _button(tr('Wait', 'Chờ'), c.chooseWait),
            _button(tr('Back', 'Quay lại'), c.cancel, primary: false),
          ];
        case Phase.targeting:
          final f = c.forecast;
          final lethal = f != null && f.damage >= s.unitAt(c.target!)!.hp;
          children = [
            _hint(
              c.healing
                  ? c.target == null
                        ? tr(
                            'Tap a wounded ally marked in green.',
                            'Chạm đồng đội bị thương có viền xanh lá.',
                          )
                        : tr(
                            'Restore up to ${formatHp(UnitType.healAmount)} HP.',
                            'Hồi tối đa ${formatHp(UnitType.healAmount)} máu.',
                          )
                  : f == null
                  ? tr('Tap an enemy marked in red.', 'Chạm quân địch viền đỏ.')
                  : lethal
                  ? tr(
                      'Deal ${formatHp(f.damage)} · defeats the enemy',
                      'Gây ${formatHp(f.damage)} · hạ gục địch',
                    )
                  : tr(
                      'Deal ${formatHp(f.damage)} · take ${formatHp(f.counter)}',
                      'Gây ${formatHp(f.damage)} · nhận ${formatHp(f.counter)}',
                    ),
            ),
            c.healing
                ? _button(
                    tr('Heal', 'Hồi máu'),
                    c.target == null ? null : c.confirmAttack,
                  )
                : _button(
                    tr('Attack', 'Tấn công'),
                    f == null ? null : c.confirmAttack,
                  ),
            _button(tr('Back', 'Quay lại'), c.cancel, primary: false),
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
                    '${tr('Move', 'Đi')} ${type.move} · ${tr('Range', 'Tầm')} '
                    '${type.minRange == type.maxRange ? type.maxRange : '${type.minRange}-${type.maxRange}'}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton(onPressed: c.cancel, child: Text(tr('Close', 'Đóng'))),
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
                  tr(
                    '${playerName(player)}\'s turn',
                    'Lượt của ${playerName(player)}',
                  ),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: playerColors[player],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tr(
                    'Pass the device, then tap to continue.',
                    'Chuyển máy cho người kia, rồi chạm để tiếp tục.',
                  ),
                ),
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
              Text(
                tr('Paused', 'Tạm dừng'),
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
                child: Text(tr('Resume', 'Tiếp tục')),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  SaveService.clear();
                  _controller.restart();
                },
                child: Text(tr('Restart', 'Chơi lại')),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  AdsService.instance.maybeShowInterstitial();
                  Navigator.of(context).pop();
                },
                child: Text(tr('Quit to menu', 'Về menu')),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _soundToggle(
                    SoundService.instance.musicEnabled,
                    Icons.music_note,
                    Icons.music_off,
                    tr('Music', 'Nhạc'),
                    SoundService.instance.toggleMusic,
                  ),
                  _soundToggle(
                    SoundService.instance.sfxEnabled,
                    Icons.volume_up,
                    Icons.volume_off,
                    tr('Sound effects', 'Hiệu ứng âm thanh'),
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
