import 'package:flutter/material.dart';
import 'package:RandomTierList/app/models/app_model.dart';

class AppModelProvider extends InheritedNotifier<AppModel> {
  const AppModelProvider({
    super.key,
    required super.notifier,
    required super.child,
  });

  static AppModel of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<AppModelProvider>();
    assert(provider != null, 'No AppModelProvider found in context');
    return provider!.notifier!;
  }
}
