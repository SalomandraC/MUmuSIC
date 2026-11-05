import 'dart:async';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mumusic/core/app_database/track_metadata_store.dart';
import 'package:mumusic/core/audio/player_adapters.dart';
import 'package:mumusic/core/audio/player_bar.dart' show formatDuration;
import 'package:mumusic/core/audio/player_service.dart';
import 'package:mumusic/core/audio/player_track.dart';
import 'package:mumusic/core/global_widgets/panel_header.dart';
import 'package:mumusic/home/domain/model/network_track_model.dart';
import 'package:mumusic/home/domain/model/downloaded_track_model.dart';
import 'package:mumusic/core/api/guest_tracks_api.dart';
import 'package:mumusic/domain/entities/track.dart' as domain;
import 'package:mumusic/domain/entities/playlist.dart';
import 'package:mumusic/domain/usecases/toggle_favorite_usecase.dart';
import 'package:mumusic/domain/usecases/add_track_to_playlist_usecase.dart';
import 'package:mumusic/domain/repositories/playlists_repository.dart';
import 'package:mumusic/domain/repositories/tracks_repository.dart';
import 'package:mumusic/di/dependency_injection.dart';
import 'package:mumusic/home/domain/usecase/download_track_usecase.dart';
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

  /// Пользовательские правки (название, подпись, обложка)
  TrackMetadata? _meta;

  /// Длительность, прочитанная из самого файла/потока
  Duration? _probedDuration;
  bool _probingDuration = false;

  String get _metaKey => _playerTrack.id;

  String get _trackName {
    if (_meta?.title?.isNotEmpty ?? false) return _meta!.title!;
    if (widget.networkTrack != null) return widget.networkTrack!.trackName;
    if (widget.downloadedTrack != null)
      return widget.downloadedTrack!.trackName;
    if (widget.guestTrack != null) return widget.guestTrack!.title;
    return '';
  }

  String get _artistName {
    if (_meta?.artist?.isNotEmpty ?? false) return _meta!.artist!;
    if (widget.networkTrack != null) return widget.networkTrack!.artistName;
    if (widget.downloadedTrack != null)
      return widget.downloadedTrack!.artistName;
    if (widget.guestTrack != null) return widget.guestTrack!.artist;
    return '';
  }

  String get _durationString {
    final playerDuration = PlayerService.instance.duration;
    if (_isCurrent && playerDuration > Duration.zero) {
      return formatDuration(playerDuration);
    }
    if (_probedDuration != null && _probedDuration! > Duration.zero) {
      return formatDuration(_probedDuration!);
    }
    if (_probingDuration) return '…';
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
    PlayerService.instance.addListener(_onPlayerChanged);
    _loadMeta();
    _probeDuration();
  }

  Future<void> _loadMeta() async {
    final meta = await TrackMetadataStore.get(_metaKey);
    if (mounted && meta != null) setState(() => _meta = meta);
  }

  /// У скачанных треков длительность не хранится, поэтому читаем её
  /// из файла (и у гостевых треков, если сервер её не прислал)
  Future<void> _probeDuration() async {
    ap.Source? source;
    if (widget.downloadedTrack != null &&
        (widget.downloadedTrack!.durationMillis ?? 0) <= 0) {
      source = ap.DeviceFileSource(widget.downloadedTrack!.filePath);
    } else if (widget.guestTrack != null && widget.guestTrack!.duration <= 0) {
      final url = widget.guestTrack!.streamUrl.isNotEmpty
          ? widget.guestTrack!.streamUrl
          : widget.guestTrack!.url;
      if (url.isNotEmpty) source = ap.UrlSource(url);
    }
    if (source == null) return;

    _probingDuration = true; // вызывается из initState, build ещё впереди
    final probe = ap.AudioPlayer();
    try {
      await probe.setReleaseMode(ap.ReleaseMode.stop);
      await probe.setSource(source).timeout(const Duration(seconds: 10));
      final d = await probe.getDuration();
      if (mounted) setState(() => _probedDuration = d);
    } catch (e) {
      debugPrint('Не удалось получить длительность трека: $e');
    } finally {
      await probe.dispose();
      if (mounted) setState(() => _probingDuration = false);
    }
  }

  Future<void> _saveMeta(TrackMetadata meta) async {
    try {
      await TrackMetadataStore.put(_metaKey, meta);
      if (!mounted) return;
      setState(() => _meta = meta.isEmpty ? null : meta);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось сохранить: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editInfo() async {
    final titleController = TextEditingController(text: _trackName);
    final artistController = TextEditingController(text: _artistName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить трек'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Название'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: artistController,
              decoration: const InputDecoration(labelText: 'Подпись'),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          if ((_meta?.title?.isNotEmpty ?? false) ||
              (_meta?.artist?.isNotEmpty ?? false))
            TextButton(
              onPressed: () => Navigator.of(context).pop('reset'),
              child: const Text('Сбросить'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    final title = titleController.text.trim();
    final artist = artistController.text.trim();
    titleController.dispose();
    artistController.dispose();
    if (result == null) return;

    if (result == 'reset') {
      await _saveMeta(TrackMetadata(coverPath: _meta?.coverPath));
    } else {
      await _saveMeta(TrackMetadata(
        title: title.isEmpty ? null : title,
        artist: artist.isEmpty ? null : artist,
        coverPath: _meta?.coverPath,
      ));
    }
  }

  Future<void> _changeCover() async {
    final hasCustom = _meta?.coverPath != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Выбрать из галереи'),
              onTap: () => Navigator.of(context).pop('pick'),
            ),
            if (hasCustom)
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Вернуть исходную обложку'),
                onTap: () => Navigator.of(context).pop('reset'),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;

    if (action == 'reset') {
      await _saveMeta(TrackMetadata(
        title: _meta?.title,
        artist: _meta?.artist,
      ));
      return;
    }

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (picked == null) return;
      final docs = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${docs.path}/covers');
      if (!await coversDir.exists()) await coversDir.create(recursive: true);
      final dot = picked.path.lastIndexOf('.');
      final ext = dot > 0 ? picked.path.substring(dot) : '.jpg';
      final target =
          '${coversDir.path}/${DateTime.now().millisecondsSinceEpoch}$ext';
      await File(picked.path).copy(target);
      await _saveMeta(TrackMetadata(
        title: _meta?.title,
        artist: _meta?.artist,
        coverPath: target,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось выбрать картинку: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    PlayerService.instance.removeListener(_onPlayerChanged);
    super.dispose();
  }

  domain.TrackEntity _mapToDomain() {
    if (widget.networkTrack != null) {
      final track = widget.networkTrack!;
      final trackId = track.trackId ?? track.uniqueId.hashCode;
      return domain.TrackEntity(
        id: trackId,
        trackName: _trackName,
        artistName: _artistName,
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
        trackName: _trackName,
        artistName: _artistName,
        trackTime: _durationString,
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
        trackName: _trackName,
        artistName: _artistName,
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

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  PlayerTrack get _playerTrack {
    if (widget.networkTrack != null)
      return widget.networkTrack!.toPlayerTrack();
    if (widget.downloadedTrack != null) {
      return widget.downloadedTrack!.toPlayerTrack();
    }
    return widget.guestTrack!.toPlayerTrack();
  }

  bool get _isCurrent => PlayerService.instance.isCurrent(_playerTrack.id);
  bool get _isPlaying => PlayerService.instance.isPlayingTrack(_playerTrack.id);

  Future<void> _playTrack() async {
    final player = PlayerService.instance;
    final track = _playerTrack;
    try {
      if (_isCurrent) {
        await player.togglePlayPause();
        return;
      }
      if (!track.hasSource) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Превью для этого трека недоступно'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      await player.playSingle(track);
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

  Future<void> _stopTrack() async {
    if (_isCurrent) await PlayerService.instance.stop();
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
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _meta?.coverPath != null
                                  ? Image.file(
                                      File(_meta!.coverPath!),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) => Icon(
                                        Icons.library_music,
                                        size: 64,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    )
                                  : _imageUrl != null
                                      ? Image.network(
                                          _imageUrl!,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child,
                                              loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Container(
                                              color: theme.colorScheme
                                                  .surfaceContainerHighest,
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
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme
                                                    .surfaceContainerHighest,
                                              ),
                                              child: Icon(
                                                Icons.library_music,
                                                size: 64,
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme
                                                .surfaceContainerHighest,
                                          ),
                                          child: Icon(
                                            Icons.library_music,
                                            size: 64,
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                            ),
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: IconButton.filledTonal(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Изменить обложку',
                                onPressed: _changeCover,
                              ),
                            ),
                          ],
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _editInfo,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Изменить название и подпись'),
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
                              '${PlayerService.instance.speed}x',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: PlayerService.instance.cycleSpeed,
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
                      // Прогресс берём из общего плеера, если играет этот трек
                      if (_isCurrent) ...[
                        const SizedBox(height: 24),
                        ValueListenableBuilder<Duration>(
                          valueListenable: PlayerService.instance.position,
                          builder: (context, position, _) {
                            final total = PlayerService.instance.duration;
                            final max = total.inMilliseconds > 0
                                ? total.inMilliseconds.toDouble()
                                : 1.0;
                            final labelStyle =
                                theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            );
                            return Row(
                              children: [
                                Text(formatDuration(position),
                                    style: labelStyle),
                                Expanded(
                                  child: Slider(
                                    value: position.inMilliseconds
                                        .toDouble()
                                        .clamp(0.0, max),
                                    max: max,
                                    onChanged: total.inMilliseconds > 0
                                        ? (v) => PlayerService.instance.seek(
                                            Duration(milliseconds: v.toInt()))
                                        : null,
                                  ),
                                ),
                                Text(formatDuration(total), style: labelStyle),
                              ],
                            );
                          },
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
