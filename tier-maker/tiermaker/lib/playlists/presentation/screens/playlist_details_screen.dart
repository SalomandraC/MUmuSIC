import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mumusic/core/audio/player_adapters.dart';
import 'package:mumusic/core/audio/player_service.dart';
import 'package:mumusic/core/global_widgets/panel_header.dart';
import 'package:mumusic/domain/entities/playlist.dart';
import 'package:mumusic/domain/entities/track.dart';
import 'package:mumusic/domain/repositories/playlists_repository.dart';
import 'package:mumusic/di/dependency_injection.dart';
import 'package:mumusic/search/presentation/widgets/track_item.dart';
import 'package:mumusic/home/domain/model/network_track_model.dart';
import 'package:mumusic/home/presentation/screens/universal_track_details_screen.dart';

class PlaylistDetailsScreen extends StatefulWidget {
  final int playlistId;

  const PlaylistDetailsScreen({
    super.key,
    required this.playlistId,
  });

  @override
  State<PlaylistDetailsScreen> createState() => _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends State<PlaylistDetailsScreen> {
  final PlaylistsRepository _playlistsRepository =
      DependencyInjection.playlistsRepository;

  PlaylistEntity? _playlist;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
    PlayerService.instance.addListener(_onPlayerChanged);
  }

  @override
  void dispose() {
    PlayerService.instance.removeListener(_onPlayerChanged);
    super.dispose();
  }

  Future<void> _loadPlaylist() async {
    setState(() {
      _isLoading = true;
    });

    final playlist =
        await _playlistsRepository.getPlaylistById(widget.playlistId);
    setState(() {
      _playlist = playlist;
      _isLoading = false;
    });
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _playTrack(TrackEntity track) => playFromList(
        context,
        (_playlist?.tracks ?? const <TrackEntity>[]).map((t) => t.toPlayerTrack()).toList(),
        track.toPlayerTrack().id,
      );

  NetworkTrack _trackEntityToNetworkTrack(TrackEntity track) {
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
          isFavorite: track.favorite,
        ),
      ),
    );

    if (result == true) {
      await _loadPlaylist();
    }
  }

  Future<void> _removeTrack(TrackEntity track) async {
    if (_playlist == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить трек?'),
        content: Text('Удалить "${track.trackName}" из плейлиста?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _playlistsRepository.removeTrackFromPlaylist(
        _playlist!.id,
        track,
      );
      await _loadPlaylist();
    }
  }

  String _formatPlaylistInfo(List<TrackEntity> tracks) {
    if (tracks.isEmpty) return 'Нет треков';
    final count = tracks.length;
    final lastDigit = count % 10;
    final lastTwoDigits = count % 100;

    if (lastTwoDigits >= 11 && lastTwoDigits <= 14) {
      return '$count треков';
    } else if (lastDigit == 1) {
      return '$count трек';
    } else if (lastDigit >= 2 && lastDigit <= 4) {
      return '$count трека';
    } else {
      return '$count треков';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const PanelHeader(
                name: 'Плейлист',
                showBackButton: true,
              ),
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      );
    }

    if (_playlist == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const PanelHeader(
                name: 'Плейлист',
                showBackButton: true,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Плейлист не найден',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PanelHeader(
              name: '',
              showBackButton: true,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 205,
                          height: 205,
                          child: _playlist!.coverImageUri != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    _playlist!.coverImageUri!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Icon(
                                          Icons.library_music,
                                          size: 64,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.library_music,
                                    size: 64,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _playlist!.name,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_playlist!.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _playlist!.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        _formatPlaylistInfo(_playlist!.tracks),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('В разработке'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      if (_playlist!.tracks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32.0),
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
                                'Плейлист пуст',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 16.0),
                          itemCount: _playlist!.tracks.length,
                          itemBuilder: (context, index) {
                            final track = _playlist!.tracks[index];
                            return GestureDetector(
                              onLongPress: () => _removeTrack(track),
                              child: Column(
                                children: [
                                  TrackItem(
                                    track: track,
                                    isCurrentlyPlaying:
                                        PlayerService.instance.isCurrent(track.toPlayerTrack().id),
                                    isPlaying: PlayerService.instance.isPlayingTrack(track.toPlayerTrack().id),
                                    onPlay: () => _playTrack(track),
                                    onFavorite: () {},
                                    onTap: () => _openTrackDetails(track),
                                  ),
                                  if (index < _playlist!.tracks.length - 1)
                                    Divider(
                                      thickness: 0.5,
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.2),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
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
