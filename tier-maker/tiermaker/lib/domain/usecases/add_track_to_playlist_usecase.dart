import '../entities/track.dart';
import '../repositories/playlists_repository.dart';

/// Use case для добавления трека в плейлист
class AddTrackToPlaylistUseCase {
  final PlaylistsRepository repository;

  AddTrackToPlaylistUseCase(this.repository);

  Future<void> execute({
    required int playlistId,
    required TrackEntity track,
  }) async {
    await repository.addTrackToPlaylist(playlistId, track);
  }
}

