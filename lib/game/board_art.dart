import 'dart:math';

import 'package:flutter/painting.dart';

import '../core/game_state.dart';
import '../core/models.dart';

/// All board artwork, drawn with canvas primitives (no image assets).
/// Everything is laid out for a [tile]-sized square.
const tile = 64.0;

const playerColors = [Color(0xFF2F6FDB), Color(0xFFD63A3A)];
const _neutral = Color(0xFFB8B2A7);
const ink = Color(0xFF1B1F2A);
const _white = Color(0xFFFFFFFF);
const _stone = Color(0xFFCFC8BA);
const _wall = Color(0xFFEADFC8);
const _wood = Color(0xFF8A5A33);

final _fill = Paint();
final _stroke = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint _f(Color color) => _fill..color = color;

Paint _s(Color color, double width) => _stroke
  ..color = color
  ..strokeWidth = width;

Rect tileRect(Pos p) => Rect.fromLTWH(p.x * tile, p.y * tile, tile, tile);

Path _poly(List<double> xy) {
  final path = Path()..moveTo(xy[0], xy[1]);
  for (var i = 2; i < xy.length; i += 2) {
    path.lineTo(xy[i], xy[i + 1]);
  }
  return path..close();
}

bool _isWet(GameState s, Pos p) =>
    s.inBounds(p) &&
    (s.terrainAt(p) == Terrain.water || s.terrainAt(p) == Terrain.bridge);

void drawTerrain(Canvas canvas, GameState s, Pos p) {
  final r = tileRect(p);
  final t = s.terrainAt(p);
  final wet = t == Terrain.water || t == Terrain.bridge;
  // Stable per-tile variation so the field doesn't look stamped.
  final hash = (p.x * 73856093) ^ (p.y * 19349663);

  canvas.save();
  canvas.translate(r.left, r.top);
  if (wet) {
    canvas.drawRect(Offset.zero & r.size, _f(const Color(0xFF3B78C9)));
    for (var i = 0; i < 2; i++) {
      final x = 8.0 + (hash >> (i * 3) & 7) * 3 + i * 22;
      final y = 18.0 + i * 26;
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..quadraticBezierTo(x + 5, y - 5, x + 10, y)
          ..quadraticBezierTo(x + 15, y + 5, x + 20, y),
        _s(const Color(0x66FFFFFF), 2),
      );
    }
  } else {
    canvas.drawRect(
      Offset.zero & r.size,
      _f(
        (p.x + p.y).isEven ? const Color(0xFF7DB85F) : const Color(0xFF76B059),
      ),
    );
    if (t == Terrain.plain) {
      for (var i = 0; i < 3; i++) {
        final x = 8.0 + (hash >> (i * 4) & 15) * 3;
        final y = 12.0 + (hash >> (i * 4 + 2) & 15) * 3;
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 2, y - 5),
          _s(const Color(0xFF5E9A48), 2),
        );
        canvas.drawLine(
          Offset(x + 4, y),
          Offset(x + 3, y - 4),
          _s(const Color(0xFF5E9A48), 2),
        );
      }
    }
  }

  switch (t) {
    case Terrain.plain || Terrain.water:
      break;
    case Terrain.forest:
      _pine(canvas, 17, 54, 0.85);
      _pine(canvas, 47, 56, 0.85);
      _pine(canvas, 32, 46, 1);
    case Terrain.mountain:
      canvas.drawPath(
        _poly([4, 56, 24, 16, 44, 56]),
        _f(const Color(0xFF7E776B)),
      );
      canvas.drawPath(
        _poly([22, 56, 42, 8, 60, 56]),
        _f(const Color(0xFF958D80)),
      );
      canvas.drawPath(
        _poly([42, 8, 60, 56, 46, 56]),
        _f(const Color(0xFF6F685D)),
      );
      canvas.drawPath(
        _poly([35, 24, 42, 8, 48, 24, 43, 20, 39, 26]),
        _f(_white),
      );
      canvas.drawPath(_poly([19, 26, 24, 16, 29, 26, 24, 23]), _f(_white));
    case Terrain.bridge:
      // Planks run across the river: vertical when water is left/right.
      final vertical =
          _isWet(s, Pos(p.x - 1, p.y)) || _isWet(s, Pos(p.x + 1, p.y));
      if (!vertical) {
        canvas.translate(tile, 0);
        canvas.rotate(pi / 2);
      }
      canvas.drawRect(const Rect.fromLTRB(12, 0, 52, tile), _f(_wood));
      for (var y = 8.0; y < tile; y += 12) {
        canvas.drawLine(
          Offset(14, y),
          Offset(50, y),
          _s(const Color(0xFF6E4526), 2),
        );
      }
      canvas.drawLine(
        const Offset(12, 0),
        const Offset(12, tile),
        _s(const Color(0xFF5A381E), 4),
      );
      canvas.drawLine(
        const Offset(52, 0),
        const Offset(52, tile),
        _s(const Color(0xFF5A381E), 4),
      );
    case Terrain.city || Terrain.barracks || Terrain.hq:
      _building(canvas, t, s.owners[p]);
  }
  canvas.restore();

  if (t.isBuilding) {
    // A coloured frame keeps ownership readable with a unit on the tile.
    final owner = s.owners[p];
    canvas.drawRect(
      r.deflate(2),
      _s(owner == null ? const Color(0x99FFFFFF) : playerColors[owner], 3),
    );
    final remaining = s.capture[p];
    if (remaining != null) {
      final bar = Rect.fromLTWH(r.left + 6, r.bottom - 10, tile - 12, 6);
      canvas.drawRect(bar, _f(ink));
      canvas.drawRect(
        Rect.fromLTWH(
          bar.left,
          bar.top,
          bar.width * (1 - remaining / GameState.capturePoints),
          bar.height,
        ),
        _f(const Color(0xFFFFD54F)),
      );
    }
  }
}

