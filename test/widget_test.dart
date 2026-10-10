import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tactics_app/ui/game_screen.dart';
import 'package:tactics_app/ui/home_screen.dart';

void main() {
  final map =
      jsonDecode(File('assets/maps/skirmish_01.json').readAsStringSync())
          as Map<String, dynamic>;

  Future<void> pumpGame(WidgetTester tester) async {
    // A small phone, to catch HUD overflow.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: GameScreen(mapJson: map),
      ),
    );
    await tester.pump();
  }

  testWidgets('end turn hands over to the other player', (tester) async {
    await pumpGame(tester);
    expect(find.text('Day 1 · Blue to move'), findsOneWidget);
    await tester.tap(find.text('End turn'));
    await tester.pump();
    expect(find.text('Day 1 · Red to move'), findsOneWidget);
  });

  testWidgets('menu starts a match and quitting returns to it', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: HomeScreen(mapJson: map),
      ),
    );
    await tester.tap(find.text('2 players, one device'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('End turn'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    await tester.tap(find.text('Quit to menu'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Hard'), findsOneWidget);
    expect(find.text('End turn'), findsNothing);
  });

  testWidgets('back button pauses instead of leaving', (tester) async {
    await pumpGame(tester);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(find.text('Paused'), findsNothing);
  });
}
