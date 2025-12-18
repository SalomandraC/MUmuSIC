import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:RandomTierList/core/global_widgets/panel_header.dart';
import 'package:RandomTierList/home/domain/model/network_track_model.dart';
import 'package:RandomTierList/home/domain/model/downloaded_track_model.dart';
import 'package:RandomTierList/core/api/guest_tracks_api.dart';
import 'package:RandomTierList/domain/entities/track.dart' as domain;
import 'package:RandomTierList/domain/entities/playlist.dart';
import 'package:RandomTierList/domain/usecases/toggle_favorite_usecase.dart';
import 'package:RandomTierList/domain/usecases/add_track_to_playlist_usecase.dart';
import 'package:RandomTierList/domain/repositories/playlists_repository.dart';
import 'package:RandomTierList/domain/repositories/tracks_repository.dart';
import 'package:RandomTierList/di/dependency_injection.dart';
import 'package:RandomTierList/home/domain/usecase/download_track_usecase.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Универсальный экран подробной информации о треке
/// Поддерживает NetworkTrack, DownloadedTrack и GuestTrack
class UniversalTrackDetailsScreen extends StatefulWidget {
  final NetworkTrack? networkTrack;
  final DownloadedTrack? downloadedTrack;
  final GuestTrack? guestTrack;
  final bool isFavorite;

  const UniversalTrackDetailsScreen({
    super.key,
    this.networkTrack,
    this.downloadedTrack,
    this.guestTrack,
    this.isFavorite = false,
  }) : assert(
          (networkTrack != null &&
                  downloadedTrack == null &&
                  guestTrack == null) ||
              (networkTrack == null &&
                  downloadedTrack != null &&
                  guestTrack == null) ||
              (networkTrack == null &&
                  downloadedTrack == null &&
                  guestTrack != null),
          'Должен быть указан ровно один тип трека',
        );

  @override
  State<UniversalTrackDetailsScreen> createState() =>
      _UniversalTrackDetailsScreenState();
}

