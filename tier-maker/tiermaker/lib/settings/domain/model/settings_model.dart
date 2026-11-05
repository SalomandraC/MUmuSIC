import 'package:flutter/material.dart';
import 'package:mumusic/app/models/app_model.dart';
import 'package:mumusic/theme/app_palette.dart';

class SettingsModel extends ChangeNotifier {
  final AppModel appModel;
  bool _isLoading = false;

  SettingsModel({required this.appModel});

  bool get isLoading => _isLoading;

  Future<void> toggleTheme() => setTheme(!appModel.isDarkTheme);

  Future<void> setPalette(AppPalette palette) async {
    _isLoading = true;
    notifyListeners();

    await appModel.setPalette(palette);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setTheme(bool isDark) async {
    _isLoading = true;
    notifyListeners();
    
    // Переключатель светлая/тёмная выбирает классическую схему
    await appModel.setPalette(
      isDark ? AppPalette.classicDark : AppPalette.classicLight,
    );
    
    _isLoading = false;
    notifyListeners();
  }
}

