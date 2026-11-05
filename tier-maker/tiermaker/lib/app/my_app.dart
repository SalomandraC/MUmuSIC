import 'package:mumusic/app/state/app_model_provider.dart';
import 'package:mumusic/core/navigation/app_router.dart';
import 'package:mumusic/theme/theme.dart';
import 'package:mumusic/core/audio/player_bar.dart';
import 'package:flutter/material.dart';
import 'package:mumusic/app/models/app_model.dart';
import 'package:go_router/go_router.dart';

class MuMusicApp extends StatefulWidget {
  final AppModel appModel;

  const MuMusicApp({
    super.key,
    required this.appModel,
  });

  @override
  State<MuMusicApp> createState() => _MuMusicAppState();
}

class _MuMusicAppState extends State<MuMusicApp> {
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
                title: 'MuMuSIC',
                theme: AppTheme.fromPalette(model.palette),
                locale: Locale(model.languageCode),
                routerConfig: _router,
                // Плашка плеера одна на всё приложение и видна на любом экране
                builder: (context, child) => PlayerBarHost(child: child),
              );
            },
          );
        },
      ),
    );
  }
}
