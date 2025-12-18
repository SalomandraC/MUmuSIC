import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/track_dto.dart';
import '../../models/playlist_dto.dart';

/// Локальный источник данных для хранения треков и плейлистов
abstract class LocalStorageDataSource {
  Future<List<TrackDto>> getFavorites();
  Future<void> saveFavorites(List<TrackDto> tracks);
  Future<List<String>> getSearchHistory();
  Future<void> saveSearchHistory(List<String> history);
  Future<List<PlaylistDto>> getPlaylists();
  Future<void> savePlaylists(List<PlaylistDto> playlists);
}

class LocalStorageDataSourceImpl implements LocalStorageDataSource {
  static const String _boxName = 'appBox';
  static const String _favoritesKey = 'favorites';
  static const String _searchHistoryKey = 'searchHistory';
  static const String _playlistsKey = 'playlists';
  static Box<String>? _box;

  Future<Box<String>> _ensureBox() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<String>(_boxName);
    }
    return _box!;
  }

  @override
  Future<List<TrackDto>> getFavorites() async {
    final box = await _ensureBox();
    final favoritesJson = box.get(_favoritesKey);
    if (favoritesJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(favoritesJson) as List<dynamic>;
      return jsonList
          .map((json) => TrackDto.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> saveFavorites(List<TrackDto> tracks) async {
    final box = await _ensureBox();
    final jsonList = tracks.map((t) => t.toJson()).toList();
    await box.put(_favoritesKey, json.encode(jsonList));
  }

  @override
  Future<List<String>> getSearchHistory() async {
    final box = await _ensureBox();
    final historyJson = box.get(_searchHistoryKey);
    if (historyJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(historyJson) as List<dynamic>;
      return jsonList.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> saveSearchHistory(List<String> history) async {
    final box = await _ensureBox();
    await box.put(_searchHistoryKey, json.encode(history));
  }

  @override
  Future<List<PlaylistDto>> getPlaylists() async {
    final box = await _ensureBox();
    final playlistsJson = box.get(_playlistsKey);
    if (playlistsJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(playlistsJson) as List<dynamic>;
      return jsonList
          .map((json) => PlaylistDto.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> savePlaylists(List<PlaylistDto> playlists) async {
    final box = await _ensureBox();
    final jsonList = playlists.map((p) => p.toJson()).toList();
    await box.put(_playlistsKey, json.encode(jsonList));
  }
}

