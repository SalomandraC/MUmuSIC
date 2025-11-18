import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:RandomTierList/core/app_database/app_database.dart';

class GuestTrack {
  final int id;
  final String title;
  final String artist;
  final String filePath;
  final String fileFormat;
  final int duration;
  final String fileSize;
  final bool isActive;
  final int playCount;
  final DateTime createdAt;
  final String url;
  final String streamUrl;

  GuestTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    required this.fileFormat,
    required this.duration,
    required this.fileSize,
    required this.isActive,
    required this.playCount,
    required this.createdAt,
    required this.url,
    required this.streamUrl,
  });

  factory GuestTrack.fromJson(Map<String, dynamic> json) {
    return GuestTrack(
      id: json['id'] as int,
      title: json['title'] as String,
      artist: json['artist'] as String,
      filePath: json['file_path'] as String,
      fileFormat: json['file_format'] as String,
      duration: json['duration'] as int,
      fileSize: json['file_size'] as String,
      isActive: json['is_active'] as bool,
      playCount: json['play_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      url: json['url'] as String,
      streamUrl: json['streamUrl'] as String,
    );
  }
}

class GuestTracksApi {
  static String? _cachedBaseUrl;
  static Future<String> getBaseUrl() async {
    if (_cachedBaseUrl != null) {
      return _cachedBaseUrl!;
    }
    
    final savedUrl = await AppDatabase.getApiBaseUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _cachedBaseUrl = savedUrl;
      return savedUrl;
    }
    
