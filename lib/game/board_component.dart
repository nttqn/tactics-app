import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../core/actions.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/rules.dart';
import 'board_art.dart';
import 'game_controller.dart';

export 'board_art.dart' show playerColors;

class _UnitVisual {
  /// The unit as last seen in the game state; kept after death so the
  /// figure can still be drawn while it fades.
  Unit unit;

  /// Drawn position in tile units; trails behind [goal] while animating.
  Offset pos;
  Pos goal;
  final List<Offset> waypoints = [];

  /// Remaining seconds of the forward lunge, and its direction.
  double lunge = 0;
  Offset lungeDir = Offset.zero;

  /// Remaining seconds of the white hit flash.
  double flash = 0;

  /// Seconds since recruited, for the pop-in; negative once finished.
  double spawn = -1;

  /// Null while alive. Once set, counts up through the death fade.
  double? death;

  _UnitVisual(this.unit, this.goal)
    : pos = Offset(goal.x.toDouble(), goal.y.toDouble());
}

class _Popup {
  final String text;
  final Offset at;
  final TextPaint paint;
  double age = 0;
  _Popup(this.text, this.at, this.paint);
}

class _Particle {
  Offset pos;
  final Offset velocity;
  final Color color;
  final double size;
  final double life;

  /// Smoke swells as it fades; sparks shrink.
  final bool grows;
  double age = 0;
  _Particle(
    this.pos,
    this.velocity,
    this.color,
    this.size,
    this.life, {
    this.grows = false,
  });
}

class _Projectile {
  final Offset from, to;
  final bool arc;
  double age = 0;
  _Projectile(this.from, this.to, {required this.arc});
}

class _Ring {
  final Offset at;
  final Color color;
  double age = 0;
  _Ring(this.at, this.color);
}

class _Banner {
  final String text;
  final Color color;
  double age = 0;
  _Banner(this.text, this.color);
}

class _Scheduled {
  double delay;
  final void Function() fire;
  _Scheduled(this.delay, this.fire);
}

/// Draws the whole match (terrain, highlights, units, battle effects) and
/// forwards taps to the [GameController].
class BoardComponent extends PositionComponent with TapCallbacks {
  static const _tilesPerSecond = 10.0;
  static const _popupLife = 0.9;
  static const _lungeTime = 0.26;
  static const _flashTime = 0.3;
  static const _shotTime = 0.24;
  static const _deathTime = 0.5;
  static const _spawnTime = 0.3;
  static const _ringTime = 0.6;
  static const _bannerTime = 1.3;

  final GameController controller;
  final _visuals = <int, _UnitVisual>{};
  final _popups = <_Popup>[];
  final _particles = <_Particle>[];
  final _projectiles = <_Projectile>[];
  final _rings = <_Ring>[];
  final _scheduled = <_Scheduled>[];
  final _random = Random();
  final _paint = Paint();
  _Banner? _banner;
  GameState? _lastState;

  /// Seconds since the board appeared; drives idle and water animation.
  double _time = 0;

  static TextPaint _text(Color color, [double size = 22]) => TextPaint(
    style: TextStyle(
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w900,
      shadows: const [Shadow(color: ink, blurRadius: 4)],
    ),
  );
  static final _damageText = _text(const Color(0xFFFFF176));
  static final _healText = _text(const Color(0xFF8CF29B));
  static final _alertText = _text(const Color(0xFFFF8A80));
  static final _bannerText = _text(const Color(0xFFFFFFFF), 34);

  BoardComponent(this.controller) {
    final s = controller.state;
    size = Vector2(s.width * tile, s.height * tile);
    controller.eventListeners.add(_onEvents);
  }

  @override
  void onTapUp(TapUpEvent event) {
    final p = event.localPosition;
    controller.tapTile(Pos(p.x ~/ tile, p.y ~/ tile));
  }

  static Offset _offset(Pos p) => Offset(p.x.toDouble(), p.y.toDouble());

