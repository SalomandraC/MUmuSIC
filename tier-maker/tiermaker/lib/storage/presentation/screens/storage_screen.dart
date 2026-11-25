import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:mumusic/core/audio/pocket_command.dart';
import 'package:mumusic/core/audio/title_match.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mumusic/core/audio/player_adapters.dart';
import 'package:mumusic/core/audio/player_service.dart';
import 'package:mumusic/core/global_widgets/panel_header.dart';
import 'package:mumusic/home/domain/model/downloaded_track_model.dart';
import 'package:mumusic/home/domain/repository/i_downloaded_tracks_repository.dart';
import 'package:mumusic/home/domain/repository/downloaded_tracks_repository_impl.dart';
import 'package:mumusic/home/domain/usecase/get_downloaded_tracks_usecase.dart';
import 'package:mumusic/home/domain/usecase/delete_downloaded_track_usecase.dart';
import 'package:mumusic/home/domain/usecase/import_tracks_from_downloads_usecase.dart';
import 'package:mumusic/storage/presentation/widgets/downloaded_track_item.dart';
import 'package:mumusic/home/presentation/screens/universal_track_details_screen.dart';
import 'package:mumusic/core/services/upload_service.dart';
import 'package:mumusic/app/state/app_model_provider.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  bool _listening = false;

  Future<void> _voicePlay() async {
    setState(() => _listening = true);
    try {
      final phrase = await const MethodChannel('mumusic/speech')
          .invokeMethod<String>('listen');
      if (!mounted || phrase == null || phrase.trim().isEmpty) return;
      final title = await PocketCommand.extractTitle(phrase);
      if (!mounted) return;
      final index = matchTrackTitle(title, _tracks.map((t) => t.trackName).toList());
      if (index < 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('«$phrase» — уточните название трека из хранилища.'),
        ));
        return;
      }
      await PlayerService.instance.playSingle(_tracks[index].toPlayerTrack());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Голосовой запуск: $e'),
        ));
      }
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }
  final IDownloadedTracksRepository _repository =
      DownloadedTracksRepositoryImpl();
  late final GetDownloadedTracksUseCase _getDownloadedTracksUseCase;
  late final DeleteDownloadedTrackUseCase _deleteDownloadedTrackUseCase;
  late final ImportTracksFromDownloadsUseCase _importTracksUseCase;

  List<DownloadedTrack> _tracks = [];
  bool _isLoading = true;
  String? _errorMessage;
  Set<String> _uploadingTracks = {};
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _getDownloadedTracksUseCase = GetDownloadedTracksUseCase(_repository);
    _deleteDownloadedTrackUseCase = DeleteDownloadedTrackUseCase(_repository);
    _importTracksUseCase = ImportTracksFromDownloadsUseCase(_repository);
    PlayerService.instance.addListener(_onPlayerChanged);
    _loadTracks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем список при возврате на экран
    _loadTracks();
  }

  @override
  void dispose() {
    PlayerService.instance.removeListener(_onPlayerChanged);
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

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _playTrack(DownloadedTrack track) => playFromList(
        context,
        _tracks.map((t) => t.toPlayerTrack()).toList(),
        track.toPlayerTrack().id,
      );
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
        await PlayerService.instance.removeTrack(track.toPlayerTrack().id);
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

  /// Запрос разрешения на чтение аудиофайлов.
  /// Android 13+ — READ_MEDIA_AUDIO, ниже — READ_EXTERNAL_STORAGE
  Future<bool> _requestAudioReadPermission() async {
    if (!Platform.isAndroid) return true;

    final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    final permission = sdkInt >= 33 ? Permission.audio : Permission.storage;

    var status = await permission.status;
    if (status.isGranted || status.isLimited) return true;

    status = await permission.request();
    if (status.isGranted || status.isLimited) return true;

    if (!mounted) return false;
    if (status.isPermanentlyDenied) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Нужен доступ к музыке'),
          content: const Text(
              'Разрешите приложению доступ к аудиофайлам в настройках, '
              'чтобы добавлять треки из загрузок.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Настройки'),
            ),
          ],
        ),
      );
      if (openSettings == true) await openAppSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Без разрешения нельзя прочитать загрузки'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
    return false;
  }

  Future<void> _importFromDownloads() async {
    if (_isImporting) return;

    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Импорт из загрузок доступен только на Android'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!await _requestAudioReadPermission()) return;

    setState(() => _isImporting = true);
    List<DownloadedTrack> candidates;
    try {
      candidates = await _importTracksUseCase.findImportable();
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка чтения загрузок: $e'),
            backgroundColor: const Color.fromARGB(255, 251, 126, 118),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _isImporting = false);

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('В загрузках нет новых аудиофайлов'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<List<DownloadedTrack>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ImportTracksSheet(tracks: candidates),
    );
    if (selected == null || selected.isEmpty || !mounted) return;

    setState(() => _isImporting = true);
    int imported = 0;
    try {
      imported = await _importTracksUseCase.execute(selected);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
    if (!mounted) return;

    await _loadTracks();
    if (!mounted) return;
    final failed = selected.length - imported;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failed == 0
            ? 'Добавлено треков: $imported'
            : 'Добавлено: $imported, ошибок: $failed'),
        backgroundColor: failed == 0 ? Colors.green : Colors.orange,
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
                if (Platform.isAndroid)
                  IconButton(
                    tooltip: 'Назвать трек по-английски',
                    icon: Icon(_listening ? Icons.hourglass_top : Icons.mic),
                    onPressed: _listening || _tracks.isEmpty || _isLoading ? null : _voicePlay,
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
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                onPressed: _isImporting || _isLoading
                    ? null
                    : () => _importFromDownloads(),
                icon: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_for_offline_outlined),
                label: const Text('Добавить треки из загрузок'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
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
                                  final playerId = track.toPlayerTrack().id;
                                  final isCurrentlyPlaying =
                                      PlayerService.instance.isCurrent(playerId);
                                  final isUploading =
                                      _uploadingTracks.contains(track.filePath);
                                  return DownloadedTrackItem(
                                    track: track,
                                    isCurrentlyPlaying: isCurrentlyPlaying,
                                    isPlaying: PlayerService.instance.isPlayingTrack(playerId),
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
          ],
        ),
      ),
    );
  }
}

/// Нижняя панель выбора аудиофайлов из «Загрузок»
class _ImportTracksSheet extends StatefulWidget {
  final List<DownloadedTrack> tracks;

  const _ImportTracksSheet({required this.tracks});

  @override
  State<_ImportTracksSheet> createState() => _ImportTracksSheetState();
}

class _ImportTracksSheetState extends State<_ImportTracksSheet> {
  late final Set<String> _selected =
      widget.tracks.map((t) => t.filePath).toSet();

  bool get _allSelected => _selected.length == widget.tracks.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Треки в загрузках (${widget.tracks.length})',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      if (_allSelected) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(widget.tracks.map((t) => t.filePath));
                      }
                    }),
                    child: Text(_allSelected ? 'Снять все' : 'Выбрать все'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.tracks.length,
                itemBuilder: (context, index) {
                  final track = widget.tracks[index];
                  return CheckboxListTile(
                    value: _selected.contains(track.filePath),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _selected.add(track.filePath);
                      } else {
                        _selected.remove(track.filePath);
                      }
                    }),
                    title: Text(
                      track.trackName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      track.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    secondary: const Icon(Icons.audio_file_outlined),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                          widget.tracks
                              .where((t) => _selected.contains(t.filePath))
                              .toList(),
                        ),
                icon: const Icon(Icons.add),
                label: Text('Добавить (${_selected.length})'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
