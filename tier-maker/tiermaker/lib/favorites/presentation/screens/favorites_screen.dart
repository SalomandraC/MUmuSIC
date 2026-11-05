import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mumusic/core/audio/player_adapters.dart';
import 'package:mumusic/core/audio/player_service.dart';
import 'package:mumusic/core/global_widgets/panel_header.dart';
import 'package:mumusic/domain/entities/track.dart';
import 'package:mumusic/domain/usecases/get_favorites_usecase.dart';
import 'package:mumusic/domain/usecases/toggle_favorite_usecase.dart';
import 'package:mumusic/di/dependency_injection.dart';
import 'package:mumusic/search/presentation/widgets/track_item.dart';
import 'package:mumusic/home/domain/model/network_track_model.dart';
import 'package:mumusic/home/presentation/screens/universal_track_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final GetFavoritesUseCase _getFavoritesUseCase =
      DependencyInjection.getFavoritesUseCase;
  final ToggleFavoriteUseCase _toggleFavoriteUseCase =
      DependencyInjection.toggleFavoriteUseCase;

  List<TrackEntity> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    PlayerService.instance.addListener(_onPlayerChanged);
  }

  @override
  void dispose() {
    PlayerService.instance.removeListener(_onPlayerChanged);
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

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _playTrack(TrackEntity track) => playFromList(
        context,
        (_favorites).map((t) => t.toPlayerTrack()).toList(),
        track.toPlayerTrack().id,
      );
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
                                      PlayerService.instance.isCurrent(track.toPlayerTrack().id),
                                  isPlaying: PlayerService.instance.isPlayingTrack(track.toPlayerTrack().id),
                                  onPlay: () => _playTrack(track),
                                  onFavorite: () => _toggleFavorite(track),
                                  showFavoriteButton: false,
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
