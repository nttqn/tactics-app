import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../core/actions.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import 'game_controller.dart';

const playerColors = [Color(0xFF3B82F6), Color(0xFFEF4444)];
const _neutral = Color(0xFFBDBDBD);
const _ink = Color(0xFF1B1F2A);

class _UnitVisual {
  /// Drawn position in tile units; trails behind [goal] while animating.
  Offset pos;
  Pos goal;
  final List<Offset> waypoints = [];

  _UnitVisual(this.goal) : pos = Offset(goal.x.toDouble(), goal.y.toDouble());
}

class _Popup {
  final String text;
  final Offset at;
  double age = 0;
  _Popup(this.text, this.at);
}

/// Draws the whole match (terrain, highlights, units) with plain shapes and
/// forwards taps to the [GameController].
class BoardComponent extends PositionComponent with TapCallbacks {
  static const tile = 64.0;
  static const _tilesPerSecond = 10.0;
  static const _popupLife = 0.9;

  final GameController controller;
  final _visuals = <int, _UnitVisual>{};
  final _popups = <_Popup>[];
  final _paint = Paint();
  GameState? _lastState;

  static final _glyph = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 26,
      fontWeight: FontWeight.w800,
    ),
  );
  static final _badge = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 15,
      fontWeight: FontWeight.w700,
    ),
  );
  static final _popupText = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFF176),
      fontSize: 22,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: _ink, blurRadius: 4)],
    ),
  );

  BoardComponent(this.controller) {
    final s = controller.state;
    size = Vector2(s.width * tile, s.height * tile);
    controller.onEvents = _onEvents;
  }

  @override
  void onTapUp(TapUpEvent event) {
    final p = event.localPosition;
    controller.tapTile(Pos(p.x ~/ tile, p.y ~/ tile));
  }

  void _onEvents(List<GameEvent> events) {
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
        case UnitDamaged():
          final v = _visuals[e.defenderId];
          if (v != null) {
            _popups.add(_Popup('-${formatHp(e.damage)}', v.pos));
          }
        case BuildingCaptured():
          _popups.add(_Popup('Captured!', _offset(e.at)));
        default:
          break;
      }
    }
  }

  static Offset _offset(Pos p) => Offset(p.x.toDouble(), p.y.toDouble());

  @override
  void update(double dt) {
    final s = controller.state;
    if (!identical(s, _lastState)) {
      _visuals.clear();
      _popups.clear();
      _lastState = s;
    }
    final alive = <int>{};
    for (final unit in s.units) {
      alive.add(unit.id);
      final previewing =
          controller.destination != null && controller.selected?.id == unit.id;
      final desired = previewing ? controller.destination! : unit.pos;
      final v = _visuals.putIfAbsent(unit.id, () => _UnitVisual(desired));
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
    }
    _visuals.removeWhere((id, _) => !alive.contains(id));
    for (final p in _popups) {
      p.age += dt;
    }
    _popups.removeWhere((p) => p.age > _popupLife);
  }

  @override
  void render(Canvas canvas) {
    final s = controller.state;
    for (var y = 0; y < s.height; y++) {
      for (var x = 0; x < s.width; x++) {
        _drawTerrain(canvas, s, Pos(x, y));
      }
    }
    _drawHighlights(canvas);
    for (final unit in s.units) {
      final v = _visuals[unit.id];
      if (v != null) _drawUnit(canvas, s, unit, v.pos);
    }
    for (final p in _popups) {
      final rise = p.age / _popupLife * 0.6;
      _popupText.render(
        canvas,
        p.text,
        Vector2((p.at.dx + 0.5) * tile, (p.at.dy + 0.2 - rise) * tile),
        anchor: Anchor.center,
      );
    }
  }

  Rect _rect(Pos p) => Rect.fromLTWH(p.x * tile, p.y * tile, tile, tile);

  bool _isWet(GameState s, Pos p) =>
      s.inBounds(p) &&
      (s.terrainAt(p) == Terrain.water || s.terrainAt(p) == Terrain.bridge);

  void _fill(Canvas canvas, Color color) {
    _paint
      ..style = PaintingStyle.fill
      ..color = color;
  }

  void _drawTerrain(Canvas canvas, GameState s, Pos p) {
    final r = _rect(p);
    final c = r.center;
    final t = s.terrainAt(p);
    final wet = t == Terrain.water || t == Terrain.bridge;
    _fill(
      canvas,
      wet
          ? const Color(0xFF3F7FD0)
          : (p.x + p.y).isEven
          ? const Color(0xFF7CB860)
          : const Color(0xFF74AE59),
    );
    canvas.drawRect(r, _paint);

    switch (t) {
      case Terrain.plain || Terrain.water:
        break;
      case Terrain.forest:
        _fill(canvas, const Color(0xFF2F6B3A));
        canvas.drawCircle(c + const Offset(-12, 8), 13, _paint);
        canvas.drawCircle(c + const Offset(12, 8), 13, _paint);
        _fill(canvas, const Color(0xFF3B8048));
        canvas.drawCircle(c + const Offset(0, -8), 15, _paint);
      case Terrain.mountain:
        _fill(canvas, const Color(0xFF8A8173));
        canvas.drawPath(
          Path()
            ..moveTo(r.left + 6, r.bottom - 8)
            ..lineTo(c.dx, r.top + 8)
            ..lineTo(r.right - 6, r.bottom - 8)
            ..close(),
          _paint,
        );
        _fill(canvas, const Color(0xFFF2F2F2));
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 9, r.top + 23)
            ..lineTo(c.dx, r.top + 8)
            ..lineTo(c.dx + 9, r.top + 23)
            ..close(),
          _paint,
        );
      case Terrain.bridge:
        // Planks run across the river: vertical when water is left/right.
        final crossesVertically =
            _isWet(s, Pos(p.x - 1, p.y)) || _isWet(s, Pos(p.x + 1, p.y));
        _fill(canvas, const Color(0xFF9C6B3E));
        canvas.drawRect(
          crossesVertically
              ? Rect.fromLTRB(r.left + 12, r.top, r.right - 12, r.bottom)
              : Rect.fromLTRB(r.left, r.top + 12, r.right, r.bottom - 12),
          _paint,
        );
      case Terrain.city || Terrain.barracks || Terrain.hq:
        _drawBuilding(canvas, s, p, t);
    }
  }

  void _drawBuilding(Canvas canvas, GameState s, Pos p, Terrain t) {
    final r = _rect(p);
    final c = r.center;
    final owner = s.owners[p];
    final color = owner == null ? _neutral : playerColors[owner];
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _ink;
    final shape = Path();
    switch (t) {
      case Terrain.city:
        // House: square body with a pitched roof.
        shape
          ..moveTo(c.dx - 16, r.bottom - 10)
          ..lineTo(c.dx - 16, c.dy - 2)
          ..lineTo(c.dx, r.top + 12)
          ..lineTo(c.dx + 16, c.dy - 2)
          ..lineTo(c.dx + 16, r.bottom - 10)
          ..close();
      case Terrain.barracks:
        // Tent.
        shape
          ..moveTo(r.left + 8, r.bottom - 10)
          ..lineTo(c.dx, r.top + 12)
          ..lineTo(r.right - 8, r.bottom - 10)
          ..close();
      default:
        // Castle keep with three merlons.
        final top = r.top + 12, mid = r.top + 22;
        shape
          ..moveTo(r.left + 10, r.bottom - 8)
          ..lineTo(r.left + 10, top)
          ..lineTo(r.left + 20, top)
          ..lineTo(r.left + 20, mid)
          ..lineTo(r.left + 27, mid)
          ..lineTo(r.left + 27, top)
          ..lineTo(r.left + 37, top)
          ..lineTo(r.left + 37, mid)
          ..lineTo(r.left + 44, mid)
          ..lineTo(r.left + 44, top)
          ..lineTo(r.left + 54, top)
          ..lineTo(r.left + 54, r.bottom - 8)
          ..close();
    }
    _fill(canvas, color);
    canvas.drawPath(shape, _paint);
    canvas.drawPath(shape, outline);

    final remaining = s.capture[p];
    if (remaining != null) {
      final bar = Rect.fromLTWH(r.left + 6, r.bottom - 8, tile - 12, 5);
      _fill(canvas, _ink);
      canvas.drawRect(bar, _paint);
      _fill(canvas, const Color(0xFFFFD54F));
      canvas.drawRect(
        Rect.fromLTWH(
          bar.left,
          bar.top,
          bar.width * (1 - remaining / GameState.capturePoints),
          bar.height,
        ),
        _paint,
      );
    }
  }

  void _outline(Canvas canvas, Pos p, Color color) {
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = color;
    canvas.drawRect(_rect(p).deflate(2), _paint);
  }

  void _drawHighlights(Canvas canvas) {
    const moveTint = Color(0x663B9BFF);
    const attackTint = Color(0x73FF3B3B);
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
        for (final t in controller.targets) {
          _fill(canvas, attackTint);
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

  void _drawUnit(Canvas canvas, GameState s, Unit unit, Offset at) {
    final c = Offset((at.dx + 0.5) * tile, (at.dy + 0.5) * tile);
    final spent = unit.acted && unit.owner == s.currentPlayer;
    final base = playerColors[unit.owner];
    _fill(canvas, spent ? Color.lerp(base, const Color(0xFF555555), 0.6)! : base);
    canvas.drawCircle(c, 23, _paint);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = controller.selected?.id == unit.id ? 4 : 2
      ..color = controller.selected?.id == unit.id
          ? const Color(0xFFFFE14D)
          : _ink;
    canvas.drawCircle(c, 23, _paint);
    _glyph.render(
      canvas,
      unit.type.name[0].toUpperCase(),
      Vector2(c.dx, c.dy),
      anchor: Anchor.center,
    );
    if (unit.displayHp < 10) {
      final badge = Rect.fromLTWH(c.dx + 8, c.dy + 10, 20, 20);
      _fill(canvas, _ink);
      canvas.drawRRect(
        RRect.fromRectAndRadius(badge, const Radius.circular(5)),
        _paint,
      );
      _badge.render(
        canvas,
        '${unit.displayHp}',
        Vector2(badge.center.dx, badge.center.dy),
        anchor: Anchor.center,
      );
    }
  }
}

/// Internal HP is 0..100; players see it on a 0..10 scale.
String formatHp(int hp) => (hp / 10).toStringAsFixed(1);
