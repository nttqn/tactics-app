// Renders the launcher icon to assets/icon/icon.png.
//
// Run with: flutter test tool/gen_icon_test.dart
// then:     dart run flutter_launcher_icons
//
// It lives in a test because the Flutter test harness can rasterise a
// widget without a device, and this machine has no image tooling.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _ink = Color(0xFF1B1F2A);
const _gold = Color(0xFFE9BE5C);
const _goldDark = Color(0xFF9A6E22);
const _stone = Color(0xFFF4EBD6);
const _stoneShade = Color(0xFFD3C4A3);
const _steel = Color(0xFFDDE3EA);

/// Full-bleed artwork on a 1024 grid: the two sides' colours split by a gold
/// band, crossed swords, and a castle tower in front.
class IconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 1024);
    const box = Rect.fromLTWH(0, 0, 1024, 1024);
    final fill = Paint();
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = _ink;

    // Blue field, red field, gold band between them.
    canvas.drawRect(
      box,
      fill
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4C8DF2), Color(0xFF1D4FB0)],
          stops: [0, 0.6],
        ).createShader(box),
    );
    canvas.drawPath(
      Path()
        ..moveTo(1024, 0)
        ..lineTo(1024, 1024)
        ..lineTo(0, 1024)
        ..close(),
      fill
        ..shader = const LinearGradient(
          begin: Alignment.center,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE85050), Color(0xFFA51F1F)],
        ).createShader(box),
    );
    fill.shader = null;
    canvas.drawLine(
      const Offset(-40, 1064),
      const Offset(1064, -40),
      outline..strokeWidth = 84,
    );
    canvas.drawLine(
      const Offset(-40, 1064),
      const Offset(1064, -40),
      Paint()
        ..color = _gold
        ..strokeWidth = 56,
    );

    // The emblem fills most of the square, like a full-bleed icon should.
    canvas.save();
    canvas.translate(512, 566);
    canvas.scale(1.22);
    canvas.translate(-512, -566);

    // Crossed swords behind the tower.
    void sword(double angle) {
      canvas.save();
      canvas.translate(512, 560);
      canvas.rotate(angle);
      final blade = Path()
        ..moveTo(-30, 120)
        ..lineTo(-30, -400)
        ..lineTo(0, -470)
        ..lineTo(30, -400)
        ..lineTo(30, 120)
        ..close();
      canvas.drawPath(blade, fill..color = _steel);
      canvas.drawPath(blade, outline..strokeWidth = 18);
      canvas.drawLine(
        const Offset(0, 90),
        const Offset(0, -380),
        Paint()
          ..color = const Color(0xFFAAB4BF)
          ..strokeWidth = 8,
      );
      final guard = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-110, 120, 220, 44),
        const Radius.circular(16),
      );
      canvas.drawRRect(guard, fill..color = _gold);
      canvas.drawRRect(guard, outline..strokeWidth = 18);
      final grip = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-24, 164, 48, 130),
        const Radius.circular(12),
      );
      canvas.drawRRect(grip, fill..color = const Color(0xFF6B4226));
      canvas.drawRRect(grip, outline..strokeWidth = 18);
      canvas.drawCircle(const Offset(0, 312), 34, fill..color = _gold);
      canvas.drawCircle(const Offset(0, 312), 34, outline..strokeWidth = 18);
      canvas.restore();
    }

    sword(pi / 4.6);
    sword(-pi / 4.6);

    // Castle tower: battlements, body, flared base.
    final tower = Path()
      ..moveTo(300, 860)
      ..lineTo(330, 770)
      ..lineTo(388, 770)
      ..lineTo(404, 470)
      ..lineTo(330, 470)
      ..lineTo(330, 290)
      ..lineTo(410, 290)
      ..lineTo(410, 360)
      ..lineTo(470, 360)
      ..lineTo(470, 290)
      ..lineTo(554, 290)
      ..lineTo(554, 360)
      ..lineTo(614, 360)
      ..lineTo(614, 290)
      ..lineTo(694, 290)
      ..lineTo(694, 470)
      ..lineTo(620, 470)
      ..lineTo(636, 770)
      ..lineTo(694, 770)
      ..lineTo(724, 860)
      ..close();
    canvas.drawPath(
      tower.shift(const Offset(0, 16)),
      fill..color = const Color(0x55000000),
    );
    canvas.drawPath(tower, fill..color = _stone);
    // Shaded right-hand side gives the stone some volume.
    canvas.save();
    canvas.clipPath(tower);
    canvas.drawRect(
      const Rect.fromLTWH(560, 250, 200, 640),
      fill..color = _stoneShade,
    );
    canvas.restore();
    canvas.drawPath(tower, outline..strokeWidth = 26);
    canvas.drawLine(
      const Offset(350, 470),
      const Offset(674, 470),
      outline..strokeWidth = 18,
    );
    canvas.drawLine(
      const Offset(352, 770),
      const Offset(672, 770),
      outline..strokeWidth = 18,
    );

    // Arched gate and an arrow slit.
    canvas.drawPath(
      Path()
        ..moveTo(456, 770)
        ..lineTo(456, 670)
        ..quadraticBezierTo(512, 590, 568, 670)
        ..lineTo(568, 770)
        ..close(),
      fill..color = _ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(494, 500, 36, 90),
        const Radius.circular(18),
      ),
      fill..color = _ink,
    );

    // Gold trim line under the battlements.
    canvas.drawLine(
      const Offset(350, 420),
      const Offset(674, 420),
      Paint()
        ..color = _goldDark
        ..strokeWidth = 14,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(IconPainter oldDelegate) => false;
}

void main() {
  testWidgets('render the launcher icon', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: CustomPaint(size: const Size(1024, 1024), painter: IconPainter()),
      ),
    );
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('assets/icon/icon.png')..createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    expect(File('assets/icon/icon.png').existsSync(), isTrue);
  });
}