    final defaultUrl = _getDefaultBaseUrl();
    _cachedBaseUrl = defaultUrl;
    return defaultUrl;
  }
  
  static String _getDefaultBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:5050';
    }
    
    if (Platform.isAndroid) {
      return 'http://192.168.31.200:5050'; 
    }
    return 'http://192.168.31.200:5050';
  }
  
  static Future<void> setBaseUrl(String url) async {
    await AppDatabase.setApiBaseUrl(url);
    _cachedBaseUrl = url; 
  }
  

  static Future<void> resetBaseUrl() async {
    await AppDatabase.setApiBaseUrl(null);
    _cachedBaseUrl = null; 
  }
  
  static String get baseUrl {
    return _cachedBaseUrl ?? _getDefaultBaseUrl();
  }

  static Future<List<GuestTrack>> getGuestTracks({bool logResponse = false}) async {
    try {
      final baseUrlValue = await getBaseUrl();
      final url = '$baseUrlValue/guest-tracks';
      debugPrint('🔵 [GuestTracksApi] Запрос к: $url');
      debugPrint('🔵 [GuestTracksApi] Platform: ${Platform.operatingSystem}');
      debugPrint('🔵 [GuestTracksApi] Base URL: $baseUrlValue');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏱️ [GuestTracksApi] Превышено время ожидания (10 сек)');
          throw TimeoutException('Превышено время ожидания ответа от сервера');
        },
      );

      debugPrint('🔵 [GuestTracksApi] Статус ответа: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body) as List<dynamic>;
        final tracks = jsonList.map((json) => GuestTrack.fromJson(json as Map<String, dynamic>)).toList();
        
        // Логирование данных
        if (logResponse || kDebugMode) {
          debugPrint('✅ [GuestTracksApi] Получено треков: ${tracks.length}');
          debugPrint('📦 [GuestTracksApi] Полный ответ сервера:');
          debugPrint(response.body);
          debugPrint('📋 [GuestTracksApi] Список треков:');
          for (var track in tracks) {
            debugPrint('  - ID: ${track.id}, Название: ${track.title}, Артист: ${track.artist}');
            debugPrint('    URL: ${track.url}, Stream URL: ${track.streamUrl}');
          }
        }
        
        return tracks;
      } else {
        debugPrint('❌ [GuestTracksApi] Ошибка: ${response.statusCode}');
        debugPrint('📦 [GuestTracksApi] Тело ответа: ${response.body}');
        throw Exception('Ошибка загрузки треков: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      String message = 'Превышено время ожидания ответа от сервера.\n';
      message += '\nВозможные причины:';
      message += '\n1. Сервер не запущен - запустите: cd backend && npm run dev';
      message += '\n2. Неправильный адрес сервера';
      
      if (Platform.isAndroid) {
        if (baseUrl.contains('10.0.2.2')) {
          message += '\n3. Вы используете реальное Android устройство?';
          message += '\n   Адрес 10.0.2.2 работает только в эмуляторе!';
          message += '\n   Для реального устройства используйте IP вашего компьютера.';
          message += '\n   Узнайте IP: Windows (ipconfig), Mac/Linux (ifconfig)';
          message += '\n   Пример: http://192.168.1.100:5050';
        } else {
          message += '\n3. Проверьте, что сервер доступен по адресу: $baseUrl';
        }
      } else {
        message += '\n3. Проверьте, что сервер запущен на: $baseUrl';
        message += '\n   Убедитесь, что сервер слушает на 0.0.0.0, а не только localhost';
      }
      
      debugPrint('❌ [GuestTracksApi] TimeoutException: ${e.message}');
      debugPrint('💡 [GuestTracksApi] Подсказка: $message');
      throw Exception('$message\nОшибка: ${e.message}');
    } on SocketException catch (e) {
      String message = 'Не удалось подключиться к серверу.\n';
      message += '\nВозможные причины:';
      message += '\n1. Сервер не запущен - запустите: cd backend && npm run dev';
      message += '\n2. Неправильный адрес или порт';
      
      if (Platform.isAndroid && baseUrl.contains('10.0.2.2')) {
        message += '\n3. Вы используете реальное устройство?';
        message += '\n   Адрес 10.0.2.2 работает только в эмуляторе!';
        message += '\n   Для реального устройства используйте IP вашего компьютера.';
        message += '\n   Пример: http://192.168.1.100:5050';
      } else if (baseUrl.contains('localhost')) {
        message += '\n3. Проверьте, что сервер запущен на $baseUrl';
        message += '\n   Убедитесь, что сервер слушает на 0.0.0.0, а не только localhost';
      }
      
      debugPrint('❌ [GuestTracksApi] SocketException: ${e.message}');
      debugPrint('💡 [GuestTracksApi] Подсказка: $message');
      throw Exception('$message\nОшибка: ${e.message}');
    } catch (e) {
      debugPrint('❌ [GuestTracksApi] Общая ошибка: $e');
      debugPrint('💡 [GuestTracksApi] Тип ошибки: ${e.runtimeType}');
      throw Exception('Ошибка при получении треков: $e');
    }
  }

  /// Тестовая функция для проверки подключения и вывода данных в логи
  static Future<void> testConnection() async {
    final baseUrlValue = await getBaseUrl();
    debugPrint('\n═══════════════════════════════════════');
    debugPrint('🧪 Тестирование подключения к бэкенду');
    debugPrint('═══════════════════════════════════════');
    debugPrint('📍 Base URL: $baseUrlValue');
    debugPrint('🔗 Endpoint: $baseUrlValue/guest-tracks');
    debugPrint('═══════════════════════════════════════\n');
    
    try {
      final tracks = await getGuestTracks(logResponse: true);
      debugPrint('\n✅ Успешно! Получено ${tracks.length} треков');
      debugPrint('═══════════════════════════════════════\n');
    } catch (e) {
      debugPrint('\n❌ Ошибка подключения: $e');
      debugPrint('═══════════════════════════════════════\n');
    }
  }

  /// Проверка подключения с возвратом результата
  /// Возвращает true если подключение успешно, false если ошибка
  static Future<bool> checkConnection() async {
    try {
      await getGuestTracks(logResponse: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String> getStreamUrl(int trackId) async {
    final baseUrlValue = await getBaseUrl();
    return '$baseUrlValue/guest-tracks/$trackId/stream';
  }

  static Future<String> getStreamUrlByTitle(String title) async {
    final baseUrlValue = await getBaseUrl();
    final encodedTitle = Uri.encodeComponent(title);
    return '$baseUrlValue/guest-tracks/by-title/stream?title=$encodedTitle';
  }

  static Future<String> getNfcStreamUrl(String title) async {
    final baseUrlValue = await getBaseUrl();
    final encodedTitle = Uri.encodeComponent(title);
    return '$baseUrlValue/guest-tracks/nfc/stream?title=$encodedTitle';
  }
}

