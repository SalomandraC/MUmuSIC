import '../entities/track.dart';
import '../repositories/tracks_repository.dart';

/// Use case для получения избранных треков
class GetFavoritesUseCase {
  final TracksRepository repository;

  GetFavoritesUseCase(this.repository);

  Future<List<TrackEntity>> execute() async {
    return await repository.getFavorites();
  }
}

