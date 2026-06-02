import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:RandomTierList/core/global_widgets/panel_header.dart';
import 'package:RandomTierList/domain/entities/track.dart';
import 'package:RandomTierList/domain/usecases/get_favorites_usecase.dart';
import 'package:RandomTierList/domain/usecases/toggle_favorite_usecase.dart';
import 'package:RandomTierList/di/dependency_injection.dart';
import 'package:RandomTierList/search/presentation/widgets/track_item.dart';
import 'package:RandomTierList/home/domain/model/network_track_model.dart';
import 'package:RandomTierList/home/presentation/screens/universal_track_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final GetFavoritesUseCase _getFavoritesUseCase =
      DependencyInjection.getFavoritesUseCase;
  final ToggleFavoriteUseCase _toggleFavoriteUseCase =
      DependencyInjection.toggleFavoriteUseCase;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  List<TrackEntity> _favorites = [];
  bool _isLoading = true;
  int? _currentlyPlayingId;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();

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
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
    });

    final favorites = await _getFavoritesUseCase.execute();
    setState(() {
      _favorites = favorites;
      _isLoading = false;
    });
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
    await _toggleFavoriteUseCase.execute(track);
    await _loadFavorites();
  }

  /// Преобразование TrackEntity в NetworkTrack для открытия экрана деталей
  NetworkTrack _trackEntityToNetworkTrack(TrackEntity track) {
    // Парсим время обратно в миллисекунды
    final timeParts = track.trackTime.split(':');
    final minutes = int.tryParse(timeParts[0]) ?? 0;
    final seconds = int.tryParse(timeParts[1]) ?? 0;
    final trackTimeMillis = (minutes * 60 + seconds) * 1000;

    return NetworkTrack(
      trackId: track.id,
      trackName: track.trackName,
      artistName: track.artistName,
      trackTimeMillis: trackTimeMillis,
      previewUrl: track.previewUrl,
      artworkUrl100: track.image,
    );
  }

  Future<void> _openTrackDetails(TrackEntity track) async {
    final networkTrack = _trackEntityToNetworkTrack(track);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => UniversalTrackDetailsScreen(
          networkTrack: networkTrack,
          isFavorite: true,
        ),
      ),
    );

    if (result == true) {
      // Обновляем список избранного после закрытия экрана деталей
      await _loadFavorites();
    }
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
            const PanelHeader(
              name: 'Избранное',
              showBackButton: true,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _favorites.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.favorite_border,
                                  size: 64,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Нет избранных треков',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _favorites.length,
                            itemBuilder: (context, index) {
                              final track = _favorites[index];
                              return GestureDetector(
                                onLongPress: () => _openTrackDetails(track),
                                child: TrackItem(
                                  track: track,
                                  isCurrentlyPlaying:
                                      _currentlyPlayingId == track.id,
                                  isPlaying: _isPlaying &&
                                      _currentlyPlayingId == track.id,
                                  onPlay: () => _playTrack(track),
                                  onFavorite: () => _toggleFavorite(track),
                                  showFavoriteButton: false,
                                ),
                              );
                            },
                          ),
              ),
            ),
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
                                ? (_position.inMilliseconds.toDouble()).clamp(
                                    0.0, _duration.inMilliseconds.toDouble())
                                : 0.0,
                            max: _duration.inMilliseconds > 0
                                ? _duration.inMilliseconds.toDouble()
                                : 1.0,
                            onChanged: (value) {
                              _audioPlayer
                                  .seek(Duration(milliseconds: value.toInt()));
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
    );
  }
}
