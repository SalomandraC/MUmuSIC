import 'package:flutter/material.dart';
import 'package:RandomTierList/home/domain/model/home_model.dart';

class HomeProvider extends InheritedNotifier<HomeModel> {
  const HomeProvider({
    super.key,
    required super.notifier,
    required super.child,
  });

  static HomeModel of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<HomeProvider>();
    assert(provider != null, 'No HomeProvider found in context');
    return provider!.notifier!;
  }
}

