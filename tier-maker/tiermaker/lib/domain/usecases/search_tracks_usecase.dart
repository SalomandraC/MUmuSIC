import '../entities/track.dart';
import '../repositories/tracks_repository.dart';

/// Use case для поиска треков
class SearchTracksUseCase {
  final TracksRepository repository;

  SearchTracksUseCase(this.repository);

  Future<List<TrackEntity>> execute({
    required String query,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final tracks = await repository.searchTracks(query, limit: limit);
    
    // Сохраняем запрос в историю
    await repository.addToSearchHistory(query);

    // Загружаем статус избранного для каждого трека
    final tracksWithFavorites = <TrackEntity>[];
    for (var track in tracks) {
      final isFav = await repository.isFavorite(track);
      tracksWithFavorites.add(track.copyWith(favorite: isFav));
    }

    return tracksWithFavorites;
  }
}

