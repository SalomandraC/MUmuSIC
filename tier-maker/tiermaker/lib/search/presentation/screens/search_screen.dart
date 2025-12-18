import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:RandomTierList/core/global_widgets/panel_header.dart';
import 'package:RandomTierList/domain/entities/track.dart';
import 'package:RandomTierList/domain/usecases/search_tracks_usecase.dart';
import 'package:RandomTierList/domain/usecases/toggle_favorite_usecase.dart';
import 'package:RandomTierList/domain/repositories/tracks_repository.dart';
import 'package:RandomTierList/di/dependency_injection.dart';
import 'package:RandomTierList/search/presentation/widgets/track_item.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounceTimer;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  final SearchTracksUseCase _searchTracksUseCase = DependencyInjection.searchTracksUseCase;
  final ToggleFavoriteUseCase _toggleFavoriteUseCase = DependencyInjection.toggleFavoriteUseCase;
  final TracksRepository _tracksRepository = DependencyInjection.tracksRepository;

  List<TrackEntity> _tracks = [];
  List<String> _searchHistory = [];
  bool _isSearching = false;
  String? _errorMessage;
  int? _currentlyPlayingId;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _searchController.addListener(_onSearchChanged);

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration ?? Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
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

  Future<void> _playTrack(TrackEntity track) async {
    try {
      if (_currentlyPlayingId == track.id && _isPlaying) {
        await _audioPlayer.pause();
        return;
      }

      if (track.previewUrl == null || track.previewUrl!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Превью для этого трека недоступно'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      if (_currentlyPlayingId != null) {
        await _audioPlayer.stop();
      }

      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(track.previewUrl!)),
      );
      await _audioPlayer.play();

      setState(() {
        _currentlyPlayingId = track.id;
      });
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка воспроизведения: ${e.message ?? e.code}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка воспроизведения: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _tracks.length,
                          itemBuilder: (context, index) {
                            final track = _tracks[index];
                            return TrackItem(
                              track: track,
                              isCurrentlyPlaying: _currentlyPlayingId == track.id,
                              isPlaying: _isPlaying && _currentlyPlayingId == track.id,
                              onPlay: () => _playTrack(track),
                              onFavorite: () => _toggleFavorite(track),
                              onTap: () {
                                // Можно открыть детали трека
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    // Плеер внизу экрана
                    if (_currentlyPlayingId != null)
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _formatDuration(_position),
                                  style: theme.textTheme.bodySmall,
                                ),
                                Expanded(
                                  child: Slider(
                                    value: _duration.inMilliseconds > 0
                                        ? (_position.inMilliseconds.toDouble())
                                            .clamp(0.0, _duration.inMilliseconds.toDouble())
                                        : 0.0,
                                    max: _duration.inMilliseconds > 0
                                        ? _duration.inMilliseconds.toDouble()
                                        : 1.0,
                                    onChanged: (value) {
                                      _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                                    },
                                  ),
                                ),
                                Text(
                                  _formatDuration(_duration),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Text(
                                    '${_playbackSpeed}x',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      if (_playbackSpeed >= 2.0) {
                                        _playbackSpeed = 0.5;
                                      } else if (_playbackSpeed >= 1.5) {
                                        _playbackSpeed = 2.0;
                                      } else if (_playbackSpeed >= 1.0) {
                                        _playbackSpeed = 1.5;
                                      } else {
                                        _playbackSpeed = 1.0;
                                      }
                                      _audioPlayer.setSpeed(_playbackSpeed);
                                    });
                                  },
                                ),
                                IconButton(
                                  iconSize: 48,
                                  icon: Icon(
                                    _isPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_filled,
                                    color: theme.colorScheme.primary,
                                  ),
                                  onPressed: () {
                                    if (_isPlaying) {
                                      _audioPlayer.pause();
                                    } else {
                                      _audioPlayer.play();
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.stop),
                                  onPressed: () async {
                                    await _audioPlayer.stop();
                                    setState(() {
                                      _currentlyPlayingId = null;
                                      _position = Duration.zero;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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

