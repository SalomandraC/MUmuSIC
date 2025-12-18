import '../entities/playlist.dart';
import '../entities/track.dart';

/// Интерфейс репозитория для работы с плейлистами
abstract class PlaylistsRepository {
  /// Получить все плейлисты
  Future<List<PlaylistEntity>> getAllPlaylists();

  /// Получить плейлист по ID
  Future<PlaylistEntity?> getPlaylistById(int id);

  /// Создать новый плейлист
  Future<PlaylistEntity> createPlaylist({
    required String name,
    String description = '',
    String? coverImageUri,
  });

  /// Обновить плейлист
  Future<void> updatePlaylist(PlaylistEntity playlist);

  /// Удалить плейлист
  Future<void> deletePlaylist(int id);

  /// Добавить трек в плейлист
  Future<void> addTrackToPlaylist(int playlistId, TrackEntity track);

  /// Удалить трек из плейлиста
  Future<void> removeTrackFromPlaylist(int playlistId, TrackEntity track);
}

