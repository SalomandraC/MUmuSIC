import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:RandomTierList/app/app_routes.dart';
import 'package:RandomTierList/app/models/app_model.dart';
import 'package:RandomTierList/app/state/app_model_provider.dart';
import 'package:RandomTierList/home/presentation/screens/main_screen.dart';
import 'package:RandomTierList/home/presentation/screens/network_screen.dart';
import 'package:RandomTierList/settings/domain/model/settings_model.dart';
import 'package:RandomTierList/settings/presentation/providers/settings_provider.dart';
import 'package:RandomTierList/settings/presentation/screens/settings_screen.dart';
import 'package:RandomTierList/auth/presentation/screens/auth_screen.dart';
import 'package:RandomTierList/nfc/presentation/screens/nfc_screen.dart';
import 'package:RandomTierList/search/presentation/screens/search_screen.dart';
import 'package:RandomTierList/favorites/presentation/screens/favorites_screen.dart';
import 'package:RandomTierList/playlists/presentation/screens/playlists_screen.dart';
import 'package:RandomTierList/playlists/presentation/screens/playlist_details_screen.dart';
import 'package:RandomTierList/storage/presentation/screens/storage_screen.dart';
import 'package:RandomTierList/top_charts/presentation/screens/top_charts_screen.dart';

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
          AppRoutes.network,
          AppRoutes.nfc,
          AppRoutes.auth,
          AppRoutes.settings,
          AppRoutes.search,
          AppRoutes.favorites,
          AppRoutes.playlists,
          AppRoutes.storage,
          AppRoutes.topCharts,
        ];

        // Проверяем пути с параметрами (например, /playlist-details/123)
        final isPlaylistDetails =
            currentPath.startsWith(AppRoutes.playlistDetails);

        if (model.isGuest) {
          // Для гостя разрешаем доступ к плейлистам и их деталям
          if (isPlaylistDetails || guestAllowedPaths.contains(currentPath)) {
            // Разрешаем доступ
          } else {
            return AppRoutes.home;
          }
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
          path: AppRoutes.network,
          name: AppRoutes.networkName,
          builder: (context, state) => const NetworkScreen(),
        ),
        GoRoute(
          path: AppRoutes.nfc,
          name: AppRoutes.nfcName,
          builder: (context, state) => const NfcScreen(),
        ),
        GoRoute(
          path: AppRoutes.search,
          name: AppRoutes.searchName,
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: AppRoutes.favorites,
          name: AppRoutes.favoritesName,
          builder: (context, state) => const FavoritesScreen(),
        ),
        GoRoute(
          path: AppRoutes.playlists,
          name: AppRoutes.playlistsName,
          builder: (context, state) => const PlaylistsScreen(),
        ),
        GoRoute(
          path: '${AppRoutes.playlistDetails}/:id',
          name: AppRoutes.playlistDetailsName,
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
            return PlaylistDetailsScreen(playlistId: id);
          },
        ),
        GoRoute(
          path: AppRoutes.storage,
          name: AppRoutes.storageName,
          builder: (context, state) => const StorageScreen(),
        ),
        GoRoute(
          path: AppRoutes.topCharts,
          name: AppRoutes.topChartsName,
          builder: (context, state) => const TopChartsScreen(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text('Страница не найдена: ${state.uri}'),
        ),
      ),
    );
  }

  static GoRouter get router => throw UnsupportedError(
        'Use AppRouter.createRouter(appModel) instead',
      );
}
