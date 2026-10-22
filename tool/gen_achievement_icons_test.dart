// Renders the Play Games achievement icons to store/play-games/.
//
// Run with: flutter test tool/gen_achievement_icons_test.dart
//
// One 512 x 512 PNG per achievement in lib/services/achievements.dart, on
// the same medallion as the leaderboard icons.
import 'dart:math';

import 'package:flutter/material.dart';

import 'icon_art.dart';

const _green = Color(0xFF5E9E4A);
const _stone = Color(0xFF9A9286);
const _stoneShade = Color(0xFF746D62);
const _bronze = Color(0xFFC98A4B);
const _bronzeDark = Color(0xFF7A4E24);
const _helmSteel = Color(0xFFC3CBD3);
const _helmSteelDark = Color(0xFF7D8894);

Path _oval(Offset c, double r) =>
    Path()..addOval(Rect.fromCircle(center: c, radius: r));

/// A teardrop with its round end centred on [c].
Path _drop(Offset c, double r) => Path()
  ..moveTo(c.dx, c.dy - r * 1.6)
  ..quadraticBezierTo(c.dx + r * 1.1, c.dy - r * 0.2, c.dx + r, c.dy)
  ..arcToPoint(Offset(c.dx - r, c.dy), radius: Radius.circular(r))
  ..quadraticBezierTo(c.dx - r * 1.1, c.dy - r * 0.2, c.dx, c.dy - r * 1.6);

void _firstBlood(Canvas canvas) {
  sword(canvas, const Offset(236, 276), pi / 4, 300);
  raised(canvas, _drop(const Offset(340, 350), 34), color: red, width: 11);
  raised(canvas, _drop(const Offset(392, 284), 20), color: red, width: 9);
}

void _castle(Canvas canvas) {
  // Flag on the middle battlement.
  canvas.drawLine(
    const Offset(256, 176),
    const Offset(256, 76),
    outline..strokeWidth = 12,
  );
  raised(canvas, poly([256, 78, 330, 98, 256, 122]), width: 10);
  final tower = poly([
    170, 404, 186, 352, 206, 352, 214, 232, 176, 232, 176, 140, 216, 140, //
    216, 176, 240, 176, 240, 140, 272, 140, 272, 176, 296, 176, 296, 140,
    336, 140, 336, 232, 298, 232, 306, 352, 326, 352, 342, 404,
  ]);
  canvas.drawPath(tower.shift(const Offset(0, 9)), Paint()..color = shadow);
  canvas.drawPath(tower, Paint()..color = parchment);
  canvas.save();
  canvas.clipPath(tower);
  canvas.drawRect(
    const Rect.fromLTWH(290, 120, 80, 300),
    Paint()..color = parchmentShade,
  );
  canvas.restore();
  canvas.drawPath(tower, outline..strokeWidth = 14);
  canvas.drawLine(
    const Offset(190, 232),
    const Offset(322, 232),
    outline..strokeWidth = 10,
  );
  canvas.drawPath(
    Path()
      ..moveTo(226, 404)
      ..lineTo(226, 342)
      ..quadraticBezierTo(256, 296, 286, 342)
      ..lineTo(286, 404)
      ..close(),
    Paint()..color = ink,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(246, 252, 20, 50),
      const Radius.circular(10),
    ),
    Paint()..color = ink,
  );
}

void _totalWar(Canvas canvas) {
  sword(canvas, const Offset(256, 270), pi / 4, 290);
  sword(canvas, const Offset(256, 270), -pi / 4, 290);
  final skull = Path.combine(
    PathOperation.union,
    _oval(const Offset(256, 226), 96),
    Path()..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(204, 270, 104, 82),
        const Radius.circular(22),
      ),
    ),
  );
  raised(canvas, skull, color: parchment);
  for (final x in [220.0, 292.0]) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, 236), width: 52, height: 60),
      Paint()..color = ink,
    );
  }
  canvas.drawPath(poly([256, 270, 242, 296, 270, 296]), Paint()..color = ink);
  for (final x in [232.0, 256.0, 280.0]) {
    canvas.drawLine(Offset(x, 318), Offset(x, 348), outline..strokeWidth = 8);
  }
}

