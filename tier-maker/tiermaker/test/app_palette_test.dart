import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mumusic/settings/presentation/widgets/color_picker_dialog.dart';
import 'package:mumusic/theme/app_palette.dart';
import 'package:mumusic/theme/theme.dart';

void main() {
  test('пресет сохраняется по id', () {
    final restored = AppPalette.fromJson(AppPalette.presets[3].toJson());
    expect(restored, AppPalette.presets[3]);
  });

  test('своя схема сохраняет все цвета', () {
    final custom = AppPalette.classicLight.toCustom().copyWith(
          accent: const Color(0xFF123456),
          isDark: true,
        );
    expect(AppPalette.fromJson(custom.toJson()), custom);
  });

  test('битый JSON не ломает запуск', () {
    expect(AppPalette.fromJson('{oops'), isNull);
    expect(AppPalette.fromJson(null), isNull);
  });

  test('тема строится для всех пресетов', () {
    for (final p in AppPalette.presets) {
      final theme = AppTheme.fromPalette(p);
      expect(theme.scaffoldBackgroundColor, p.background);
      expect(theme.colorScheme.secondary, p.accent);
      expect(theme.brightness, p.isDark ? Brightness.dark : Brightness.light);
    }
  });

  test('HEX туда и обратно', () {
    expect(colorToHex(const Color(0xFFFF7400)), '#FF7400');
    expect(colorFromHex('#ff7400'), const Color(0xFFFF7400));
    expect(colorFromHex('zzz'), isNull);
  });
}
