import 'package:flutter/material.dart';

class AppTheme {
  static const Color _primary = Color(0xff163a70);
  static const Color _sosRed = Color(0xffdc2626);

  // Backwards-compatible alias: `AppTheme.lightTheme`
  static ThemeData get theme {
    final seed = _primary;
    final colorScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light, error: _sosRed);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xfff6f7fb),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _sosRed,
        foregroundColor: Colors.white,
      ),
      chipTheme: ChipThemeData.fromDefaults(
        secondaryColor: colorScheme.primary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        brightness: Brightness.light,
      ),
    );
  }

  // Alias for callers that expect `lightTheme` (keeps compatibility with examples)
  static ThemeData get lightTheme => theme;
}