void _landlord(Canvas canvas) {
  void house(double left, Color roof) {
    final body = Path()..addRect(Rect.fromLTWH(left, 284, 104, 110));
    raised(canvas, body, color: parchment, width: 12);
    raised(
      canvas,
      poly([left - 14, 290, left + 52, 214, left + 118, 290]),
      color: roof,
      width: 12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + 36, 330, 32, 64),
        const Radius.circular(14),
      ),
      Paint()..color = ink,
    );
  }

  house(118, red);
  house(290, blue);
  // Keep in the middle, in front.
  canvas.drawLine(
    const Offset(256, 160),
    const Offset(256, 92),
    outline..strokeWidth = 10,
  );
  raised(canvas, poly([256, 94, 310, 110, 256, 126]), width: 9);
  raised(
    canvas,
    poly([
      206, 404, 206, 160, 230, 160, 230, 184, 244, 184, 244, 160, 268, 160, //
      268, 184, 282, 184, 282, 160, 306, 160, 306, 404,
    ]),
    color: parchment,
    width: 13,
  );
  canvas.drawPath(
    Path()
      ..moveTo(236, 404)
      ..lineTo(236, 352)
      ..quadraticBezierTo(256, 322, 276, 352)
      ..lineTo(276, 404)
      ..close(),
    Paint()..color = ink,
  );
}

void _veteran(Canvas canvas) {
  for (final y in [168.0, 250.0, 332.0]) {
    final chevron = poly([
      146, y + 40, 256, y - 34, 366, y + 40, //
      366, y + 86, 256, y + 12, 146, y + 86,
    ]);
    raised(
      canvas,
      chevron,
      shader: goldShader(Rect.fromLTWH(146, y - 34, 220, 120)),
      width: 12,
    );
  }
}

void _medic(Canvas canvas) {
  final heart = Path()
    ..moveTo(256, 398)
    ..cubicTo(80, 290, 132, 116, 256, 196)
    ..cubicTo(380, 116, 432, 290, 256, 398)
    ..close();
  raised(canvas, heart, color: red);
  final cross = Path.combine(
    PathOperation.union,
    Path()..addRect(const Rect.fromLTWH(234, 214, 44, 124)),
    Path()..addRect(const Rect.fromLTWH(194, 254, 124, 44)),
  );
  shape(canvas, cross, Colors.white, 10);
}

void _unleashed(Canvas canvas) {
  // Glow behind the bolt.
  canvas.drawCircle(
    const Offset(256, 256),
    150,
    Paint()
      ..shader =
          RadialGradient(
            colors: [
              goldLight.withValues(alpha: 0.6),
              goldLight.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(center: const Offset(256, 256), radius: 150),
          ),
  );
  raised(
    canvas,
    poly([284, 92, 160, 284, 240, 284, 208, 420, 352, 220, 272, 220, 334, 92]),
    shader: goldShader(const Rect.fromLTWH(160, 92, 192, 328)),
  );
}

void _blitz(Canvas canvas) {
  // Speed lines on the left.
  for (final (y, len) in [(196.0, 70.0), (256.0, 100.0), (316.0, 70.0)]) {
    canvas.drawLine(
      Offset(150 - len, y),
      Offset(140, y),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 14
        ..color = goldLight,
    );
  }
  final glass = poly([
    194, 144, 318, 144, 318, 172, 270, 256, 318, 340, 318, 368, //
    194, 368, 194, 340, 242, 256, 194, 172,
  ]);
  raised(canvas, glass, color: const Color(0xFFDDEFFF), width: 12);
  canvas.save();
  canvas.clipPath(glass);
  canvas.drawPath(poly([210, 200, 302, 200, 256, 252]), Paint()..color = gold);
  canvas.drawPath(poly([196, 370, 316, 370, 256, 308]), Paint()..color = gold);
  canvas.drawLine(
    const Offset(256, 250),
    const Offset(256, 340),
    Paint()
      ..color = gold
      ..strokeWidth = 6,
  );
  canvas.restore();
  canvas.drawPath(glass, outline..strokeWidth = 12);
  for (final y in [116.0, 368.0]) {
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(170, y, 172, 30),
      const Radius.circular(10),
    );
    canvas.drawRRect(bar, Paint()..color = const Color(0xFF8A5A33));
    canvas.drawRRect(bar, outline..strokeWidth = 12);
  }
}

