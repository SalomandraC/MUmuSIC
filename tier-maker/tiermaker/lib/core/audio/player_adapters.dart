import 'package:flutter/material.dart';
import 'package:mumusic/core/audio/player_service.dart';
import 'package:mumusic/core/audio/player_track.dart';
import 'package:mumusic/core/api/guest_tracks_api.dart';
import 'package:mumusic/domain/entities/track.dart';
import 'package:mumusic/home/domain/model/downloaded_track_model.dart';
import 'package:mumusic/home/domain/model/network_track_model.dart';

/// Преобразования моделей экранов в [PlayerTrack].
extension TrackEntityPlayer on TrackEntity {
  PlayerTrack toPlayerTrack() => PlayerTrack(
        id: 'entity:$id',
        title: trackName,
        artist: artistName,
        source: previewUrl ?? '',
        artworkUrl: image,
      );
}

extension DownloadedTrackPlayer on DownloadedTrack {
  PlayerTrack toPlayerTrack() => PlayerTrack(
        id: 'file:$filePath',
        title: trackName,
        artist: artistName,
        source: filePath,
      );
}

extension NetworkTrackPlayer on NetworkTrack {
  PlayerTrack toPlayerTrack() => PlayerTrack(
        id: 'network:$uniqueId',
        title: trackName,
        artist: artistName,
        source: previewUrl ?? '',
        artworkUrl: artworkUrl100,
      );
}

extension GuestTrackPlayer on GuestTrack {
  PlayerTrack toPlayerTrack() => PlayerTrack(
        id: 'guest:$id',
        title: title,
        artist: artist,
        source: streamUrl,
        resolveSource:
            streamUrl.isEmpty ? () => GuestTracksApi.getStreamUrl(id) : null,
      );
}

/// Общая логика нажатия на трек в списке: строим очередь из треков,
/// у которых есть что играть, и запускаем/ставим на паузу выбранный.
/// Ошибки показываем снекбаром.
Future<void> playFromList(
  BuildContext context,
  List<PlayerTrack> tracks,
  String trackId,
) async {
  final playable = tracks.where((t) => t.hasSource).toList();
  final index = playable.indexWhere((t) => t.id == trackId);
  if (index == -1) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Превью для этого трека недоступно'),
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }
  try {
    await PlayerService.instance.toggleFromList(playable, index);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ошибка воспроизведения: $e'),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red,
      ),
    );
  }
}
