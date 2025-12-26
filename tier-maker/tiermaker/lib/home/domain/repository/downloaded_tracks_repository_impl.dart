import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../model/downloaded_track_model.dart';
import 'i_downloaded_tracks_repository.dart';

/// Реализация репозитория для работы со скачанными треками
class DownloadedTracksRepositoryImpl implements IDownloadedTracksRepository {
  /// Получить директорию для скачанных треков
  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      try {
        // Пытаемся использовать стандартную директорию Downloads
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          // Используем поддиректорию Downloads в приложении
          final downloadDir = Directory('${directory.path}/Downloads/MuMuSIC');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
          debugPrint(
              '✅ [DownloadedTracksRepository] Используется путь: ${downloadDir.path}');
          return downloadDir;
        }
      } catch (e) {
        debugPrint(
            '⚠️ [DownloadedTracksRepository] Ошибка получения стандартной директории: $e');
      }

      // Fallback: пытаемся использовать старый путь
      try {
        final directory = Directory('/storage/emulated/0/Download/MuMuSIC');
        if (await directory.exists() || await _canCreateDirectory(directory)) {
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
          debugPrint(
              '✅ [DownloadedTracksRepository] Используется fallback путь: ${directory.path}');
          return directory;
        }
      } catch (e) {
        debugPrint('⚠️ [DownloadedTracksRepository] Ошибка fallback пути: $e');
      }

      // Последний fallback: используем директорию приложения
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads/MuMuSIC');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      debugPrint(
          '✅ [DownloadedTracksRepository] Используется директория приложения: ${downloadDir.path}');
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
  Future<bool> _canCreateDirectory(Directory directory) async {
    try {
      await directory.create(recursive: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Парсинг имени файла для извлечения информации о треке
  DownloadedTrack _parseTrackFromFile(File file) {
    final fileName = file.path.split('/').last;
    final nameWithoutExt =
        fileName.replaceAll(RegExp(r'\.(m4a|mp3|mp4|aac)$'), '');

    // Формат: "Artist - Track Name"
    String trackName = nameWithoutExt;
    String artistName = 'Неизвестный исполнитель';

    if (nameWithoutExt.contains(' - ')) {
      final parts = nameWithoutExt.split(' - ');
      if (parts.length >= 2) {
        artistName = parts[0].trim();
        trackName = parts.sublist(1).join(' - ').trim();
      }
    }

    return DownloadedTrack(
      filePath: file.path,
      fileName: fileName,
      trackName: trackName,
      artistName: artistName,
      dateAdded: file.lastModifiedSync(),
    );
  }

  @override
  Future<List<DownloadedTrack>> getDownloadedTracks() async {
    try {
      final directory = await _getDownloadDirectory();
      debugPrint(
          '📁 [DownloadedTracksRepository] Проверка директории: ${directory.path}');

      if (!await directory.exists()) {
        debugPrint(
            '⚠️ [DownloadedTracksRepository] Директория не существует, создание...');
        try {
          await directory.create(recursive: true);
          debugPrint('✅ [DownloadedTracksRepository] Директория создана');
        } catch (e) {
          debugPrint(
              '❌ [DownloadedTracksRepository] Не удалось создать директорию: $e');
          return [];
        }
      }

      debugPrint(
          '📂 [DownloadedTracksRepository] Чтение файлов из директории...');
      List<FileSystemEntity> entities;
      try {
        entities = directory.listSync(recursive: false);
        debugPrint(
            '📄 [DownloadedTracksRepository] Найдено элементов: ${entities.length}');
      } catch (e) {
        debugPrint(
            '❌ [DownloadedTracksRepository] Ошибка чтения директории: $e');
        return [];
      }

      final files = entities.whereType<File>().where((file) {
        final ext = file.path.toLowerCase();
        final isAudioFile = ext.endsWith('.m4a') ||
            ext.endsWith('.mp3') ||
            ext.endsWith('.mp4') ||
            ext.endsWith('.aac') ||
            ext.endsWith('.wav') ||
            ext.endsWith('.flac');
        if (isAudioFile) {
          debugPrint(
              '🎵 [DownloadedTracksRepository] Найден аудио файл: ${file.path}');
        }
        return isAudioFile;
      }).toList();

      debugPrint(
          '🎵 [DownloadedTracksRepository] Найдено аудио файлов: ${files.length}');

      final tracks = files
          .map((file) {
            try {
              return _parseTrackFromFile(file);
            } catch (e) {
              debugPrint(
                  '⚠️ [DownloadedTracksRepository] Ошибка парсинга файла ${file.path}: $e');
              return null;
            }
          })
          .whereType<DownloadedTrack>()
          .toList();

      // Сортируем по дате добавления (новые первыми)
      tracks.sort((a, b) {
        final dateA = a.dateAdded ?? DateTime(1970);
        final dateB = b.dateAdded ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });

      debugPrint(
          '✅ [DownloadedTracksRepository] Найдено скачанных треков: ${tracks.length}');
      if (tracks.isEmpty) {
        debugPrint(
            'ℹ️ [DownloadedTracksRepository] Список треков пуст. Проверьте путь: ${directory.path}');
      }
      return tracks;
    } catch (e, stackTrace) {
      debugPrint(
          '❌ [DownloadedTracksRepository] Критическая ошибка получения треков: $e');
      debugPrint('❌ [DownloadedTracksRepository] Stack trace: $stackTrace');
      return [];
    }
  }

  @override
  Future<void> deleteDownloadedTrack(DownloadedTrack track) async {
    try {
      final file = File(track.filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint(
            '✅ [DownloadedTracksRepository] Трек удален: ${track.filePath}');
      }
    } catch (e) {
      debugPrint('❌ [DownloadedTracksRepository] Ошибка удаления трека: $e');
      rethrow;
    }
  }
}