  void _after(double delay, void Function() fire) =>
      _scheduled.add(_Scheduled(delay, fire));

  bool _seen(Offset at) => controller.state.isVisible(
    controller.viewer,
    Pos(at.dx.round(), at.dy.round()),
  );

  /// Turns the events of one applied action into a short timed sequence:
  /// walk, strike, flash, counter, fall.
  void _onEvents(List<GameEvent> events) {
    final s = controller.state;
    var t = 0.0;
    for (final e in events) {
      switch (e) {
        case UnitMoved():
          final v = _visuals[e.unitId];
          // The player's own move was already animated as a preview.
          if (v == null || v.goal == e.path.last) break;
          v.goal = e.path.last;
          v.waypoints
            ..clear()
            ..addAll(e.path.skip(1).map(_offset));
          t += (e.path.length - 1) / _tilesPerSecond;
        case UnitDamaged():
          final attacker = _visuals[e.attackerId];
          final defender = _visuals[e.defenderId];
          if (attacker == null || defender == null) break;
          final from = _offset(attacker.goal), to = _offset(defender.goal);
          final ranged = (from - to).distance > 1.5;
          _after(t, () {
            if (ranged) {
              _projectiles.add(
                _Projectile(
                  from,
                  to,
                  arc: attacker.unit.type == UnitType.catapult,
                ),
              );
            } else {
              attacker
                ..lunge = _lungeTime
                ..lungeDir = (to - from) / (to - from).distance * 0.32;
            }
          });
          final impact = t + (ranged ? _shotTime : _lungeTime / 2);
          _after(impact, () {
            defender.flash = _flashTime;
            if (!_seen(to)) return;
            _popups.add(_Popup('-${formatHp(e.damage)}', to, _damageText));
            _burst(to, const Color(0xFFFFE082), 7, speed: 2.2, life: 0.3);
          });
          t = impact + 0.26;
        case UnitDied():
          final v = _visuals[e.unitId];
          if (v == null) break;
          // Hold the figure on the board until its hit has landed.
          v.death = -t;
          _after(t, () {
            if (_seen(v.pos)) _smoke(v.pos);
          });
        case UnitHealed():
          final v = _visuals[e.unitId];
          if (v == null) break;
          _after(t, () {
            _popups.add(_Popup('+${formatHp(e.amount)}', v.pos, _healText));
            _burst(
              v.pos,
              const Color(0xFF8CF29B),
              6,
              speed: 1.2,
              life: 0.6,
              up: true,
            );
          });
          t += 0.12;
        case UnitPromoted():
          final v = _visuals[e.unitId];
          if (v == null) break;
          _after(t + 0.1, () {
            _popups.add(
              _Popup('Rank up!', v.pos - const Offset(0, 0.4), _damageText),
            );
            _rings.add(_Ring(v.pos, const Color(0xFFFFD54F)));
          });
        case CaptureProgressed():
          _after(t, () {
            _burst(
              _offset(e.at) + const Offset(0, 0.3),
              const Color(0xFFD9C7A0),
              6,
              speed: 1.0,
              life: 0.5,
              grows: true,
            );
          });
        case BuildingCaptured():
          _after(t, () {
            _popups.add(_Popup('Captured!', _offset(e.at), _damageText));
            _rings.add(_Ring(_offset(e.at), playerColors[e.owner]));
          });
        case UnitBuilt():
          // The visual does not exist yet; it is created on the next update.
          _after(0, () => _visuals[e.unitId]?.spawn = 0);
        case Ambushed():
          _after(t, () {
            _popups.add(_Popup('Ambush!', _offset(e.stoppedAt), _alertText));
          });
        case PowerUsed():
          _banner = _Banner(e.commander.power, playerColors[e.player]);
        case TurnStarted():
          // Against the computer only the player's own turn is announced.
          if (controller.ai == null || e.player == 0) {
            _banner = _Banner('Day ${s.turn}', playerColors[e.player]);
          }
        case GameOver():
          break;
      }
    }
  }

