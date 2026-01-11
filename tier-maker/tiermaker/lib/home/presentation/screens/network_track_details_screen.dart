import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:RandomTierList/core/global_widgets/panel_header.dart';
import 'package:RandomTierList/domain/entities/track.dart' as domain;
import 'package:RandomTierList/domain/entities/playlist.dart';
import 'package:RandomTierList/domain/usecases/toggle_favorite_usecase.dart';
import 'package:RandomTierList/domain/usecases/add_track_to_playlist_usecase.dart';
import 'package:RandomTierList/domain/repositories/playlists_repository.dart';
import 'package:RandomTierList/di/dependency_injection.dart';
import 'package:RandomTierList/home/domain/model/network_track_model.dart';
import 'package:RandomTierList/home/domain/usecase/download_track_usecase.dart';

/// Экран подробной информации о треке из вкладки сети
class NetworkTrackDetailsScreen extends StatefulWidget {
  final NetworkTrack track;
  final bool isFavorite;

  const NetworkTrackDetailsScreen({
    super.key,
    required this.track,
    required this.isFavorite,
  });

  @override
  State<NetworkTrackDetailsScreen> createState() =>
      _NetworkTrackDetailsScreenState();
}

class _NetworkTrackDetailsScreenState extends State<NetworkTrackDetailsScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ToggleFavoriteUseCase _toggleFavoriteUseCase =
      DependencyInjection.toggleFavoriteUseCase;
  final AddTrackToPlaylistUseCase _addTrackToPlaylistUseCase =
      DependencyInjection.addTrackToPlaylistUseCase;
  final PlaylistsRepository _playlistsRepository =
      DependencyInjection.playlistsRepository;
  final DownloadTrackUseCase _downloadTrackUseCase =
      DependencyInjection.downloadTrackUseCase;

  bool _isDownloading = false;

  bool _isFavorite = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;

    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
      });
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

  domain.TrackEntity _mapToDomain(NetworkTrack track) {
    final trackId = track.trackId ?? track.uniqueId.hashCode;
    return domain.TrackEntity(
      id: trackId,
      trackName: track.trackName,
      artistName: track.artistName,
      trackTime: track.formattedDuration,
      image: track.artworkUrl100,
      previewUrl: track.previewUrl,
      favorite: _isFavorite,
    );
  }

  Future<void> _toggleFavorite() async {
    try {
      final entity = _mapToDomain(widget.track);
      final updated = await _toggleFavoriteUseCase.execute(entity);
      if (!mounted) return;
      setState(() {
        _isFavorite = updated.favorite;
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

  Future<void> _playPreview() async {
    final url = widget.track.previewUrl;
    if (url == null || url.isEmpty) {
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

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        return;
      }
      if (_audioPlayer.processingState == ProcessingState.ready) {
        await _audioPlayer.play();
        return;
      }

      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(url)),
      );
      await _audioPlayer.play();
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка воспроизведения: ${e.message ?? e.code}'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка воспроизведения: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
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

  Future<void> _stopTrack() async {
    await _audioPlayer.stop();
    setState(() {
      _position = Duration.zero;
    });
  }

  Future<void> _downloadTrack() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final filePath = await _downloadTrackUseCase.execute(widget.track);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Трек скачан: ${filePath.split('/').last}'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка скачивания: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  /// Получить URL изображения высокого качества
  String? _getHighQualityImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.replaceAll('100x100bb', '600x600bb');
  }

  Future<void> _showAddToPlaylistDialog() async {
    try {
      final playlists = await _playlistsRepository.getAllPlaylists();

      if (playlists.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сначала создайте плейлист'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      if (!mounted) return;
      final selectedPlaylist = await showDialog<PlaylistEntity>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Добавить в плейлист'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return ListTile(
                  leading: playlist.coverImageUri != null
                      ? Image.network(
                          playlist.coverImageUri!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.library_music,
                              color: Theme.of(context).colorScheme.primary,
                            );
                          },
                        )
                      : Icon(
                          Icons.library_music,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  title: Text(playlist.name),
                  subtitle: playlist.description.isNotEmpty
                      ? Text(playlist.description)
                      : null,
                  trailing: Text(
                    '${playlist.tracks.length} треков',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () {
                    Navigator.of(context).pop(playlist);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
          ],
        ),
      );

      if (selectedPlaylist != null) {
        final trackEntity = _mapToDomain(widget.track);
        await _addTrackToPlaylistUseCase.execute(
          playlistId: selectedPlaylist.id,
          track: trackEntity,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Трек добавлен в "${selectedPlaylist.name}"'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка добавления в плейлист: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = widget.track;
    final highQualityImageUrl = _getHighQualityImageUrl(track.artworkUrl100);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PanelHeader(
              name: '',
              showBackButton: true,
              onBackClick: () {
                Navigator.of(context).pop(true);
              },
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                ),
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 260,
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: highQualityImageUrl != null
                              ? Image.network(
                                  highQualityImageUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: theme
                                          .colorScheme.surfaceContainerHighest,
                                      alignment: Alignment.center,
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                        color: theme.colorScheme.primary,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: theme
                                          .colorScheme.surfaceContainerHighest,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.music_note,
                                        size: 64,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.music_note,
                                    size: 64,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          track.trackName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          track.artistName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Длительность',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            track.formattedDuration,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                iconSize: 48,
                                icon: Icon(
                                  _isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: _isFavorite ? Colors.red : null,
                                ),
                                onPressed: _toggleFavorite,
                                tooltip: _isFavorite
                                    ? 'Удалить из избранного'
                                    : 'Добавить в избранное',
                              ),
                              Text(
                                'В избранное',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                iconSize: 48,
                                icon: const Icon(Icons.playlist_add),
                                onPressed: _showAddToPlaylistDialog,
                                tooltip: 'Добавить в плейлист',
                              ),
                              Text(
                                'В плейлист',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                iconSize: 48,
                                icon: _isDownloading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.download),
                                onPressed:
                                    _isDownloading ? null : _downloadTrack,
                                tooltip: 'Скачать',
                              ),
                              Text(
                                'Скачать',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
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
                            iconSize: 56,
                            icon: Icon(
                              _isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed: _playPreview,
                            tooltip: _isPlaying ? 'Пауза' : 'Прослушать',
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.stop),
                            onPressed: _stopTrack,
                            tooltip: 'Остановить',
                          ),
                        ],
                      ),
                      // Плеер с контролами
                      if (_duration.inMilliseconds > 0 || _isPlaying) ...[
                        const SizedBox(height: 24),
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
                                    ? (_position.inMilliseconds.toDouble())
                                        .clamp(0.0,
                                            _duration.inMilliseconds.toDouble())
                                    : 0.0,
                                max: _duration.inMilliseconds > 0
                                    ? _duration.inMilliseconds.toDouble()
                                    : 1.0,
                                onChanged: (value) {
                                  _seekTo(
                                      Duration(milliseconds: value.toInt()));
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
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
