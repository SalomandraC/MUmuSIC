import 'package:flutter/material.dart';
import 'package:RandomTierList/home/presentation/state/network_model.dart';

class NetworkProvider extends InheritedNotifier<NetworkModel> {
  const NetworkProvider({
    super.key,
    required super.notifier,
    required super.child,
  });

  static NetworkModel of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<NetworkProvider>();
    assert(provider != null, 'No NetworkProvider found in context');
    return provider!.notifier!;
  }
}

