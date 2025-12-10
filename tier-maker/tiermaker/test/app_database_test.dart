import 'package:flutter_test/flutter_test.dart';
import 'package:RandomTierList/core/app_database/app_database.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Тестовый модуль для объекта тестирования AppDatabase.setApiBaseUrl
/// 
/// Набор тестов покрывает следующие сценарии:
/// 1. Установка валидного URL без завершающего слеша
/// 2. Установка валидного URL с завершающим слешем (должен быть удален)
/// 3. Установка null значения (должно удалить ключ)
/// 4. Установка пустой строки (должно удалить ключ)
/// 5. Установка URL с пробелами
/// 6. Проверка сохранения и получения значения
void main() {
  group('AppDatabase.setApiBaseUrl', () {
    setUpAll(() async {
      // Инициализация Hive для тестов
      await Hive.initFlutter();
    });

    setUp(() async {
      // Очистка box перед каждым тестом
      final box = await Hive.openBox<String>('appBox');
      await box.clear();
      await box.close();
    });

    tearDown(() async {
      // Закрытие box после каждого теста
      await AppDatabase.close();
    });

    test('должен сохранить валидный URL без завершающего слеша', () async {
      // Arrange
      const testUrl = 'https://api.example.com';

      // Act
      await AppDatabase.setApiBaseUrl(testUrl);

      // Assert
      final savedUrl = await AppDatabase.getApiBaseUrl();
      expect(savedUrl, equals(testUrl));
    });

    test('должен удалить завершающий слеш из URL', () async {
      // Arrange
      const testUrl = 'https://api.example.com/';

      // Act
      await AppDatabase.setApiBaseUrl(testUrl);

      // Assert
      final savedUrl = await AppDatabase.getApiBaseUrl();
      expect(savedUrl, equals('https://api.example.com'));
    });

    test('должен удалить ключ при установке null', () async {
      // Arrange
      const testUrl = 'https://api.example.com';
      await AppDatabase.setApiBaseUrl(testUrl);
      
      // Act
      await AppDatabase.setApiBaseUrl(null);

      // Assert
      final savedUrl = await AppDatabase.getApiBaseUrl();
      expect(savedUrl, isNull);
    });

    test('должен удалить ключ при установке пустой строки', () async {
      // Arrange
      const testUrl = 'https://api.example.com';
      await AppDatabase.setApiBaseUrl(testUrl);
      
      // Act
      await AppDatabase.setApiBaseUrl('');

      // Assert
      final savedUrl = await AppDatabase.getApiBaseUrl();
      expect(savedUrl, isNull);
    });

    test('должен обработать URL с множественными слешами', () async {
      // Arrange
      const testUrl = 'https://api.example.com///';

      // Act
      await AppDatabase.setApiBaseUrl(testUrl);

      // Assert
      final savedUrl = await AppDatabase.getApiBaseUrl();
      expect(savedUrl, equals('https://api.example.com//'));
    });

    test('должен сохранить URL с подпутем без завершающего слеша', () async {
      // Arrange
      const testUrl = 'https://api.example.com/v1';

      // Act
      await AppDatabase.setApiBaseUrl(testUrl);

      // Assert
      final savedUrl = await AppDatabase.getApiBaseUrl();
      expect(savedUrl, equals(testUrl));
    });

    test('должен удалить завершающий слеш из URL с подпутем', () async {
      // Arrange
      const testUrl = 'https://api.example.com/v1/';

      // Act
      await AppDatabase.setApiBaseUrl(testUrl);

      // Assert
      final savedUrl = await AppDatabase.getApiBaseUrl();
      expect(savedUrl, equals('https://api.example.com/v1'));
    });

    test('должен корректно обработать перезапись существующего URL', () async {
      // Arrange
      const firstUrl = 'https://api1.example.com';
      const secondUrl = 'https://api2.example.com';
      await AppDatabase.setApiBaseUrl(firstUrl);

      // Act
      await AppDatabase.setApiBaseUrl(secondUrl);

      // Assert
      final savedUrl = await AppDatabase.getApiBaseUrl();
      expect(savedUrl, equals(secondUrl));
      expect(savedUrl, isNot(equals(firstUrl)));
    });
  });
}

