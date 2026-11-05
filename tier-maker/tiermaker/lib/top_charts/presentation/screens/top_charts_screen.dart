import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mumusic/core/audio/player_adapters.dart';
import 'package:mumusic/core/audio/player_service.dart';
import 'package:mumusic/core/audio/player_track.dart';
import 'package:mumusic/core/api/top_chart_api.dart';
import 'package:mumusic/core/api/guest_tracks_api.dart';
import 'package:mumusic/core/global_widgets/panel_header.dart';
import 'package:mumusic/home/presentation/screens/universal_track_details_screen.dart';

class TopChartsScreen extends StatefulWidget {
  const TopChartsScreen({super.key});

  @override
  State<TopChartsScreen> createState() => _TopChartsScreenState();
}

class _TopChartsScreenState extends State<TopChartsScreen> {
  final ScrollController _scrollController = ScrollController();
  List<TopChart> _tracks = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTracks();
    PlayerService.instance.addListener(_onPlayerChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    PlayerService.instance.removeListener(_onPlayerChanged);
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

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  PlayerTrack _toPlayerTrack(TopChart track) => PlayerTrack(
        id: 'chart:${track.id}',
        title: track.title,
        artist: track.artist,
        resolveSource: () async {
          var streamUrl = track.streamUrl.isNotEmpty
              ? track.streamUrl
              : await TopChartApi.getTopChartStreamUrl(track.id);
          if (!streamUrl.startsWith('http')) {
            final base = await TopChartApi.getBaseUrl();
            streamUrl =
                base + (streamUrl.startsWith('/') ? '' : '/') + streamUrl;
          }
          return streamUrl;
        },
      );

  Future<void> _playTrack(TopChart track) => playFromList(
        context,
        _tracks.map(_toPlayerTrack).toList(),
        _toPlayerTrack(track).id,
      );
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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
                                  final playerId = _toPlayerTrack(track).id;
                                  final isCurrentlyPlaying =
                                      PlayerService.instance.isCurrent(playerId);
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
                                                PlayerService.instance.isPlayingTrack(playerId)
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
          ],
        ),
      ),
    );
  }
}
