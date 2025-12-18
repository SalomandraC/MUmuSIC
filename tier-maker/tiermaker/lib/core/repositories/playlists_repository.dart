import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/playlist.dart';
import '../models/track.dart';

/// Репозиторий для работы с плейлистами
class PlaylistsRepository {
  static const String _playlistsKey = 'playlists';
  static Box<String>? _box;
  static int _nextId = 1;

  static Future<Box<String>> _ensureBox() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<String>('appBox');
    }
    return _box!;
  }

  /// Инициализация - загрузка следующего ID
  static Future<void> init() async {
    final playlists = await getAllPlaylists();
    if (playlists.isNotEmpty) {
      _nextId = playlists.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1;
    }
  }

  /// Получить все плейлисты
  static Future<List<Playlist>> getAllPlaylists() async {
    final box = await _ensureBox();
    final playlistsJson = box.get(_playlistsKey);
    if (playlistsJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(playlistsJson) as List<dynamic>;
      return jsonList
          .map((json) => Playlist.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Получить плейлист по ID
  static Future<Playlist?> getPlaylistById(int id) async {
    final playlists = await getAllPlaylists();
    try {
      return playlists.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Создать новый плейлист
  static Future<Playlist> createPlaylist({
    required String name,
    String description = '',
    String? coverImageUri,
  }) async {
    final playlist = Playlist(
      id: _nextId++,
      name: name,
      description: description,
      coverImageUri: coverImageUri,
      tracks: [],
    );

    final playlists = await getAllPlaylists();
    playlists.add(playlist);
    await _savePlaylists(playlists);

    return playlist;
  }

  /// Обновить плейлист
  static Future<void> updatePlaylist(Playlist playlist) async {
    final playlists = await getAllPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlist.id);
    if (index != -1) {
      playlists[index] = playlist;
      await _savePlaylists(playlists);
    }
  }

  /// Удалить плейлист
  static Future<void> deletePlaylist(int id) async {
    final playlists = await getAllPlaylists();
    playlists.removeWhere((p) => p.id == id);
    await _savePlaylists(playlists);
  }

  /// Добавить трек в плейлист
  static Future<void> addTrackToPlaylist(int playlistId, Track track) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) return;

    if (playlist.tracks.any((t) => t.id == track.id)) return;

    final updatedTracks = List<Track>.from(playlist.tracks);
    updatedTracks.add(track);

    final updatedPlaylist = Playlist(
      id: playlist.id,
      name: playlist.name,
      description: playlist.description,
      coverImageUri: playlist.coverImageUri,
      tracks: updatedTracks,
    );

    await updatePlaylist(updatedPlaylist);
  }

  /// Удалить трек из плейлиста
  static Future<void> removeTrackFromPlaylist(int playlistId, Track track) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) return;

    final updatedTracks = playlist.tracks.where((t) => t.id != track.id).toList();

    final updatedPlaylist = Playlist(
      id: playlist.id,
      name: playlist.name,
      description: playlist.description,
      coverImageUri: playlist.coverImageUri,
      tracks: updatedTracks,
    );

    await updatePlaylist(updatedPlaylist);
  }

  static Future<void> _savePlaylists(List<Playlist> playlists) async {
    final box = await _ensureBox();
    final jsonList = playlists.map((p) => p.toJson()).toList();
    await box.put(_playlistsKey, json.encode(jsonList));
  }
}

