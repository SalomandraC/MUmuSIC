import 'track.dart';

class PlaylistEntity {
  final int id;
  final String name;
  final String description;
  final String? coverImageUri;
  final List<TrackEntity> tracks;

  PlaylistEntity({
    required this.id,
    required this.name,
    this.description = '',
    this.coverImageUri,
    required this.tracks,
  });

  PlaylistEntity copyWith({
    int? id,
    String? name,
    String? description,
    String? coverImageUri,
    List<TrackEntity>? tracks,
  }) {
    return PlaylistEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverImageUri: coverImageUri ?? this.coverImageUri,
      tracks: tracks ?? this.tracks,
    );
  }
}