void _mist(Canvas canvas) {
  final eye = Path()
    ..moveTo(116, 246)
    ..quadraticBezierTo(256, 110, 396, 246)
    ..quadraticBezierTo(256, 382, 116, 246)
    ..close();
  raised(canvas, eye, color: parchment);
  canvas.save();
  canvas.clipPath(eye);
  shape(canvas, _oval(const Offset(256, 246), 62), blue, 10);
  canvas.drawCircle(const Offset(256, 246), 28, Paint()..color = ink);
  canvas.drawCircle(const Offset(274, 228), 11, Paint()..color = Colors.white);
  canvas.restore();
  canvas.drawPath(eye, outline..strokeWidth = 14);
  // Fog drifting across the lower half.
  for (final (y, x0) in [(318.0, 130.0), (362.0, 160.0)]) {
    final wave = Path()..moveTo(x0, y);
    for (var x = x0; x < 512 - x0; x += 60) {
      wave.quadraticBezierTo(x + 15, y - 18, x + 30, y);
      wave.quadraticBezierTo(x + 45, y + 18, x + 60, y);
    }
    canvas.drawPath(
      wave,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 18
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  }
}

void _tactician(Canvas canvas) {
  final map = RRect.fromRectAndRadius(
    const Rect.fromLTWH(124, 146, 264, 220),
    const Radius.circular(18),
  );
  raised(canvas, Path()..addRRect(map), color: parchment);
  // Grid of the battlefield.
  canvas.save();
  canvas.clipRRect(map);
  final grid = Paint()
    ..color = parchmentShade
    ..strokeWidth = 4;
  for (var x = 168.0; x < 388; x += 44) {
    canvas.drawLine(Offset(x, 146), Offset(x, 366), grid);
  }
  for (var y = 190.0; y < 366; y += 44) {
    canvas.drawLine(Offset(124, y), Offset(388, y), grid);
  }
  canvas.restore();
  canvas.drawRRect(map, outline..strokeWidth = 14);
  // Our units, the plan and the target.
  for (final p in const [Offset(168, 322), Offset(212, 322)]) {
    shape(canvas, _oval(p, 16), blue, 7);
  }
  final arrow = Path()
    ..moveTo(190, 296)
    ..quadraticBezierTo(210, 196, 316, 212);
  canvas.drawPath(
    arrow,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10
      ..color = ink,
  );
  canvas.drawPath(poly([330, 214, 300, 194, 304, 234]), Paint()..color = ink);
  final cross = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 14
    ..color = red;
  canvas.drawLine(const Offset(330, 168), const Offset(366, 204), cross);
  canvas.drawLine(const Offset(366, 168), const Offset(330, 204), cross);
}

void _cartographer(Canvas canvas) {
  const c = Offset(256, 256);
  void point(
    double angle,
    double length,
    double width,
    Color light,
    Color dark,
  ) {
    final tip = c + Offset(cos(angle) * length, sin(angle) * length);
    final side = Offset(
      cos(angle + pi / 2) * width,
      sin(angle + pi / 2) * width,
    );
    final left = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(c.dx + side.dx, c.dy + side.dy)
      ..close();
    final right = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(c.dx - side.dx, c.dy - side.dy)
      ..close();
    canvas.drawPath(left, Paint()..color = light);
    canvas.drawPath(right, Paint()..color = dark);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(c.dx + side.dx, c.dy + side.dy)
        ..lineTo(c.dx - side.dx, c.dy - side.dy)
        ..close(),
      outline..strokeWidth = 9,
    );
  }

  canvas.drawCircle(c, 120, outline..strokeWidth = 22);
  canvas.drawCircle(
    c,
    120,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = parchment,
  );
  for (var i = 0; i < 4; i++) {
    point(pi / 4 + i * pi / 2, 112, 26, parchment, parchmentShade);
  }
  for (var i = 0; i < 4; i++) {
    // North in red, the rest in gold.
    point(
      -pi / 2 + i * pi / 2,
      182,
      38,
      i == 0 ? const Color(0xFFF07070) : goldLight,
      i == 0 ? red : goldDark,
    );
  }
  shape(canvas, _oval(c, 20), gold, 8);
}

