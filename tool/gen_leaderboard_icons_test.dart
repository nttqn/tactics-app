// Renders the Play Games leaderboard icons to store/play-games/.
//
// Run with: flutter test tool/gen_leaderboard_icons_test.dart
//
// Play Console wants 512 x 512 PNGs and may show them in a circle, so each
// emblem sits well inside the square on a timber-and-gold medallion.
import 'dart:math';

import 'package:flutter/material.dart';

import 'icon_art.dart';

/// Daily challenge: a calendar page with the sun rising on it.
void _daily(Canvas canvas) {
  // Sun rays behind the page.
  const sun = Offset(256, 150);
  for (var i = 0; i < 12; i++) {
    final a = i * pi / 6;
    canvas.drawLine(
      sun + Offset(cos(a) * 70, sin(a) * 70),
      sun + Offset(cos(a) * 112, sin(a) * 112),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 16
        ..color = gold,
    );
  }

  final page = RRect.fromRectAndRadius(
    const Rect.fromLTWH(146, 168, 220, 210),
    const Radius.circular(22),
  );
  canvas.drawRRect(page.shift(const Offset(0, 10)), Paint()..color = shadow);
  canvas.drawRRect(page, Paint()..color = parchment);
  canvas.save();
  canvas.clipRRect(page);
  canvas.drawRect(const Rect.fromLTWH(146, 168, 220, 58), Paint()..color = red);
  canvas.drawRect(
    const Rect.fromLTWH(300, 226, 66, 152),
    Paint()..color = parchmentShade,
  );
  // The sun rising over a hill, on the page.
  shape(
    canvas,
    Path()
      ..addOval(Rect.fromCircle(center: const Offset(256, 320), radius: 56)),
    gold,
    10,
  );
  shape(
    canvas,
    Path()
      ..moveTo(130, 400)
      ..lineTo(130, 330)
      ..quadraticBezierTo(256, 280, 382, 330)
      ..lineTo(382, 400)
      ..close(),
    const Color(0xFF5E9E4A),
    10,
  );
  canvas.restore();
  canvas.drawRRect(page, outline..strokeWidth = 14);
  canvas.drawLine(
    const Offset(146, 226),
    const Offset(366, 226),
    outline..strokeWidth = 10,
  );
  // Binding rings.
  for (final x in [196.0, 316.0]) {
    final ring = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, 170), width: 22, height: 56),
      const Radius.circular(11),
    );
    canvas.drawRRect(ring, Paint()..color = gold);
    canvas.drawRRect(ring, outline..strokeWidth = 9);
  }
}

/// Conquest points: a lord's crown over crossed swords.
void _conquest(Canvas canvas) {
  sword(canvas, const Offset(256, 280), pi / 5, 284);
  sword(canvas, const Offset(256, 280), -pi / 5, 284);

  final crown = poly([
    146,
    330,
    128,
    182,
    196,
    240,
    256,
    150,
    316,
    240,
    384,
    182,
    366,
    330,
  ]);
  raised(
    canvas,
    crown,
    shader: goldShader(const Rect.fromLTWH(128, 150, 256, 180)),
  );
  final band = RRect.fromRectAndRadius(
    const Rect.fromLTWH(140, 300, 232, 48),
    const Radius.circular(10),
  );
  canvas.drawRRect(band, Paint()..color = gold);
  canvas.drawRRect(band, outline..strokeWidth = 14);
  for (final (x, color) in [(196.0, blue), (256.0, red), (316.0, blue)]) {
    shape(
      canvas,
      Path()..addOval(Rect.fromCircle(center: Offset(x, 324), radius: 12)),
      color,
      7,
    );
  }
  for (final p in const [
    Offset(128, 182),
    Offset(256, 150),
    Offset(384, 182),
  ]) {
    shape(
      canvas,
      Path()..addOval(Rect.fromCircle(center: p, radius: 16)),
      goldLight,
      9,
    );
  }
}

/// Campaign stars: three stars over a shield in the two sides' colours.
void _stars(Canvas canvas) {
  final shield = Path()
    ..moveTo(166, 196)
    ..lineTo(346, 196)
    ..lineTo(346, 300)
    ..quadraticBezierTo(346, 380, 256, 420)
    ..quadraticBezierTo(166, 380, 166, 300)
    ..close();
  canvas.drawPath(shield.shift(const Offset(0, 10)), Paint()..color = shadow);
  canvas.save();
  canvas.clipPath(shield);
  canvas.drawRect(
    const Rect.fromLTWH(160, 190, 96, 240),
    Paint()..color = blue,
  );
  canvas.drawRect(const Rect.fromLTWH(256, 190, 96, 240), Paint()..color = red);
  canvas.drawLine(
    const Offset(256, 190),
    const Offset(256, 430),
    Paint()
      ..color = gold
      ..strokeWidth = 18,
  );
  canvas.restore();
  canvas.drawPath(shield, outline..strokeWidth = 14);

  goldStar(canvas, const Offset(160, 190), 56);
  goldStar(canvas, const Offset(352, 190), 56);
  goldStar(canvas, const Offset(256, 150), 74);
}

void main() => renderIcons({
  'leaderboard-daily': MedallionIcon(blueField, _daily),
  'leaderboard-conquest': MedallionIcon(redField, _conquest),
  'leaderboard-stars': MedallionIcon(brownField, _stars),
});
