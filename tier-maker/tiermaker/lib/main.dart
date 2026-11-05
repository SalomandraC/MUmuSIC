import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mumusic/app/my_app.dart';
import 'package:mumusic/app/models/app_model.dart';
import 'package:mumusic/core/app_database/app_database.dart';
import 'package:mumusic/core/api/guest_tracks_api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[main] Предупреждение: не удалось загрузить .env файл: $e');
  }

  await AppDatabase.init();

  await GuestTracksApi.getBaseUrl();

  final appModel = AppModel();
  await appModel.init();

  runApp(MuMusicApp(appModel: appModel));
}
