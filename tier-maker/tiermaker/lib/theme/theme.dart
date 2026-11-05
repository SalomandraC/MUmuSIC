import 'package:mumusic/theme/app_palette.dart';
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

  /// Светлая тема (пресет «Классика»)
  static ThemeData get ligthTheme => fromPalette(AppPalette.classicLight);

  /// Темная тема (пресет «Классика тёмная»)
  static ThemeData get darkTheme => fromPalette(AppPalette.classicDark);

  /// Тема из цветовой схемы. Сохраняет прежнюю логику цветов:
  /// colorScheme.primary — цвет текста/иконок на surface,
  /// colorScheme.secondary — акцент, scaffoldBackgroundColor — фон экрана.
  static ThemeData fromPalette(AppPalette palette) {
    final brightness = palette.isDark ? Brightness.dark : Brightness.light;
    final onBackground = contrastOn(palette.background);
    final onAccent = contrastOn(palette.accent);
    final secondaryText = Color.lerp(palette.text, palette.surface, 0.4)!;
    final container = Color.lerp(palette.surface, palette.text, 0.08)!;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.text,
      onPrimary: palette.text,
      primaryContainer: palette.accent,
      onPrimaryContainer: onAccent,
      secondary: palette.accent,
      onSecondary: onAccent,
      tertiary: palette.accent,
      onTertiary: onAccent,
      error: palette.isDark ? const Color(0xFFFF8A80) : const Color(0xFFD32F2F),
      onError: palette.isDark ? Colors.black : Colors.white,
      surface: palette.surface,
      onSurface: palette.text,
      onSurfaceVariant: secondaryText,
      surfaceContainerLowest: palette.surface,
      surfaceContainerLow: Color.lerp(palette.surface, palette.text, 0.03),
      surfaceContainer: Color.lerp(palette.surface, palette.text, 0.05),
      surfaceContainerHigh: Color.lerp(palette.surface, palette.text, 0.07),
      surfaceContainerHighest: container,
      outline: secondaryText,
      outlineVariant: Color.lerp(palette.surface, palette.text, 0.2),
      inverseSurface: palette.text,
      onInverseSurface: palette.surface,
      scrim: palette.isDark ? darkScrim : lightScrim,
      // ignore: deprecated_member_use
      background: palette.background,
      // ignore: deprecated_member_use
      onBackground: onBackground,
    );

    TextStyle style(double size, [FontWeight weight = FontWeight.normal]) =>
        TextStyle(fontSize: size, fontWeight: weight, color: palette.text);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      dialogTheme: DialogThemeData(backgroundColor: palette.surface),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: onAccent,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: palette.accent),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? palette.accent : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? palette.accent.withValues(alpha: 0.5)
                : null),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.accent,
        thumbColor: palette.accent,
        inactiveTrackColor: palette.accent.withValues(alpha: 0.25),
      ),
      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: palette.accent),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: onBackground),
        titleTextStyle: TextStyle(
          color: onBackground,
          fontSize: 22,
          fontWeight: FontWeight.normal,
        ),
      ),
      textTheme: TextTheme(
        headlineSmall: style(26),
        bodyLarge: style(19),
        bodyMedium: style(14),
        titleLarge: style(22),
        bodySmall: style(12),
        labelSmall: style(11),
        labelLarge: style(21, FontWeight.bold),
      ),
    );
  }
}
