import 'package:hive_flutter/hive_flutter.dart';

/// Класс для работы с локальным хранилищем приложения
/// Использует Hive для хранения состояния приложения
class AppDatabase {
  static const String _boxName = 'appBox';
  static const String _themeKey = 'appState';
  static Box<String>? _box;

  /// Проверяет и открывает box, если он еще не открыт
  static Future<Box<String>> _ensureBox() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<String>(_boxName);
    }
    return _box!;
  }

  /// Инициализирует Hive и открывает box
  /// Должен быть вызван перед использованием других методов
  static Future<void> init() async {
    await Hive.initFlutter();
    await _ensureBox();
  }

  /// Получает текущее состояние приложения
  /// Формат: 'ltru000000' где:
  /// - lt/dr - тема (light/dark)
  /// - ru/en - язык (russian/english)
  /// - 000000 - дополнительные данные для будущего использования
  static Future<String> getAppTheme() async {
    final box = await _ensureBox();
    return box.get(_themeKey, defaultValue: 'ltru000000') ?? 'ltru000000';
  }

  /// Сохраняет состояние приложения
  static Future<void> setAppTheme(String appState) async {
    final box = await _ensureBox();
    await box.put(_themeKey, appState);
  }

  /// Закрывает box (опционально, для очистки ресурсов)
  static Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}
