// Renders the Play Games leaderboard icons to store/play-games/.
//
// Run with: flutter test tool/gen_leaderboard_icons_test.dart
//
// Play Console wants 512 x 512 PNGs and may show them in a circle, so each
// emblem sits well inside the square on a timber-and-gold medallion.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _ink = Color(0xFF1B1F2A);
const _gold = Color(0xFFE9BE5C);
const _goldLight = Color(0xFFFFE2A0);
const _goldDark = Color(0xFF9A6E22);
const _woodDark = Color(0xFF21170F);
const _wood = Color(0xFF4A3420);
const _parchment = Color(0xFFF2E6CC);
const _parchmentShade = Color(0xFFD9C7A0);
const _blue = Color(0xFF2F6FDB);
const _red = Color(0xFFD63A3A);

final _outline = Paint()
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..color = _ink;

void _shape(Canvas canvas, Path path, Color color, [double width = 14]) {
  canvas.drawPath(path, Paint()..color = color);
  canvas.drawPath(path, _outline..strokeWidth = width);
}

Path _star(Offset c, double outer, double inner) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? outer : inner;
    final a = -pi / 2 + i * pi / 5;
    final p = c + Offset(cos(a) * r, sin(a) * r);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// Shared background: dark timber with a gold ring, on a 512 grid.
void _medallion(Canvas canvas, List<Color> field) {
  const box = Rect.fromLTWH(0, 0, 512, 512);
  canvas.drawRect(
    box,
    Paint()
      ..shader = const RadialGradient(
        colors: [_wood, _woodDark],
        radius: 0.75,
      ).createShader(box),
  );
  const c = Offset(256, 256);
  final disc = Rect.fromCircle(center: c, radius: 222);
  canvas.drawCircle(
    c,
    222,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: field,
      ).createShader(disc),
  );
  canvas.drawCircle(
    c,
    222,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..color = _ink,
  );
  canvas.drawCircle(
    c,
    222,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..shader = const SweepGradient(
        colors: [_goldLight, _gold, _goldDark, _gold, _goldLight],
      ).createShader(disc),
  );
  // Rivets around the ring.
  for (var i = 0; i < 12; i++) {
    final a = i * pi / 6;
    canvas.drawCircle(
      c + Offset(cos(a) * 222, sin(a) * 222),
      5,
      Paint()..color = _goldDark,
    );
  }
}

/// Daily challenge: a calendar page with the rising sun on it.
class DailyIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 512);
    _medallion(canvas, const [Color(0xFF3E7BE0), Color(0xFF173E8C)]);

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
          ..color = _gold,
      );
    }

    // The page.
    final page = RRect.fromRectAndRadius(
      const Rect.fromLTWH(146, 168, 220, 210),
      const Radius.circular(22),
    );
    canvas.drawRRect(
      page.shift(const Offset(0, 10)),
      Paint()..color = const Color(0x66000000),
    );
    canvas.drawRRect(page, Paint()..color = _parchment);
    canvas.save();
    canvas.clipRRect(page);
    canvas.drawRect(
      const Rect.fromLTWH(146, 168, 220, 58),
      Paint()..color = _red,
    );
    canvas.drawRect(
      const Rect.fromLTWH(300, 226, 66, 152),
      Paint()..color = _parchmentShade,
    );
    canvas.restore();
    canvas.drawRRect(page, _outline..strokeWidth = 14);
    canvas.drawLine(
      const Offset(146, 226),
      const Offset(366, 226),
      _outline..strokeWidth = 10,
    );
    // Binding rings.
    for (final x in [196.0, 316.0]) {
      final ring = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, 170), width: 22, height: 56),
        const Radius.circular(11),
      );
      canvas.drawRRect(ring, Paint()..color = _gold);
      canvas.drawRRect(ring, _outline..strokeWidth = 9);
    }

    // The sun rising over a hill, on the page.
    canvas.save();
    canvas.clipRRect(page);
    final sunDisc = Path()
      ..addOval(Rect.fromCircle(center: const Offset(256, 320), radius: 56));
    _shape(canvas, sunDisc, _gold, 10);
    final hill = Path()
      ..moveTo(130, 400)
      ..lineTo(130, 330)
      ..quadraticBezierTo(256, 280, 382, 330)
      ..lineTo(382, 400)
      ..close();
    _shape(canvas, hill, const Color(0xFF5E9E4A), 10);
    canvas.restore();
    canvas.drawRRect(page, _outline..strokeWidth = 14);
  }

  @override
  bool shouldRepaint(DailyIcon oldDelegate) => false;
}

