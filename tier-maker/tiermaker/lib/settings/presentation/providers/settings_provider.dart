import 'package:flutter/material.dart';
import 'package:RandomTierList/settings/domain/model/settings_model.dart';

/// Provider для SettingsModel
class SettingsProvider extends InheritedNotifier<SettingsModel> {
  const SettingsProvider({
    super.key,
    required super.notifier,
    required super.child,
  });

  static SettingsModel of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<SettingsProvider>();
    assert(provider != null, 'No SettingsProvider found in context');
    return provider!.notifier!;
  }
}

