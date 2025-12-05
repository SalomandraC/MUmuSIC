import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:RandomTierList/core/api/guest_tracks_api.dart';
import 'package:RandomTierList/core/global_widgets/panel_header.dart';

class GuestTracksScreen extends StatefulWidget {
  const GuestTracksScreen({super.key});

  @override
  State<GuestTracksScreen> createState() => _GuestTracksScreenState();
}

class _GuestTracksScreenState extends State<GuestTracksScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<GuestTrack> _tracks = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _currentlyPlayingId;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _loadTracks();

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    // Подписываемся на позицию воспроизведения
    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration ?? Duration.zero;
        });
      }
    });

    _audioPlayer.processingStateStream.listen((processingState) {
      debugPrint(
          '🔄 [GuestTracksScreen] ProcessingState изменился: $processingState');
    });

    _audioPlayer.playbackEventStream.listen((event) {
      debugPrint(
          '🎵 [GuestTracksScreen] PlaybackEvent: ${event.processingState}, currentIndex=${event.currentIndex}');
    }, onError: (error) {
      debugPrint('❌ [GuestTracksScreen] Ошибка в playbackEventStream: $error');
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tracks = await GuestTracksApi.getGuestTracks();
      setState(() {
        _tracks = tracks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки треков: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _playTrack(GuestTrack track) async {
    try {
      if (_currentlyPlayingId == track.id && _isPlaying) {
        // Если трек уже играет, ставим на паузу
        debugPrint('⏸️ [GuestTracksScreen] Пауза трека: ${track.title}');
        await _audioPlayer.pause();
      } else {
        debugPrint(
            '▶️ [GuestTracksScreen] Начало воспроизведения трека: ${track.title} (ID: ${track.id})');

        // Останавливаем текущий трек, если играет другой
        if (_currentlyPlayingId != null) {
          debugPrint('⏹️ [GuestTracksScreen] Остановка предыдущего трека');
          await _audioPlayer.stop();
        }

        // Используем streamUrl из объекта трека, если доступен, иначе формируем URL
        String streamUrl;
        if (track.streamUrl.isNotEmpty) {
          streamUrl = track.streamUrl;
          debugPrint(
              '🔵 [GuestTracksScreen] Используем streamUrl из объекта: $streamUrl');
        } else {
          // Формируем URL по ID (более надежно, чем по названию)
          streamUrl = await GuestTracksApi.getStreamUrl(track.id);
          debugPrint(
              '🔵 [GuestTracksScreen] Сформирован streamUrl по ID: $streamUrl');
        }

        debugPrint('🔵 [GuestTracksScreen] Итоговый Stream URL: $streamUrl');

        // Парсим URI и проверяем его валидность
        final uri = Uri.parse(streamUrl);
        debugPrint('🔵 [GuestTracksScreen] Парсинг URI: $uri');
        debugPrint(
            '🔵 [GuestTracksScreen] URI scheme: ${uri.scheme}, host: ${uri.host}, port: ${uri.port}, path: ${uri.path}');

        if (uri.scheme != 'http' && uri.scheme != 'https') {
          throw Exception(
              'Неподдерживаемая схема URI: ${uri.scheme}. Ожидается http или https');
        }

        // Проверяем доступность URL перед использованием
        debugPrint('🔵 [GuestTracksScreen] Проверка доступности URL...');
        try {
          final headResponse = await http.head(uri).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('⏱️ [GuestTracksScreen] Таймаут при проверке URL');
              throw TimeoutException(
                  'Превышено время ожидания при проверке URL');
            },
          );
          debugPrint(
              '🔵 [GuestTracksScreen] HEAD запрос: статус=${headResponse.statusCode}, content-type=${headResponse.headers['content-type']}');
          if (headResponse.statusCode != 200 &&
              headResponse.statusCode != 206) {
            debugPrint(
                '⚠️ [GuestTracksScreen] Неожиданный статус код: ${headResponse.statusCode}');
          }
        } catch (e) {
          debugPrint(
              '⚠️ [GuestTracksScreen] Предупреждение при проверке URL: $e (продолжаем попытку воспроизведения)');
        }

        debugPrint('🔵 [GuestTracksScreen] Создание AudioSource.uri...');
        final audioSource = AudioSource.uri(
          uri,
          headers: {
            'accept': 'audio/mpeg',
          },
        );
        debugPrint(
            '🔵 [GuestTracksScreen] AudioSource создан, установка источника...');
        try {
          await _audioPlayer.setAudioSource(audioSource);
          debugPrint('✅ [GuestTracksScreen] Аудио источник установлен успешно');
        } catch (e, stackTrace) {
          debugPrint(
              '❌ [GuestTracksScreen] Ошибка при установке источника: $e');
          debugPrint('❌ [GuestTracksScreen] Тип ошибки: ${e.runtimeType}');
          debugPrint('❌ [GuestTracksScreen] Stack trace: $stackTrace');
          throw Exception('Не удалось загрузить аудио: $e');
        }

        // Ждем, пока плеер обработает источник
        debugPrint('⏳ [GuestTracksScreen] Ожидание готовности плеера...');
        int attempts = 0;
        const maxAttempts = 20; // Увеличиваем до 20 попыток (4 секунды)
        bool isReady = false;

        while (attempts < maxAttempts) {
          final state = _audioPlayer.playerState;
          final processingState = state.processingState;
          debugPrint(
              '🔄 [GuestTracksScreen] Попытка ${attempts + 1}/$maxAttempts: processingState=$processingState, playing=${state.playing}');

          if (processingState == ProcessingState.ready) {
            debugPrint('✅ [GuestTracksScreen] Плеер готов к воспроизведению');
            isReady = true;
            break;
          }

          // Проверяем, что состояние не idle после попыток загрузки
          if (attempts > 5 && processingState == ProcessingState.idle) {
            final errorMessage =
                'Плеер не смог загрузить источник. Состояние: $processingState';
            debugPrint('❌ [GuestTracksScreen] $errorMessage');
            throw Exception(errorMessage);
          }

          // Если состояние loading или buffering, продолжаем ждать
          if (processingState == ProcessingState.loading ||
              processingState == ProcessingState.buffering) {
            debugPrint('⏳ [GuestTracksScreen] Плеер загружает/буферизует...');
          }

          await Future.delayed(const Duration(milliseconds: 200));
          attempts++;
        }

        // Проверяем финальное состояние
        final playerState = _audioPlayer.playerState;
        debugPrint(
            '🎵 [GuestTracksScreen] Финальное состояние: playing=${playerState.playing}, processingState=${playerState.processingState}');

        if (!isReady && playerState.processingState != ProcessingState.ready) {
          final errorMsg =
              'Плеер не готов к воспроизведению после $maxAttempts попыток. Состояние: ${playerState.processingState}';
          debugPrint('❌ [GuestTracksScreen] $errorMsg');
          throw Exception(errorMsg);
        }

        // Начинаем воспроизведение
        debugPrint('▶️ [GuestTracksScreen] Запуск воспроизведения...');
        try {
          await _audioPlayer.play();
          debugPrint('✅ [GuestTracksScreen] Команда play() выполнена');
        } catch (e) {
          debugPrint('❌ [GuestTracksScreen] Ошибка при вызове play(): $e');
          throw Exception('Не удалось начать воспроизведение: $e');
        }

        // Ждем и проверяем, что воспроизведение началось
        await Future.delayed(const Duration(milliseconds: 1000));
        final stateAfterPlay = _audioPlayer.playerState;
        debugPrint(
            '🎵 [GuestTracksScreen] Состояние плеера после play: playing=${stateAfterPlay.playing}, processingState=${stateAfterPlay.processingState}');

        if (!stateAfterPlay.playing) {
          debugPrint('⚠️ [GuestTracksScreen] Плеер не начал воспроизведение!');
          if (stateAfterPlay.processingState == ProcessingState.idle) {
            throw Exception(
                'Ошибка обработки аудио. Проверьте формат файла и URL.');
          }
        } else {
          debugPrint('✅ [GuestTracksScreen] Воспроизведение запущено успешно');
        }

        setState(() {
          _currentlyPlayingId = track.id;
        });
      }
    } on PlatformException catch (e) {
      debugPrint(
          '❌ [GuestTracksScreen] PlatformException: ${e.code} - ${e.message}');
      debugPrint('❌ [GuestTracksScreen] Details: ${e.details}');
      debugPrint('❌ [GuestTracksScreen] Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Ошибка воспроизведения: ${e.message ?? e.code}\nПроверьте формат аудио и подключение к серверу'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [GuestTracksScreen] Ошибка воспроизведения: $e');
      debugPrint('❌ [GuestTracksScreen] Тип ошибки: ${e.runtimeType}');
      debugPrint('❌ [GuestTracksScreen] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Ошибка воспроизведения: ${e.toString()}\nПроверьте подключение к серверу'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopTrack() async {
    await _audioPlayer.stop();
    setState(() {
      _currentlyPlayingId = null;
      _isPlaying = false;
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDurationFromDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _searchTrack() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return;
    }

    // Ищем трек по названию или исполнителю
    final foundIndex = _tracks.indexWhere((track) {
      return track.title.toLowerCase().contains(query) ||
          track.artist.toLowerCase().contains(query);
    });

    if (foundIndex != -1) {
      // Прокручиваем к найденному треку
      final itemHeight = 80.0; // Примерная высота элемента списка
      final scrollOffset = foundIndex * itemHeight;

      _scrollController.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Показываем сообщение, если трек не найден
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Трек не найден'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _changePlaybackSpeed() {
    setState(() {
      if (_playbackSpeed >= 2.0) {
        _playbackSpeed = 0.5;
      } else if (_playbackSpeed >= 1.5) {
        _playbackSpeed = 2.0;
      } else if (_playbackSpeed >= 1.0) {
        _playbackSpeed = 1.5;
      } else {
        _playbackSpeed = 1.0;
      }
      _audioPlayer.setSpeed(_playbackSpeed);
    });
  }

  void _seekTo(Duration position) {
    _audioPlayer.seek(position);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PanelHeader(
              name: 'Сеть',
              showBackButton: true,
            ),
            // Строка поиска
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.surface,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Поиск трека...',
                        prefixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _searchTrack,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                      onSubmitted: (_) => _searchTrack(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: theme.colorScheme.error,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Ошибка подключения',
                                    style:
                                        theme.textTheme.headlineSmall?.copyWith(
                                      color: theme.colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorMessage!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: _loadTracks,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Повторить'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _tracks.isEmpty
                            ? Center(
                                child: Text(
                                  'Треки не найдены',
                                  style: theme.textTheme.bodyLarge,
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                itemCount: _tracks.length,
                                itemBuilder: (context, index) {
                                  final track = _tracks[index];
                                  final isCurrentlyPlaying =
                                      _currentlyPlayingId == track.id;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    color: isCurrentlyPlaying
                                        ? theme.colorScheme.primaryContainer
                                            .withValues(alpha: 0.3)
                                        : null,
                                    child: ListTile(
                                      leading: IconButton(
                                        icon: Icon(
                                          isCurrentlyPlaying && _isPlaying
                                              ? Icons.pause_circle_filled
                                              : Icons.play_circle_filled,
                                          color: isCurrentlyPlaying
                                              ? theme.colorScheme.primary
                                              : theme
                                                  .colorScheme.onSurfaceVariant,
                                          size: 40,
                                        ),
                                        onPressed: () => _playTrack(track),
                                      ),
                                      title: Text(
                                        track.title,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: isCurrentlyPlaying
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isCurrentlyPlaying
                                              ? theme.colorScheme.primary
                                              : null,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (track.artist.isNotEmpty)
                                            Text(
                                              track.artist,
                                              style: theme.textTheme.bodyMedium,
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatDuration(track.duration),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: isCurrentlyPlaying
                                          ? Icon(
                                              Icons.graphic_eq,
                                              color: theme.colorScheme.primary,
                                            )
                                          : null,
                                      onTap: () => _playTrack(track),
                                      enableFeedback: false,
                                    ),
                                  );
                                },
                              ),
              ),
            ),
            if (_currentlyPlayingId != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _tracks
                                    .firstWhere(
                                        (t) => t.id == _currentlyPlayingId)
                                    .title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _tracks
                                    .firstWhere(
                                        (t) => t.id == _currentlyPlayingId)
                                    .artist,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _formatDurationFromDuration(_position),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _duration.inMilliseconds > 0
                                ? _position.inMilliseconds.toDouble()
                                : 0.0,
                            max: _duration.inMilliseconds > 0
                                ? _duration.inMilliseconds.toDouble()
                                : 1.0,
                            onChanged: (value) {
                              _seekTo(Duration(milliseconds: value.toInt()));
                            },
                          ),
                        ),
                        Text(
                          _formatDurationFromDuration(_duration),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Text(
                            '${_playbackSpeed}x',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _changePlaybackSpeed,
                          tooltip: 'Скорость воспроизведения',
                        ),
                        const SizedBox(width: 8),
                        // Кнопка паузы/воспроизведения
                        IconButton(
                          iconSize: 48,
                          icon: Icon(
                            _isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () {
                            if (_isPlaying) {
                              _audioPlayer.pause();
                            } else {
                              _audioPlayer.play();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        // Кнопка остановки
                        IconButton(
                          icon: const Icon(Icons.stop),
                          onPressed: _stopTrack,
                          tooltip: 'Остановить',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
