import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tactics_app/campaign/campaign.dart';
import 'package:tactics_app/campaign/progress.dart';
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
        home: const HomeScreen(),
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
    expect(find.text('Campaign'), findsOneWidget);
    expect(find.text('End turn'), findsNothing);
  });

  testWidgets('campaign lists every mission with only the first unlocked', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const HomeScreen(),
      ),
    );
    await tester.tap(find.text('Campaign'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(campaign.first.name), findsOneWidget);
    expect(find.text('Not yet won'), findsOneWidget);
    expect(find.text('Locked'), findsWidgets);

    await tester.tap(find.text(campaign.first.name));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('End turn'), findsOneWidget);
  });

  test(
    'winning unlocks the next mission and keeps the best day count',
    () async {
      SharedPreferences.setMockInitialValues({});
      final progress = await Progress.load();
      expect(progress.isUnlocked(0), isTrue);
      expect(progress.isUnlocked(1), isFalse);
      await progress.recordWin(0, 12);
      await progress.recordWin(0, 15);
      expect(progress.isUnlocked(1), isTrue);
      expect(progress.isUnlocked(2), isFalse);
      expect(progress.bestDays(0), 12);
      await progress.recordWin(0, 9);
      expect((await Progress.load()).bestDays(0), 9);
      expect(progress.completed, 1);
    },
  );

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