void _halfway(Canvas canvas) {
  final mountain = poly([104, 392, 228, 168, 290, 262, 334, 206, 410, 392]);
  canvas.drawPath(mountain.shift(const Offset(0, 9)), Paint()..color = shadow);
  canvas.drawPath(mountain, Paint()..color = _stone);
  canvas.save();
  canvas.clipPath(mountain);
  canvas.drawPath(
    poly([228, 168, 300, 400, 420, 400, 334, 206, 290, 262]),
    Paint()..color = _stoneShade,
  );
  canvas.drawPath(
    poly([228, 168, 196, 226, 218, 214, 236, 232, 256, 206]),
    Paint()..color = Colors.white,
  );
  canvas.restore();
  canvas.drawPath(mountain, outline..strokeWidth = 14);
  // The banner planted at the summit.
  canvas.drawLine(
    const Offset(228, 170),
    const Offset(228, 86),
    outline..strokeWidth = 11,
  );
  raised(canvas, poly([228, 88, 300, 108, 228, 130]), color: blue, width: 10);
}

void _devoted(Canvas canvas) {
  final flame = Path()
    ..moveTo(256, 96)
    ..cubicTo(300, 176, 372, 214, 362, 306)
    ..cubicTo(354, 380, 302, 414, 256, 414)
    ..cubicTo(210, 414, 158, 380, 150, 306)
    ..cubicTo(144, 246, 188, 218, 198, 166)
    ..cubicTo(220, 206, 234, 216, 240, 238)
    ..cubicTo(252, 196, 250, 148, 256, 96)
    ..close();
  raised(canvas, flame, color: const Color(0xFFF08A24));
  final inner = flame.transform(
    (Matrix4.identity()
          ..translateByDouble(256, 414, 0, 1)
          ..scaleByDouble(0.55, 0.55, 1, 1)
          ..translateByDouble(-256, -414, 0, 1))
        .storage,
  );
  shape(canvas, inner, goldLight, 10);
}

/// A great helm over [stars] stars, for the lifetime-win achievements.
void Function(Canvas) _helm(int stars, Color metal, Color metalDark) =>
    (canvas) {
      final helm = Path()
        ..moveTo(170, 352)
        ..lineTo(170, 196)
        ..quadraticBezierTo(170, 104, 256, 98)
        ..quadraticBezierTo(342, 104, 342, 196)
        ..lineTo(342, 352)
        ..close();
      canvas.drawPath(helm.shift(const Offset(0, 9)), Paint()..color = shadow);
      canvas.drawPath(helm, Paint()..color = metal);
      canvas.save();
      canvas.clipPath(helm);
      canvas.drawRect(
        const Rect.fromLTWH(272, 90, 80, 270),
        Paint()..color = metalDark,
      );
      canvas.restore();
      canvas.drawPath(helm, outline..strokeWidth = 14);
      canvas.drawLine(
        const Offset(256, 100),
        const Offset(256, 212),
        outline..strokeWidth = 9,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(190, 214, 132, 22),
          const Radius.circular(11),
        ),
        Paint()..color = ink,
      );
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 3; col++) {
          canvas.drawCircle(
            Offset(282 + col * 16.0, 270 + row * 18.0),
            4.5,
            Paint()..color = ink,
          );
        }
      }
      final xs = switch (stars) {
        1 => [256.0],
        2 => [222.0, 290.0],
        _ => [190.0, 256.0, 322.0],
      };
      for (final x in xs) {
        goldStar(canvas, Offset(x, 392), 34);
      }
    };

