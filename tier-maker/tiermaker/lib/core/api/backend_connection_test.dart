import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Сервис для проверки подключения к бэкенду
class BackendConnectionTest {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://192.168.31.200:5050';
    }
    
    if (Platform.isAndroid) {
      return 'http://192.168.31.200:5050';
    }
    return 'http://192.168.31.200:5050';
  }

  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final url = '$baseUrl/health';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'status': response.statusCode,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'status': response.statusCode,
          'error': 'Неожиданный статус: ${response.statusCode}',
        };
      }
    } on SocketException catch (e) {
      return {
        'success': false,
        'error': 'Не удалось подключиться к серверу',
        'details': e.message,
        'hint': _getConnectionHint(),
      };
    } on TimeoutException catch (e) {
      return {
        'success': false,
        'error': 'Превышено время ожидания',
        'details': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Ошибка при проверке подключения',
        'details': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> checkGuestTracksHealth() async {
    try {
      final url = '$baseUrl/guest-tracks/health';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'status': response.statusCode,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'status': response.statusCode,
          'error': 'Неожиданный статус: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Ошибка при проверке файлового сервера',
        'details': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> getGuestTracks() async {
    try {
      final url = '$baseUrl/guest-tracks';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> tracks = json.decode(response.body) as List<dynamic>;
        return {
          'success': true,
          'status': response.statusCode,
          'count': tracks.length,
          'data': tracks,
        };
      } else {
        return {
          'success': false,
          'status': response.statusCode,
          'error': 'Неожиданный статус: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Ошибка при получении треков',
        'details': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> checkDatabase() async {
    try {
      final url = '$baseUrl/debug/tracks';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> tracks = json.decode(response.body) as List<dynamic>;
        return {
          'success': true,
          'status': response.statusCode,
          'count': tracks.length,
          'data': tracks,
        };
      } else {
        return {
          'success': false,
          'status': response.statusCode,
          'error': 'Неожиданный статус: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Ошибка при проверке БД',
        'details': e.toString(),
      };
    }
  }

  static String _getConnectionHint() {
    if (Platform.isAndroid && baseUrl.contains('10.0.2.2')) {
      return 'Вы используете реальное Android устройство.\n'
          'Измените baseUrl на IP адрес вашего компьютера.\n'
          'Пример: http://192.168.1.100:5050';
    } else if (baseUrl.contains('localhost')) {
      return 'Проверьте, что сервер запущен на $baseUrl\n'
          'Запустите: cd backend && npm run dev';
    }
    return 'Проверьте настройки подключения';
  }
}

