import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/playlists_repository.dart';
import '../datasources/local/local_storage_datasource.dart';
import '../models/playlist_dto.dart';

/// Реализация репозитория для работы с плейлистами
class PlaylistsRepositoryImpl implements PlaylistsRepository {
  final LocalStorageDataSource localDataSource;
  int _nextId = 1;

  PlaylistsRepositoryImpl({
    required this.localDataSource,
  });

  Future<void> _init() async {
    final playlists = await getAllPlaylists();
    if (playlists.isNotEmpty) {
      _nextId = playlists.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1;
    }
  }

  @override
  Future<List<PlaylistEntity>> getAllPlaylists() async {
    final dtos = await localDataSource.getPlaylists();
    return dtos.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<PlaylistEntity?> getPlaylistById(int id) async {
    final playlists = await getAllPlaylists();
    try {
      return playlists.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<PlaylistEntity> createPlaylist({
    required String name,
    String description = '',
    String? coverImageUri,
  }) async {
    await _init();
    
    final playlist = PlaylistEntity(
      id: _nextId++,
      name: name,
      description: description,
      coverImageUri: coverImageUri,
      tracks: [],
    );

    final playlists = await getAllPlaylists();
    playlists.add(playlist);
    
    final dtos = playlists.map((p) => PlaylistDto.fromEntity(p)).toList();
    await localDataSource.savePlaylists(dtos);

    return playlist;
  }

  @override
  Future<void> updatePlaylist(PlaylistEntity playlist) async {
    final playlists = await getAllPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlist.id);
    if (index != -1) {
      playlists[index] = playlist;
      final dtos = playlists.map((p) => PlaylistDto.fromEntity(p)).toList();
      await localDataSource.savePlaylists(dtos);
    }
  }

  @override
  Future<void> deletePlaylist(int id) async {
    final playlists = await getAllPlaylists();
    playlists.removeWhere((p) => p.id == id);
    final dtos = playlists.map((p) => PlaylistDto.fromEntity(p)).toList();
    await localDataSource.savePlaylists(dtos);
  }

  @override
  Future<void> addTrackToPlaylist(int playlistId, TrackEntity track) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) return;

    if (playlist.tracks.any((t) => t.id == track.id)) return;

    final updatedTracks = List<TrackEntity>.from(playlist.tracks);
    updatedTracks.add(track);

    final updatedPlaylist = playlist.copyWith(tracks: updatedTracks);
    await updatePlaylist(updatedPlaylist);
  }

  @override
  Future<void> removeTrackFromPlaylist(int playlistId, TrackEntity track) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) return;

    final updatedTracks = playlist.tracks.where((t) => t.id != track.id).toList();
    final updatedPlaylist = playlist.copyWith(tracks: updatedTracks);
    await updatePlaylist(updatedPlaylist);
  }
}

