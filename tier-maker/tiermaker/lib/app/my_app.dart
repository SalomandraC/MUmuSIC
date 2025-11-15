import 'package:RandomTierList/app/state/app_model_provider.dart';
import 'package:RandomTierList/core/navigation/app_router.dart';
import 'package:RandomTierList/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:RandomTierList/app/models/app_model.dart';

class TierMakerApp extends StatelessWidget {
  final AppModel appModel;

  const TierMakerApp({
    super.key,
    required this.appModel,
  });

  @override
  Widget build(BuildContext context) {
    return AppModelProvider(
      notifier: appModel,
      child: Builder(
        builder: (context) {
          final model = AppModelProvider.of(context);
          return MaterialApp.router(
            title: 'Tier Maker',
            theme: AppTheme.ligthTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: _themeModeFromString(model.themeCode),
            locale: Locale(model.languageCode),
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}

ThemeMode _themeModeFromString(String code) {
  switch (code) {
    case 'dr':
      return ThemeMode.dark;
    case 'lt':
      return ThemeMode.light;
    default:
      return ThemeMode.system;
  }
}
