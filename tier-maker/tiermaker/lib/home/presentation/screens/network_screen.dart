import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:RandomTierList/core/global_widgets/panel_header.dart';
import 'package:RandomTierList/home/domain/model/network_track_model.dart';
import 'package:RandomTierList/home/domain/repository/i_network_repository.dart';
import 'package:RandomTierList/home/domain/repository/network_repository_impl.dart';
import 'package:RandomTierList/home/domain/usecase/download_track_usecase.dart';
import 'package:RandomTierList/home/domain/usecase/search_tracks_usecase.dart';
import 'package:RandomTierList/home/presentation/providers/network_provider.dart';
import 'package:RandomTierList/home/presentation/state/network_model.dart';
import 'package:RandomTierList/home/presentation/widgets/network_track_item.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounceTimer;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  late final NetworkModel _model;
  late final SearchTracksUseCase _searchUseCase;
  late final DownloadTrackUseCase _downloadUseCase;
  late final INetworkRepository _repository;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _repository = NetworkRepositoryImpl();
    _searchUseCase = SearchTracksUseCase(_repository);
    _downloadUseCase = DownloadTrackUseCase(_repository);
    _model = NetworkModel();

    _searchController.addListener(_onSearchChanged);

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        _model.setPlaying(state.playing);
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
    _model.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      _model.setTracks([]);
      return;
    }

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
    } catch (e) {
      _model.setError('Ошибка поиска: $e');
    } finally {
      _model.setSearching(false);
    }
  }

  Future<void> _playTrack(NetworkTrack track) async {
    try {
      final trackId = track.uniqueId;

      if (_model.currentlyPlayingId == trackId && _model.isPlaying) {
        await _audioPlayer.pause();
        return;
      }

      final previewUrl = _repository.getPreviewUrl(track);
      if (previewUrl == null || previewUrl.isEmpty) {
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

      if (_model.currentlyPlayingId != null) {
        await _audioPlayer.stop();
      }

      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(previewUrl)));
      await _audioPlayer.play();

      _model.setCurrentlyPlaying(trackId);
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

  Future<void> _stopTrack() async {
    await _audioPlayer.stop();
    _model.setCurrentlyPlaying(null);
    _model.setPlaying(false);
  }

  void _changePlaybackSpeed() {
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
  }

  void _seekTo(Duration position) {
    _audioPlayer.seek(position);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
                          final isCurrentlyPlaying =
                              _model.currentlyPlayingId == trackId;

                          return NetworkTrackItem(
                            track: track,
                            isCurrentlyPlaying: isCurrentlyPlaying,
                            isPlaying: isCurrentlyPlaying && _model.isPlaying,
                            isDownloading: _model.isDownloading(trackId),
                            onPlay: () => _playTrack(track),
                            onDownload: () => _downloadTrack(track),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              if (_model.currentlyPlayingId != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _model.tracks
                                      .firstWhere((t) =>
                                          t.uniqueId == _model.currentlyPlayingId)
                                      .trackName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _model.tracks
                                      .firstWhere((t) =>
                                          t.uniqueId == _model.currentlyPlayingId)
                                      .artistName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _duration.inMilliseconds > 0
                                  ? _position.inMilliseconds.toDouble()
                                  : 0.0,
                              max: _duration.inMilliseconds > 0
                                  ? _duration.inMilliseconds.toDouble()
                                  : 1.0,
                              onChanged: (value) {
                                _seekTo(Duration(milliseconds: value.toInt()));
                              },
                            ),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Text(
                              '${_playbackSpeed}x',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: _changePlaybackSpeed,
                            tooltip: 'Скорость воспроизведения',
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            iconSize: 48,
                            icon: Icon(
                              _model.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed: () {
                              if (_model.isPlaying) {
                                _audioPlayer.pause();
                              } else {
                                _audioPlayer.play();
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.stop),
                            onPressed: _stopTrack,
                            tooltip: 'Остановить',
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
    );
  }
}

