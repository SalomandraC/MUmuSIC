import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ITunesTrack {
  final int? trackId;
  final String trackName;
  final String artistName;
  final int? trackTimeMillis;
  final String? previewUrl;
  final String? artworkUrl100;

  ITunesTrack({
    this.trackId,
    required this.trackName,
    required this.artistName,
    this.trackTimeMillis,
    this.previewUrl,
    this.artworkUrl100,
  });

  factory ITunesTrack.fromJson(Map<String, dynamic> json) {
    return ITunesTrack(
      trackId: json['trackId'] as int?,
      trackName: json['trackName'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      trackTimeMillis: json['trackTimeMillis'] as int?,
      previewUrl: json['previewUrl'] as String?,
      artworkUrl100: json['artworkUrl100'] as String?,
    );
  }

  String get formattedDuration {
    if (trackTimeMillis == null) return '0:00';
    final seconds = (trackTimeMillis! / 1000).round();
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

class ITunesSearchResponse {
  final int resultCount;
  final List<ITunesTrack> results;

  ITunesSearchResponse({
    required this.resultCount,
    required this.results,
  });

  factory ITunesSearchResponse.fromJson(Map<String, dynamic> json) {
    final resultsList = json['results'] as List<dynamic>? ?? [];
    return ITunesSearchResponse(
      resultCount: json['resultCount'] as int? ?? 0,
      results: resultsList
          .map((item) => ITunesTrack.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ITunesApi {
  static const String baseUrl = 'https://itunes.apple.com';

  /// Поиск треков через iTunes API
  ///
  /// [query] - поисковый запрос
  /// [limit] - максимальное количество результатов (по умолчанию 50)
  static Future<List<ITunesTrack>> searchTracks({
    required String query,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url =
          '$baseUrl/search?term=$encodedQuery&media=music&entity=song&limit=$limit';

      debugPrint('🔍 [ITunesApi] Поиск треков: $query');
      debugPrint('🔗 [ITunesApi] URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Превышено время ожидания ответа от iTunes API');
        },
      );

      debugPrint('📡 [ITunesApi] Статус ответа: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final searchResponse = ITunesSearchResponse.fromJson(jsonData);

        debugPrint(
            '✅ [ITunesApi] Найдено треков: ${searchResponse.resultCount}');

        return searchResponse.results;
      } else {
        debugPrint('❌ [ITunesApi] Ошибка: ${response.statusCode}');
        debugPrint('📦 [ITunesApi] Тело ответа: ${response.body}');
        throw Exception('Ошибка поиска треков: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [ITunesApi] Ошибка при поиске: $e');
      rethrow;
    }
  }
}
