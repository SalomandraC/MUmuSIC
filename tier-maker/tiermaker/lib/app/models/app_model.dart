import 'package:RandomTierList/core/app_database/app_database.dart';
import 'package:flutter/material.dart';

class AppModel extends ChangeNotifier {
  bool isLoading = true;
  String _appState = 'ltru000000';

  AppModel() {
    init();
  }

  // Геттер для полного состояния приложения
  String get appState => _appState;

  // Геттер для кода темы (первые 2 символа: lt/dr)
  String get themeCode => _appState.length >= 2 ? _appState.substring(0, 2) : 'lt';

  // Геттер для кода языка (символы 3-4: ru/en и т.д.)
  String get languageCode => _appState.length >= 4 ? _appState.substring(2, 4) : 'ru';

  // Геттер для дополнительных данных (остальные символы)
  String get additionalData => _appState.length > 4 ? _appState.substring(4) : '000000';

  // Геттер для проверки темной темы
  bool get isDarkTheme => themeCode == 'dr';

  Future<void> init() async {
    isLoading = true;
    notifyListeners();
    await getCurrentTheme();
    isLoading = false;
    notifyListeners();
  }

  Future<void> getCurrentTheme() async {
    final value = await AppDatabase.getAppTheme();
    _appState = value;
    notifyListeners();
  }

  Future<void> setAppState(String appState) async {
    _appState = appState;
    await AppDatabase.setAppTheme(appState);
    notifyListeners();
  }

  // Удобные методы для изменения отдельных частей состояния
  Future<void> setTheme(String themeCode) async {
    // themeCode должен быть 'lt' или 'dr'
    if (themeCode.length == 2) {
      _appState = themeCode + _appState.substring(2);
      await AppDatabase.setAppTheme(_appState);
      notifyListeners();
    }
  }

  Future<void> setLanguage(String languageCode) async {
    // languageCode должен быть 'ru', 'en' и т.д.
    if (languageCode.length == 2 && _appState.length >= 4) {
      _appState = _appState.substring(0, 2) + languageCode + _appState.substring(4);
      await AppDatabase.setAppTheme(_appState);
      notifyListeners();
    }
  }
}
