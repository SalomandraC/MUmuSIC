/// Модель трека из iTunes API
class Track {
  final int id;
  final String trackName;
  final String artistName;
  final String trackTime;
  final String? image;
  final String? previewUrl;
  bool favorite;
  int playlistId;

  Track({
    required this.id,
    required this.trackName,
    required this.artistName,
    required this.trackTime,
    this.image,
    this.previewUrl,
    this.favorite = false,
    this.playlistId = 0,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    final trackTimeMillis = json['trackTimeMillis'] as int? ?? 0;
    final minutes = trackTimeMillis ~/ 60000;
    final seconds = (trackTimeMillis % 60000) ~/ 1000;
    final trackTime = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Track(
      id: json['trackId'] as int,
      trackName: json['trackName'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      trackTime: trackTime,
      image: json['artworkUrl100'] as String?,
      previewUrl: json['previewUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trackName': trackName,
      'artistName': artistName,
      'trackTime': trackTime,
      'image': image,
      'previewUrl': previewUrl,
      'favorite': favorite,
      'playlistId': playlistId,
    };
  }

  String get highQualityImage {
    if (image == null) return '';
    return image!.replaceAll('100x100bb', '600x600bb');
  }
}

