import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../app_database/app_database.dart';
import '../config/env_config.dart';

class AuthApi {
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

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = '$baseUrl/auth/register';

      debugPrint('[AuthApi] Регистрация: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('[AuthApi] Статус ответа: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data};
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>?;
        final errorMessage = errorData?['error'] as String? ?? 
                           errorData?['message'] as String? ?? 
                           'Ошибка регистрации: ${response.statusCode}';
        return {
          'success': false,
          'error': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('[AuthApi] Ошибка регистрации: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = '$baseUrl/auth/login';

      debugPrint('[AuthApi] Вход: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('[AuthApi] Статус ответа: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data};
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>?;
        final errorMessage = errorData?['error'] as String? ?? 
                           errorData?['message'] as String? ?? 
                           'Ошибка входа: ${response.statusCode}';
        return {
          'success': false,
          'error': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('[AuthApi] Ошибка входа: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getMe(String accessToken) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = '$baseUrl/auth/me';

      debugPrint('[AuthApi] Получение профиля: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('[AuthApi] Статус ответа: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': 'Ошибка получения профиля: ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('[AuthApi] Ошибка получения профиля: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = '$baseUrl/auth/refresh-token';

      debugPrint('[AuthApi] Обновление токена: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'refreshToken': refreshToken,
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('[AuthApi] Статус ответа: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': 'Ошибка обновления токена: ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('[AuthApi] Ошибка обновления токена: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}

