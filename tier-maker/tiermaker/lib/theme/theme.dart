import 'package:flutter/material.dart';

/// Цветовая схема приложения
/// Соответствует Kotlin версии из PlaylistMaker
abstract class AppTheme {
  // Основной цвет фона (синий)
  static const Color primaryBackgroundColor = Color.fromRGBO(55, 114, 231, 1.0);
  
  // Цвета для светлой темы
  static const Color lightPrimary = Colors.black;
  static const Color lightOnPrimary = Colors.white;
  static const Color lightSecondary = Colors.grey;
  static const Color lightOnSecondary = Colors.black;
  static const Color lightSurface = Colors.grey;
  static const Color lightOnSurface = Colors.black;
  static const Color lightOnSurfaceVariant = Color.fromRGBO(174, 175, 180, 1.0);
  static const Color lightInverseSurface = Color.fromRGBO(230, 232, 235, 1.0);
  static const Color lightScrim = Color.fromRGBO(174, 175, 180, 1.0);

  // Цвета для темной темы
  static const Color darkPrimary = Colors.white;
  static const Color darkOnPrimary = Colors.black;
  static const Color darkSecondary = Colors.blue;
  static const Color darkOnSecondary = Colors.white;
  static const Color darkSurface = Colors.white;
  static const Color darkOnSurface = Colors.white;
  static const Color darkOnSurfaceVariant = Colors.black;
  static const Color darkInverseSurface = Colors.white;
  static const Color darkScrim = Colors.white;

  /// Светлая тема
  static ThemeData get ligthTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: primaryBackgroundColor,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        onPrimary: lightOnPrimary,
        secondary: lightSecondary,
        onSecondary: lightOnSecondary,
        tertiary: Colors.pink,
        background: primaryBackgroundColor,
        onBackground: Colors.white,
        surface: lightSurface,
        onSurface: lightOnSurface,
        onSurfaceVariant: lightOnSurfaceVariant,
        inverseSurface: lightInverseSurface,
        scrim: lightScrim,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.normal,
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.normal,
          color: Colors.black,
        ),
        bodyLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.normal,
          color: Colors.black,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: Colors.black,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.normal,
          color: Colors.black,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: Colors.black,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.normal,
          color: Colors.black,
        ),
        labelLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  /// Темная тема
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryBackgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        onPrimary: darkOnPrimary,
        secondary: darkSecondary,
        onSecondary: darkOnSecondary,
        tertiary: Colors.pink,
        background: primaryBackgroundColor,
        onBackground: Colors.white,
        surface: darkSurface,
        onSurface: darkOnSurface,
        onSurfaceVariant: darkOnSurfaceVariant,
        inverseSurface: darkInverseSurface,
        scrim: darkScrim,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.normal,
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        labelLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
