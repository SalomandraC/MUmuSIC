/// Доменная сущность трека
class TrackEntity {
  final int id;
  final String trackName;
  final String artistName;
  final String trackTime;
  final String? image;
  final String? previewUrl;
  final bool favorite;
  final int playlistId;

  TrackEntity({
    required this.id,
    required this.trackName,
    required this.artistName,
    required this.trackTime,
    this.image,
    this.previewUrl,
    this.favorite = false,
    this.playlistId = 0,
  });

  TrackEntity copyWith({
    int? id,
    String? trackName,
    String? artistName,
    String? trackTime,
    String? image,
    String? previewUrl,
    bool? favorite,
    int? playlistId,
  }) {
    return TrackEntity(
      id: id ?? this.id,
      trackName: trackName ?? this.trackName,
      artistName: artistName ?? this.artistName,
      trackTime: trackTime ?? this.trackTime,
      image: image ?? this.image,
      previewUrl: previewUrl ?? this.previewUrl,
      favorite: favorite ?? this.favorite,
      playlistId: playlistId ?? this.playlistId,
    );
  }

  String get highQualityImage {
    if (image == null) return '';
    return image!.replaceAll('100x100bb', '600x600bb');
  }
}

