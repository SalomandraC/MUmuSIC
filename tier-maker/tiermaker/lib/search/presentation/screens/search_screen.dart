import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mumusic/core/audio/player_adapters.dart';
import 'package:mumusic/core/audio/player_service.dart';
import 'package:mumusic/core/global_widgets/panel_header.dart';
import 'package:mumusic/domain/entities/track.dart';
import 'package:mumusic/domain/usecases/search_tracks_usecase.dart';
import 'package:mumusic/domain/usecases/toggle_favorite_usecase.dart';
import 'package:mumusic/domain/repositories/tracks_repository.dart';
import 'package:mumusic/di/dependency_injection.dart';
import 'package:mumusic/search/presentation/widgets/track_item.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounceTimer;

  final SearchTracksUseCase _searchTracksUseCase = DependencyInjection.searchTracksUseCase;
  final ToggleFavoriteUseCase _toggleFavoriteUseCase = DependencyInjection.toggleFavoriteUseCase;
  final TracksRepository _tracksRepository = DependencyInjection.tracksRepository;

  List<TrackEntity> _tracks = [];
  List<String> _searchHistory = [];
  bool _isSearching = false;
  String? _errorMessage;
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final history = await _tracksRepository.getSearchHistory();
    setState(() {
      _searchHistory = history;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _showHistory = query.isEmpty && _searchHistory.isNotEmpty;
    });

    if (query.isEmpty) {
      setState(() {
        _tracks = [];
        _errorMessage = null;
      });
      return;
    }

    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 1000), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _showHistory = false;
    });

    try {
      final tracks = await _searchTracksUseCase.execute(query: query, limit: 50);

      setState(() {
        _tracks = tracks;
        _isSearching = false;
      });

      await _loadSearchHistory();
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка поиска: $e';
        _isSearching = false;
      });
    }
  }

  Future<void> _playTrack(TrackEntity track) => playFromList(
        context,
        _tracks.map((t) => t.toPlayerTrack()).toList(),
        track.toPlayerTrack().id,
      );

  Future<void> _toggleFavorite(TrackEntity track) async {
    final updatedTrack = await _toggleFavoriteUseCase.execute(track);
    setState(() {
      final index = _tracks.indexWhere((t) => t.id == track.id);
      if (index != -1) {
        _tracks[index] = updatedTrack;
      }
    });
  }

  void _onHistoryItemTap(String query) {
    _searchController.text = query;
    _performSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PanelHeader(
              name: 'Поиск',
              showBackButton: true,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Введите название трека или исполнителя',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _tracks = [];
                                      _errorMessage = null;
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _performSearch(value.trim());
                          }
                        },
                      ),
                    ),
                    if (_showHistory && _searchHistory.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'История поиска',
                              style: theme.textTheme.titleSmall,
                            ),
                            TextButton(
                              onPressed: () async {
                                await _tracksRepository.clearSearchHistory();
                                await _loadSearchHistory();
                              },
                              child: const Text('Очистить'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _searchHistory.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              leading: const Icon(Icons.history),
                              title: Text(_searchHistory[index]),
                              onTap: () => _onHistoryItemTap(_searchHistory[index]),
                            );
                          },
                        ),
                      ),
                    ] else if (_isSearching) ...[
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ] else if (_errorMessage != null) ...[
                      Expanded(
                        child: Center(
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
                                _errorMessage!,
                                style: theme.textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  if (_searchController.text.trim().isNotEmpty) {
                                    _performSearch(_searchController.text.trim());
                                  }
                                },
                                child: const Text('Повторить'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (_tracks.isEmpty && _searchController.text.isEmpty) ...[
                      Expanded(
                        child: Center(
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
                                'Введите название трека или исполнителя',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (_tracks.isEmpty) ...[
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.music_off,
                                size: 64,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Треки не найдены',
                                style: theme.textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: ListenableBuilder(
                          listenable: PlayerService.instance,
                          builder: (context, _) => ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _tracks.length,
                          itemBuilder: (context, index) {
                            final track = _tracks[index];
                            final playerId = track.toPlayerTrack().id;
                            final player = PlayerService.instance;
                            return TrackItem(
                              track: track,
                              isCurrentlyPlaying: player.isCurrent(playerId),
                              isPlaying: player.isPlayingTrack(playerId),
                              onPlay: () => _playTrack(track),
                              onFavorite: () => _toggleFavorite(track),
                              onTap: () {
                                // Можно открыть детали трека
                              },
                            );
                          },
                        ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

