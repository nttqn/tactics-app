// Renders the Google Play feature graphic to store/feature-graphic.png
// (1024 x 500).
//
// Run with: flutter test tool/gen_feature_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tactics_app/core/game_state.dart';
import 'package:tactics_app/core/models.dart';
import 'package:tactics_app/game/board_art.dart';
import 'package:tactics_app/ui/theme.dart';
import 'package:tactics_app/ui/title_backdrop.dart';

/// Two small armies facing each other across the foreground.
class _ArmiesPainter extends CustomPainter {
  static const _blue = [UnitType.archer, UnitType.infantry, UnitType.knight];
  static const _red = [UnitType.griffin, UnitType.spearman, UnitType.catapult];

  @override
  void paint(Canvas canvas, Size size) {
    void army(List<UnitType> types, int owner, double startX, double step) {
      for (var i = 0; i < types.length; i++) {
        canvas.save();
        canvas.translate(startX + i * step, size.height - 92);
        canvas.scale(2.1);
        drawUnit(
          canvas,
          Offset.zero,
          Unit(id: i, type: types[i], owner: owner, pos: const Pos(0, 0)),
          spent: false,
          selected: false,
        );
        canvas.restore();
      }
    }

    army(_blue, 0, 90, 118);
    army(_red, 1, size.width - 90 - 2 * 118, 118);
  }

  @override
  bool shouldRepaint(_ArmiesPainter oldDelegate) => false;
}

void main() {
  testWidgets('render the feature graphic', (tester) async {
    // Tests fall back to a placeholder font unless the real one is loaded.
    final font = FontLoader(titleFont)
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Cinzel.ttf').readAsBytesSync(),
          ),
        ),
      );
    await font.load();

    tester.view.physicalSize = const Size(1024, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    const shadow = [Shadow(color: Colors.black, blurRadius: 14)];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 1024,
            height: 500,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ClipRect(child: TitleBackdrop()),
                CustomPaint(painter: _ArmiesPainter()),
                const Align(
                  alignment: Alignment(0, -0.72),
                  child: Text(
                    'MARCHLORDS',
                    style: TextStyle(
                      fontFamily: titleFont,
                      fontSize: 104,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: gold,
                      shadows: shadow,
                    ),
                  ),
                ),
                const Align(
                  alignment: Alignment(0, -0.22),
                  child: Text(
                    'MEDIEVAL TURN-BASED TACTICS',
                    style: TextStyle(
                      fontFamily: titleFont,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: parchment,
                      shadows: shadow,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('store/feature-graphic.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    expect(File('store/feature-graphic.png').existsSync(), isTrue);
  });
}
