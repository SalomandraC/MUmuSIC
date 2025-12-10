import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:RandomTierList/home/domain/usecase/search_tracks_usecase.dart';
import 'package:RandomTierList/home/domain/repository/i_network_repository.dart';
import 'package:RandomTierList/home/domain/model/network_track_model.dart';

/// Мок-класс для INetworkRepository
class MockNetworkRepository extends Mock implements INetworkRepository {}

/// Тестовый модуль для объекта тестирования SearchTracksUseCase.execute
/// 
/// Набор тестов покрывает следующие сценарии:
/// 1. Успешный поиск с валидным запросом
/// 2. Поиск с пустым запросом (должен вернуть пустой список)
/// 3. Поиск с запросом, содержащим только пробелы
/// 4. Поиск с различными значениями limit
/// 5. Обработка ошибок репозитория
/// 6. Проверка передачи параметров в репозиторий
void main() {
  group('SearchTracksUseCase.execute', () {
    late SearchTracksUseCase useCase;
    late MockNetworkRepository mockRepository;

    setUp(() {
      mockRepository = MockNetworkRepository();
      useCase = SearchTracksUseCase(mockRepository);
    });

    test('должен вернуть список треков при валидном запросе', () async {
      // Arrange
      const query = 'test query';
      const limit = 50;
      final expectedTracks = [
        NetworkTrack(
          trackId: 1,
          trackName: 'Test Track',
          artistName: 'Test Artist',
          trackTimeMillis: 200000,
        ),
        NetworkTrack(
          trackId: 2,
          trackName: 'Another Track',
          artistName: 'Another Artist',
          trackTimeMillis: 180000,
        ),
      ];

      when(() => mockRepository.searchTracks(query: query, limit: limit))
          .thenAnswer((_) async => expectedTracks);

      // Act
      final result = await useCase.execute(query: query, limit: limit);

      // Assert
      expect(result, equals(expectedTracks));
      expect(result.length, equals(2));
      verify(() => mockRepository.searchTracks(query: query, limit: limit))
          .called(1);
    });

    test('должен вернуть пустой список при пустом запросе', () async {
      // Arrange
      const query = '';

      // Act
      final result = await useCase.execute(query: query);

      // Assert
      expect(result, isEmpty);
      verifyNever(() => mockRepository.searchTracks(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ));
    });

    test('должен вернуть пустой список при запросе только с пробелами', () async {
      // Arrange
      const query = '   ';

      // Act
      final result = await useCase.execute(query: query);

      // Assert
      expect(result, isEmpty);
      verifyNever(() => mockRepository.searchTracks(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ));
    });

    test('должен использовать значение limit по умолчанию', () async {
      // Arrange
      const query = 'test query';
      final expectedTracks = <NetworkTrack>[];

      when(() => mockRepository.searchTracks(query: query, limit: 50))
          .thenAnswer((_) async => expectedTracks);

      // Act
      await useCase.execute(query: query);

      // Assert
      verify(() => mockRepository.searchTracks(query: query, limit: 50))
          .called(1);
    });

    test('должен передать кастомное значение limit в репозиторий', () async {
      // Arrange
      const query = 'test query';
      const limit = 10;
      final expectedTracks = <NetworkTrack>[];

      when(() => mockRepository.searchTracks(query: query, limit: limit))
          .thenAnswer((_) async => expectedTracks);

      // Act
      await useCase.execute(query: query, limit: limit);

      // Assert
      verify(() => mockRepository.searchTracks(query: query, limit: limit))
          .called(1);
    });

    test('должен пробросить исключение при ошибке репозитория', () async {
      // Arrange
      const query = 'test query';
      final exception = Exception('Network error');

      when(() => mockRepository.searchTracks(query: query, limit: 50))
          .thenThrow(exception);

      // Act & Assert
      expect(
        () => useCase.execute(query: query),
        throwsA(isA<Exception>()),
      );
      verify(() => mockRepository.searchTracks(query: query, limit: 50))
          .called(1);
    });

    test('должен обработать запрос с обрезанными пробелами', () async {
      // Arrange
      const query = '  test query  ';
      final expectedTracks = <NetworkTrack>[];

      when(() => mockRepository.searchTracks(query: 'test query', limit: 50))
          .thenAnswer((_) async => expectedTracks);

      // Act
      await useCase.execute(query: query);

      // Assert
      verify(() => mockRepository.searchTracks(query: 'test query', limit: 50))
          .called(1);
    });

    test('должен вернуть пустой список при null-подобном запросе', () async {
      // Arrange
      const query = '\t\n\r';

      // Act
      final result = await useCase.execute(query: query);

      // Assert
      expect(result, isEmpty);
    });

    test('должен обработать запрос с специальными символами', () async {
      // Arrange
      const query = 'test+query&special';
      final expectedTracks = <NetworkTrack>[];

      when(() => mockRepository.searchTracks(query: query, limit: 50))
          .thenAnswer((_) async => expectedTracks);

      // Act
      await useCase.execute(query: query);

      // Assert
      verify(() => mockRepository.searchTracks(query: query, limit: 50))
          .called(1);
    });

    test('должен обработать запрос с limit равным 0', () async {
      // Arrange
      const query = 'test query';
      const limit = 0;
      final expectedTracks = <NetworkTrack>[];

      when(() => mockRepository.searchTracks(query: query, limit: limit))
          .thenAnswer((_) async => expectedTracks);

      // Act
      final result = await useCase.execute(query: query, limit: limit);

      // Assert
      expect(result, equals(expectedTracks));
      verify(() => mockRepository.searchTracks(query: query, limit: limit))
          .called(1);
    });
  });
}