void _pine(Canvas canvas, double x, double base, double scale) {
  canvas.drawRect(
    Rect.fromLTWH(x - 2 * scale, base - 6 * scale, 4 * scale, 8 * scale),
    _f(_wood),
  );
  for (var i = 0; i < 3; i++) {
    final w = (13 - i * 3) * scale;
    final y = base - (6 + i * 9) * scale;
    canvas.drawPath(
      _poly([x - w, y, x, y - 15 * scale, x + w, y]),
      _f(i.isEven ? const Color(0xFF2F6B3A) : const Color(0xFF3A7C46)),
    );
  }
}

void _building(Canvas canvas, Terrain t, int? owner) {
  final color = owner == null ? _neutral : playerColors[owner];
  final outline = _s(ink, 2);
  switch (t) {
    case Terrain.city:
      // Cottage: plaster walls, roof in the owner's colour.
      final walls = const Rect.fromLTRB(16, 32, 48, 54);
      canvas.drawRect(walls, _f(_wall));
      canvas.drawRect(walls, outline);
      final roof = _poly([10, 34, 32, 12, 54, 34]);
      canvas.drawPath(roof, _f(color));
      canvas.drawPath(roof, outline);
      canvas.drawRect(const Rect.fromLTRB(28, 42, 36, 54), _f(_wood));
      canvas.drawRect(const Rect.fromLTRB(40, 16, 45, 26), _f(_stone));
    case Terrain.barracks:
      // Striped campaign tent with a pennant.
      final tent = _poly([8, 54, 32, 18, 56, 54]);
      canvas.drawPath(tent, _f(color));
      canvas.drawPath(_poly([20, 54, 32, 18, 28, 54]), _f(_wall));
      canvas.drawPath(_poly([44, 54, 32, 18, 36, 54]), _f(_wall));
      canvas.drawPath(tent, outline);
      canvas.drawPath(_poly([28, 54, 32, 36, 36, 54]), _f(ink));
      canvas.drawLine(const Offset(32, 18), const Offset(32, 6), outline);
      canvas.drawPath(_poly([32, 6, 44, 10, 32, 14]), _f(color));
    default:
      // Castle keep: stone towers, gate, and a banner.
      final keep = _poly([
        10, 56, 10, 22, 16, 22, 16, 28, 22, 28, 22, 22, 28, 22, 28, 28, //
        36, 28, 36, 22, 42, 22, 42, 28, 48, 28, 48, 22, 54, 22, 54, 56,
      ]);
      canvas.drawPath(keep, _f(_stone));
      canvas.drawPath(keep, outline);
      canvas.drawPath(
        Path()
          ..moveTo(26, 56)
          ..lineTo(26, 46)
          ..quadraticBezierTo(32, 36, 38, 46)
          ..lineTo(38, 56)
          ..close(),
        _f(ink),
      );
      canvas.drawLine(const Offset(32, 28), const Offset(32, 6), outline);
      final banner = _poly([32, 6, 50, 10, 32, 16]);
      canvas.drawPath(banner, _f(color));
      canvas.drawPath(banner, outline);
      canvas.drawRect(const Rect.fromLTRB(13, 34, 19, 42), _f(color));
      canvas.drawRect(const Rect.fromLTRB(45, 34, 51, 42), _f(color));
  }
}

final _hpText = TextPainter(textDirection: TextDirection.ltr);

