import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/track.dart';

/// Репозиторий для работы с треками
class TracksRepository {
  static const String _favoritesKey = 'favorites';
  static const String _searchHistoryKey = 'searchHistory';
  static Box<String>? _box;

  static Future<Box<String>> _ensureBox() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<String>('appBox');
    }
    return _box!;
  }

  /// Получить список избранных треков
  static Future<List<Track>> getFavorites() async {
    final box = await _ensureBox();
    final favoritesJson = box.get(_favoritesKey);
    if (favoritesJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(favoritesJson) as List<dynamic>;
      return jsonList
          .map((json) => Track.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Добавить трек в избранное
  static Future<void> addToFavorites(Track track) async {
    final favorites = await getFavorites();
    if (favorites.any((t) => t.id == track.id)) return;

    final updatedTrack = Track(
      id: track.id,
      trackName: track.trackName,
      artistName: track.artistName,
      trackTime: track.trackTime,
      image: track.image,
      previewUrl: track.previewUrl,
      favorite: true,
      playlistId: track.playlistId,
    );

    favorites.add(updatedTrack);
    await _saveFavorites(favorites);
  }

  /// Удалить трек из избранного
  static Future<void> removeFromFavorites(Track track) async {
    final favorites = await getFavorites();
    favorites.removeWhere((t) => t.id == track.id);
    await _saveFavorites(favorites);
  }

  /// Переключить статус избранного
  static Future<void> toggleFavorite(Track track) async {
    final favorites = await getFavorites();
    if (favorites.any((t) => t.id == track.id)) {
      await removeFromFavorites(track);
    } else {
      await addToFavorites(track);
    }
  }

  /// Проверить, является ли трек избранным
  static Future<bool> isFavorite(Track track) async {
    final favorites = await getFavorites();
    return favorites.any((t) => t.id == track.id);
  }

  static Future<void> _saveFavorites(List<Track> favorites) async {
    final box = await _ensureBox();
    final jsonList = favorites.map((t) => t.toJson()).toList();
    await box.put(_favoritesKey, json.encode(jsonList));
  }

  /// Получить историю поиска
  static Future<List<String>> getSearchHistory() async {
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

  /// Добавить запрос в историю поиска
  static Future<void> addToSearchHistory(String query) async {
    if (query.trim().isEmpty) return;

    final history = await getSearchHistory();
    history.remove(query.trim());
    history.insert(0, query.trim());

    // Ограничиваем историю 10 записями
    if (history.length > 10) {
      history.removeRange(10, history.length);
    }

    final box = await _ensureBox();
    await box.put(_searchHistoryKey, json.encode(history));
  }

  /// Очистить историю поиска
  static Future<void> clearSearchHistory() async {
    final box = await _ensureBox();
    await box.delete(_searchHistoryKey);
  }
}

