import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/track.dart';

class ITunesApi {
  static const String baseUrl = 'https://itunes.apple.com';

  /// Поиск треков в iTunes
  static Future<List<Track>> searchTracks({
    required String query,
    int limit = 50,
  }) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$baseUrl/search?term=$encodedQuery&media=music&entity=song&limit=$limit';

      debugPrint('[ITunesApi] Поиск треков: $url');

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
            .map((json) => Track.fromJson(json as Map<String, dynamic>))
            .toList();

        debugPrint('[ITunesApi] Найдено треков: ${tracks.length}');
        return tracks;
      } else {
        debugPrint('[ITunesApi] Ошибка: ${response.statusCode}');
        throw Exception('Ошибка поиска треков: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ITunesApi] Ошибка поиска: $e');
      rethrow;
    }
  }
}
