import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:RandomTierList/app/app_routes.dart';
import 'package:RandomTierList/app/models/app_model.dart';
import 'package:RandomTierList/app/state/app_model_provider.dart';
import 'package:RandomTierList/home/presentation/screens/main_screen.dart';
import 'package:RandomTierList/settings/domain/model/settings_model.dart';
import 'package:RandomTierList/settings/presentation/providers/settings_provider.dart';
import 'package:RandomTierList/settings/presentation/screens/settings_screen.dart';
import 'package:RandomTierList/auth/presentation/screens/auth_screen.dart';
import 'package:RandomTierList/guest_tracks/presentation/screens/guest_tracks_screen.dart';
import 'package:RandomTierList/nfc/presentation/screens/nfc_screen.dart';

class AppRouter {
  static GoRouter createRouter(AppModel appModel) {
    return GoRouter(
      initialLocation: AppRoutes.home,
      refreshListenable: appModel,
      redirect: (context, state) {
        final model = AppModelProvider.of(context);
        final currentPath = state.uri.path;
        final isAuth = currentPath == AppRoutes.auth;
        
        final guestAllowedPaths = [
          AppRoutes.home,
          AppRoutes.guestTracks,
          AppRoutes.nfc,
          AppRoutes.auth,
          AppRoutes.settings,
        ];
        
        if (model.isGuest && !guestAllowedPaths.contains(currentPath)) {
          return AppRoutes.home;
        }
        
        if (!model.isGuest && isAuth) {
          return AppRoutes.home;
        }
        
        return null;
      },
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
        GoRoute(
          path: AppRoutes.auth,
          name: AppRoutes.authName,
          builder: (context, state) => const AuthScreen(),
        ),
        GoRoute(
          path: AppRoutes.guestTracks,
          name: AppRoutes.guestTracksName,
          builder: (context, state) => const GuestTracksScreen(),
        ),
        GoRoute(
          path: AppRoutes.nfc,
          name: AppRoutes.nfcName,
          builder: (context, state) => const NfcScreen(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text('Страница не найдена: ${state.uri}'),
        ),
      ),
    );
  }

  // Для обратной совместимости
  static GoRouter get router => throw UnsupportedError(
    'Use AppRouter.createRouter(appModel) instead',
  );
}
