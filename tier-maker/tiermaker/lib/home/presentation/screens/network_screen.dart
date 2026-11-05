import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mumusic/core/audio/player_adapters.dart';
import 'package:mumusic/core/audio/player_service.dart';
import 'package:mumusic/core/global_widgets/panel_header.dart';
import 'package:mumusic/domain/entities/track.dart' as domain;
import 'package:mumusic/domain/repositories/tracks_repository.dart'
    as domain_repo;
import 'package:mumusic/domain/usecases/get_favorites_usecase.dart';
import 'package:mumusic/domain/usecases/toggle_favorite_usecase.dart';
import 'package:mumusic/di/dependency_injection.dart';
import 'package:mumusic/home/domain/model/network_track_model.dart';
import 'package:mumusic/home/domain/repository/i_network_repository.dart';
import 'package:mumusic/home/domain/repository/network_repository_impl.dart';
import 'package:mumusic/home/domain/usecase/download_track_usecase.dart';
import 'package:mumusic/home/domain/usecase/search_network_tracks_usecase.dart';
import 'package:mumusic/home/presentation/providers/network_provider.dart';
import 'package:mumusic/home/presentation/state/network_model.dart';
import 'package:mumusic/home/presentation/widgets/network_track_item.dart';
import 'package:mumusic/home/presentation/screens/universal_track_details_screen.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounceTimer;

  late final NetworkModel _model;
  late final SearchNetworkTracksUseCase _searchUseCase;
  late final DownloadTrackUseCase _downloadUseCase;
  late final INetworkRepository _repository;

  // История поиска и избранное
  List<String> _searchHistory = [];
  bool _showHistory = false;
  Set<String> _favoriteIds = {};

  // Domain use cases / репозитории
  final GetFavoritesUseCase _getFavoritesUseCase =
      DependencyInjection.getFavoritesUseCase;
  final ToggleFavoriteUseCase _toggleFavoriteUseCase =
      DependencyInjection.toggleFavoriteUseCase;
  final domain_repo.TracksRepository _tracksRepository =
      DependencyInjection.tracksRepository;

  @override
  void initState() {
    super.initState();
    _repository = NetworkRepositoryImpl();
    _searchUseCase = SearchNetworkTracksUseCase(_repository);
    _downloadUseCase = DownloadTrackUseCase(_repository);
    _model = NetworkModel();

    _searchController.addListener(_onSearchChanged);

    // Загружаем историю и избранное
    _loadSearchHistory();
    _loadFavorites();
    PlayerService.instance.addListener(_onPlayerChanged);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    PlayerService.instance.removeListener(_onPlayerChanged);
    _model.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final history = await _tracksRepository.getSearchHistory();
    if (!mounted) return;
    setState(() {
      _searchHistory = history;
      _showHistory = _searchController.text.trim().isEmpty &&
          _searchHistory.isNotEmpty;
    });
  }

  Future<void> _loadFavorites() async {
    final favorites = await _getFavoritesUseCase.execute();
    if (!mounted) return;
    setState(() {
      _favoriteIds = favorites.map((t) => t.id.toString()).toSet();
    });
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      _model.setTracks([]);
      setState(() {
        _showHistory = _searchHistory.isNotEmpty;
      });
      return;
    }

    setState(() {
      _showHistory = false;
    });

    _searchDebounceTimer = Timer(const Duration(milliseconds: 1000), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    _model.setSearching(true);
    _model.setError(null);

    try {
      final tracks = await _searchUseCase.execute(query: query, limit: 50);
      _model.setTracks(tracks);

      // Сохраняем запрос в историю
      await _tracksRepository.addToSearchHistory(query);
      await _loadSearchHistory();
    } catch (e) {
      _model.setError('Ошибка поиска: $e');
    } finally {
      _model.setSearching(false);
    }
  }

  domain.TrackEntity _mapNetworkToDomain(NetworkTrack track) {
    final trackId = track.trackId ?? track.uniqueId.hashCode;
    return domain.TrackEntity(
      id: trackId,
      trackName: track.trackName,
      artistName: track.artistName,
      trackTime: track.formattedDuration,
      image: track.artworkUrl100,
      previewUrl: track.previewUrl,
    );
  }

  Future<void> _toggleFavorite(NetworkTrack track) async {
    try {
      final entity = _mapNetworkToDomain(track);
      final updated = await _toggleFavoriteUseCase.execute(entity);
      if (!mounted) return;
      setState(() {
        final idStr = updated.id.toString();
        if (updated.favorite) {
          _favoriteIds.add(idStr);
        } else {
          _favoriteIds.remove(idStr);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка обновления избранного: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openTrackDetails(NetworkTrack track) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => UniversalTrackDetailsScreen(
          networkTrack: track,
          isFavorite: _favoriteIds.contains(
            (track.trackId ?? track.uniqueId.hashCode).toString(),
          ),
        ),
      ),
    );

    if (result == true) {
      // Обновляем список избранного после закрытия экрана деталей
      await _loadFavorites();
    }
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _playTrack(NetworkTrack track) => playFromList(
        context,
        _model.tracks.map((t) => t.toPlayerTrack()).toList(),
        track.toPlayerTrack().id,
      );
  Future<void> _downloadTrack(NetworkTrack track) async {
    final trackId = track.uniqueId;
    _model.setDownloading(trackId, true);

    try {
      final filePath = await _downloadUseCase.execute(track);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Трек скачан: $filePath'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка скачивания: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _model.setDownloading(trackId, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NetworkProvider(
      notifier: _model,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const PanelHeader(
                name: 'Сеть',
                showBackButton: true,
              ),
              // Строка поиска
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: theme.colorScheme.surface,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Поиск треков в iTunes...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _model.setTracks([]);
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                  ),
                  child: ListenableBuilder(
                    listenable: _model,
                    builder: (context, _) {
                      if (_model.isSearching) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (_model.errorMessage != null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Ошибка поиска',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _model.errorMessage!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (_showHistory && _searchHistory.isNotEmpty) {
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: _searchHistory.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'История поиска',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await _tracksRepository
                                            .clearSearchHistory();
                                        await _loadSearchHistory();
                                      },
                                      child: const Text('Очистить'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final item = _searchHistory[index - 1];
                            return ListTile(
                              leading: const Icon(Icons.history),
                              title: Text(item),
                              onTap: () {
                                _searchController.text = item;
                                _performSearch(item);
                              },
                            );
                          },
                        );
                      }

                      if (_model.tracks.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search,
                                size: 64,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'Введите запрос для поиска'
                                    : 'Треки не найдены',
                                style: theme.textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _model.tracks.length,
                        itemBuilder: (context, index) {
                          final track = _model.tracks[index];
                          final trackId = track.uniqueId;
                          final playerId = track.toPlayerTrack().id;
                          final isCurrentlyPlaying =
                              PlayerService.instance.isCurrent(playerId);
                          final favoriteId =
                              (track.trackId ?? track.uniqueId.hashCode)
                                  .toString();

                          return NetworkTrackItem(
                            track: track,
                            isCurrentlyPlaying: isCurrentlyPlaying,
                            isPlaying: PlayerService.instance.isPlayingTrack(playerId),
                            isDownloading: _model.isDownloading(trackId),
                            isFavorite: _favoriteIds.contains(favoriteId),
                            onPlay: () => _playTrack(track),
                            onDownload: () => _downloadTrack(track),
                            onToggleFavorite: () => _toggleFavorite(track),
                            onLongPress: () => _openTrackDetails(track),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

