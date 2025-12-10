import 'package:flutter_test/flutter_test.dart';
import 'package:RandomTierList/core/api/itunes_api.dart';

/// Тестовый модуль для объекта тестирования ITunesTrack.formattedDuration
/// 
/// Набор тестов покрывает следующие сценарии:
/// 1. Форматирование null значения (должно вернуть "0:00")
/// 2. Форматирование нулевого значения
/// 3. Форматирование значения меньше минуты
/// 4. Форматирование значения ровно одна минута
/// 5. Форматирование значения больше минуты
/// 6. Форматирование значения больше часа
/// 7. Форматирование значения с неполными секундами (округление)
/// 8. Проверка формата вывода (MM:SS)
void main() {
  group('ITunesTrack.formattedDuration', () {
    test('должен вернуть "0:00" для null значения', () {
      // Arrange
      final track = ITunesTrack(
        trackName: 'Test Track',
        artistName: 'Test Artist',
        trackTimeMillis: null,
      );

      // Act
      final result = track.formattedDuration;

      // Assert
      // При null метод возвращает '0:00' без ведущего нуля
      expect(result, equals('0:00'));
    });

    test('должен вернуть "0:00" для нулевого значения', () {
      // Arrange
      final track = ITunesTrack(
        trackName: 'Test Track',
        artistName: 'Test Artist',
        trackTimeMillis: 0,
      );

      // Act
      final result = track.formattedDuration;

      // Assert
      expect(result, equals('00:00'));
    });

    test('должен отформатировать значение меньше минуты', () {
      // Arrange
      final track = ITunesTrack(
        trackName: 'Test Track',
        artistName: 'Test Artist',
        trackTimeMillis: 30000, // 30 секунд
      );

      // Act
      final result = track.formattedDuration;

      // Assert
      expect(result, equals('00:30'));
    });

    test('должен отформатировать значение ровно одна минута', () {
      // Arrange
      final track = ITunesTrack(
        trackName: 'Test Track',
        artistName: 'Test Artist',
        trackTimeMillis: 60000, // 60 секунд = 1 минута
      );

      // Act
      final result = track.formattedDuration;

      // Assert
      expect(result, equals('01:00'));
    });

    test('должен отформатировать значение больше минуты', () {
      // Arrange
      final track = ITunesTrack(
        trackName: 'Test Track',
        artistName: 'Test Artist',
        trackTimeMillis: 125000, // 2 минуты 5 секунд
      );

      // Act
      final result = track.formattedDuration;

      // Assert
      expect(result, equals('02:05'));
    });

    test('должен отформатировать значение больше часа', () {
      // Arrange
      final track = ITunesTrack(
        trackName: 'Test Track',
        artistName: 'Test Artist',
        trackTimeMillis: 3661000, // 1 час 1 минута 1 секунда
      );

      // Act
      final result = track.formattedDuration;

      // Assert
      expect(result, equals('61:01'));
    });

    test('должен округлить неполные секунды', () {
      // Arrange
      final track = ITunesTrack(
        trackName: 'Test Track',
        artistName: 'Test Artist',
        trackTimeMillis: 3599, // 3.599 секунды, должно округлиться до 4
      );

      // Act
      final result = track.formattedDuration;

      // Assert
      expect(result, equals('00:04'));
    });

    test('должен округлить вниз при неполных секундах', () {
      // Arrange
      final track = ITunesTrack(
        trackName: 'Test Track',
        artistName: 'Test Artist',
        trackTimeMillis: 3499, // 3.499 секунды, должно округлиться до 3
      );

      // Act
      final result = track.formattedDuration;

      // Assert
      expect(result, equals('00:03'));
    });

    test('должен корректно отформатировать значение с ведущими нулями', () {
      // Arrange
      final track = ITunesTrack(
        trackName: 'Test Track',
        artistName: 'Test Artist',
        trackTimeMillis: 305000, // 5 минут 5 секунд
      );

      // Act
      final result = track.formattedDuration;

      // Assert
      expect(result, equals('05:05'));
      expect(result.length, equals(5)); // Формат MM:SS
    });

    test('должен корректно обработать большое значение', () {
      // Arrange
      final track = ITunesTrack(
        trackName: 'Test Track',
        artistName: 'Test Artist',
        trackTimeMillis: 7200000, // 120 минут
      );

      // Act
      final result = track.formattedDuration;

      // Assert
      expect(result, equals('120:00'));
    });

    test('должен использовать правильный формат MM:SS', () {
      // Arrange
      final track = ITunesTrack(
        trackName: 'Test Track',
        artistName: 'Test Artist',
        trackTimeMillis: 125000, // 2:05
      );

      // Act
      final result = track.formattedDuration;

      // Assert
      expect(result, matches(RegExp(r'^\d{1,3}:\d{2}$')));
      expect(result.split(':').length, equals(2));
      expect(result.split(':')[1].length, equals(2)); // Секунды всегда 2 цифры
    });
  });
}

