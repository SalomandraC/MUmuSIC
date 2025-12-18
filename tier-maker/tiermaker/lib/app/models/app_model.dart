import 'package:RandomTierList/core/app_database/app_database.dart';
import 'package:flutter/material.dart';

class AppModel extends ChangeNotifier {
  bool isLoading = true;
  String _appState = 'ltru000000';
  bool _isGuest = true;
  String? _userEmail;
  String? _userNickname;

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

  // Геттеры для авторизации
  bool get isGuest => _isGuest;
  String? get userEmail => _userEmail;
  String? get userNickname => _userNickname;

  Future<String?> getAccessToken() async {
    return await AppDatabase.getAccessToken();
  }

  Future<void> init() async {
    isLoading = true;
    notifyListeners();
    await getCurrentTheme();
    await loadAuthState();
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadAuthState() async {
    _isGuest = await AppDatabase.getIsGuest();
    _userEmail = await AppDatabase.getUserEmail();
    _userNickname = await AppDatabase.getUserNickname();
    
    // Если есть токен, значит пользователь авторизован
    final accessToken = await AppDatabase.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      _isGuest = false;
    }
    
    notifyListeners();
  }

  Future<void> setGuestMode(bool isGuest) async {
    _isGuest = isGuest;
    await AppDatabase.setIsGuest(isGuest);
    if (isGuest) {
      _userEmail = null;
      _userNickname = null;
      await AppDatabase.setUserEmail(null);
      await AppDatabase.setUserNickname(null);
    }
    notifyListeners();
  }

  Future<void> setUserInfo({
    required String email,
    required String nickname,
  }) async {
    _isGuest = false;
    _userEmail = email;
    _userNickname = nickname;
    await AppDatabase.setIsGuest(false);
    await AppDatabase.setUserEmail(email);
    await AppDatabase.setUserNickname(nickname);
    notifyListeners();
  }

  Future<void> setAuthData({
    required String email,
    required String username,
    required String accessToken,
    required String refreshToken,
    required int userId,
  }) async {
    _isGuest = false;
    _userEmail = email;
    _userNickname = username;
    await AppDatabase.setIsGuest(false);
    await AppDatabase.setUserEmail(email);
    await AppDatabase.setUserNickname(username);
    await AppDatabase.setAccessToken(accessToken);
    await AppDatabase.setRefreshToken(refreshToken);
    await AppDatabase.setUserId(userId);
    notifyListeners();
  }

  Future<void> clearAuthData() async {
    _isGuest = true;
    _userEmail = null;
    _userNickname = null;
    await AppDatabase.setIsGuest(true);
    await AppDatabase.setUserEmail(null);
    await AppDatabase.setUserNickname(null);
    await AppDatabase.setAccessToken(null);
    await AppDatabase.setRefreshToken(null);
    await AppDatabase.setUserId(null);
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
