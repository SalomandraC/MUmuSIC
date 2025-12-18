import 'track.dart';

/// Модель плейлиста
class Playlist {
  final int id;
  final String name;
  final String description;
  final String? coverImageUri;
  final List<Track> tracks;

  Playlist({
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
      'tracks': tracks.map((t) => t.toJson()).toList(),
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      coverImageUri: json['coverImageUri'] as String?,
      tracks: (json['tracks'] as List<dynamic>?)
              ?.map((t) => Track.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

