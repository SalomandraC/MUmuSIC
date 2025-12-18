import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../models/track_dto.dart';

/// Удаленный источник данных для iTunes API
abstract class ITunesRemoteDataSource {
  Future<List<TrackDto>> searchTracks(String query, {int limit = 50});
}

class ITunesRemoteDataSourceImpl implements ITunesRemoteDataSource {
  static const String baseUrl = 'https://itunes.apple.com';

  @override
  Future<List<TrackDto>> searchTracks(String query, {int limit = 50}) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$baseUrl/search?term=$encodedQuery&media=music&entity=song&limit=$limit';

      debugPrint('🔵 [ITunesRemoteDataSource] Поиск треков: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Превышено время ожидания ответа от сервера');
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final results = jsonData['results'] as List<dynamic>? ?? [];

        final tracks = results
            .map((json) => TrackDto.fromJson(json as Map<String, dynamic>))
            .toList();

        debugPrint('✅ [ITunesRemoteDataSource] Найдено треков: ${tracks.length}');
        return tracks;
      } else {
        debugPrint('❌ [ITunesRemoteDataSource] Ошибка: ${response.statusCode}');
        throw Exception('Ошибка поиска треков: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [ITunesRemoteDataSource] Ошибка поиска: $e');
      rethrow;
    }
  }
}

