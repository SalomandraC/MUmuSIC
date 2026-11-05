import 'dart:convert';

import 'package:flutter/material.dart';

/// Цветовая схема приложения: четыре базовых цвета + светлая/тёмная основа.
/// Остальные цвета (контрастный текст, вторичный текст, фон плеера и т.д.)
/// вычисляются из них в [AppTheme.fromPalette].
@immutable
class AppPalette {
  static const String customId = 'custom';

  final String id;
  final String name;

  /// Фон экрана (за шапкой и списками)
  final Color background;

  /// Фон контента: списки, карточки, настройки
  final Color surface;

  /// Акцент: кнопки, слайдеры, активный трек
  final Color accent;

  /// Основной текст и иконки на [surface]
  final Color text;
  final bool isDark;

  const AppPalette({
    required this.id,
    required this.name,
    required this.background,
    required this.surface,
    required this.accent,
    required this.text,
    required this.isDark,
  });

  bool get isCustom => id == customId;

  AppPalette copyWith({
    String? id,
    String? name,
    Color? background,
    Color? surface,
    Color? accent,
    Color? text,
    bool? isDark,
  }) {
    return AppPalette(
      id: id ?? this.id,
      name: name ?? this.name,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      accent: accent ?? this.accent,
      text: text ?? this.text,
      isDark: isDark ?? this.isDark,
    );
  }

  /// Своя схема на основе этой
  AppPalette toCustom() => copyWith(id: customId, name: 'Своя');

  String toJson() {
    if (!isCustom) return jsonEncode({'preset': id});
    return jsonEncode({
      'preset': customId,
      'background': background.toARGB32(),
      'surface': surface.toARGB32(),
      'accent': accent.toARGB32(),
      'text': text.toARGB32(),
      'isDark': isDark,
    });
  }

  static AppPalette? fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final preset = map['preset'] as String?;
      if (preset != customId) return byId(preset);
      return AppPalette(
        id: customId,
        name: 'Своя',
        background: Color(map['background'] as int),
        surface: Color(map['surface'] as int),
        accent: Color(map['accent'] as int),
        text: Color(map['text'] as int),
        isDark: map['isDark'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  static AppPalette? byId(String? id) {
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return null;
  }

  static const AppPalette classicLight = AppPalette(
    id: 'classic_light',
    name: 'Классика',
    background: Color(0xFFF2918A),
    surface: Color(0xFFFFFFFF),
    accent: Color(0xFFFF7400),
    text: Color(0xFF000000),
    isDark: false,
  );

  static const AppPalette classicDark = AppPalette(
    id: 'classic_dark',
    name: 'Классика тёмная',
    background: Color(0xFFF2918A),
    surface: Color(0xFF000000),
    accent: Color(0xFFE667AF),
    text: Color(0xFFFFFFFF),
    isDark: true,
  );

  static const List<AppPalette> presets = [
    classicLight,
    classicDark,
    AppPalette(
      id: 'midnight',
      name: 'Полночь',
      background: Color(0xFF1E1B2E),
      surface: Color(0xFF121018),
      accent: Color(0xFF8B7CF6),
      text: Color(0xFFEDEBFF),
      isDark: true,
    ),
    AppPalette(
      id: 'ocean',
      name: 'Океан',
      background: Color(0xFF1F6F8B),
      surface: Color(0xFFF3FAFC),
      accent: Color(0xFF0FA3B1),
      text: Color(0xFF0B2530),
      isDark: false,
    ),
    AppPalette(
      id: 'forest',
      name: 'Лес',
      background: Color(0xFF2F5D50),
      surface: Color(0xFF0F1A17),
      accent: Color(0xFF7BC67E),
      text: Color(0xFFE6F2EA),
      isDark: true,
    ),
    AppPalette(
      id: 'sunset',
      name: 'Закат',
      background: Color(0xFFF46B45),
      surface: Color(0xFFFFF6F0),
      accent: Color(0xFFC2185B),
      text: Color(0xFF2B1B17),
      isDark: false,
    ),
    AppPalette(
      id: 'lavender',
      name: 'Лаванда',
      background: Color(0xFFB39DDB),
      surface: Color(0xFFFBF8FF),
      accent: Color(0xFF7E57C2),
      text: Color(0xFF241B35),
      isDark: false,
    ),
    AppPalette(
      id: 'mono',
      name: 'Монохром',
      background: Color(0xFF2B2B2B),
      surface: Color(0xFF1A1A1A),
      accent: Color(0xFFE0E0E0),
      text: Color(0xFFF5F5F5),
      isDark: true,
    ),
  ];

  @override
  bool operator ==(Object other) =>
      other is AppPalette &&
      other.id == id &&
      other.background == background &&
      other.surface == surface &&
      other.accent == accent &&
      other.text == text &&
      other.isDark == isDark;

  @override
  int get hashCode => Object.hash(id, background, surface, accent, text, isDark);
}

/// Чёрный или белый — что лучше читается на [color]
Color contrastOn(Color color) =>
    color.computeLuminance() > 0.45 ? Colors.black : Colors.white;
