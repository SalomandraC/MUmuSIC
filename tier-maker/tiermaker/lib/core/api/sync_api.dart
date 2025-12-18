import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../app_database/app_database.dart';
import '../config/env_config.dart';
import '../../data/models/playlist_dto.dart';

class SyncApi {
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
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> downloadData() async {
    try {
      final baseUrl = await getBaseUrl();
      final url = '$baseUrl/sync/data';
      final headers = await _getHeaders();

      debugPrint('[SyncApi] Загрузка данных: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': 'Ошибка загрузки: ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('[SyncApi] Ошибка загрузки: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> uploadData({
    required List<PlaylistDto> playlists,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = '$baseUrl/sync/upload';
      final headers = await _getHeaders();

      final body = {
        'playlists': playlists.map((p) => p.toJson()).toList(),
      };

      debugPrint('[SyncApi] Отправка данных: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': 'Ошибка отправки: ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('[SyncApi] Ошибка отправки: $e');
      return {'success': false, 'error': e.toString()};
    }
  }


  static Future<Map<String, dynamic>> uploadPlaylists(List<PlaylistDto> playlists) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = '$baseUrl/sync/playlists';
      final headers = await _getHeaders();

      final body = playlists.map((p) => p.toJson()).toList();

      debugPrint('[SyncApi] Отправка плейлистов: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': 'Ошибка отправки плейлистов: ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('[SyncApi] Ошибка отправки плейлистов: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}

