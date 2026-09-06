import 'package:flutter/material.dart';

class SakiColors {
  static const royalPurple = Color(0xFF656BF9);
  static const darkPurple = Color(0xFF4F55C9);
  static const cyan = Color(0xFF8E91FF);
  static const navy = Color(0xFF1B1B23);
  static const dark = Color(0xFF09090B);
  static const card = Color(0xFF18181B);
  static const muted = Color(0xFFA1A1AA);
  static const gold = Color(0xFFF59E0B);
  static const light = Color(0xFFF7F7F7);
}

class SakiTheme {
  static const gradient = LinearGradient(
    colors: [SakiColors.royalPurple, SakiColors.cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: SakiColors.royalPurple,
          brightness: Brightness.dark,
          surface: SakiColors.dark,
        ).copyWith(
          primary: SakiColors.royalPurple,
          secondary: SakiColors.cyan,
          surface: SakiColors.dark,
          surfaceContainer: SakiColors.card,
          onSurface: Colors.white,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: SakiColors.dark,
      fontFamily: 'sans',
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SakiColors.card.withValues(alpha: .9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: SakiColors.cyan, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
      ),
      cardTheme: CardThemeData(
        color: SakiColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SakiColors.card,
        indicatorColor: SakiColors.royalPurple.withValues(alpha: .28),
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: SakiColors.royalPurple,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: SakiColors.light,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    );
  }
}
