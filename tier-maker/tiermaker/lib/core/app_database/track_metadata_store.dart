import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';

/// Пользовательские правки трека: название, подпись (исполнитель) и обложка.
class TrackMetadata {
  final String? title;
  final String? artist;
  final String? coverPath;

  const TrackMetadata({this.title, this.artist, this.coverPath});

  bool get isEmpty =>
      (title == null || title!.isEmpty) &&
      (artist == null || artist!.isEmpty) &&
      (coverPath == null || coverPath!.isEmpty);

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (artist != null) 'artist': artist,
        if (coverPath != null) 'coverPath': coverPath,
      };

  factory TrackMetadata.fromJson(Map<String, dynamic> json) => TrackMetadata(
        title: json['title'] as String?,
        artist: json['artist'] as String?,
        coverPath: json['coverPath'] as String?,
      );
}

/// Локальное хранилище правок треков (Hive). Ключ — id трека в плеере
/// (например `file:/storage/...`), так правки видны во всех экранах.
class TrackMetadataStore {
  static const String _boxName = 'trackMetadata';
  static Box<String>? _box;

  static Future<Box<String>> _ensureBox() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<String>(_boxName);
    }
    return _box!;
  }

  static Future<TrackMetadata?> get(String key) async {
    final box = await _ensureBox();
    final raw = box.get(key);
    if (raw == null) return null;
    try {
      return TrackMetadata.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> put(String key, TrackMetadata meta) async {
    final box = await _ensureBox();
    final old = await get(key);
    if (old?.coverPath != null && old!.coverPath != meta.coverPath) {
      await _deleteCover(old.coverPath!);
    }
    if (meta.isEmpty) {
      await box.delete(key);
    } else {
      await box.put(key, jsonEncode(meta.toJson()));
    }
  }

  static Future<void> remove(String key) async {
    final box = await _ensureBox();
    final old = await get(key);
    if (old?.coverPath != null) await _deleteCover(old!.coverPath!);
    await box.delete(key);
  }

  static Future<void> _deleteCover(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
