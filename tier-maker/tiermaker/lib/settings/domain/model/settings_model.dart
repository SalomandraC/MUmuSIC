import 'package:flutter/material.dart';
import 'package:RandomTierList/app/models/app_model.dart';

class SettingsModel extends ChangeNotifier {
  final AppModel appModel;
  bool _isLoading = false;

  SettingsModel({required this.appModel});

  bool get isLoading => _isLoading;

  Future<void> toggleTheme() async {
    _isLoading = true;
    notifyListeners();
    
    final currentTheme = appModel.isDarkTheme;
    await appModel.setTheme(currentTheme ? 'lt' : 'dr');
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setTheme(bool isDark) async {
    _isLoading = true;
    notifyListeners();
    
    await appModel.setTheme(isDark ? 'dr' : 'lt');
    
    _isLoading = false;
    notifyListeners();
  }
}

