import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tactics_app/campaign/campaign.dart';
import 'package:tactics_app/campaign/progress.dart';
import 'package:tactics_app/editor/map_store.dart';
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

  testWidgets('a quit match can be continued from the menu', (tester) async {
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
    await tester.pump();
    expect(find.text('Continue'), findsNothing);
    await tester.tap(find.text('2 players, one device'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('To battle!'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('End turn'), findsOneWidget);
    await tester.tap(find.text('End turn'));
    await tester.pump();
    expect(find.text('Day 1 · Red to move'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    await tester.tap(find.text('Quit to menu'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Campaign'), findsOneWidget);
    expect(find.text('End turn'), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Day 1 · Red to move'), findsOneWidget);
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
    expect(find.text('Par 9 days'), findsOneWidget);
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

  Future<void> pumpHome(WidgetTester tester) async {
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
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('the first mission coaches the player', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Campaign'));
    await settle(tester);
    await tester.tap(find.text(campaign.first.name));
    await settle(tester);
    expect(find.textContaining('Welcome, commander'), findsOneWidget);
  });

  testWidgets('how to play lists every unit', (tester) async {
    await pumpHome(tester);
    await tester.ensureVisible(find.text('How to play'));
    await tester.tap(find.text('How to play'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Units'), 200);
    await tester.scrollUntilVisible(find.text('Griffin'), 200);
    await tester.scrollUntilVisible(find.text('Castle'), 200);
  });

  testWidgets('a new map opens in the editor and painting changes it', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.tap(find.text('Map editor'));
    await settle(tester);
    // The stored maps load asynchronously, then the button animates in.
    await settle(tester);
    await tester.tap(find.text('New map'));
    await settle(tester);
    await tester.tap(find.text('6 × 8'));
    await settle(tester);
    expect(find.text('Map 1'), findsOneWidget);
    expect(find.text('Mirror'), findsOneWidget);

    // An empty map cannot be played yet.
    await tester.tap(find.byTooltip('Play test (2 players)'));
    await settle(tester);
    expect(find.text('Not ready to play'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await settle(tester);

    await tester.tap(find.byTooltip('Forest'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('editor-board')));
    await tester.pump();
    await tester.pageBack();
    await settle(tester);
    expect(find.textContaining('Unfinished'), findsOneWidget);
    final saved = (await MapStore.load()).maps.single;
    // Mirror is on by default, so one tap paints two tiles.
    final forests =
        (saved.toJson()['terrain'] as List).join().split('f').length - 1;
    expect(forests, 2);
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
