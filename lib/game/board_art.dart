import 'dart:math';

import 'package:flutter/painting.dart';

import '../core/game_state.dart';
import '../core/models.dart';
import 'unit_art.dart';

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

const _sand = Color(0xFFE6D3A0);
const _shadow = Color(0x33000000);

/// Draws one terrain tile. [time] (seconds) animates the water; 0 is still.
void drawTerrain(Canvas canvas, GameState s, Pos p, {double time = 0}) {
  final r = tileRect(p);
  final t = s.terrainAt(p);
  final wet = t == Terrain.water || t == Terrain.bridge;
  // Stable per-tile variation so the field doesn't look stamped.
  final hash = (p.x * 73856093) ^ (p.y * 19349663);

  canvas.save();
  canvas.translate(r.left, r.top);
  if (wet) {
    canvas.drawRect(Offset.zero & r.size, _f(const Color(0xFF3E7CCB)));
    // Deeper water away from the top edge gives the river some body.
    canvas.drawRect(
      const Rect.fromLTWH(0, tile * 0.55, tile, tile * 0.45),
      _f(const Color(0x223250A8)),
    );
    for (var i = 0; i < 2; i++) {
      // Ripples drift sideways and wrap inside the tile.
      final drift = time * (6 + i * 3);
      final x = (8.0 + (hash >> (i * 3) & 7) * 3 + i * 22 + drift) % 44;
      final y =
          18.0 + i * 26 + (time == 0 ? 0 : sin(time * 1.5 + i + p.x) * 1.5);
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..quadraticBezierTo(x + 5, y - 5, x + 10, y)
          ..quadraticBezierTo(x + 15, y + 5, x + 20, y),
        _s(const Color(0x66FFFFFF), 2),
      );
    }
    // Sandy banks with a line of foam wherever the water meets land.
    bool land(int dx, int dy) {
      final n = Pos(p.x + dx, p.y + dy);
      return s.inBounds(n) && !_isWet(s, n);
    }

    const bank = 7.0;
    final foam = _s(const Color(0xAAFFFFFF), 2);
    if (land(0, -1)) {
      canvas.drawRect(const Rect.fromLTWH(0, 0, tile, bank), _f(_sand));
      canvas.drawLine(
        const Offset(0, bank + 1),
        const Offset(tile, bank + 1),
        foam,
      );
    }
    if (land(0, 1)) {
      canvas.drawRect(
        const Rect.fromLTWH(0, tile - bank, tile, bank),
        _f(_sand),
      );
      canvas.drawLine(
        const Offset(0, tile - bank - 1),
        const Offset(tile, tile - bank - 1),
        foam,
      );
    }
    if (land(-1, 0)) {
      canvas.drawRect(const Rect.fromLTWH(0, 0, bank, tile), _f(_sand));
      canvas.drawLine(
        const Offset(bank + 1, 0),
        const Offset(bank + 1, tile),
        foam,
      );
    }
    if (land(1, 0)) {
      canvas.drawRect(
        const Rect.fromLTWH(tile - bank, 0, bank, tile),
        _f(_sand),
      );
      canvas.drawLine(
        const Offset(tile - bank - 1, 0),
        const Offset(tile - bank - 1, tile),
        foam,
      );
    }
  } else {
    canvas.drawRect(
      Offset.zero & r.size,
      _f(
        (p.x + p.y).isEven ? const Color(0xFF7DB85F) : const Color(0xFF76B059),
      ),
    );
    // A soft darker patch breaks up the flat colour.
    canvas.drawOval(
      Rect.fromLTWH(6.0 + (hash >> 5 & 15), 8.0 + (hash >> 9 & 15), 30, 18),
      _f(const Color(0x14204A16)),
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
      // About one meadow tile in three carries a few wildflowers.
      if (hash % 3 == 0) {
        const petals = [
          Color(0xFFFFF3C4),
          Color(0xFFFFC1D6),
          Color(0xFFFFFFFF),
        ];
        for (var i = 0; i < 3; i++) {
          final x = 10.0 + (hash >> (i * 5 + 1) & 31) * 1.4;
          final y = 14.0 + (hash >> (i * 5 + 3) & 31) * 1.3;
          canvas.drawCircle(Offset(x, y), 2.2, _f(petals[(hash >> i) % 3]));
          canvas.drawCircle(Offset(x, y), 0.9, _f(const Color(0xFFE0A21B)));
        }
      }
    }
    // Faint grid so distances are easy to count.
    canvas.drawRect(Offset.zero & r.size, _s(const Color(0x14000000), 1));
  }

  // Ground shadows anchor whatever stands on the tile.
  switch (t) {
    case Terrain.forest:
      canvas.drawOval(const Rect.fromLTWH(6, 46, 52, 14), _f(_shadow));
    case Terrain.mountain:
      canvas.drawOval(const Rect.fromLTWH(2, 50, 60, 10), _f(_shadow));
    case Terrain.city || Terrain.barracks || Terrain.hq:
      canvas.drawOval(
        const Rect.fromLTWH(5, 44, 54, 17),
        _f(const Color(0x66B79B6B)),
      );
    default:
      break;
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

/// Draws a unit figure with its HP badge. [time] animates the idle pose and
/// [flash] (0..1) whitens the figure when it has just been hit.
void drawUnit(
  Canvas canvas,
  Offset center,
  Unit unit, {
  required bool spent,
  required bool selected,
  double time = 0,
  double flash = 0,
  bool showHp = true,
}) {
  drawUnitFigure(
    canvas,
    center,
    unit,
    playerColors[unit.owner],
    spent: spent,
    selected: selected,
    time: time,
    flash: flash,
  );
  if (showHp && unit.displayHp < 10) {
    final badge = Rect.fromLTWH(center.dx + 9, center.dy + 10, 21, 21);
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
