import 'dart:math';

import 'package:flutter/material.dart';

/// The home screen's painted scene: a castle on a hill at dusk.
class TitleBackdrop extends StatelessWidget {
  const TitleBackdrop({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _BackdropPainter(), size: Size.infinite);
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  static const _night = Color(0xFF14101C);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fill = Paint();

    // Dusk sky.
    canvas.drawRect(
      Offset.zero & size,
      fill
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF171C38),
            Color(0xFF4A2F56),
            Color(0xFFB85C4A),
            Color(0xFFF0A85C),
          ],
          stops: [0, 0.35, 0.6, 0.78],
        ).createShader(Offset.zero & size),
    );
    fill.shader = null;

    // Stars in the upper sky, placed by a fixed seed so they never jump.
    final random = Random(7);
    for (var i = 0; i < 40; i++) {
      canvas.drawCircle(
        Offset(random.nextDouble() * w, random.nextDouble() * h * 0.32),
        random.nextDouble() * 1.2 + 0.4,
        fill
          ..color = Colors.white.withValues(
            alpha: 0.5 + random.nextDouble() * 0.4,
          ),
      );
    }

    // Low sun behind the hills.
    final sun = Offset(w * 0.72, h * 0.66);
    canvas.drawCircle(sun, w * 0.3, fill..color = const Color(0x33FFD9A0));
    canvas.drawCircle(sun, w * 0.12, fill..color = const Color(0xFFFFE2B0));

    // Two ranges of hills, nearer ones darker.
    void ridge(double base, double height, Color color, int seed) {
      final r = Random(seed);
      final path = Path()..moveTo(0, h);
      var x = 0.0;
      path.lineTo(0, base - r.nextDouble() * height);
      while (x < w) {
        final step = w * (0.12 + r.nextDouble() * 0.14);
        final peak = base - r.nextDouble() * height;
        path.quadraticBezierTo(
          x + step / 2,
          peak - height * 0.4,
          x + step,
          peak,
        );
        x += step;
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, fill..color = color);
    }

    ridge(h * 0.72, h * 0.08, const Color(0xFF5A3550), 3);
    ridge(h * 0.8, h * 0.06, const Color(0xFF33223A), 11);

    // The castle's hill and silhouette.
    final hill = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.86)
      ..quadraticBezierTo(w * 0.3, h * 0.66, w * 0.62, h * 0.84)
      ..quadraticBezierTo(w * 0.85, h * 0.92, w, h * 0.9)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(hill, fill..color = _night);

    // The castle is laid out on a unit grid about 65 wide and 50 tall.
    final u = h / 88;
    final ground = h * 0.775;
    canvas.save();
    canvas.translate(w * 0.34 - 32.5 * u, 0);
    void block(double x, double width, double height) => canvas.drawRect(
      Rect.fromLTWH(x * u, ground - height * u, width * u, height * u + 4 * u),
      fill..color = _night,
    );
    void merlons(double x, double width, double height) {
      for (var i = 0.0; i < width; i += 2.4) {
        canvas.drawRect(
          Rect.fromLTWH(
            (x + i) * u,
            ground - (height + 1.6) * u,
            1.3 * u,
            1.7 * u,
          ),
          fill..color = _night,
        );
      }
    }

    void tower(double x, double width, double height, Color banner) {
      block(x, width, height);
      merlons(x, width, height);
      // Pointed roof, pole and banner.
      final top = ground - (height + 1.6) * u;
      final cx = (x + width / 2) * u;
      canvas.drawPath(
        Path()
          ..moveTo((x - 0.6) * u, top)
          ..lineTo(cx, top - width * 1.1 * u)
          ..lineTo((x + width + 0.6) * u, top)
          ..close(),
        fill..color = _night,
      );
      final tip = top - width * 1.1 * u;
      canvas.drawRect(
        Rect.fromLTWH(cx - 0.2 * u, tip - 5 * u, 0.4 * u, 5 * u),
        fill,
      );
      canvas.drawPath(
        Path()
          ..moveTo(cx, tip - 5 * u)
          ..lineTo(cx + 5 * u, tip - 3.8 * u)
          ..lineTo(cx, tip - 2.4 * u)
          ..close(),
        fill..color = banner,
      );
      // A lit window.
      canvas.drawRect(
        Rect.fromLTWH(
          cx - 0.6 * u,
          ground - height * 0.62 * u,
          1.2 * u,
          2.2 * u,
        ),
        fill..color = const Color(0xFFFFC56B),
      );
    }

    block(16, 34, 13); // curtain wall
    merlons(16, 34, 13);
    tower(13, 7, 20, const Color(0xFF2F6FDB));
    tower(45, 7, 20, const Color(0xFFD63A3A));
    tower(27, 10, 30, const Color(0xFFE2B55A)); // keep
    // Gate.
    canvas.drawPath(
      Path()
        ..moveTo(29.5 * u, ground + 2 * u)
        ..lineTo(29.5 * u, ground - 5 * u)
        ..quadraticBezierTo(32 * u, ground - 9 * u, 34.5 * u, ground - 5 * u)
        ..lineTo(34.5 * u, ground + 2 * u)
        ..close(),
      fill..color = const Color(0xFFFFB45A),
    );
    canvas.restore();

    // Darken the lower part so the menu stays readable on top.
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.3, w, h * 0.7),
      fill
        ..color = Colors.black
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
        ).createShader(Rect.fromLTWH(0, h * 0.3, w, h * 0.7)),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) => false;
}
