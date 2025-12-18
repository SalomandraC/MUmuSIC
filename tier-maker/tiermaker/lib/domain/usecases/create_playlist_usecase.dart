import '../entities/playlist.dart';
import '../repositories/playlists_repository.dart';

/// Use case для создания плейлиста
class CreatePlaylistUseCase {
  final PlaylistsRepository repository;

  CreatePlaylistUseCase(this.repository);

  Future<PlaylistEntity> execute({
    required String name,
    String description = '',
    String? coverImageUri,
  }) async {
    return await repository.createPlaylist(
      name: name,
      description: description,
      coverImageUri: coverImageUri,
    );
  }
}