  void _burst(
    Offset at,
    Color color,
    int count, {
    required double speed,
    required double life,
    bool up = false,
    bool grows = false,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = up
          ? -pi / 2 + (_random.nextDouble() - 0.5) * 1.2
          : _random.nextDouble() * 2 * pi;
      final v = speed * (0.5 + _random.nextDouble() * 0.5);
      _particles.add(
        _Particle(
          at +
              Offset(_random.nextDouble() - 0.5, _random.nextDouble() - 0.5) *
                  0.3,
          Offset(cos(angle), sin(angle)) * v,
          color,
          grows ? 5 : 3,
          life,
          grows: grows,
        ),
      );
    }
  }

  void _smoke(Offset at) => _burst(
    at + const Offset(0, 0.15),
    const Color(0xFFB0B0B0),
    8,
    speed: 0.8,
    life: 0.6,
    grows: true,
  );

  @override
  void update(double dt) {
    _time += dt;
    final s = controller.state;
    if (!identical(s, _lastState)) {
      // A different match state (restart, undo): drop everything in flight.
      _visuals.clear();
      _popups.clear();
      _particles.clear();
      _projectiles.clear();
      _rings.clear();
      _scheduled.clear();
      _banner = null;
      _lastState = s;
    }

    for (final item in _scheduled) {
      item.delay -= dt;
    }
    final due = _scheduled.where((i) => i.delay <= 0).toList();
    _scheduled.removeWhere((i) => i.delay <= 0);
    for (final item in due) {
      item.fire();
    }

    final alive = <int>{};
    for (final unit in s.units) {
      alive.add(unit.id);
      final previewing =
          controller.destination != null && controller.selected?.id == unit.id;
      final desired = previewing ? controller.destination! : unit.pos;
      final v = _visuals.putIfAbsent(unit.id, () => _UnitVisual(unit, desired));
      v.unit = unit;
      if (v.goal != desired) {
        v.goal = desired;
        v.waypoints.clear();
        if (previewing) {
          v.pos = _offset(unit.pos);
          v.waypoints.addAll(controller.previewPath.skip(1).map(_offset));
        } else {
          v.pos = _offset(desired);
        }
      }
    }
    for (final v in _visuals.values) {
      var budget = _tilesPerSecond * dt;
      while (budget > 0 && v.waypoints.isNotEmpty) {
        final delta = v.waypoints.first - v.pos;
        if (delta.distance <= budget) {
          budget -= delta.distance;
          v.pos = v.waypoints.removeAt(0);
        } else {
          v.pos += delta / delta.distance * budget;
          budget = 0;
        }
      }
      v.lunge = max(0, v.lunge - dt);
      v.flash = max(0, v.flash - dt);
      if (v.spawn >= 0) {
        v.spawn += dt;
        if (v.spawn > _spawnTime) v.spawn = -1;
      }
      if (v.death != null) v.death = v.death! + dt;
    }
    // Units that left the state linger only while their death plays out.
    _visuals.removeWhere(
      (id, v) =>
          !alive.contains(id) && (v.death == null || v.death! > _deathTime),
    );

    for (final p in _popups) {
      p.age += dt;
    }
    _popups.removeWhere((p) => p.age > _popupLife);
    for (final p in _particles) {
      p.age += dt;
      p.pos += p.velocity * dt;
    }
    _particles.removeWhere((p) => p.age > p.life);
    for (final p in _projectiles) {
      p.age += dt;
    }
    _projectiles.removeWhere((p) => p.age > _shotTime);
    for (final r in _rings) {
      r.age += dt;
    }
    _rings.removeWhere((r) => r.age > _ringTime);
    final banner = _banner;
    if (banner != null) {
      banner.age += dt;
      if (banner.age > _bannerTime) _banner = null;
    }
  }

