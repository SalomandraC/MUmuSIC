import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:mumusic/core/audio/player_track.dart';

/// Единый плеер приложения.
///
/// Раньше у каждого экрана был свой `AudioPlayer` из just_audio, и
/// `await play()` возвращался только по окончании трека, поэтому
/// текущий трек в UI обновлялся с опозданием (отсюда «двойные нажатия»
/// и чужое название в плашке). Теперь состояние одно на всё приложение,
/// а переключение защищено от гонок счётчиком [_loadGeneration].
class PlayerService extends ChangeNotifier {
  PlayerService._() {
    _player.setReleaseMode(ReleaseMode.stop);
    _subscriptions.addAll([
      _player.onPlayerStateChanged.listen(_onStateChanged),
      _player.onPositionChanged.listen((p) => position.value = p),
      _player.onDurationChanged.listen((d) {
        _duration = d;
        notifyListeners();
      }),
      _player.onPlayerComplete.listen((_) => _onComplete()),
    ]);
  }

  static final PlayerService instance = PlayerService._();

  static const List<double> speeds = [0.5, 1.0, 1.25, 1.5, 2.0];

  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Позиция обновляется часто, поэтому вынесена отдельно,
  /// чтобы не перестраивать списки на каждый тик.
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);

  List<PlayerTrack> _queue = const [];
  int _index = -1;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  double _speed = 1.0;
  String? _lastError;
  int _loadGeneration = 0;

  List<PlayerTrack> get queue => _queue;
  int get index => _index;
  PlayerTrack? get current =>
      _index >= 0 && _index < _queue.length ? _queue[_index] : null;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get duration => _duration;
  double get speed => _speed;
  String? get lastError => _lastError;
  bool get hasNext => _index >= 0 && _index < _queue.length - 1;
  bool get hasPrevious => _index > 0;

  bool isCurrent(String trackId) => current?.id == trackId;
  bool isPlayingTrack(String trackId) => isCurrent(trackId) && _isPlaying;

  /// Нажатие на трек в списке: если он уже текущий — пауза/продолжить,
  /// иначе запускаем очередь [tracks] с позиции [startIndex].
  Future<void> toggleFromList(List<PlayerTrack> tracks, int startIndex) async {
    if (startIndex < 0 || startIndex >= tracks.length) return;
    if (isCurrent(tracks[startIndex].id)) {
      // Обновляем очередь (список мог измениться), не перезапуская трек
      _queue = List.unmodifiable(tracks);
      _index = startIndex;
      await togglePlayPause();
      return;
    }
    await playQueue(tracks, startIndex);
  }

  Future<void> playQueue(List<PlayerTrack> tracks, int startIndex) async {
    if (startIndex < 0 || startIndex >= tracks.length) return;
    _queue = List.unmodifiable(tracks);
    await _playAt(startIndex);
  }

  Future<void> playSingle(PlayerTrack track) => playQueue([track], 0);

  Future<void> togglePlayPause() async {
    if (current == null) return;
    if (_isPlaying) {
      await _player.pause();
    } else if (_player.state == PlayerState.paused) {
      await _player.resume();
    } else {
      // Трек был остановлен или закончился — запускаем заново
      await _playAt(_index);
    }
  }

  Future<void> next() async {
    if (hasNext) await _playAt(_index + 1);
  }

  /// Как в обычных плеерах: если трек играет дольше 3 секунд —
  /// перематываем в начало, иначе переходим к предыдущему.
  Future<void> previous() async {
    if (position.value > const Duration(seconds: 3) || !hasPrevious) {
      await seek(Duration.zero);
      return;
    }
    await _playAt(_index - 1);
  }

  Future<void> seek(Duration to) => _player.seek(to);

  Future<void> cycleSpeed() async {
    final i = speeds.indexOf(_speed);
    await setSpeed(speeds[(i + 1) % speeds.length]);
  }

  Future<void> setSpeed(double value) async {
    _speed = value;
    notifyListeners();
    if (_isPlaying) await _player.setPlaybackRate(value);
  }

  /// Полная остановка и очистка очереди (скрывает плашку плеера).
  Future<void> stop() async {
    _loadGeneration++;
    await _player.stop();
    _queue = const [];
    _index = -1;
    _isPlaying = false;
    _isLoading = false;
    _duration = Duration.zero;
    position.value = Duration.zero;
    notifyListeners();
  }

  /// Убирает трек из очереди (например, после удаления файла).
  Future<void> removeTrack(String trackId) async {
    if (isCurrent(trackId)) {
      await stop();
      return;
    }
    final i = _queue.indexWhere((t) => t.id == trackId);
    if (i == -1) return;
    _queue = List.unmodifiable([..._queue]..removeAt(i));
    if (i < _index) _index--;
    notifyListeners();
  }

  Future<void> _playAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final generation = ++_loadGeneration;
    final track = _queue[index];

    // Сразу обновляем текущий трек, чтобы UI не отставал от нажатий
    _index = index;
    _isLoading = true;
    _lastError = null;
    _duration = Duration.zero;
    position.value = Duration.zero;
    notifyListeners();

    try {
      await _player.stop();
      final source = track.source.isNotEmpty
          ? track.source
          : await track.resolveSource!.call();
      if (generation != _loadGeneration) return; // уже переключились дальше

      await _player.play(_toSource(source));
      if (generation != _loadGeneration) return;
      if (_speed != 1.0) await _player.setPlaybackRate(_speed);
    } catch (e) {
      if (generation != _loadGeneration) return;
      _lastError = 'Не удалось воспроизвести «${track.title}»: $e';
      debugPrint('[PlayerService] $_lastError');
      rethrow;
    } finally {
      if (generation == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Source _toSource(String source) {
    final uri = Uri.tryParse(source);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return UrlSource(source);
    }
    if (uri != null && uri.scheme == 'file') {
      return DeviceFileSource(uri.toFilePath());
    }
    return DeviceFileSource(source);
  }

  void _onStateChanged(PlayerState state) {
    final playing = state == PlayerState.playing;
    if (playing != _isPlaying) {
      _isPlaying = playing;
      notifyListeners();
    }
  }

  Future<void> _onComplete() async {
    position.value = _duration;
    if (hasNext) {
      try {
        await next();
      } catch (_) {
        // Ошибка уже сохранена в lastError и показывается в плашке
      }
    } else {
      _isPlaying = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player.dispose();
    position.dispose();
    super.dispose();
  }
}