/// Conquest points: a lord's crown over crossed swords.
class ConquestIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 512);
    _medallion(canvas, const [Color(0xFFE85050), Color(0xFF8E1C1C)]);

    void sword(double angle) {
      canvas.save();
      canvas.translate(256, 280);
      canvas.rotate(angle);
      final blade = Path()
        ..moveTo(-14, 70)
        ..lineTo(-14, -176)
        ..lineTo(0, -214)
        ..lineTo(14, -176)
        ..lineTo(14, 70)
        ..close();
      _shape(canvas, blade, const Color(0xFFDDE3EA), 10);
      final guard = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-52, 70, 104, 22),
        const Radius.circular(8),
      );
      canvas.drawRRect(guard, Paint()..color = _gold);
      canvas.drawRRect(guard, _outline..strokeWidth = 10);
      final grip = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-12, 92, 24, 58),
        const Radius.circular(6),
      );
      canvas.drawRRect(grip, Paint()..color = const Color(0xFF6B4226));
      canvas.drawRRect(grip, _outline..strokeWidth = 10);
      canvas.restore();
    }

    sword(pi / 5);
    sword(-pi / 5);

    // The crown.
    final crown = Path()
      ..moveTo(146, 330)
      ..lineTo(128, 182)
      ..lineTo(196, 240)
      ..lineTo(256, 150)
      ..lineTo(316, 240)
      ..lineTo(384, 182)
      ..lineTo(366, 330)
      ..close();
    canvas.drawPath(
      crown.shift(const Offset(0, 10)),
      Paint()..color = const Color(0x66000000),
    );
    canvas.drawPath(
      crown,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_goldLight, _gold, _goldDark],
        ).createShader(const Rect.fromLTWH(128, 150, 256, 180)),
    );
    canvas.drawPath(crown, _outline..strokeWidth = 14);
    final band = RRect.fromRectAndRadius(
      const Rect.fromLTWH(140, 300, 232, 48),
      const Radius.circular(10),
    );
    canvas.drawRRect(band, Paint()..color = _gold);
    canvas.drawRRect(band, _outline..strokeWidth = 14);
    // Jewels.
    for (final (x, color) in [(196.0, _blue), (256.0, _red), (316.0, _blue)]) {
      _shape(
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
      _shape(
        canvas,
        Path()..addOval(Rect.fromCircle(center: p, radius: 16)),
        _goldLight,
        9,
      );
    }
  }

  @override
  bool shouldRepaint(ConquestIcon oldDelegate) => false;
}

/// Campaign stars: three stars over a heater shield.
class StarsIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 512);
    _medallion(canvas, const [Color(0xFF6D5A3E), Color(0xFF2E2216)]);

    // Shield split in the two sides' colours.
    final shield = Path()
      ..moveTo(166, 196)
      ..lineTo(346, 196)
      ..lineTo(346, 300)
      ..quadraticBezierTo(346, 380, 256, 420)
      ..quadraticBezierTo(166, 380, 166, 300)
      ..close();
    canvas.drawPath(
      shield.shift(const Offset(0, 10)),
      Paint()..color = const Color(0x66000000),
    );
    canvas.save();
    canvas.clipPath(shield);
    canvas.drawRect(
      const Rect.fromLTWH(160, 190, 96, 240),
      Paint()..color = _blue,
    );
    canvas.drawRect(
      const Rect.fromLTWH(256, 190, 96, 240),
      Paint()..color = _red,
    );
    canvas.drawLine(
      const Offset(256, 190),
      const Offset(256, 430),
      Paint()
        ..color = _gold
        ..strokeWidth = 18,
    );
    canvas.restore();
    canvas.drawPath(shield, _outline..strokeWidth = 14);

    // Three stars in an arc, the middle one raised and larger.
    void star(Offset c, double r) {
      final path = _star(c, r, r * 0.45);
      canvas.drawPath(
        path.shift(const Offset(0, 8)),
        Paint()..color = const Color(0x66000000),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_goldLight, _gold, _goldDark],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      canvas.drawPath(path, _outline..strokeWidth = 11);
    }

    star(const Offset(160, 190), 56);
    star(const Offset(352, 190), 56);
    star(const Offset(256, 150), 74);
  }

  @override
  bool shouldRepaint(StarsIcon oldDelegate) => false;
}

void main() {
  for (final (name, painter) in [
    ('leaderboard-daily', DailyIcon()),
    ('leaderboard-conquest', ConquestIcon()),
    ('leaderboard-stars', StarsIcon()),
  ]) {
    testWidgets('render $name', (tester) async {
      tester.view.physicalSize = const Size(512, 512);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: CustomPaint(size: const Size(512, 512), painter: painter),
        ),
      );
      final path = 'store/play-games/$name.png';
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      expect(File(path).existsSync(), isTrue);
    });
  }
}