  @override
  void render(Canvas canvas) {
    final s = controller.state;
    for (var y = 0; y < s.height; y++) {
      for (var x = 0; x < s.width; x++) {
        drawTerrain(canvas, s, Pos(x, y), time: _time);
      }
    }
    final viewer = controller.viewer;
    if (s.fog) {
      _fill(canvas, const Color(0xA60B0F1A));
      for (var y = 0; y < s.height; y++) {
        for (var x = 0; x < s.width; x++) {
          if (!s.isVisible(viewer, Pos(x, y))) {
            canvas.drawRect(_rect(Pos(x, y)), _paint);
          }
        }
      }
    }
    _drawHighlights(canvas);

    // Lower rows are drawn last so figures overlap the tile above them.
    final order = _visuals.values.toList()
      ..sort((a, b) => a.pos.dy.compareTo(b.pos.dy));
    for (final v in order) {
      if (v.unit.owner != viewer && !_seen(v.pos)) continue;
      _drawUnit(canvas, s, v);
    }

    for (final p in _projectiles) {
      _drawProjectile(canvas, p);
    }
    for (final r in _rings) {
      final k = r.age / _ringTime;
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - k)
        ..color = r.color.withValues(alpha: 1 - k);
      canvas.drawCircle(_centre(r.at), tile * (0.3 + 0.5 * k), _paint);
    }
    for (final p in _particles) {
      final k = p.age / p.life;
      _fill(canvas, p.color.withValues(alpha: (1 - k) * 0.9));
      canvas.drawCircle(
        _centre(p.pos),
        p.grows ? p.size * (1 + k * 1.6) : p.size * (1 - k * 0.6),
        _paint,
      );
    }
    for (final p in _popups) {
      final rise = p.age / _popupLife * 0.6;
      p.paint.render(
        canvas,
        p.text,
        Vector2((p.at.dx + 0.5) * tile, (p.at.dy + 0.2 - rise) * tile),
        anchor: Anchor.center,
      );
    }
    _drawBanner(canvas);
  }

  Offset _centre(Offset tilePos) =>
      Offset((tilePos.dx + 0.5) * tile, (tilePos.dy + 0.5) * tile);

  Rect _rect(Pos p) => tileRect(p);

  void _fill(Canvas canvas, Color color) {
    _paint
      ..style = PaintingStyle.fill
      ..color = color;
  }

  void _outline(Canvas canvas, Pos p, Color color) {
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = color;
    canvas.drawRect(_rect(p).deflate(2), _paint);
  }

  void _drawHighlights(Canvas canvas) {
    // Tints breathe slightly so they read as interactive.
    final pulse = 0.85 + sin(_time * 4) * 0.15;
    final moveTint = const Color(0xFF3B9BFF).withValues(alpha: 0.4 * pulse);
    final attackTint = const Color(0xFFFF3B3B).withValues(alpha: 0.45 * pulse);
    const focus = Color(0xFFFFE14D);
    switch (controller.phase) {
      case Phase.idle:
        break;
      case Phase.moving:
        for (final p in controller.moves!.destinations) {
          _fill(canvas, moveTint);
          canvas.drawRect(_rect(p).deflate(1), _paint);
        }
        for (final p in controller.threatened) {
          _fill(canvas, attackTint);
          canvas.drawRect(_rect(p).deflate(1), _paint);
        }
      case Phase.menu:
        _outline(canvas, controller.destination!, focus);
      case Phase.targeting:
        for (final t in controller.currentTargets) {
          _fill(
            canvas,
            controller.healing
                ? const Color(0xFF39D353).withValues(alpha: 0.45 * pulse)
                : attackTint,
          );
          canvas.drawRect(_rect(t.pos).deflate(1), _paint);
        }
        _outline(canvas, controller.destination!, focus);
        if (controller.target != null) {
          _outline(canvas, controller.target!, const Color(0xFFFFFFFF));
        }
      case Phase.building:
        _outline(canvas, controller.buildAt!, focus);
    }
  }

  void _drawUnit(Canvas canvas, GameState s, _UnitVisual v) {
    var at = v.pos;
    if (v.lunge > 0) {
      at += v.lungeDir * sin(pi * (1 - v.lunge / _lungeTime));
    }
    if (v.flash > 0) {
      // A struck unit shudders sideways.
      at += Offset(sin(v.flash * 60) * 0.04, 0);
    }
    final centre = _centre(at);
    final fading = (v.death ?? -1) > 0;
    final popping = v.spawn >= 0;
    if (fading) {
      final k = (v.death! / _deathTime).clamp(0.0, 1.0);
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(255, 255, 255, 1 - k),
      );
      canvas.translate(0, k * 8);
    } else if (popping) {
      // Recruits pop in with a small overshoot, growing from the feet.
      final k = v.spawn / _spawnTime;
      final scale = k < 0.7 ? k / 0.7 * 1.15 : 1.15 - (k - 0.7) / 0.3 * 0.15;
      canvas.save();
      canvas.translate(centre.dx, centre.dy + 19);
      canvas.scale(scale);
      canvas.translate(-centre.dx, -(centre.dy + 19));
    }
    drawUnit(
      canvas,
      centre,
      v.unit,
      spent: v.unit.acted && v.unit.owner == s.currentPlayer,
      selected: controller.selected?.id == v.unit.id,
      time: _time,
      flash: v.flash / _flashTime,
      showHp: v.death == null,
    );
    if (fading || popping) canvas.restore();
  }

  void _drawProjectile(Canvas canvas, _Projectile p) {
    final k = (p.age / _shotTime).clamp(0.0, 1.0);
    final from = _centre(p.from) - const Offset(0, 8);
    final to = _centre(p.to) - const Offset(0, 4);
    // Catapult stones lob high; arrows fly nearly flat.
    final height = (p.arc ? 40.0 : 10.0) * sin(pi * k);
    final at = Offset.lerp(from, to, k)! - Offset(0, height);
    if (p.arc) {
      _fill(canvas, ink);
      canvas.drawCircle(at, 6, _paint);
      _fill(canvas, const Color(0xFF9E9E9E));
      canvas.drawCircle(at, 4.5, _paint);
    } else {
      final dir = (to - from) / (to - from).distance;
      _paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = ink;
      canvas.drawLine(at - dir * 9, at + dir * 9, _paint);
      _paint
        ..strokeWidth = 1.6
        ..color = const Color(0xFFE8D9B5);
      canvas.drawLine(at - dir * 9, at + dir * 9, _paint);
    }
  }

  /// A ribbon across the middle of the board that slides in and fades out.
  void _drawBanner(Canvas canvas) {
    final banner = _banner;
    if (banner == null) return;
    final k = banner.age / _bannerTime;
    final alpha = k < 0.15
        ? k / 0.15
        : k > 0.75
        ? (1 - k) / 0.25
        : 1.0;
    final slide = (1 - min(1.0, k / 0.15)) * 40;
    final band = Rect.fromCenter(
      center: Offset(size.x / 2 - slide, size.y / 2),
      width: size.x,
      height: 64,
    );
    _fill(canvas, ink.withValues(alpha: 0.72 * alpha));
    canvas.drawRect(band, _paint);
    _fill(canvas, banner.color.withValues(alpha: alpha));
    canvas.drawRect(Rect.fromLTWH(band.left, band.top, band.width, 4), _paint);
    canvas.drawRect(
      Rect.fromLTWH(band.left, band.bottom - 4, band.width, 4),
      _paint,
    );
    TextPaint(
      style: _bannerText.style.copyWith(
        color: const Color(0xFFFFFFFF).withValues(alpha: alpha),
      ),
    ).render(
      canvas,
      banner.text,
      Vector2(band.center.dx, band.center.dy),
      anchor: Anchor.center,
    );
  }
}

/// Internal HP is 0..100; players see it on a 0..10 scale.
String formatHp(int hp) => (hp / 10).toStringAsFixed(1);
