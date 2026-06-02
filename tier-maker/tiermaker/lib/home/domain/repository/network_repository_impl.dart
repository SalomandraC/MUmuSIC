import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:RandomTierList/data/datasources/remote/itunes_remote_datasource.dart';
import 'package:RandomTierList/home/domain/model/network_track_model.dart';
import 'package:RandomTierList/home/domain/repository/i_network_repository.dart';

/// Реализация репозитория для работы с треками из сети
class NetworkRepositoryImpl implements INetworkRepository {
  final ITunesRemoteDataSource _remoteDataSource;

  NetworkRepositoryImpl({ITunesRemoteDataSource? remoteDataSource})
      : _remoteDataSource =
            remoteDataSource ?? ITunesRemoteDataSourceImpl();

  @override
  Future<List<NetworkTrack>> searchTracks({
    required String query,
    int limit = 50,
  }) async {
    try {
      final dtos = await _remoteDataSource.searchTracks(query, limit: limit);

      return dtos
          .map(
            (dto) => NetworkTrack(
              trackId: dto.trackId,
              trackName: dto.trackName ?? '',
              artistName: dto.artistName ?? '',
              trackTimeMillis: dto.trackTimeMillis,
              previewUrl: dto.previewUrl,
              artworkUrl100: dto.artworkUrl100,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('❌ [NetworkRepository] Ошибка поиска: $e');
      rethrow;
    }
  }

  @override
  Future<String> downloadTrack(NetworkTrack track) async {
    try {
      // Проверяем разрешение на запись
      if (Platform.isAndroid) {
        // Для Android 13+ (API 33+) используем READ_MEDIA_AUDIO
        // Для более старых версий - WRITE_EXTERNAL_STORAGE
        // permission_handler автоматически выберет правильное разрешение
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          // Пробуем альтернативное разрешение для Android 13+
          final audioStatus = await Permission.audio.request();
          if (!audioStatus.isGranted) {
            throw Exception('Необходимо разрешение на доступ к хранилищу');
          }
        }
      } else if (Platform.isIOS) {
        // Для iOS разрешения запрашиваются автоматически при доступе к файлам
      }

      // Получаем директорию для сохранения
      final directory = await _getDownloadDirectory();
      final fileName =
          _sanitizeFileName('${track.artistName} - ${track.trackName}.m4a');
      final filePath = '${directory.path}/$fileName';

      // Проверяем, существует ли файл
      final file = File(filePath);
      if (await file.exists()) {
        debugPrint('✅ [NetworkRepository] Файл уже существует: $filePath');
        return filePath;
      }

      // Скачиваем файл
      // Примечание: iTunes API не предоставляет прямую ссылку на скачивание,
      // поэтому используем previewUrl как временное решение
      // В реальном приложении нужно использовать другой API или сервис
      final downloadUrl = track.previewUrl;
      if (downloadUrl == null || downloadUrl.isEmpty) {
        throw Exception('URL для скачивания недоступен');
      }

      debugPrint('⬇️ [NetworkRepository] Начало скачивания: $downloadUrl');
      final response = await http.get(Uri.parse(downloadUrl));

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('✅ [NetworkRepository] Файл скачан: $filePath');
        return filePath;
      } else {
        throw Exception('Ошибка скачивания: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [NetworkRepository] Ошибка скачивания: $e');
      rethrow;
    }
  }

  @override
  String? getPreviewUrl(NetworkTrack track) {
    return track.previewUrl;
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final directory = Directory('/storage/emulated/0/Download/MuMuSIC');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    } else {
      // Для других платформ
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    }
  }

  /// Очистка имени файла от недопустимых символов
  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
