import '../data/datasources/local/local_storage_datasource.dart';
import '../data/datasources/remote/itunes_remote_datasource.dart';
import '../data/repositories/playlists_repository_impl.dart';
import '../data/repositories/tracks_repository_impl.dart';
import '../domain/repositories/playlists_repository.dart';
import '../domain/repositories/tracks_repository.dart';
import '../domain/usecases/search_tracks_usecase.dart';
import '../domain/usecases/toggle_favorite_usecase.dart';
import '../domain/usecases/get_favorites_usecase.dart';
import '../domain/usecases/create_playlist_usecase.dart';
import '../domain/usecases/add_track_to_playlist_usecase.dart';
import '../home/domain/repository/network_repository_impl.dart';
import '../home/domain/repository/i_network_repository.dart';
import '../home/domain/usecase/download_track_usecase.dart';

/// Контейнер зависимостей (Dependency Injection)
class DependencyInjection {
  // Data Sources
  static final LocalStorageDataSource _localDataSource =
      LocalStorageDataSourceImpl();
  static final ITunesRemoteDataSource _remoteDataSource =
      ITunesRemoteDataSourceImpl();

  // Repositories
  static final TracksRepository _tracksRepository = TracksRepositoryImpl(
    remoteDataSource: _remoteDataSource,
    localDataSource: _localDataSource,
  );

  static final PlaylistsRepository _playlistsRepository =
      PlaylistsRepositoryImpl(
    localDataSource: _localDataSource,
  );

  // Use Cases
  static final SearchTracksUseCase searchTracksUseCase =
      SearchTracksUseCase(_tracksRepository);
  static final ToggleFavoriteUseCase toggleFavoriteUseCase =
      ToggleFavoriteUseCase(_tracksRepository);
  static final GetFavoritesUseCase getFavoritesUseCase =
      GetFavoritesUseCase(_tracksRepository);
  static final CreatePlaylistUseCase createPlaylistUseCase =
      CreatePlaylistUseCase(_playlistsRepository);
  static final AddTrackToPlaylistUseCase addTrackToPlaylistUseCase =
      AddTrackToPlaylistUseCase(_playlistsRepository);

  // Network Repository (общий iTunes data source)
  static final INetworkRepository _networkRepository = NetworkRepositoryImpl(
    remoteDataSource: _remoteDataSource,
  );

  // Download Use Case
  static final DownloadTrackUseCase downloadTrackUseCase =
      DownloadTrackUseCase(_networkRepository);

  // Repositories для прямого доступа (если нужно)
  static TracksRepository get tracksRepository => _tracksRepository;
  static PlaylistsRepository get playlistsRepository => _playlistsRepository;
}
