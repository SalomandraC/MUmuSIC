import '../../domain/entities/playlist.dart';
import 'track_dto.dart';

/// DTO модель плейлиста для хранения
class PlaylistDto {
  final int id;
  final String name;
  final String description;
  final String? coverImageUri;
  final List<TrackDto> tracks;

  PlaylistDto({
    required this.id,
    required this.name,
    this.description = '',
    this.coverImageUri,
    required this.tracks,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'coverImageUri': coverImageUri,
      'tracks': tracks.asMap().entries.map((entry) {
        final trackJson = entry.value.toJson();
        trackJson['position'] = entry.key;
        return trackJson;
      }).toList(),
    };
  }

  factory PlaylistDto.fromJson(Map<String, dynamic> json) {
    return PlaylistDto(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      coverImageUri: json['coverImageUri'] as String?,
      tracks: (json['tracks'] as List<dynamic>?)
              ?.map((t) => TrackDto.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Преобразование DTO в доменную сущность
  PlaylistEntity toEntity() {
    return PlaylistEntity(
      id: id,
      name: name,
      description: description,
      coverImageUri: coverImageUri,
      tracks: tracks.map((t) => t.toEntity()).toList(),
    );
  }

  /// Создание DTO из доменной сущности
  factory PlaylistDto.fromEntity(PlaylistEntity entity) {
    return PlaylistDto(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      coverImageUri: entity.coverImageUri,
      tracks: entity.tracks.map((t) => TrackDto.fromEntity(t)).toList(),
    );
  }
}


