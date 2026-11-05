import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mumusic/app/models/app_model.dart';
import 'package:mumusic/app/state/app_model_provider.dart';
import 'package:mumusic/settings/domain/model/settings_model.dart';
import 'package:mumusic/settings/presentation/providers/settings_provider.dart';
import 'package:mumusic/settings/presentation/screens/settings_screen.dart';
import 'package:mumusic/settings/presentation/screens/theme_settings_screen.dart';
import 'package:mumusic/theme/app_palette.dart';
import 'package:mumusic/theme/theme.dart';

void main() {
  late AppModel appModel;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('mumusic_test');
    Hive.init(dir.path);
    appModel = AppModel();
    await appModel.init();
  });

  tearDown(() => Hive.close());

  Widget app(Widget home) => AppModelProvider(
        notifier: appModel,
        child: ListenableBuilder(
          listenable: appModel,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.fromPalette(appModel.palette),
            home: SettingsProvider(
              notifier: SettingsModel(appModel: appModel),
              child: home,
            ),
          ),
        ),
      );

  testWidgets('настройки не переполняются на маленьком экране с клавиатурой',
      (tester) async {
    // Маленький телефон, клавиатура занимает почти половину экрана
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(app(const SettingsScreen()));
      await tester.pump();
    });
    expect(tester.takeException(), isNull);
    expect(find.text('Цветовая схема'), findsOneWidget);
  });

  testWidgets('выбор пресета меняет тему приложения', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app(const ThemeSettingsScreen()));
      await tester.pump();
    });
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      await tester.tap(find.text('Океан'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(appModel.palette.id, 'ocean');
    expect(appModel.isDarkTheme, isFalse);

    // Схема сохраняется и восстанавливается после перезапуска
    final restored = AppModel();
    await tester.runAsync(() => restored.init());
    expect(restored.palette, AppPalette.byId('ocean'));
  });
}
