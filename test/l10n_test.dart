import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tactics_app/core/models.dart';
import 'package:tactics_app/l10n.dart';
import 'package:tactics_app/ui/home_screen.dart';

void main() {
  tearDown(() => L10n.language.value = AppLanguage.en);

  test('the language choice is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    L10n.language.value = AppLanguage.en;
    await L10n.toggle();
    expect(L10n.vi, isTrue);
    L10n.language.value = AppLanguage.en;
    await L10n.load();
    expect(L10n.vi, isTrue);
    expect(UnitType.knight.label, 'Kỵ sĩ');
    expect(Commander.bold.powerName, 'Cuồng Nộ');
  });

  testWidgets('the home screen is in Vietnamese when chosen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    L10n.language.value = AppLanguage.vi;
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const HomeScreen(),
      ),
    );
    await tester.pump();
    expect(find.text('Chiến dịch'), findsOneWidget);
    expect(find.text('Giao tranh'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });
}
