import 'package:flutter/material.dart';

class SakiColors {
  static const orange = Color(0xFFFF6B35);
  static const royalPurple = orange;
  static const darkPurple = Color(0xFFE34D1C);
  static const cyan = Color(0xFF06B6D4);
  static const navy = Color(0xFF0F172A);
  static const dark = Colors.white;
  static const card = Colors.white;
  static const muted = Color(0xFF64748B);
  static const ink = Color(0xFF111827);
  static const line = Color(0xFFE2E8F0);
  static const gold = Color(0xFFF59E0B);
  static const light = Colors.white;
}

class SakiTheme {
  static const gradient = LinearGradient(
    colors: [SakiColors.orange, SakiColors.cyan],
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
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: SakiColors.orange,
          brightness: Brightness.light,
        ).copyWith(
          primary: SakiColors.orange,
          secondary: SakiColors.cyan,
          surface: Colors.white,
          onSurface: SakiColors.ink,
          onPrimary: Colors.white,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: SakiColors.ink,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: SakiColors.line),
        ),
        hintStyle: const TextStyle(color: SakiColors.muted),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.white,
        shadowColor: const Color(0x140F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: SakiColors.orange.withValues(alpha: .12),
        height: 72,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(color: SakiColors.ink, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
