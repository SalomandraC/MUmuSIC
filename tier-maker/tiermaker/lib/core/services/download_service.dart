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
      debugPrint('[DownloadService] Начало загрузки треков с сервера...');
      final result = await TracksApi.getUserTracks();

      debugPrint(
          '[DownloadService] Результат API: success=${result['success']}, error=${result['error']}');

      if (result['success'] != true) {
        debugPrint(
            '[DownloadService] Ошибка получения треков: ${result['error']}');
        return result;
      }

      final data = result['data'] as Map<String, dynamic>?;
      if (data == null) {
        debugPrint('[DownloadService] Данные отсутствуют в ответе');
        return {
          'success': false,
          'error': 'Данные отсутствуют в ответе сервера'
        };
      }

      debugPrint('[DownloadService] Данные получены: ${data.keys}');
      final tracksJson = data['tracks'] as List<dynamic>?;

      if (tracksJson == null || tracksJson.isEmpty) {
        debugPrint('[DownloadService] Треки отсутствуют на сервере');
        return {'success': true, 'message': 'Нет треков на сервере'};
      }

      debugPrint('[DownloadService] Получено треков: ${tracksJson.length}');

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
            debugPrint('[DownloadService] Скачан трек: ${track.trackName}');
          } catch (e) {
            failedCount++;
            debugPrint(
                '[DownloadService] Ошибка скачивания трека ${track.trackName}: $e');
          }
        }
      }

      debugPrint(
          '[DownloadService] Скачано файлов: $downloadedCount, ошибок: $failedCount');

      // Получаем существующие избранные треки
      debugPrint('[DownloadService] Загрузка существующих избранных треков...');
      final existingFavorites = await _localStorage.getFavorites();
      debugPrint(
          '[DownloadService] Существующих избранных: ${existingFavorites.length}');

      // Объединяем треки, избегая дубликатов (по trackId)
      final existingTrackIds = existingFavorites.map((t) => t.trackId).toSet();
      final newTracks =
          tracks.where((t) => !existingTrackIds.contains(t.trackId)).toList();
      debugPrint('[DownloadService] Новых треков: ${newTracks.length}');

      // Сохраняем все треки (существующие + новые) в избранное
      final allTracks = [...existingFavorites, ...newTracks];
      debugPrint(
          '[DownloadService] Сохранение ${allTracks.length} треков в избранное...');
      await _localStorage.saveFavorites(allTracks);
      debugPrint('[DownloadService] Треки успешно сохранены в избранное');

      debugPrint(
          '[DownloadService] Итого загружено треков: ${tracks.length} (новых: ${newTracks.length})');

      return {
        'success': true,
        'message':
            'Загружено треков: ${tracks.length} (новых: ${newTracks.length})',
        'count': tracks.length,
        'newCount': newTracks.length,
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

    // Формируем имя файла
    final sanitizedTitle =
        _sanitizeFileName(track.trackName ?? 'Unknown Track');
    final sanitizedArtist =
        _sanitizeFileName(track.artistName ?? 'Unknown Artist');
    final fileName = '$sanitizedArtist - $sanitizedTitle.m4a';
    final filePath = '${directory.path}/$fileName';

    // Проверяем, существует ли файл
    final file = File(filePath);
    if (await file.exists()) {
      debugPrint('[DownloadService] Файл уже существует: $filePath');
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
  static Future<Directory> _getDownloadDirectory() async {
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
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
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
