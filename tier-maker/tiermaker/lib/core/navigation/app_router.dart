import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:RandomTierList/app/app_routes.dart';
import 'package:RandomTierList/app/state/app_model_provider.dart';
import 'package:RandomTierList/home/presentation/screens/main_screen.dart';
import 'package:RandomTierList/settings/domain/model/settings_model.dart';
import 'package:RandomTierList/settings/presentation/providers/settings_provider.dart';
import 'package:RandomTierList/settings/presentation/screens/settings_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: AppRoutes.settingsName,
        builder: (context, state) {
          final appModel = AppModelProvider.of(context);
          final settingsModel = SettingsModel(appModel: appModel);
          return SettingsProvider(
            notifier: settingsModel,
            child: const SettingsScreen(),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Страница не найдена: ${state.uri}'),
      ),
    ),
  );
}
