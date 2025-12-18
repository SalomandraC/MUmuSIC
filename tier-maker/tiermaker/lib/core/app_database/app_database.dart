import 'package:hive_flutter/hive_flutter.dart';

/// Класс для работы с локальным хранилищем приложения
/// Использует Hive для хранения состояния приложения
class AppDatabase {
  static const String _boxName = 'appBox';
  static const String _themeKey = 'appState';
  static const String _isGuestKey = 'isGuest';
  static const String _userEmailKey = 'userEmail';
  static const String _userNicknameKey = 'userNickname';
  static const String _apiBaseUrlKey = 'apiBaseUrl';
  static const String _accessTokenKey = 'accessToken';
  static const String _refreshTokenKey = 'refreshToken';
  static const String _userIdKey = 'userId';
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

  static Future<void> setAppTheme(String appState) async {
    final box = await _ensureBox();
    await box.put(_themeKey, appState);
  }

  static Future<bool> getIsGuest() async {
    final box = await _ensureBox();
    final value = box.get(_isGuestKey, defaultValue: 'true');
    return value == 'true';
  }

  static Future<void> setIsGuest(bool isGuest) async {
    final box = await _ensureBox();
    await box.put(_isGuestKey, isGuest.toString());
  }

  static Future<String?> getUserEmail() async {
    final box = await _ensureBox();
    return box.get(_userEmailKey);
  }

  static Future<void> setUserEmail(String? email) async {
    final box = await _ensureBox();
    if (email != null) {
      await box.put(_userEmailKey, email);
    } else {
      await box.delete(_userEmailKey);
    }
  }

  static Future<String?> getUserNickname() async {
    final box = await _ensureBox();
    return box.get(_userNicknameKey);
  }

  static Future<void> setUserNickname(String? nickname) async {
    final box = await _ensureBox();
    if (nickname != null) {
      await box.put(_userNicknameKey, nickname);
    } else {
      await box.delete(_userNicknameKey);
    }
  }

  static Future<String?> getApiBaseUrl() async {
    final box = await _ensureBox();
    return box.get(_apiBaseUrlKey);
  }

  static Future<void> setApiBaseUrl(String? url) async {
    final box = await _ensureBox();
    if (url != null && url.isNotEmpty) {
      final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      await box.put(_apiBaseUrlKey, cleanUrl);
    } else {
      await box.delete(_apiBaseUrlKey);
    }
  }

  static Future<String?> getAccessToken() async {
    final box = await _ensureBox();
    return box.get(_accessTokenKey);
  }

  static Future<void> setAccessToken(String? token) async {
    final box = await _ensureBox();
    if (token != null) {
      await box.put(_accessTokenKey, token);
    } else {
      await box.delete(_accessTokenKey);
    }
  }

  static Future<String?> getRefreshToken() async {
    final box = await _ensureBox();
    return box.get(_refreshTokenKey);
  }

  static Future<void> setRefreshToken(String? token) async {
    final box = await _ensureBox();
    if (token != null) {
      await box.put(_refreshTokenKey, token);
    } else {
      await box.delete(_refreshTokenKey);
    }
  }

  static Future<int?> getUserId() async {
    final box = await _ensureBox();
    final value = box.get(_userIdKey);
    return value != null ? int.tryParse(value) : null;
  }

  static Future<void> setUserId(int? userId) async {
    final box = await _ensureBox();
    if (userId != null) {
      await box.put(_userIdKey, userId.toString());
    } else {
      await box.delete(_userIdKey);
    }
  }

  static Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}