void _champion(Canvas canvas) {
  for (final side in [-1.0, 1.0]) {
    final handle = Path()
      ..moveTo(256 + side * 78, 150)
      ..cubicTo(
        256 + side * 160,
        150,
        256 + side * 150,
        250,
        256 + side * 60,
        266,
      );
    canvas.drawPath(handle, outline..strokeWidth = 32);
    canvas.drawPath(
      handle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 16
        ..color = gold,
    );
  }
  raised(
    canvas,
    Path()
      ..moveTo(170, 126)
      ..lineTo(342, 126)
      ..lineTo(342, 186)
      ..quadraticBezierTo(342, 290, 256, 300)
      ..quadraticBezierTo(170, 290, 170, 186)
      ..close(),
    shader: goldShader(const Rect.fromLTWH(170, 126, 172, 174)),
  );
  raised(
    canvas,
    Path()..addRect(const Rect.fromLTWH(238, 298, 36, 50)),
    color: goldDark,
    width: 12,
  );
  raised(
    canvas,
    Path()..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(186, 344, 140, 30),
        const Radius.circular(10),
      ),
    ),
    width: 12,
  );
  raised(
    canvas,
    Path()..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(164, 372, 184, 34),
        const Radius.circular(10),
      ),
    ),
    color: const Color(0xFF8A5A33),
    width: 12,
  );
  shape(canvas, starPath(const Offset(256, 204), 40, 18), Colors.white, 8);
}

void _flawless(Canvas canvas) {
  const c = Offset(256, 262);
  const radius = 136.0;
  for (final side in [-1.0, 1.0]) {
    // Stem, from the bottom round to the top on this side.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      side < 0 ? pi / 2 : pi / 2,
      side * pi * 0.78,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = const Color(0xFF2F5A24),
    );
    for (var i = 0; i < 7; i++) {
      final t = pi / 2 + side * (0.22 + i * 0.36);
      final p = c + Offset(cos(t) * radius, sin(t) * radius);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(t + side * (pi / 2 - 0.5));
      final leaf = Path()
        ..addOval(Rect.fromCenter(center: Offset.zero, width: 62, height: 26));
      shape(canvas, leaf, _green, 7);
      canvas.restore();
    }
  }
  goldStar(canvas, const Offset(256, 254), 96);
}

void main() => renderIcons({
  'achievement-first_blood': MedallionIcon(redField, _firstBlood),
  'achievement-castle': MedallionIcon(blueField, _castle),
  'achievement-total_war': MedallionIcon(redField, _totalWar),
  'achievement-landlord': MedallionIcon(greenField, _landlord),
  'achievement-veteran': MedallionIcon(purpleField, _veteran),
  'achievement-medic': MedallionIcon(tealField, _medic),
  'achievement-unleashed': MedallionIcon(purpleField, _unleashed),
  'achievement-blitz': MedallionIcon(redField, _blitz),
  'achievement-mist': MedallionIcon(steelField, _mist),
  'achievement-tactician': MedallionIcon(brownField, _tactician),
  'achievement-cartographer': MedallionIcon(tealField, _cartographer),
  'achievement-halfway': MedallionIcon(greenField, _halfway),
  'achievement-devoted': MedallionIcon(blueField, _devoted),
  'achievement-seasoned': MedallionIcon(
    brownField,
    _helm(1, _bronze, _bronzeDark),
  ),
  'achievement-warmonger': MedallionIcon(
    steelField,
    _helm(2, _helmSteel, _helmSteelDark),
  ),
  'achievement-legend': MedallionIcon(redField, _helm(3, gold, goldDark)),
  'achievement-champion': MedallionIcon(blueField, _champion),
  'achievement-flawless': MedallionIcon(purpleField, _flawless),
});
