import 'package:flutter/material.dart';

/// Medieval look: dark timber surfaces, gold trim, parchment text, and the
/// Cinzel display face for titles and buttons.
const woodDark = Color(0xFF21170F);
const wood = Color(0xFF34261A);
const woodLight = Color(0xFF5B4129);
const gold = Color(0xFFE2B55A);
const goldDark = Color(0xFF8A6427);
const parchment = Color(0xFFF2E6CC);
const displayFont = 'Cinzel';

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: gold,
    onPrimary: woodDark,
    secondary: Color(0xFFC96A3B),
    onSecondary: parchment,
    surface: wood,
    onSurface: parchment,
    surfaceContainerHighest: woodLight,
    secondaryContainer: goldDark,
    onSecondaryContainer: parchment,
    outline: goldDark,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
  );
  const display = TextStyle(
    fontFamily: displayFont,
    fontWeight: FontWeight.w700,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  return base.copyWith(
    scaffoldBackgroundColor: woodDark,
    textTheme: base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.merge(
        display.copyWith(color: gold),
      ),
      headlineSmall: base.textTheme.headlineSmall?.merge(display),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: woodDark,
      foregroundColor: gold,
      centerTitle: true,
      titleTextStyle: display.copyWith(fontSize: 22, color: gold),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: woodDark,
        disabledBackgroundColor: const Color(0xFF4A3A2A),
        disabledForegroundColor: const Color(0xFF8C7A62),
        textStyle: display.copyWith(fontSize: 15),
        shape: shape.copyWith(
          side: const BorderSide(color: goldDark, width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: parchment,
        backgroundColor: wood,
        textStyle: display.copyWith(fontSize: 15),
        side: const BorderSide(color: goldDark, width: 2),
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: gold,
        textStyle: display.copyWith(fontSize: 15),
      ),
    ),
    cardTheme: CardThemeData(
      color: wood,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF5A4326)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: wood,
      titleTextStyle: display.copyWith(fontSize: 20, color: gold),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: goldDark, width: 2),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: wood),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: woodLight,
      contentTextStyle: TextStyle(color: parchment),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: gold,
      foregroundColor: woodDark,
    ),
  );
}

/// A timber strip with a line of gold trim, used for the in-battle HUD.
BoxDecoration hudDecoration({required bool trimOnTop}) => BoxDecoration(
  gradient: const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3D2C1D), Color(0xFF2A1E14)],
  ),
  border: Border(
    top: trimOnTop
        ? const BorderSide(color: goldDark, width: 2)
        : BorderSide.none,
    bottom: trimOnTop
        ? BorderSide.none
        : const BorderSide(color: goldDark, width: 2),
  ),
);
