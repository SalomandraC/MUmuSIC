import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:mumusic/core/app_database/track_metadata_store.dart';
import 'package:mumusic/core/services/file_delete_service.dart';
import '../model/downloaded_track_model.dart';
import 'i_downloaded_tracks_repository.dart';

/// Реализация репозитория для работы со скачанными треками
class DownloadedTracksRepositoryImpl implements IDownloadedTracksRepository {
  /// Получить директорию для скачанных треков
  /// ВАЖНО: Должен использовать тот же путь, что и NetworkRepository и DownloadService
  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // ПРИОРИТЕТ 1: Используем путь, где реально скачиваются файлы
      // Это путь, который использует NetworkRepository
      try {
        final directory = Directory('/storage/emulated/0/Download/MuMuSIC');
        if (await directory.exists()) {
          debugPrint(
              '✅ [DownloadedTracksRepository] Используется путь скачивания: ${directory.path}');
          return directory;
        }
        // Если директория не существует, пытаемся создать
        if (await _canCreateDirectory(directory)) {
          debugPrint(
              '✅ [DownloadedTracksRepository] Создана директория скачивания: ${directory.path}');
          return directory;
        }
      } catch (e) {
        debugPrint(
            '⚠️ [DownloadedTracksRepository] Ошибка пути скачивания: $e');
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
              '✅ [DownloadedTracksRepository] Используется fallback путь: ${downloadDir.path}');
          return downloadDir;
        }
      } catch (e) {
        debugPrint(
            '⚠️ [DownloadedTracksRepository] Ошибка получения fallback директории: $e');
      }

      // ПРИОРИТЕТ 3: Последний fallback - директория приложения
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
    // Удаляем все поддерживаемые расширения аудио файлов
    final nameWithoutExt = fileName.replaceAll(
        RegExp(r'\.(m4a|mp3|mp4|aac|wav|flac)$', caseSensitive: false), '');

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

    debugPrint(
        '📝 [DownloadedTracksRepository] Парсинг файла: $fileName -> "$artistName - $trackName"');

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

        // Логируем все найденные элементы для диагностики
        for (var entity in entities) {
          if (entity is File) {
            debugPrint('  📄 Файл: ${entity.path.split('/').last}');
          } else if (entity is Directory) {
            debugPrint('  📁 Директория: ${entity.path.split('/').last}');
          }
        }
      } catch (e) {
        debugPrint(
            '❌ [DownloadedTracksRepository] Ошибка чтения директории: $e');
        return [];
      }

      // Фильтруем файлы по расширению
      final potentialFiles = entities.whereType<File>().where((file) {
        final ext = file.path.toLowerCase();
        return ext.endsWith('.m4a') ||
            ext.endsWith('.mp3') ||
            ext.endsWith('.mp4') ||
            ext.endsWith('.aac') ||
            ext.endsWith('.wav') ||
            ext.endsWith('.flac');
      }).toList();

      debugPrint(
          '🎵 [DownloadedTracksRepository] Найдено потенциальных аудио файлов: ${potentialFiles.length}');

      // Проверяем существование и доступность файлов
      final files = <File>[];
      for (final file in potentialFiles) {
        try {
          if (await file.exists()) {
            final size = await file.length();
            debugPrint(
                '✅ [DownloadedTracksRepository] Аудио файл подтвержден: ${file.path.split('/').last} (размер: $size байт)');
            files.add(file);
          } else {
            debugPrint(
                '⚠️ [DownloadedTracksRepository] Файл не существует: ${file.path}');
          }
        } catch (e) {
          debugPrint(
              '❌ [DownloadedTracksRepository] Ошибка проверки файла ${file.path}: $e');
        }
      }

      debugPrint(
          '🎵 [DownloadedTracksRepository] Найдено аудио файлов: ${files.length}');

      final parsed = files
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

      // Применяем пользовательские название и подпись
      final tracks = <DownloadedTrack>[];
      for (final t in parsed) {
        final meta = await TrackMetadataStore.get('file:${t.filePath}');
        tracks.add(meta == null
            ? t
            : DownloadedTrack(
                filePath: t.filePath,
                fileName: t.fileName,
                trackName: (meta.title?.isNotEmpty ?? false)
                    ? meta.title!
                    : t.trackName,
                artistName: (meta.artist?.isNotEmpty ?? false)
                    ? meta.artist!
                    : t.artistName,
                durationMillis: t.durationMillis,
                dateAdded: t.dateAdded,
              ));
      }

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
      // Если файла уже нет, просто убираем трек из списка без ошибки
      await FileDeleteService.delete(track.filePath);
      await TrackMetadataStore.remove('file:${track.filePath}');
      debugPrint(
          '✅ [DownloadedTracksRepository] Трек удален: ${track.filePath}');
    } catch (e) {
      debugPrint('❌ [DownloadedTracksRepository] Ошибка удаления трека: $e');
      rethrow;
    }
  }

  /// Папка «Загрузки» телефона (Android)
  static const String _publicDownloadsPath = '/storage/emulated/0/Download';

  /// Те же форматы, что отображаются во внутреннем хранилище
  static final RegExp _audioExtRegExp =
      RegExp(r'\.(m4a|mp3|mp4|aac|wav|flac)$', caseSensitive: false);

  bool _isAudioFile(String path) => _audioExtRegExp.hasMatch(path);

  /// Обход папки с ограничением глубины. Ошибки доступа к отдельным
  /// подпапкам пропускаются, чтобы не прерывать весь поиск
  Future<void> _collectAudioFiles(
    Directory dir,
    String excludePath,
    List<File> result, {
    int depth = 0,
    int maxDepth = 2,
  }) async {
    List<FileSystemEntity> entities;
    try {
      entities = await dir.list(followLinks: false).toList();
    } catch (e) {
      debugPrint(
          '⚠️ [DownloadedTracksRepository] Нет доступа к ${dir.path}: $e');
      return;
    }
    for (final entity in entities) {
      if (entity is File && _isAudioFile(entity.path)) {
        result.add(entity);
      } else if (entity is Directory &&
          depth < maxDepth &&
          entity.path != excludePath) {
        await _collectAudioFiles(entity, excludePath, result,
            depth: depth + 1, maxDepth: maxDepth);
      }
    }
  }

  @override
  Future<List<DownloadedTrack>> getImportableTracks() async {
    if (!Platform.isAndroid) return [];

    final downloads = Directory(_publicDownloadsPath);
    if (!await downloads.exists()) {
      debugPrint(
          '⚠️ [DownloadedTracksRepository] Папка загрузок не найдена: $_publicDownloadsPath');
      return [];
    }

    final targetDir = await _getDownloadDirectory();
    final existingNames = <String>{};
    try {
      await for (final entity in targetDir.list(followLinks: false)) {
        if (entity is File) {
          existingNames.add(entity.path.split('/').last.toLowerCase());
        }
      }
    } catch (_) {}

    final files = <File>[];
    await _collectAudioFiles(downloads, targetDir.path, files);

    final tracks = files
        .where((f) =>
            !existingNames.contains(f.path.split('/').last.toLowerCase()))
        .map((f) {
          try {
            return _parseTrackFromFile(f);
          } catch (_) {
            return null;
          }
        })
        .whereType<DownloadedTrack>()
        .toList();

    tracks.sort((a, b) =>
        a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()));
    debugPrint(
        '📥 [DownloadedTracksRepository] Доступно для импорта: ${tracks.length}');
    return tracks;
  }

  @override
  Future<int> importTracks(List<DownloadedTrack> tracks) async {
    final targetDir = await _getDownloadDirectory();
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    int imported = 0;
    for (final track in tracks) {
      try {
        final source = File(track.filePath);
        if (!await source.exists()) continue;

        // Если файл с таким именем уже есть, добавляем суффикс (1), (2)...
        final dot = track.fileName.lastIndexOf('.');
        final base = dot > 0 ? track.fileName.substring(0, dot) : track.fileName;
        final ext = dot > 0 ? track.fileName.substring(dot) : '';
        var target = File('${targetDir.path}/${track.fileName}');
        var n = 1;
        while (await target.exists()) {
          target = File('${targetDir.path}/$base ($n)$ext');
          n++;
        }

        await source.copy(target.path);
        imported++;
        debugPrint(
            '✅ [DownloadedTracksRepository] Импортирован: ${track.fileName}');
      } catch (e) {
        debugPrint(
            '❌ [DownloadedTracksRepository] Ошибка импорта ${track.fileName}: $e');
      }
    }
    return imported;
  }
}
