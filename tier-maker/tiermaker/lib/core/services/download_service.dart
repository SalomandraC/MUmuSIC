import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../api/tracks_api.dart';
import '../api/sync_api.dart';
import '../../data/datasources/local/local_storage_datasource.dart';
import '../../data/models/track_dto.dart';
import '../../data/models/playlist_dto.dart';

class DownloadService {
  static final LocalStorageDataSource _localStorage =
      LocalStorageDataSourceImpl();

  static Future<Map<String, dynamic>> downloadTracks() async {
    try {
      debugPrint(
          '[DownloadService] ========== Начало загрузки треков с сервера ==========');
      final result = await TracksApi.getUserTracks();

      debugPrint(
          '[DownloadService] Результат API: success=${result['success']}, error=${result['error']}, statusCode=${result['statusCode']}');

      if (result['success'] != true) {
        final error = result['error'] as String? ?? 'Неизвестная ошибка';
        final statusCode = result['statusCode'] as int?;
        debugPrint(
            '[DownloadService] ❌ Ошибка получения треков: $error (код: $statusCode)');
        return result;
      }

      final data = result['data'] as Map<String, dynamic>?;
      if (data == null) {
        debugPrint('[DownloadService] ❌ Данные отсутствуют в ответе');
        debugPrint('[DownloadService] Полный результат: $result');
        return {
          'success': false,
          'error': 'Данные отсутствуют в ответе сервера'
        };
      }

      debugPrint('[DownloadService] ✅ Данные получены: keys=${data.keys}');
      final tracksJson = data['tracks'] as List<dynamic>?;

      if (tracksJson == null) {
        debugPrint('[DownloadService] ⚠️ Поле tracks отсутствует в ответе');
        debugPrint('[DownloadService] Структура данных: $data');
        return {
          'success': false,
          'error': 'Некорректный формат ответа сервера: поле tracks отсутствует'
        };
      }

      if (tracksJson.isEmpty) {
        debugPrint('[DownloadService] ℹ️ Треки отсутствуют на сервере');
        return {'success': true, 'message': 'Нет треков на сервере'};
      }

      debugPrint('[DownloadService] ✅ Получено треков: ${tracksJson.length}');

      // Преобразуем треки в TrackDto
      final tracks = <TrackDto>[];
      for (final json in tracksJson) {
        try {
          final trackData = json as Map<String, dynamic>;
          debugPrint(
              '[DownloadService] Обработка трека: id=${trackData['id']}, title=${trackData['title']}');

          // Получаем полный URL для файла
          String? fileUrl = trackData['file_url'] as String?;
          if (fileUrl != null && !fileUrl.startsWith('http')) {
            // Если URL относительный, добавляем базовый URL
            final baseUrl = await TracksApi.getBaseUrl();
            if (fileUrl.startsWith('/')) {
              fileUrl = '$baseUrl$fileUrl';
            } else {
              fileUrl = '$baseUrl/$fileUrl';
            }
          }

          final track = TrackDto(
            trackId: trackData['id'] as int,
            trackName: trackData['title'] as String?,
            artistName: trackData['artist'] as String?,
            trackTimeMillis: trackData['duration'] != null
                ? (trackData['duration'] as int) * 1000
                : null,
            previewUrl: fileUrl,
            artworkUrl100: null,
          );
          tracks.add(track);
        } catch (e) {
          debugPrint('[DownloadService] Ошибка обработки трека: $e');
        }
      }

      debugPrint('[DownloadService] Преобразовано треков: ${tracks.length}');

      // Скачиваем файлы треков в локальное хранилище
      debugPrint('[DownloadService] Начало скачивания файлов треков...');
      int downloadedCount = 0;
      int failedCount = 0;

      for (final track in tracks) {
        if (track.previewUrl != null && track.previewUrl!.isNotEmpty) {
          try {
            await _downloadTrackFile(track);
            downloadedCount++;
            debugPrint(
                '[DownloadService] ✅ Скачан трек: ${track.trackName ?? "Unknown"}');
          } catch (e) {
            failedCount++;
            debugPrint(
                '[DownloadService] ❌ Ошибка скачивания трека ${track.trackName ?? "Unknown"}: $e');
          }
        } else {
          debugPrint(
              '[DownloadService] ⚠️ Пропущен трек ${track.trackName ?? "Unknown"}: отсутствует URL');
        }
      }

      debugPrint(
          '[DownloadService] ✅ Скачано файлов: $downloadedCount, ошибок: $failedCount');

      // Треки скачиваются как файлы и будут отображаться во внутреннем хранилище
      // Не сохраняем в избранное - файлы доступны через DownloadedTracksRepository

      final skippedCount = tracks.length - downloadedCount - failedCount;
      debugPrint(
          '[DownloadService] 📊 Итого: обработано ${tracks.length}, скачано $downloadedCount, пропущено $skippedCount, ошибок $failedCount');

      return {
        'success': true,
        'message':
            'Скачано треков: $downloadedCount из ${tracks.length}${failedCount > 0 ? ' (ошибок: $failedCount)' : ''}',
        'count': tracks.length,
        'downloadedCount': downloadedCount,
        'failedCount': failedCount,
        'skippedCount': skippedCount,
      };
    } catch (e) {
      debugPrint('[DownloadService] Ошибка загрузки треков: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> downloadPlaylists() async {
    try {
      final result = await SyncApi.downloadData();
      if (result['success'] != true) {
        return result;
      }

      final data = result['data'] as Map<String, dynamic>;
      final playlistsJson = data['playlists'] as List<dynamic>?;

      if (playlistsJson == null || playlistsJson.isEmpty) {
        return {'success': true, 'message': 'Нет плейлистов на сервере'};
      }

      // Преобразуем плейлисты в PlaylistDto и сохраняем локально
      final playlists = playlistsJson.map((json) {
        final playlistData = json as Map<String, dynamic>;
        final tracksJson = playlistData['tracks'] as List<dynamic>? ?? [];

        final nameValue = playlistData['name'];
        final nameString = nameValue is String
            ? nameValue
            : (nameValue != null ? nameValue.toString() : '');
        final descriptionValue = playlistData['description'];
        final descriptionString = descriptionValue is String
            ? descriptionValue
            : (descriptionValue != null ? descriptionValue.toString() : '');
        return PlaylistDto(
          id: playlistData['id'] != null ? playlistData['id'] as int : 0,
          name: nameString,
          description: descriptionString,
          coverImageUri: playlistData['coverImageUri'] as String?,
          tracks: tracksJson.map((t) {
            final trackData = t as Map<String, dynamic>;
            return TrackDto(
              trackId: trackData['trackId'] as int,
              trackName: trackData['trackName'] as String?,
              artistName: trackData['artistName'] as String?,
              trackTimeMillis: trackData['trackTimeMillis'] as int?,
              previewUrl: trackData['previewUrl'] as String?,
              artworkUrl100: trackData['artworkUrl100'] as String?,
            );
          }).toList(),
        );
      }).toList();

      // Сохраняем плейлисты локально
      await _localStorage.savePlaylists(playlists);

      debugPrint('[DownloadService] Загружено плейлистов: ${playlists.length}');

      return {
        'success': true,
        'message': 'Загружено плейлистов: ${playlists.length}',
        'count': playlists.length,
      };
    } catch (e) {
      debugPrint('[DownloadService] Ошибка загрузки плейлистов: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Скачивает файл трека с сервера в локальное хранилище
  static Future<void> _downloadTrackFile(TrackDto track) async {
    if (track.previewUrl == null || track.previewUrl!.isEmpty) {
      throw Exception('URL для скачивания недоступен');
    }

    // Проверяем разрешение на запись
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        final audioStatus = await Permission.audio.request();
        if (!audioStatus.isGranted) {
          throw Exception('Необходимо разрешение на доступ к хранилищу');
        }
      }
    }

    // Получаем директорию для сохранения
    final directory = await _getDownloadDirectory();

    // Формируем имя файла в формате "Artist - Track Name.ext"
    // Это соответствует формату, который ожидает DownloadedTracksRepositoryImpl
    final sanitizedTitle =
        _sanitizeFileName(track.trackName ?? 'Unknown Track');
    final sanitizedArtist =
        _sanitizeFileName(track.artistName ?? 'Unknown Artist');

    // Определяем расширение файла из URL или используем m4a по умолчанию
    String extension = 'm4a';
    if (track.previewUrl != null) {
      final urlLower = track.previewUrl!.toLowerCase();
      if (urlLower.contains('.mp3')) {
        extension = 'mp3';
      } else if (urlLower.contains('.m4a')) {
        extension = 'm4a';
      } else if (urlLower.contains('.mp4')) {
        extension = 'mp4';
      } else if (urlLower.contains('.wav')) {
        extension = 'wav';
      } else if (urlLower.contains('.flac')) {
        extension = 'flac';
      }
    }

    final fileName = '$sanitizedArtist - $sanitizedTitle.$extension';
    final filePath = '${directory.path}/$fileName';

    debugPrint('[DownloadService] 📥 Скачивание в: $filePath');

    // Проверяем, существует ли файл
    final file = File(filePath);
    if (await file.exists()) {
      debugPrint(
          '[DownloadService] ⏭️ Файл уже существует, пропуск: $filePath');
      return;
    }

    // Получаем токен для авторизации
    final token = await TracksApi.getAccessToken();
    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    // Скачиваем файл
    debugPrint('[DownloadService] Скачивание: ${track.previewUrl}');
    final response = await http
        .get(
          Uri.parse(track.previewUrl!),
          headers: headers,
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
      debugPrint('[DownloadService] Файл скачан: $filePath');
    } else {
      throw Exception('Ошибка скачивания: ${response.statusCode}');
    }
  }

  /// Получение директории для скачивания
  /// ВАЖНО: Должен использовать тот же путь, что и NetworkRepository
  static Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // ПРИОРИТЕТ 1: Используем путь, где реально скачиваются файлы
      // Это путь, который использует NetworkRepository
      try {
        final directory = Directory('/storage/emulated/0/Download/MuMuSIC');
        if (await directory.exists()) {
          debugPrint(
              '[DownloadService] ✅ Используется путь скачивания: ${directory.path}');
          return directory;
        }
        // Если директория не существует, пытаемся создать
        if (await _canCreateDirectory(directory)) {
          debugPrint(
              '[DownloadService] ✅ Создана директория скачивания: ${directory.path}');
          return directory;
        }
      } catch (e) {
        debugPrint('[DownloadService] ⚠️ Ошибка пути скачивания: $e');
      }

      // ПРИОРИТЕТ 2: Fallback на директорию приложения (если основной путь недоступен)
      try {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final downloadDir = Directory('${directory.path}/Downloads/MuMuSIC');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
          debugPrint(
              '[DownloadService] ✅ Используется fallback путь: ${downloadDir.path}');
          return downloadDir;
        }
      } catch (e) {
        debugPrint(
            '[DownloadService] ⚠️ Ошибка получения fallback директории: $e');
      }

      // ПРИОРИТЕТ 3: Последний fallback - директория приложения
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads/MuMuSIC');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      debugPrint(
          '[DownloadService] ✅ Используется директория приложения: ${downloadDir.path}');
      return downloadDir;
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    }
  }

  /// Проверка возможности создания директории
  static Future<bool> _canCreateDirectory(Directory directory) async {
    try {
      await directory.create(recursive: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Очистка имени файла от недопустимых символов
  static String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
