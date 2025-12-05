/// Модель трека из сети (iTunes)
class NetworkTrack {
  final int? trackId;
  final String trackName;
  final String artistName;
  final int? trackTimeMillis;
  final String? previewUrl;
  final String? artworkUrl100;

  NetworkTrack({
    this.trackId,
    required this.trackName,
    required this.artistName,
    this.trackTimeMillis,
    this.previewUrl,
    this.artworkUrl100,
  });

  String get formattedDuration {
    if (trackTimeMillis == null) return '0:00';
    final seconds = (trackTimeMillis! / 1000).round();
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String get uniqueId => trackId?.toString() ?? '${trackName}_$artistName';
}

