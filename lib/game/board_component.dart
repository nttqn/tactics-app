import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../core/actions.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import 'board_art.dart';
import 'game_controller.dart';

export 'board_art.dart' show playerColors;

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

/// Draws the whole match (terrain, highlights, units) and forwards taps to the [GameController].
class BoardComponent extends PositionComponent with TapCallbacks {
  static const _tilesPerSecond = 10.0;
  static const _popupLife = 0.9;

  final GameController controller;
  final _visuals = <int, _UnitVisual>{};
  final _popups = <_Popup>[];
  final _paint = Paint();
  GameState? _lastState;

  static final _popupText = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFF176),
      fontSize: 22,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: ink, blurRadius: 4)],
    ),
  );

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
        drawTerrain(canvas, s, Pos(x, y));
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
    drawUnit(
      canvas,
      Offset((at.dx + 0.5) * tile, (at.dy + 0.5) * tile),
      unit,
      spent: unit.acted && unit.owner == s.currentPlayer,
      selected: controller.selected?.id == unit.id,
    );
  }
}

/// Internal HP is 0..100; players see it on a 0..10 scale.
String formatHp(int hp) => (hp / 10).toStringAsFixed(1);
