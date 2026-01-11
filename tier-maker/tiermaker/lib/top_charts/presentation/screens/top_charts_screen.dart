import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:RandomTierList/core/api/top_chart_api.dart';
import 'package:RandomTierList/core/api/guest_tracks_api.dart';
import 'package:RandomTierList/core/global_widgets/panel_header.dart';
import 'package:RandomTierList/home/presentation/screens/universal_track_details_screen.dart';

class TopChartsScreen extends StatefulWidget {
  const TopChartsScreen({super.key});

  @override
  State<TopChartsScreen> createState() => _TopChartsScreenState();
}

class _TopChartsScreenState extends State<TopChartsScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  List<TopChart> _tracks = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _currentlyPlayingId;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _loadTracks();

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
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tracks = await TopChartApi.fetchTopCharts();
      setState(() {
        _tracks = tracks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки топ-чартов: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _playTrack(TopChart track) async {
    try {
      if (_currentlyPlayingId == track.id && _isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_currentlyPlayingId != null) {
          await _audioPlayer.stop();
        }

        String streamUrl;
        if (track.streamUrl.isNotEmpty) {
          streamUrl = track.streamUrl;
        } else {
          streamUrl = await TopChartApi.getTopChartStreamUrl(track.id);
        }

        if (!streamUrl.startsWith('http')) {
          final base = await TopChartApi.getBaseUrl();
          streamUrl = base + (streamUrl.startsWith('/') ? '' : '/') + streamUrl;
        }

        final uri = Uri.parse(streamUrl);
        if (uri.scheme != 'http' && uri.scheme != 'https') {
          throw Exception('Неподдерживаемая схема URI: ${uri.scheme}');
        }

        final audioSource = AudioSource.uri(
          uri,
          headers: {'accept': 'audio/mpeg'},
        );

        await _audioPlayer.setAudioSource(audioSource);

        int attempts = 0;
        const maxAttempts = 20;
        bool isReady = false;

        while (attempts < maxAttempts) {
          final state = _audioPlayer.playerState;
          if (state.processingState == ProcessingState.ready) {
            isReady = true;
            break;
          }
          if (attempts > 5 && state.processingState == ProcessingState.idle) {
            throw Exception('Плеер не смог загрузить источник');
          }
          await Future.delayed(const Duration(milliseconds: 200));
          attempts++;
        }

        if (!isReady &&
            _audioPlayer.playerState.processingState != ProcessingState.ready) {
          throw Exception('Плеер не готов к воспроизведению');
        }

        await _audioPlayer.play();
        await Future.delayed(const Duration(milliseconds: 1000));

        setState(() {
          _currentlyPlayingId = track.id;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка воспроизведения: ${e.message ?? e.code}'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка воспроизведения: $e'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopTrack() async {
    await _audioPlayer.stop();
    setState(() {
      _currentlyPlayingId = null;
      _isPlaying = false;
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDurationFromDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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

  Future<void> _openTrackDetails(TopChart track) async {
    // Преобразуем TopChart в GuestTrack для совместимости с UniversalTrackDetailsScreen
    final guestTrack = GuestTrack(
      id: track.id,
      title: track.title,
      artist: track.artist,
      filePath: track.filePath,
      fileFormat: track.fileFormat,
      duration: track.duration,
      fileSize: track.fileSize,
      isActive: track.isActive,
      playCount: track.playCount,
      createdAt: track.createdAt,
      url: track.url,
      streamUrl: track.streamUrl,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UniversalTrackDetailsScreen(
          guestTrack: guestTrack,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PanelHeader(
              name: 'Топ-чарт',
              showBackButton: true,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
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
                                    'Ошибка подключения',
                                    style:
                                        theme.textTheme.headlineSmall?.copyWith(
                                      color: theme.colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorMessage!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: _loadTracks,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Повторить'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _tracks.isEmpty
                            ? Center(
                                child: Text(
                                  'Треки не найдены',
                                  style: theme.textTheme.bodyLarge,
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                itemCount: _tracks.length,
                                itemBuilder: (context, index) {
                                  final track = _tracks[index];
                                  final isCurrentlyPlaying =
                                      _currentlyPlayingId == track.id;
                                  final rank = index + 1;

                                  return GestureDetector(
                                    onLongPress: () => _openTrackDetails(track),
                                    child: Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: isCurrentlyPlaying
                                          ? theme.colorScheme.primaryContainer
                                              .withValues(alpha: 0.3)
                                          : null,
                                      child: ListTile(
                                        leading: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 32,
                                              alignment: Alignment.center,
                                              child: Text(
                                                '#$rank',
                                                style: theme
                                                    .textTheme.titleSmall
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: rank <= 3
                                                      ? theme
                                                          .colorScheme.primary
                                                      : theme.colorScheme
                                                          .onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: Icon(
                                                isCurrentlyPlaying && _isPlaying
                                                    ? Icons.pause_circle_filled
                                                    : Icons.play_circle_filled,
                                                color: isCurrentlyPlaying
                                                    ? theme.colorScheme.primary
                                                    : theme.colorScheme
                                                        .onSurfaceVariant,
                                                size: 40,
                                              ),
                                              onPressed: () =>
                                                  _playTrack(track),
                                            ),
                                          ],
                                        ),
                                        title: Text(
                                          track.title,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: isCurrentlyPlaying
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isCurrentlyPlaying
                                                ? theme.colorScheme.primary
                                                : null,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (track.artist.isNotEmpty)
                                              Text(
                                                track.artist,
                                                style:
                                                    theme.textTheme.bodyMedium,
                                              ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.play_arrow,
                                                  size: 14,
                                                  color: theme.colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${track.playCount}',
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Text(
                                                  _formatDuration(
                                                      track.duration),
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        trailing: isCurrentlyPlaying
                                            ? Icon(
                                                Icons.graphic_eq,
                                                color:
                                                    theme.colorScheme.primary,
                                              )
                                            : null,
                                        onTap: () => _playTrack(track),
                                        enableFeedback: false,
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ),
            if (_currentlyPlayingId != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                _tracks
                                    .firstWhere(
                                        (t) => t.id == _currentlyPlayingId)
                                    .title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _tracks
                                    .firstWhere(
                                        (t) => t.id == _currentlyPlayingId)
                                    .artist,
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
                          _formatDurationFromDuration(_position),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
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
                              _seekTo(Duration(milliseconds: value.toInt()));
                            },
                          ),
                        ),
                        Text(
                          _formatDurationFromDuration(_duration),
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
    );
  }
}
