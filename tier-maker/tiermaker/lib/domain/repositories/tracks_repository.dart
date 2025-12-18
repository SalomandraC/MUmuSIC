import '../entities/track.dart';

/// Интерфейс репозитория для работы с треками
abstract class TracksRepository {
  /// Поиск треков
  Future<List<TrackEntity>> searchTracks(String query, {int limit = 50});

  /// Получить все избранные треки
  Future<List<TrackEntity>> getFavorites();

  /// Добавить трек в избранное
  Future<void> addToFavorites(TrackEntity track);

  /// Удалить трек из избранного
  Future<void> removeFromFavorites(TrackEntity track);

  /// Переключить статус избранного
  Future<void> toggleFavorite(TrackEntity track);

  /// Проверить, является ли трек избранным
  Future<bool> isFavorite(TrackEntity track);

  /// Получить историю поиска
  Future<List<String>> getSearchHistory();

  /// Добавить запрос в историю поиска
  Future<void> addToSearchHistory(String query);

  /// Очистить историю поиска
  Future<void> clearSearchHistory();
}

