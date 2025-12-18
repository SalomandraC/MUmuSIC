import '../../domain/entities/track.dart';

/// DTO модель трека из iTunes API
class TrackDto {
  final int trackId;
  final String? trackName;
  final String? artistName;
  final int? trackTimeMillis;
  final String? artworkUrl100;
  final String? previewUrl;

  TrackDto({
    required this.trackId,
    this.trackName,
    this.artistName,
    this.trackTimeMillis,
    this.artworkUrl100,
    this.previewUrl,
  });

  factory TrackDto.fromJson(Map<String, dynamic> json) {
    return TrackDto(
      trackId: json['trackId'] as int,
      trackName: json['trackName'] as String?,
      artistName: json['artistName'] as String?,
      trackTimeMillis: json['trackTimeMillis'] as int?,
      artworkUrl100: json['artworkUrl100'] as String?,
      previewUrl: json['previewUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trackId': trackId,
      'trackName': trackName,
      'artistName': artistName,
      'trackTimeMillis': trackTimeMillis,
      'artworkUrl100': artworkUrl100,
      'previewUrl': previewUrl,
    };
  }

  /// Создание DTO из доменной сущности
  static TrackDto fromEntity(TrackEntity entity) {
    // Парсим время обратно в миллисекунды
    final timeParts = entity.trackTime.split(':');
    final minutes = int.tryParse(timeParts[0]) ?? 0;
    final seconds = int.tryParse(timeParts[1]) ?? 0;
    final trackTimeMillis = (minutes * 60 + seconds) * 1000;

    return TrackDto(
      trackId: entity.id,
      trackName: entity.trackName,
      artistName: entity.artistName,
      trackTimeMillis: trackTimeMillis,
      artworkUrl100: entity.image,
      previewUrl: entity.previewUrl,
    );
  }

  /// Преобразование DTO в доменную сущность
  TrackEntity toEntity() {
    final trackTimeMillis = this.trackTimeMillis ?? 0;
    final minutes = trackTimeMillis ~/ 60000;
    final seconds = (trackTimeMillis % 60000) ~/ 1000;
    final trackTime = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return TrackEntity(
      id: trackId,
      trackName: trackName ?? '',
      artistName: artistName ?? '',
      trackTime: trackTime,
      image: artworkUrl100,
      previewUrl: previewUrl,
    );
  }
}

