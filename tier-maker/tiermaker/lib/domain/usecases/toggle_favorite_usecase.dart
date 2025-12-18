import '../entities/track.dart';
import '../repositories/tracks_repository.dart';

/// Use case для переключения статуса избранного
class ToggleFavoriteUseCase {
  final TracksRepository repository;

  ToggleFavoriteUseCase(this.repository);

  Future<TrackEntity> execute(TrackEntity track) async {
    await repository.toggleFavorite(track);
    final isFavorite = await repository.isFavorite(track);
    return track.copyWith(favorite: isFavorite);
  }
}

