/// Модель скачанного трека из внутреннего хранилища
class DownloadedTrack {
  final String filePath;
  final String fileName;
  final String trackName;
  final String artistName;
  final int? durationMillis;
  final DateTime? dateAdded;

  DownloadedTrack({
    required this.filePath,
    required this.fileName,
    required this.trackName,
    required this.artistName,
    this.durationMillis,
    this.dateAdded,
  });

  String get formattedDuration {
    if (durationMillis == null) return '0:00';
    final seconds = (durationMillis! / 1000).round();
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

