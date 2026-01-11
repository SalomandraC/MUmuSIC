import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:RandomTierList/core/app_database/app_database.dart';
import '../config/env_config.dart';

class TopChart {
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

  TopChart({
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

  factory TopChart.fromJson(Map<String, dynamic> json) {
    return TopChart(
      id: json['id'] as int,
      title: json['title'] as String,
      artist: json['artist'] as String,
      filePath: json['file_path'] as String,
      fileFormat: json['file_format'] as String,
      duration: json['duration'] as int,
      fileSize: json['file_size']?.toString() ?? '',
      isActive: json['is_active'] as bool,
      playCount: json['play_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      url: json['url'] as String? ?? '',
      streamUrl: json['streamUrl'] as String? ?? '',
    );
  }
}

class TopChartApi {
  static String? _cachedBaseUrl;
  static Future<String> getBaseUrl() async {
    if (_cachedBaseUrl != null) {
      return _cachedBaseUrl!;
    }

    final savedUrl = await AppDatabase.getApiBaseUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _cachedBaseUrl = savedUrl;
      return _cachedBaseUrl!;
    }

    final defaultUrl = _getDefaultBaseUrl();
    _cachedBaseUrl = defaultUrl;
    return defaultUrl;
  }

  static String _getDefaultBaseUrl() {
    return EnvConfig.getApiBaseUrl();
  }

  static Future<List<TopChart>> fetchTopCharts(
      {bool logResponse = false}) async {
    try {
      final baseUrlValue = await getBaseUrl();
      final url = '$baseUrlValue/top-charts';
      debugPrint('[TopChartApi] Запрос к: $url');
      debugPrint('[TopChartApi] Platform: ${Platform.operatingSystem}');
      debugPrint('[TopChartApi] Base URL: $baseUrlValue');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        if (logResponse) {
          debugPrint('[TopChartApi] Ответ: ${response.body}');
        }

        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => TopChart.fromJson(item)).toList();
      } else {
        debugPrint(
            '[TopChartApi] Ошибка: ${response.statusCode} - ${response.reasonPhrase}');
        throw Exception('Ошибка при загрузке топ-чартов');
      }
    } catch (e) {
      debugPrint('[TopChartApi] Исключение: $e');
      throw Exception('Исключение при загрузке топ-чартов: $e');
    }
  }

  static Future<String> getTopChartStreamUrl(int trackId) async {
    final baseUrlValue = await getBaseUrl();
    return '$baseUrlValue/guest-tracks/$trackId/stream';
  }

  static Future<String> getTopChartStreamUrlByTitle(String title) async {
    final baseUrlValue = await getBaseUrl();
    final encodedTitle = Uri.encodeComponent(title);
    return '$baseUrlValue/guest-tracks/by-title/stream?title=$encodedTitle';
  }
}
