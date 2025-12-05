import 'package:flutter/material.dart';
import 'package:RandomTierList/home/domain/model/network_track_model.dart';

/// Модель состояния для экрана сети
class NetworkModel extends ChangeNotifier {
  List<NetworkTrack> _tracks = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;
  String? _currentlyPlayingId;
  bool _isPlaying = false;
  Map<String, bool> _downloadingTracks = {};

  List<NetworkTrack> get tracks => _tracks;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;
  String? get currentlyPlayingId => _currentlyPlayingId;
  bool get isPlaying => _isPlaying;
  bool isDownloading(String trackId) => _downloadingTracks[trackId] ?? false;

  void setTracks(List<NetworkTrack> tracks) {
    _tracks = tracks;
    _errorMessage = null;
    notifyListeners();
  }

  void setLoading(bool isLoading) {
    _isLoading = isLoading;
    notifyListeners();
  }

  void setSearching(bool isSearching) {
    _isSearching = isSearching;
    notifyListeners();
  }

  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void setCurrentlyPlaying(String? trackId) {
    _currentlyPlayingId = trackId;
    notifyListeners();
  }

  void setPlaying(bool playing) {
    _isPlaying = playing;
    notifyListeners();
  }

  void setDownloading(String trackId, bool downloading) {
    if (downloading) {
      _downloadingTracks[trackId] = true;
    } else {
      _downloadingTracks.remove(trackId);
    }
    notifyListeners();
  }

  void clear() {
    _tracks = [];
    _errorMessage = null;
    _currentlyPlayingId = null;
    _isPlaying = false;
    notifyListeners();
  }
}

