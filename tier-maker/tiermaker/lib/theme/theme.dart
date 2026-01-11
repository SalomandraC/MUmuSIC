import 'package:flutter/material.dart';

/// Цветовая схема приложения
abstract class AppTheme {
  /// Основные цвета
  static const Color whiteColor = Colors.white;
  static const Color blackColor = Colors.black;
  static const Color greyColor = Colors.grey;
  static const Color redColor = Colors.red;
  static const Color orangeColor = Colors.orange;
  static const Color yellowColor = Colors.yellow;
  static const Color greenColor = Colors.green;
  static const Color blueColor = Colors.blue;
  static const Color indigoColor = Colors.indigo;
  static const Color purpleColor = Colors.purple;
  static const Color pinkColor = Colors.pink;
  static const Color brownColor = Colors.brown;

  // Основной цвет (красный)
  static const Color primaryColor = Color(0xFFFF0000); // #FF0000
  static const Color primaryColorDark = Color(0xFFBF3030); // #BF3030
  static const Color primaryColorDarker = Color(0xFFA60000); // #A60000
  static const Color primaryColorLight = Color(0xFFFF4040); // #FF4040
  static const Color primaryColorLighter = Color(0xFFFF7373); // #FF7373

  // Вторичный цвет A (оранжевый)
  static const Color secondaryColorA = Color(0xFFFF7400); // #FF7400
  static const Color secondaryColorADark = Color(0xFFBF7130); // #BF7130
  static const Color secondaryColorADarker = Color(0xFFA64B00); // #A64B00
  static const Color secondaryColorALight = Color(0xFFFF9640); // #FF9640
  static const Color secondaryColorALighter = Color(0xFFFFB273); // #FFB273

  // Вторичный цвет B (розовый/пурпурный)
  static const Color secondaryColorB = Color(0xFFCD0074); // #CD0074
  static const Color secondaryColorBDark = Color(0xFF992667); // #992667
  static const Color secondaryColorBDarker = Color(0xFF85004B); // #85004B
  static const Color secondaryColorBLight = Color(0xFFE6399B); // #E6399B
  static const Color secondaryColorBLighter = Color(0xFFE667AF); // #E667AF

  // Основной цвет фона
  // Используется: scaffoldBackgroundColor - фон всего экрана (Scaffold)
  static const Color primaryBackgroundColor =
      Color.fromARGB(255, 242, 145, 138);

  // Цвета для светлой темы

  // Используется: colorScheme.primary - иконки меню (MenuItemWidget), текст настроек (SettingsItem)
  static const Color lightPrimary = blackColor;
  // OnPrimary - цвет текста/иконок на primary фоне
  static const Color lightOnPrimary = blackColor;
  // Secondary - вторичный акцентный цвет (оранжевый)
  static const Color lightSecondary = secondaryColorA;
  // OnSecondary - цвет текста/иконок на secondary фоне
  static const Color lightOnSecondary = whiteColor;
  // Surface - цвет поверхности для контента
  static const Color lightSurface = whiteColor;
  // OnSurface - основной цвет текста на surface
  static const Color lightOnSurface = blackColor;
  // OnSurfaceVariant - вторичный цвет текста/иконок на surface
  static const Color lightOnSurfaceVariant = greyColor;
  // InverseSurface - инвертированная поверхность
  // Используется: colorScheme.inverseSurface - для специальных случаев инверсии
  static const Color lightInverseSurface = pinkColor;
  // Scrim - затемнение фона
  static const Color lightScrim = Color.fromRGBO(0, 0, 0, 0.5);

  // Цвета для темной темы
  // Primary - основной акцентный цвет (светло-красный для лучшей видимости)
  // Используется: colorScheme.primary - иконки и текст в темной теме
  static const Color darkPrimary = whiteColor;
  // OnPrimary - цвет текста/иконок на primary фоне
  // Используется: colorScheme.onPrimary - текст на кнопках с primary цветом
  static const Color darkOnPrimary = whiteColor;
  // Secondary - вторичный акцентный цвет (светло-оранжевый)
  static const Color darkSecondary = secondaryColorBLighter;
  // OnSecondary - цвет текста/иконок на secondary фоне
  // Используется: colorScheme.onSecondary - текст на элементах с secondary цветом
  static const Color darkOnSecondary = whiteColor;
  // Surface - цвет поверхности для контента (темно-красный)
  // Используется: colorScheme.surface - фон контейнера с контентом в темной теме
  static const Color darkSurface = blackColor;
  // OnSurface - основной цвет текста на surface (белый для контраста)
  static const Color darkOnSurface = whiteColor;
  // OnSurfaceVariant - вторичный цвет текста/иконок на surface
  static const Color darkOnSurfaceVariant = greyColor;
  // InverseSurface - инвертированная поверхность
  // Используется: colorScheme.inverseSurface - для специальных случаев инверсии
  static const Color darkInverseSurface = whiteColor;
  // Scrim - затемнение фона (более темное для темной темы)
  static const Color darkScrim = Color.fromRGBO(0, 0, 0, 0.7);

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
        tertiary: secondaryColorB,
        onTertiary: Colors.white,
        background: primaryBackgroundColor,
        onBackground: Colors.white,
        surface: lightSurface,
        onSurface: lightOnSurface,
        onSurfaceVariant: lightOnSurfaceVariant,
        inverseSurface: Color.fromARGB(255, 248, 122, 164),
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
        tertiary: secondaryColorBLight,
        onTertiary: Colors.white,
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
