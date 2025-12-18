import '../../domain/entities/track.dart';
import '../../domain/repositories/tracks_repository.dart';
import '../datasources/remote/itunes_remote_datasource.dart';
import '../datasources/local/local_storage_datasource.dart';
import '../models/track_dto.dart';

/// Реализация репозитория для работы с треками
class TracksRepositoryImpl implements TracksRepository {
  final ITunesRemoteDataSource remoteDataSource;
  final LocalStorageDataSource localDataSource;

  TracksRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<List<TrackEntity>> searchTracks(String query, {int limit = 50}) async {
    final dtos = await remoteDataSource.searchTracks(query, limit: limit);
    return dtos.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<List<TrackEntity>> getFavorites() async {
    final dtos = await localDataSource.getFavorites();
    return dtos.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<void> addToFavorites(TrackEntity track) async {
    final favorites = await getFavorites();
    if (favorites.any((t) => t.id == track.id)) return;

    final updatedTrack = track.copyWith(favorite: true);
    favorites.add(updatedTrack);
    
    final dtos = favorites.map((t) => TrackDto.fromEntity(t)).toList();
    await localDataSource.saveFavorites(dtos);
  }

  @override
  Future<void> removeFromFavorites(TrackEntity track) async {
    final favorites = await getFavorites();
    favorites.removeWhere((t) => t.id == track.id);
    
    final dtos = favorites.map((t) => TrackDto.fromEntity(t)).toList();
    await localDataSource.saveFavorites(dtos);
  }

  @override
  Future<void> toggleFavorite(TrackEntity track) async {
    final favorites = await getFavorites();
    if (favorites.any((t) => t.id == track.id)) {
      await removeFromFavorites(track);
    } else {
      await addToFavorites(track);
    }
  }

  @override
  Future<bool> isFavorite(TrackEntity track) async {
    final favorites = await getFavorites();
    return favorites.any((t) => t.id == track.id);
  }

  @override
  Future<List<String>> getSearchHistory() async {
    return await localDataSource.getSearchHistory();
  }

  @override
  Future<void> addToSearchHistory(String query) async {
    if (query.trim().isEmpty) return;

    final history = await getSearchHistory();
    history.remove(query.trim());
    history.insert(0, query.trim());

    // Ограничиваем историю 10 записями
    if (history.length > 10) {
      history.removeRange(10, history.length);
    }

    await localDataSource.saveSearchHistory(history);
  }

  @override
  Future<void> clearSearchHistory() async {
    await localDataSource.saveSearchHistory([]);
  }
}


