import 'dart:io';
import 'package:flutter/foundation.dart';
import '../api/tracks_api.dart';
import '../api/sync_api.dart';
import '../../data/datasources/local/local_storage_datasource.dart';
import '../../home/domain/model/downloaded_track_model.dart';

class UploadService {
  static final LocalStorageDataSource _localStorage = LocalStorageDataSourceImpl();

  static Future<Map<String, dynamic>> uploadDownloadedTrack(DownloadedTrack track) async {
    try {
      final file = File(track.filePath);
      if (!await file.exists()) {
        return {'success': false, 'error': 'Файл не найден'};
      }

      final duration = track.durationMillis != null 
          ? (track.durationMillis! / 1000).round() 
          : null;

      final result = await TracksApi.uploadTrack(
        file: file,
        title: track.trackName,
        artist: track.artistName,
        duration: duration,
      );

      return result;
    } catch (e) {
      debugPrint('[UploadService] Ошибка загрузки трека: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> uploadAllDownloadedTracks(
    List<DownloadedTrack> tracks,
    Function(int current, int total)? onProgress,
  ) async {
    int successCount = 0;
    int failCount = 0;
    final errors = <String>[];

    for (int i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      onProgress?.call(i + 1, tracks.length);

      final result = await uploadDownloadedTrack(track);
      if (result['success'] == true) {
        successCount++;
      } else {
        failCount++;
        errors.add('${track.trackName}: ${result['error']}');
      }
    }

    return {
      'success': failCount == 0,
      'successCount': successCount,
      'failCount': failCount,
      'errors': errors,
    };
  }


  static Future<Map<String, dynamic>> uploadPlaylists() async {
    try {
      final playlists = await _localStorage.getPlaylists();
      if (playlists.isEmpty) {
        return {'success': true, 'message': 'Нет плейлистов для загрузки'};
      }

      final result = await SyncApi.uploadPlaylists(playlists);
      return result;
    } catch (e) {
      debugPrint('[UploadService] Ошибка загрузки плейлистов: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> uploadAllData({
    required List<DownloadedTrack> tracks,
    Function(String step)? onStep,
    Function(int current, int total)? onProgress,
  }) async {
    final results = <String, dynamic>{};

    // Загрузка треков
    onStep?.call('Загрузка треков...');
    final tracksResult = await uploadAllDownloadedTracks(tracks, onProgress);
    results['tracks'] = tracksResult;

    // Загрузка плейлистов
    onStep?.call('Загрузка плейлистов...');
    final playlistsResult = await uploadPlaylists();
    results['playlists'] = playlistsResult;

    final allSuccess = tracksResult['success'] == true &&
                      playlistsResult['success'] == true;

    return {
      'success': allSuccess,
      'results': results,
    };
  }
}

