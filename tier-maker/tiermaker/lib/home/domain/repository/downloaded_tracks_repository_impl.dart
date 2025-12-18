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

  /// Парсинг имени файла для извлечения информации о треке
  DownloadedTrack _parseTrackFromFile(File file) {
    final fileName = file.path.split('/').last;
    final nameWithoutExt = fileName.replaceAll(RegExp(r'\.(m4a|mp3|mp4|aac)$'), '');
    
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
      final files = directory.listSync()
          .whereType<File>()
          .where((file) {
            final ext = file.path.toLowerCase();
            return ext.endsWith('.m4a') || 
                   ext.endsWith('.mp3') || 
                   ext.endsWith('.mp4') || 
                   ext.endsWith('.aac');
          })
          .toList();

      final tracks = files.map((file) => _parseTrackFromFile(file)).toList();
      
      // Сортируем по дате добавления (новые первыми)
      tracks.sort((a, b) {
        final dateA = a.dateAdded ?? DateTime(1970);
        final dateB = b.dateAdded ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });

      debugPrint('✅ [DownloadedTracksRepository] Найдено скачанных треков: ${tracks.length}');
      return tracks;
    } catch (e) {
      debugPrint('❌ [DownloadedTracksRepository] Ошибка получения треков: $e');
      return [];
    }
  }

  @override
  Future<void> deleteDownloadedTrack(DownloadedTrack track) async {
    try {
      final file = File(track.filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ [DownloadedTracksRepository] Трек удален: ${track.filePath}');
      }
    } catch (e) {
      debugPrint('❌ [DownloadedTracksRepository] Ошибка удаления трека: $e');
      rethrow;
    }
  }
}