class _UniversalTrackDetailsScreenState
    extends State<UniversalTrackDetailsScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ToggleFavoriteUseCase _toggleFavoriteUseCase =
      DependencyInjection.toggleFavoriteUseCase;
  final AddTrackToPlaylistUseCase _addTrackToPlaylistUseCase =
      DependencyInjection.addTrackToPlaylistUseCase;
  final PlaylistsRepository _playlistsRepository =
      DependencyInjection.playlistsRepository;
  final TracksRepository _tracksRepository =
      DependencyInjection.tracksRepository;
  final DownloadTrackUseCase _downloadTrackUseCase =
      DependencyInjection.downloadTrackUseCase;

  bool _isFavorite = false;
  bool _isDownloading = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  String get _trackName {
    if (widget.networkTrack != null) return widget.networkTrack!.trackName;
    if (widget.downloadedTrack != null)
      return widget.downloadedTrack!.trackName;
    if (widget.guestTrack != null) return widget.guestTrack!.title;
    return '';
  }

  String get _artistName {
    if (widget.networkTrack != null) return widget.networkTrack!.artistName;
    if (widget.downloadedTrack != null)
      return widget.downloadedTrack!.artistName;
    if (widget.guestTrack != null) return widget.guestTrack!.artist;
    return '';
  }

  String get _durationString {
    if (widget.networkTrack != null) {
      final duration = widget.networkTrack!.formattedDuration;
      return duration.isNotEmpty ? duration : '0:00';
    }
    if (widget.downloadedTrack != null) {
      final duration = widget.downloadedTrack!.formattedDuration;
      return duration.isNotEmpty ? duration : '0:00';
    }
    if (widget.guestTrack != null) {
      final seconds = widget.guestTrack!.duration;
      if (seconds > 0) {
        final minutes = seconds ~/ 60;
        final secs = seconds % 60;
        return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
      }
      return '0:00';
    }
    return '0:00';
  }

  String? get _imageUrl {
    if (widget.networkTrack != null) {
      final url = widget.networkTrack!.artworkUrl100;
      if (url == null || url.isEmpty) return null;
      return url.replaceAll('100x100bb', '600x600bb');
    }
    return null;
  }

  bool get _canDownload =>
      widget.downloadedTrack == null; // Нельзя скачать уже скачанный трек

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
    _checkFavoriteStatus();

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

  Future<void> _checkFavoriteStatus() async {
    try {
      final entity = _mapToDomain();
      final isFavorite = await _tracksRepository.isFavorite(entity);
      if (mounted) {
        setState(() {
          _isFavorite = isFavorite;
        });
      }
    } catch (e) {
      // Игнорируем ошибки при проверке избранного
      debugPrint('Ошибка проверки избранного: $e');
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  domain.TrackEntity _mapToDomain() {
    if (widget.networkTrack != null) {
      final track = widget.networkTrack!;
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
    } else if (widget.downloadedTrack != null) {
      final track = widget.downloadedTrack!;
      final trackId = track.filePath.hashCode;
      return domain.TrackEntity(
        id: trackId,
        trackName: track.trackName,
        artistName: track.artistName,
        trackTime: track.formattedDuration,
        image: null,
        previewUrl: track.filePath,
        favorite: _isFavorite,
      );
    } else if (widget.guestTrack != null) {
      final track = widget.guestTrack!;
      final seconds = track.duration;
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      final durationString =
          '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
      return domain.TrackEntity(
        id: track.id,
        trackName: track.title,
        artistName: track.artist,
        trackTime: durationString,
        image: null,
        previewUrl: track.streamUrl.isNotEmpty ? track.streamUrl : track.url,
        favorite: _isFavorite,
      );
    }
    return domain.TrackEntity(
      id: 0,
      trackName: '',
      artistName: '',
      trackTime: '0:00',
      image: null,
      previewUrl: null,
      favorite: false,
    );
  }

  Future<void> _toggleFavorite() async {
    try {
      final entity = _mapToDomain();
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

  Future<void> _playTrack() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        return;
      }

      if (widget.networkTrack != null) {
        final url = widget.networkTrack!.previewUrl;
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
        await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
      } else if (widget.downloadedTrack != null) {
        await _audioPlayer.setAudioSource(
          AudioSource.file(widget.downloadedTrack!.filePath),
        );
      } else if (widget.guestTrack != null) {
        String streamUrl;
        if (widget.guestTrack!.streamUrl.isNotEmpty) {
          streamUrl = widget.guestTrack!.streamUrl;
        } else {
          streamUrl = await GuestTracksApi.getStreamUrl(widget.guestTrack!.id);
        }
        final uri = Uri.parse(streamUrl);
        if (uri.scheme != 'http' && uri.scheme != 'https') {
          throw Exception('Неподдерживаемая схема URI: ${uri.scheme}');
        }
        await _audioPlayer.setAudioSource(
          AudioSource.uri(uri, headers: {'accept': 'audio/mpeg'}),
        );
      }

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
    if (!_canDownload) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      if (widget.networkTrack != null) {
        // Скачивание NetworkTrack
        final filePath =
            await _downloadTrackUseCase.execute(widget.networkTrack!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Трек скачан: ${filePath.split('/').last}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      } else if (widget.guestTrack != null) {
        // Скачивание GuestTrack
        await _downloadGuestTrack(widget.guestTrack!);
      }
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

  Future<void> _downloadGuestTrack(GuestTrack track) async {
    try {
      // Проверяем разрешение на запись
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          final audioStatus = await Permission.audio.request();
          if (!audioStatus.isGranted) {
            throw Exception('Необходимо разрешение на доступ к хранилищу');
          }
        }
      }

      // Получаем директорию для сохранения
      final directory = await _getDownloadDirectory();
      final fileName =
          _sanitizeFileName('${track.artist} - ${track.title}.m4a');
      final filePath = '${directory.path}/$fileName';

      // Проверяем, существует ли файл
      final file = File(filePath);
      if (await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Файл уже существует'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Получаем URL для скачивания
      String downloadUrl;
      if (track.streamUrl.isNotEmpty) {
        downloadUrl = track.streamUrl;
      } else if (track.url.isNotEmpty) {
        downloadUrl = track.url;
      } else {
        throw Exception('URL для скачивания недоступен');
      }

      // Скачиваем файл
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Трек скачан: ${file.path.split('/').last}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Ошибка скачивания: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final directory = Directory('/storage/emulated/0/Download/MuMuSIC');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    }
  }

  String _sanitizeFileName(String fileName) {
    // Удаляем недопустимые символы для имени файла
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
        final trackEntity = _mapToDomain();
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
                          child: _imageUrl != null
                              ? Image.network(
                                  _imageUrl!,
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
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme
                                            .surfaceContainerHighest,
                                      ),
                                      child: Icon(
                                        Icons.library_music,
                                        size: 64,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme.surfaceContainerHighest,
                                  ),
                                  child: Icon(
                                    Icons.library_music,
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
                          _trackName,
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
                          _artistName,
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
                            _durationString,
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
                          if (_canDownload)
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
                            onPressed: _playTrack,
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
