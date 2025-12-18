import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class EnvConfig {
  static String? _apiBaseUrl;

  static String getApiBaseUrl() {
    if (_apiBaseUrl != null) return _apiBaseUrl!;
    
    try {
      final url = dotenv.env['API_BASE_URL'];
      if (url != null && url.isNotEmpty) {
        _apiBaseUrl = url;
        return url;
      }
    } catch (e) {
      debugPrint('[EnvConfig] Ошибка чтения API_BASE_URL из .env: $e');
    }

    // Fallback значение, если .env не загружен или переменная не задана
    const fallbackUrl = 'http://localhost:5050';
    _apiBaseUrl = fallbackUrl;
    return fallbackUrl;
  }

  static void setApiBaseUrl(String url) {
    _apiBaseUrl = url;
  }

  static void clearCache() {
    _apiBaseUrl = null;
  }
}

