import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:RandomTierList/core/global_widgets/panel_header.dart';
import 'package:RandomTierList/home/domain/model/downloaded_track_model.dart';
import 'package:RandomTierList/home/domain/repository/i_downloaded_tracks_repository.dart';
import 'package:RandomTierList/home/domain/repository/downloaded_tracks_repository_impl.dart';
import 'package:RandomTierList/home/domain/usecase/get_downloaded_tracks_usecase.dart';
import 'package:RandomTierList/home/domain/usecase/delete_downloaded_track_usecase.dart';
import 'package:RandomTierList/storage/presentation/widgets/downloaded_track_item.dart';
import 'package:RandomTierList/home/presentation/screens/universal_track_details_screen.dart';
import 'package:RandomTierList/core/services/upload_service.dart';
import 'package:RandomTierList/app/state/app_model_provider.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final IDownloadedTracksRepository _repository =
      DownloadedTracksRepositoryImpl();
  late final GetDownloadedTracksUseCase _getDownloadedTracksUseCase;
  late final DeleteDownloadedTrackUseCase _deleteDownloadedTrackUseCase;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  List<DownloadedTrack> _tracks = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentlyPlayingPath;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;
  Set<String> _uploadingTracks = {};

  @override
  void initState() {
    super.initState();
    _getDownloadedTracksUseCase = GetDownloadedTracksUseCase(_repository);
    _deleteDownloadedTrackUseCase = DeleteDownloadedTrackUseCase(_repository);
    _loadTracks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем список при возврате на экран
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
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tracks = await _getDownloadedTracksUseCase.execute();
      setState(() {
        _tracks = tracks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки треков: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _playTrack(DownloadedTrack track) async {
    try {
      if (_currentlyPlayingPath == track.filePath && _isPlaying) {
        await _audioPlayer.pause();
        return;
      }

      if (_currentlyPlayingPath != null) {
        await _audioPlayer.stop();
      }

      await _audioPlayer.setAudioSource(AudioSource.file(track.filePath));
      await _audioPlayer.play();

      setState(() {
        _currentlyPlayingPath = track.filePath;
      });
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка воспроизведения: ${e.message ?? e.code}'),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color.fromARGB(255, 239, 132, 124),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка воспроизведения: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color.fromARGB(255, 255, 151, 143),
          ),
        );
      }
    }
  }

  Future<void> _deleteTrack(DownloadedTrack track) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить трек?'),
        content: Text('Вы уверены, что хотите удалить "${track.trackName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 249, 139, 132),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _deleteDownloadedTrackUseCase.execute(track);
        if (_currentlyPlayingPath == track.filePath) {
          await _audioPlayer.stop();
          setState(() {
            _currentlyPlayingPath = null;
            _position = Duration.zero;
          });
        }
        await _loadTracks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Трек удален'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка удаления: $e'),
              duration: const Duration(seconds: 3),
              backgroundColor: const Color.fromARGB(255, 251, 126, 118),
            ),
          );
        }
      }
    }
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

  Future<void> _openTrackDetails(DownloadedTrack track) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UniversalTrackDetailsScreen(
          downloadedTrack: track,
        ),
      ),
    );
  }

  Future<void> _uploadTrack(DownloadedTrack track) async {
    if (_uploadingTracks.contains(track.filePath)) {
      return;
    }

    setState(() {
      _uploadingTracks.add(track.filePath);
    });

    try {
      final result = await UploadService.uploadDownloadedTrack(track);

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Трек успешно загружен на сервер'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        final error = result['error'] as String? ?? 'Ошибка загрузки';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $error'),
            backgroundColor: const Color.fromARGB(255, 255, 134, 125),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingTracks.remove(track.filePath);
        });
      }
    }
  }

  Future<void> _uploadAllTracks() async {
    if (_tracks.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Загрузить все треки?'),
        content: Text('Загрузить ${_tracks.length} треков на сервер?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Загрузить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    for (final track in _tracks) {
      _uploadingTracks.add(track.filePath);
    }
    setState(() {});

    int successCount = 0;
    int failCount = 0;

    for (final track in _tracks) {
      try {
        final result = await UploadService.uploadDownloadedTrack(track);
        if (result['success'] == true) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }

      if (mounted) {
        setState(() {
          _uploadingTracks.remove(track.filePath);
        });
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Загружено: $successCount успешно, $failCount ошибок'),
        backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appModel = AppModelProvider.of(context);
    final isAuthorized = !appModel.isGuest;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: PanelHeader(
                    name: 'Внутреннее хранилище',
                    showBackButton: true,
                  ),
                ),
                IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : _loadTracks,
                  tooltip: 'Обновить список',
                ),
              ],
            ),
            if (isAuthorized &&
                _tracks.isNotEmpty &&
                !_isLoading &&
                _errorMessage == null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton.icon(
                  onPressed: _uploadingTracks.isEmpty
                      ? () => _uploadAllTracks()
                      : null,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Загрузить все треки на сервер'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
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
                                    _errorMessage!,
                                    style: theme.textTheme.bodyLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadTracks,
                                    child: const Text('Повторить'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _tracks.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.folder_off,
                                      size: 64,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Нет скачанных треков',
                                      style:
                                          theme.textTheme.bodyLarge?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16.0),
                                itemCount: _tracks.length,
                                itemBuilder: (context, index) {
                                  final track = _tracks[index];
                                  final isCurrentlyPlaying =
                                      _currentlyPlayingPath == track.filePath;
                                  final isUploading =
                                      _uploadingTracks.contains(track.filePath);
                                  return DownloadedTrackItem(
                                    track: track,
                                    isCurrentlyPlaying: isCurrentlyPlaying,
                                    isPlaying: isCurrentlyPlaying && _isPlaying,
                                    onPlay: () => _playTrack(track),
                                    onDelete: () => _deleteTrack(track),
                                    onLongPress: () => _openTrackDetails(track),
                                    onUpload: isAuthorized && !isUploading
                                        ? () => _uploadTrack(track)
                                        : null,
                                    showUploadButton: isAuthorized,
                                    isUploading: isUploading,
                                  );
                                },
                              ),
              ),
            ),
            // Плеер внизу экрана
            if (_currentlyPlayingPath != null)
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _tracks
                                    .firstWhere((t) =>
                                        t.filePath == _currentlyPlayingPath)
                                    .trackName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _tracks
                                    .firstWhere((t) =>
                                        t.filePath == _currentlyPlayingPath)
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
                              _seekTo(Duration(milliseconds: value.toInt()));
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
                          onPressed: _changePlaybackSpeed,
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
                              _currentlyPlayingPath = null;
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
