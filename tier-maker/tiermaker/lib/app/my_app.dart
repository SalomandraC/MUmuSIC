import 'package:RandomTierList/app/state/app_model_provider.dart';
import 'package:RandomTierList/core/navigation/app_router.dart';
import 'package:RandomTierList/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:RandomTierList/app/models/app_model.dart';
import 'package:go_router/go_router.dart';

class TierMakerApp extends StatefulWidget {
  final AppModel appModel;

  const TierMakerApp({
    super.key,
    required this.appModel,
  });

  @override
  State<TierMakerApp> createState() => _TierMakerAppState();
}

class _TierMakerAppState extends State<TierMakerApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.createRouter(widget.appModel);
  }

  @override
  Widget build(BuildContext context) {
    return AppModelProvider(
      notifier: widget.appModel,
      child: Builder(
        builder: (context) {
          final model = AppModelProvider.of(context);
          
          return ListenableBuilder(
            listenable: model,
            builder: (context, child) {
              return MaterialApp.router(
                title: 'Tier Maker',
                theme: AppTheme.ligthTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: _themeModeFromString(model.themeCode),
                locale: Locale(model.languageCode),
                routerConfig: _router,
              );
            },
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
