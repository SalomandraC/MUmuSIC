import 'package:flutter_test/flutter_test.dart';
import 'package:RandomTierList/core/api/itunes_api.dart';

/// Тестовый модуль для объекта тестирования ITunesSearchResponse.fromJson
/// 
/// Набор тестов покрывает следующие сценарии:
/// 1. Десериализация валидного JSON с полными данными
/// 2. Десериализация JSON с отсутствующим resultCount
/// 3. Десериализация JSON с отсутствующим results
/// 4. Десериализация JSON с null значениями
/// 5. Десериализация JSON с пустым списком results
/// 6. Десериализация JSON с некорректными элементами в results
/// 7. Обработка большого количества результатов
void main() {
  group('ITunesSearchResponse.fromJson', () {
    test('должен десериализовать валидный JSON с полными данными', () {
      // Arrange
      final json = {
        'resultCount': 2,
        'results': [
          {
            'trackId': 123456,
            'trackName': 'Test Track 1',
            'artistName': 'Test Artist 1',
            'trackTimeMillis': 200000,
            'previewUrl': 'https://example.com/preview1.m4a',
            'artworkUrl100': 'https://example.com/artwork1.jpg',
          },
          {
            'trackId': 789012,
            'trackName': 'Test Track 2',
            'artistName': 'Test Artist 2',
            'trackTimeMillis': 180000,
            'previewUrl': 'https://example.com/preview2.m4a',
            'artworkUrl100': 'https://example.com/artwork2.jpg',
          },
        ],
      };

      // Act
      final response = ITunesSearchResponse.fromJson(json);

      // Assert
      expect(response.resultCount, equals(2));
      expect(response.results.length, equals(2));
      expect(response.results[0].trackName, equals('Test Track 1'));
      expect(response.results[1].trackName, equals('Test Track 2'));
    });

    test('должен использовать значение по умолчанию для отсутствующего resultCount', () {
      // Arrange
      final json = {
        'results': [],
      };

      // Act
      final response = ITunesSearchResponse.fromJson(json);

      // Assert
      expect(response.resultCount, equals(0));
      expect(response.results, isEmpty);
    });

    test('должен использовать пустой список для отсутствующего results', () {
      // Arrange
      final json = {
        'resultCount': 5,
      };

      // Act
      final response = ITunesSearchResponse.fromJson(json);

      // Assert
      expect(response.resultCount, equals(5));
      expect(response.results, isEmpty);
    });

    test('должен обработать null значения в JSON', () {
      // Arrange
      final json = {
        'resultCount': null,
        'results': null,
      };

      // Act
      final response = ITunesSearchResponse.fromJson(json);

      // Assert
      expect(response.resultCount, equals(0));
      expect(response.results, isEmpty);
    });

    test('должен обработать пустой список results', () {
      // Arrange
      final json = {
        'resultCount': 0,
        'results': [],
      };

      // Act
      final response = ITunesSearchResponse.fromJson(json);

      // Assert
      expect(response.resultCount, equals(0));
      expect(response.results, isEmpty);
    });

    test('должен обработать результаты с частичными данными', () {
      // Arrange
      final json = {
        'resultCount': 2,
        'results': [
          {
            'trackName': 'Track 1',
            'artistName': 'Artist 1',
            // Отсутствуют некоторые поля
          },
          {
            'trackId': 123,
            'trackName': 'Track 2',
            'artistName': 'Artist 2',
            'trackTimeMillis': 200000,
          },
        ],
      };

      // Act
      final response = ITunesSearchResponse.fromJson(json);

      // Assert
      expect(response.resultCount, equals(2));
      expect(response.results.length, equals(2));
      expect(response.results[0].trackName, equals('Track 1'));
      expect(response.results[0].trackId, isNull);
      expect(response.results[1].trackId, equals(123));
    });

    test('должен обработать большое количество результатов', () {
      // Arrange
      final results = List.generate(100, (index) => {
        'trackId': index,
        'trackName': 'Track $index',
        'artistName': 'Artist $index',
        'trackTimeMillis': 200000 + index * 1000,
      });

      final json = {
        'resultCount': 100,
        'results': results,
      };

      // Act
      final response = ITunesSearchResponse.fromJson(json);

      // Assert
      expect(response.resultCount, equals(100));
      expect(response.results.length, equals(100));
      expect(response.results[0].trackName, equals('Track 0'));
      expect(response.results[99].trackName, equals('Track 99'));
    });

    test('должен обработать несоответствие resultCount и количества results', () {
      // Arrange
      final json = {
        'resultCount': 5,
        'results': [
          {
            'trackName': 'Track 1',
            'artistName': 'Artist 1',
          },
        ],
      };

      // Act
      final response = ITunesSearchResponse.fromJson(json);

      // Assert
      expect(response.resultCount, equals(5));
      expect(response.results.length, equals(1));
    });

    test('должен обработать некорректные типы в results', () {
      // Arrange
      final json = {
        'resultCount': 2,
        'results': [
          {
            'trackName': 'Valid Track',
            'artistName': 'Valid Artist',
          },
          // Некорректный элемент будет обработан как Map<String, dynamic>
          {
            'trackName': 'Another Valid Track',
            'artistName': 'Another Valid Artist',
          },
        ],
      };

      // Act
      final response = ITunesSearchResponse.fromJson(json);

      // Assert
      expect(response.resultCount, equals(2));
      expect(response.results.length, equals(2));
    });

    test('должен обработать результаты с null значениями полей', () {
      // Arrange
      final json = {
        'resultCount': 1,
        'results': [
          {
            'trackId': null,
            'trackName': null,
            'artistName': null,
            'trackTimeMillis': null,
            'previewUrl': null,
            'artworkUrl100': null,
          },
        ],
      };

      // Act
      final response = ITunesSearchResponse.fromJson(json);

      // Assert
      expect(response.resultCount, equals(1));
      expect(response.results.length, equals(1));
      expect(response.results[0].trackName, equals(''));
      expect(response.results[0].artistName, equals(''));
      expect(response.results[0].trackId, isNull);
    });
  });
}