/// Draws a unit as a heraldic shield with its weapon as the charge.
void drawUnit(
  Canvas canvas,
  Offset center,
  Unit unit, {
  required bool spent,
  required bool selected,
}) {
  final base = playerColors[unit.owner];
  final color = spent ? Color.lerp(base, const Color(0xFF55585F), 0.65)! : base;
  canvas.save();
  canvas.translate(center.dx, center.dy);

  final shield = Path()
    ..moveTo(-21, -22)
    ..lineTo(21, -22)
    ..lineTo(21, 2)
    ..quadraticBezierTo(21, 18, 0, 26)
    ..quadraticBezierTo(-21, 18, -21, 2)
    ..close();
  canvas.drawPath(
    shield.shift(const Offset(0, 2)),
    _f(const Color(0x55000000)),
  );
  canvas.drawPath(shield, _f(color));
  canvas.drawPath(
    shield,
    _s(selected ? const Color(0xFFFFE14D) : ink, selected ? 4 : 2.5),
  );

  final charge = spent ? const Color(0xFFC9CCD2) : _white;
  canvas.translate(0, -1);
  switch (unit.type) {
    case UnitType.infantry:
      // Sword.
      canvas.drawLine(
        const Offset(-4, 5),
        const Offset(10, -13),
        _s(charge, 4.5),
      );
      canvas.drawLine(const Offset(-9, 1), const Offset(0, 9), _s(charge, 3.5));
      canvas.drawLine(
        const Offset(-5, 6),
        const Offset(-10, 12),
        _s(charge, 4),
      );
    case UnitType.spearman:
      canvas.drawLine(const Offset(-9, 13), const Offset(6, -8), _s(charge, 3));
      canvas.drawPath(_poly([11, -15, 9.5, -5, 2.5, -10.5]), _f(charge));
      canvas.drawPath(_poly([-1, 2, 8, 6, 2, -3]), _f(charge));
    case UnitType.archer:
      canvas.drawPath(
        Path()
          ..moveTo(-3, -14)
          ..quadraticBezierTo(15, 0, -3, 14),
        _s(charge, 3.5),
      );
      canvas.drawLine(
        const Offset(-3, -14),
        const Offset(-3, 14),
        _s(charge, 1.5),
      );
      canvas.drawLine(
        const Offset(-12, 0),
        const Offset(9, 0),
        _s(charge, 2.5),
      );
      canvas.drawPath(_poly([14, 0, 7, -4, 7, 4]), _f(charge));
    case UnitType.knight:
      // Horse head, facing left.
      canvas.drawPath(
        _poly([
          -8, 14, 9, 14, 7, 3, 10, -5, 6, -15, 3, -10, -2, -11, //
          -12, 0, -10, 5, -3, 2, -6, 9,
        ]),
        _f(charge),
      );
      canvas.drawCircle(const Offset(0, -5), 1.8, _f(color));
    case UnitType.catapult:
      canvas.drawLine(const Offset(-11, 9), const Offset(11, 9), _s(charge, 3));
      canvas.drawLine(const Offset(-5, 9), const Offset(0, -2), _s(charge, 3));
      canvas.drawLine(const Offset(5, 9), const Offset(0, -2), _s(charge, 3));
      canvas.drawLine(
        const Offset(-11, 4),
        const Offset(8, -11),
        _s(charge, 3),
      );
      canvas.drawCircle(const Offset(9, -12), 3.5, _f(charge));
      canvas.drawCircle(const Offset(-8, 11), 3.5, _f(charge));
      canvas.drawCircle(const Offset(8, 11), 3.5, _f(charge));
    case UnitType.monk:
      // Staff with a glowing orb.
      canvas.drawLine(const Offset(-6, 14), const Offset(4, -8), _s(charge, 3));
      canvas.drawCircle(const Offset(6, -11), 5, _f(charge));
    case UnitType.griffin:
      // Spread wings.
      for (final side in const [1.0, -1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(0, 5)
            ..quadraticBezierTo(5 * side, -15, 16 * side, -9)
            ..quadraticBezierTo(10 * side, -5, 13 * side, 2)
            ..quadraticBezierTo(7 * side, -1, 9 * side, 8)
            ..quadraticBezierTo(4 * side, 4, 0, 11)
            ..close(),
          _f(charge),
        );
      }
  }
  canvas.restore();

  if (unit.displayHp < 10) {
    final badge = Rect.fromLTWH(center.dx + 8, center.dy + 9, 21, 21);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badge, const Radius.circular(6)),
      _f(ink),
    );
    _hpText
      ..text = TextSpan(
        text: '${unit.displayHp}',
        style: const TextStyle(
          color: _white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      )
      ..layout();
    _hpText.paint(
      canvas,
      badge.center - Offset(_hpText.width / 2, _hpText.height / 2),
    );
  }
}
