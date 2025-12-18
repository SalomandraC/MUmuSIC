import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../app_database/app_database.dart';
import '../config/env_config.dart';

class TracksApi {
  static String? _cachedBaseUrl;

  static Future<String> getBaseUrl() async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;

    final savedUrl = await AppDatabase.getApiBaseUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _cachedBaseUrl = savedUrl;
      return savedUrl;
    }

    final defaultUrl = EnvConfig.getApiBaseUrl();
    _cachedBaseUrl = defaultUrl;
    return defaultUrl;
  }

  static Future<String?> getAccessToken() async {
    return await AppDatabase.getAccessToken();
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await getAccessToken();
    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> uploadTrack({
    required File file,
    required String title,
    String? artist,
    String? album,
    int? duration,
    String? notes,
    bool isPublic = false,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = '$baseUrl/tracks';
      final headers = await _getHeaders();

      debugPrint('[TracksApi] Загрузка трека: $url');

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll(headers);

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      request.fields['title'] = title;
      if (artist != null && artist.isNotEmpty) {
        request.fields['artist'] = artist;
      }
      if (album != null && album.isNotEmpty) {
        request.fields['album'] = album;
      }
      if (duration != null) {
        request.fields['duration'] = duration.toString();
      }
      if (notes != null && notes.isNotEmpty) {
        request.fields['notes'] = notes;
      }
      request.fields['is_public'] = isPublic.toString();

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 60),
          );

      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('[TracksApi] Статус ответа: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data};
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>?;
        final errorMessage = errorData?['error'] as String? ??
            errorData?['message'] as String? ??
            'Ошибка загрузки трека: ${response.statusCode}';
        return {
          'success': false,
          'error': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('[TracksApi] Ошибка загрузки трека: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getUserTracks() async {
    try {
      final baseUrl = await getBaseUrl();
      final url = '$baseUrl/tracks';
      final headers = await _getHeaders();

      debugPrint('[TracksApi] Получение треков: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('[TracksApi] Статус ответа: ${response.statusCode}');
      debugPrint(
          '[TracksApi] Тело ответа (первые 500 символов): ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        debugPrint(
            '[TracksApi] Данные получены: keys=${data.keys}, tracks count=${(data['tracks'] as List?)?.length ?? 0}');
        return {'success': true, 'data': data};
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>?;
        final errorMessage = errorData?['error'] as String? ??
            'Ошибка получения треков: ${response.statusCode}';
        debugPrint('[TracksApi] Ошибка: $errorMessage');
        return {
          'success': false,
          'error': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('[TracksApi] Ошибка получения треков: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
