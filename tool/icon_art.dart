// Shared drawing for the Play Games icons (leaderboards and achievements):
// a timber-and-gold medallion on a 512 grid, plus the emblem helpers.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const ink = Color(0xFF1B1F2A);
const gold = Color(0xFFE9BE5C);
const goldLight = Color(0xFFFFE2A0);
const goldDark = Color(0xFF9A6E22);
const woodDark = Color(0xFF21170F);
const wood = Color(0xFF4A3420);
const parchment = Color(0xFFF2E6CC);
const parchmentShade = Color(0xFFD9C7A0);
const blue = Color(0xFF2F6FDB);
const red = Color(0xFFD63A3A);
const steel = Color(0xFFDDE3EA);
const shadow = Color(0x66000000);

// Medallion backgrounds, light to dark.
const blueField = [Color(0xFF3E7BE0), Color(0xFF173E8C)];
const redField = [Color(0xFFE85050), Color(0xFF8E1C1C)];
const brownField = [Color(0xFF6D5A3E), Color(0xFF2E2216)];
const greenField = [Color(0xFF4FA35A), Color(0xFF1F5A2A)];
const purpleField = [Color(0xFF8A5BD0), Color(0xFF3E2373)];
const tealField = [Color(0xFF3AA6A6), Color(0xFF145858)];
const steelField = [Color(0xFF8792A0), Color(0xFF363D47)];

final outline = Paint()
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..color = ink;

/// Fills [path] and outlines it in ink.
void shape(Canvas canvas, Path path, Color color, [double width = 14]) {
  canvas.drawPath(path, Paint()..color = color);
  canvas.drawPath(path, outline..strokeWidth = width);
}

/// Like [shape], with a drop shadow and an optional gradient fill.
void raised(
  Canvas canvas,
  Path path, {
  Color color = gold,
  Shader? shader,
  double width = 14,
}) {
  canvas.drawPath(path.shift(const Offset(0, 9)), Paint()..color = shadow);
  canvas.drawPath(
    path,
    Paint()
      ..color = color
      ..shader = shader,
  );
  canvas.drawPath(path, outline..strokeWidth = width);
}

/// Polished gold, light at the top.
Shader goldShader(Rect rect) => const LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [goldLight, gold, goldDark],
).createShader(rect);

Path poly(List<double> xy) {
  final path = Path()..moveTo(xy[0], xy[1]);
  for (var i = 2; i < xy.length; i += 2) {
    path.lineTo(xy[i], xy[i + 1]);
  }
  return path..close();
}

Path starPath(Offset c, double outer, double inner) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? outer : inner;
    final a = -pi / 2 + i * pi / 5;
    final p = c + Offset(cos(a) * r, sin(a) * r);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// A gold star with a shadow.
void goldStar(Canvas canvas, Offset c, double r) => raised(
  canvas,
  starPath(c, r, r * 0.45),
  shader: goldShader(Rect.fromCircle(center: c, radius: r)),
  width: r > 50 ? 12 : 9,
);

/// A sword pointing up from [center], turned by [angle], [length] long
/// from guard to tip.
void sword(Canvas canvas, Offset center, double angle, [double length = 250]) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(angle);
  final tip = -length + 70;
  shape(
    canvas,
    poly([-14, 70, -14, tip + 36, 0, tip, 14, tip + 36, 14, 70]),
    steel,
    10,
  );
  final guard = RRect.fromRectAndRadius(
    const Rect.fromLTWH(-52, 70, 104, 22),
    const Radius.circular(8),
  );
  canvas.drawRRect(guard, Paint()..color = gold);
  canvas.drawRRect(guard, outline..strokeWidth = 10);
  final grip = RRect.fromRectAndRadius(
    const Rect.fromLTWH(-12, 92, 24, 58),
    const Radius.circular(6),
  );
  canvas.drawRRect(grip, Paint()..color = const Color(0xFF6B4226));
  canvas.drawRRect(grip, outline..strokeWidth = 10);
  canvas.drawCircle(const Offset(0, 160), 14, Paint()..color = gold);
  canvas.drawCircle(const Offset(0, 160), 14, outline..strokeWidth = 9);
  canvas.restore();
}

/// Background: dark timber with a riveted gold ring around [field].
void medallion(Canvas canvas, List<Color> field) {
  const box = Rect.fromLTWH(0, 0, 512, 512);
  canvas.drawRect(
    box,
    Paint()
      ..shader = const RadialGradient(
        colors: [wood, woodDark],
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
      ..color = ink,
  );
  canvas.drawCircle(
    c,
    222,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..shader = const SweepGradient(
        colors: [goldLight, gold, goldDark, gold, goldLight],
      ).createShader(disc),
  );
  for (var i = 0; i < 12; i++) {
    final a = i * pi / 6;
    canvas.drawCircle(
      c + Offset(cos(a) * 222, sin(a) * 222),
      5,
      Paint()..color = goldDark,
    );
  }
}

/// An emblem drawn on a 512 medallion with the given field colours.
class MedallionIcon extends CustomPainter {
  MedallionIcon(this.field, this.emblem);

  final List<Color> field;
  final void Function(Canvas canvas) emblem;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 512);
    medallion(canvas, field);
    emblem(canvas);
  }

  @override
  bool shouldRepaint(MedallionIcon oldDelegate) => false;
}

/// One test per icon, each writing `store/play-games/<name>.png` at 512 x 512.
void renderIcons(Map<String, CustomPainter> icons) {
  for (final MapEntry(key: name, value: painter) in icons.entries) {
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
