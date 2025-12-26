import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:http/http.dart' as http;
import 'package:RandomTierList/core/api/guest_tracks_api.dart';
import 'package:RandomTierList/core/global_widgets/panel_header.dart';

// Platform channel для обработки NFC intent'ов
const MethodChannel _nfcChannel = MethodChannel('com.example.tiermaker/nfc');

class NfcScreen extends StatefulWidget {
  const NfcScreen({super.key});

  @override
  State<NfcScreen> createState() => _NfcScreenState();
}

class _NfcScreenState extends State<NfcScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isNfcAvailable = false;
  bool _isListening = false;
  String? _lastReadTag;
  String? _currentTrackTitle;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  String _removeEnPrefix(String text) {
    if (text.isEmpty) return text;
    var cleaned = text;
    while (cleaned.isNotEmpty && cleaned.codeUnitAt(0) < 32) {
      debugPrint(
          '🔵 [NfcScreen] Удален невидимый символ: 0x${cleaned.codeUnitAt(0).toRadixString(16)}');
      cleaned = cleaned.substring(1);
    }

    cleaned = cleaned.trimLeft();

    if (cleaned.length >= 2) {
      final firstTwo = cleaned.substring(0, 2).toLowerCase();
      if (firstTwo == 'en') {
        final result = cleaned.substring(2).trim();
        debugPrint(
            '🔵 [NfcScreen] Убран префикс "en" (было: "$text", стало: "$result")');
        return result;
      }
    }

    return cleaned;
  }

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
    _checkNfcIntent();

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });

        if (state.processingState == ProcessingState.completed) {
          debugPrint('✅ [NfcScreen] Воспроизведение завершено');
          if (mounted) {
            setState(() {
              _isPlaying = false;
              if (_duration.inMilliseconds > 0) {
                _position = _duration;
              }
            });
          }
        }
      }
    }, onError: (error) {
      debugPrint('❌ [NfcScreen] Ошибка в playerStateStream: $error');
    });

    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    }, onError: (error) {
      debugPrint('❌ [NfcScreen] Ошибка в positionStream: $error');
    });

    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration ?? Duration.zero;
        });
      }
    }, onError: (error) {
      debugPrint('❌ [NfcScreen] Ошибка в durationStream: $error');
    });

    _audioPlayer.processingStateStream.listen((processingState) {
      debugPrint('🔄 [NfcScreen] ProcessingState изменился: $processingState');

      if (processingState == ProcessingState.completed) {
        debugPrint('✅ [NfcScreen] Обработка завершена');
        if (mounted) {
          setState(() {
            _isPlaying = false;
            if (_duration.inMilliseconds > 0) {
              _position = _duration;
            }
          });
        }
      }
    }, onError: (error) {
      debugPrint('❌ [NfcScreen] Ошибка в processingStateStream: $error');
    });
    _audioPlayer.playbackEventStream.listen((event) {
      debugPrint(
          '🎵 [NfcScreen] PlaybackEvent: ${event.processingState}, currentIndex=${event.currentIndex}');
      if (event.processingState == ProcessingState.completed) {
        debugPrint(
            '✅ [NfcScreen] Воспроизведение завершено через playbackEventStream');
        if (mounted) {
          setState(() {
            _isPlaying = false;
            if (_duration.inMilliseconds > 0) {
              _position = _duration;
            }
          });
        }
      }
    }, onError: (error) {
      debugPrint('❌ [NfcScreen] Ошибка в playbackEventStream: $error');
      // Не показываем ошибку пользователю, если это просто завершение трека
      if (mounted && error.toString().contains('completed') == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка воспроизведения: $error'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _stopListening();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkNfcIntent() async {
    try {
      // Проверяем, был ли перехвачен NFC intent от Android
      final hasIntent = await _nfcChannel.invokeMethod<bool>('getNfcIntent');
      if (hasIntent == true) {
        debugPrint(
            '🔵 [NfcScreen] Обнаружен NFC intent, начинаем сканирование...');
        // Если был перехвачен intent, автоматически начинаем сканирование
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startListening();
        });
      }
    } catch (e) {
      debugPrint('⚠️ [NfcScreen] Ошибка проверки NFC intent: $e');
    }
  }

  Future<void> _checkNfcAvailability() async {
    try {
      final availability = await FlutterNfcKit.nfcAvailability;
      final isAvailable = availability == NFCAvailability.available;
      setState(() {
        _isNfcAvailable = isAvailable;
      });
      debugPrint(
          '🔵 [NfcScreen] NFC доступность: $availability, доступно: $isAvailable');

      if (!isAvailable) {
        String message = 'NFC недоступен';
        if (availability == NFCAvailability.disabled) {
          message = 'NFC отключен. Включите NFC в настройках устройства.';
        } else if (availability != NFCAvailability.available) {
          message = 'NFC недоступен: $availability';
        }
        debugPrint('⚠️ [NfcScreen] $message');
      }
    } catch (e) {
      debugPrint('⚠️ [NfcScreen] Ошибка проверки доступности NFC: $e');
      setState(() {
        _isNfcAvailable = false;
      });
    }
  }

  Future<void> _startListening() async {
    // Проверяем доступность NFC перед началом
    await _checkNfcAvailability();

    if (!_isNfcAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'NFC недоступен на этом устройстве. Включите NFC в настройках.'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isListening = true;
    });

    try {
      debugPrint('🔵 [NfcScreen] Начало сканирования NFC...');
      debugPrint('🔵 [NfcScreen] Проверка доступности перед poll...');

      // Дополнительная проверка перед poll
      try {
        final availability = await FlutterNfcKit.nfcAvailability;
        debugPrint('🔵 [NfcScreen] NFC доступность перед poll: $availability');
        if (availability != NFCAvailability.available) {
          throw Exception('NFC недоступен: $availability');
        }
      } catch (e) {
        debugPrint('❌ [NfcScreen] NFC недоступен перед poll: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'NFC недоступен: $e\nВключите NFC в настройках устройства.'),
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isListening = false;
          });
        }
        return;
      }

      // Запускаем сессию NFC с улучшенной обработкой для Android 15
      NFCTag tag;
      try {
        debugPrint('🔵 [NfcScreen] Вызов FlutterNfcKit.poll...');
        debugPrint(
            '🔵 [NfcScreen] Поднесите NFC метку к задней части устройства (где находится NFC антенна)');
        // Используем более длинный таймаут для Android 15
        tag = await FlutterNfcKit.poll(
          timeout: const Duration(seconds: 60),
          iosMultipleTagMessage: 'Обнаружено несколько меток',
          iosAlertMessage: 'Поднесите NFC метку к устройству',
        );
        debugPrint('✅ [NfcScreen] Poll успешно завершен');
      } catch (e) {
        debugPrint('❌ [NfcScreen] Ошибка при poll: $e');
        debugPrint('❌ [NfcScreen] Тип ошибки: ${e.runtimeType}');

        // Улучшенная обработка ошибок для Android 15
        String errorMessage = e.toString();
        if (errorMessage.contains('timeout') ||
            errorMessage.contains('Timeout') ||
            errorMessage.contains('408')) {
          errorMessage =
              'Метка не обнаружена за 60 секунд.\n\nПопробуйте:\n• Поднести метку к задней части устройства\n• Держать метку неподвижно 2-3 секунды\n• Убедиться, что метка не повреждена\n• Попробовать другую метку';
        } else if (errorMessage.contains('not enabled') ||
            errorMessage.contains('disabled')) {
          errorMessage = 'NFC отключен. Включите NFC в настройках устройства.';
        } else if (errorMessage.contains('not supported')) {
          errorMessage = 'NFC не поддерживается на этом устройстве.';
        } else if (errorMessage.contains('UserCancel')) {
          errorMessage = 'Сканирование отменено пользователем.';
        } else {
          errorMessage = 'Ошибка чтения метки: $errorMessage';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Ошибка чтения метки: $errorMessage\n\nПроверьте:\n- NFC включен в настройках\n- Метка поднесена близко к устройству\n- Метка не повреждена'),
              duration: const Duration(seconds: 6),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() {
            _isListening = false;
          });
        }
        return;
      }

      debugPrint('🔵 [NfcScreen] Обнаружена NFC метка');
      debugPrint('🔵 [NfcScreen] Тип метки: ${tag.type}');
      debugPrint('🔵 [NfcScreen] ID: ${tag.id}');
      debugPrint('🔵 [NfcScreen] NDEF доступен: ${tag.ndefAvailable}');

      String? tagData;

      // Пробуем прочитать NDEF данные с улучшенной обработкой для Android 15
      try {
        debugPrint(
            '🔵 [NfcScreen] Проверка NDEF доступности: ${tag.ndefAvailable}');
        debugPrint('🔵 [NfcScreen] Тип метки: ${tag.type}');
        debugPrint('🔵 [NfcScreen] ID метки: ${tag.id}');

        if (tag.ndefAvailable == true) {
          debugPrint('🔵 [NfcScreen] NDEF доступен, читаем данные...');
          var ndefRecords = <dynamic>[];
          try {
            // Добавляем небольшую задержку для Android 15 перед чтением NDEF
            await Future.delayed(const Duration(milliseconds: 100));
            ndefRecords = await FlutterNfcKit.readNDEFRecords();
            debugPrint(
                '🔵 [NfcScreen] NDEF записи успешно прочитаны: ${ndefRecords.length}');
          } catch (e, stackTrace) {
            debugPrint('❌ [NfcScreen] Ошибка при readNDEFRecords: $e');
            debugPrint('❌ [NfcScreen] Stack trace: $stackTrace');

            // Для Android 15 пробуем альтернативный способ чтения
            try {
              debugPrint(
                  '🔵 [NfcScreen] Пробуем альтернативный способ чтения...');
              // Небольшая пауза перед повторной попыткой
              await Future.delayed(const Duration(milliseconds: 200));
              ndefRecords = await FlutterNfcKit.readNDEFRecords();
              debugPrint(
                  '🔵 [NfcScreen] Альтернативное чтение успешно: ${ndefRecords.length}');
            } catch (e2) {
              debugPrint(
                  '❌ [NfcScreen] Альтернативное чтение также не удалось: $e2');
              // Продолжаем работу, пробуем использовать ID метки
            }
          }

          debugPrint(
              '🔵 [NfcScreen] Найдено NDEF записей: ${ndefRecords.length}');

          // Обрабатываем все записи, ищем текстовую
          for (int i = 0; i < ndefRecords.length; i++) {
            final record = ndefRecords[i];
            debugPrint(
                '🔵 [NfcScreen] Запись $i: тип=${record.type}, payload.length=${record.payload?.length ?? 0}');

            try {
              final payload = record.payload;
              if (payload == null || payload.isEmpty) {
                continue;
              }

              // Проверяем тип записи
              final recordType = (record.type ?? '').toString().toLowerCase();
              debugPrint('🔵 [NfcScreen] Тип записи (lowercase): $recordType');

              // Для текстовых записей (RTD_TEXT = 0x54)
              if (recordType.contains('text') ||
                  recordType.contains('wellknown') ||
                  recordType.contains('rtd_text') ||
                  (payload.isNotEmpty && payload[0] == 0x54)) {
                debugPrint(
                    '🔵 [NfcScreen] Обработка текстовой записи, payload: ${payload.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');

                // Для RTD_TEXT первый байт payload - это статус байт
                // Бит 7: UTF-16 (1) или UTF-8 (0)
                // Бит 6: зарезервирован (0)
                // Бит 5-0: длина языкового кода (обычно 2 для "en")
                if (payload.length > 1) {
                  final statusByte = payload[0];
                  final isUtf16 = (statusByte & 0x80) != 0;
                  final langCodeLength = statusByte & 0x3F;

                  debugPrint(
                      '🔵 [NfcScreen] Статус байт: 0x${statusByte.toRadixString(16)}, UTF-16=$isUtf16, langCodeLength=$langCodeLength');

                  // textStart = 1 (статус байт) + langCodeLength (обычно 2 для "en") = 3
                  // После статус-байта идут байты языкового кода, затем текст
                  final textStart = langCodeLength + 1;

                  if (payload.length > textStart) {
                    // Берем текст после языкового кода
                    var textBytes = payload.sublist(textStart);
                    final charset = isUtf16 ? 'UTF-16' : 'UTF-8';
                    debugPrint(
                        '🔵 [NfcScreen] Текст начинается с позиции $textStart (пропущено $langCodeLength байт языкового кода), длина=${textBytes.length}, charset=$charset');

                    if (isUtf16) {
                      // Для UTF-16 декодируем как последовательность 16-битных символов
                      try {
                        // UTF-16 LE (little-endian) - стандарт для Android
                        final chars = <int>[];
                        for (int i = 0; i < textBytes.length - 1; i += 2) {
                          final low = textBytes[i];
                          final high = textBytes[i + 1];
                          chars.add((high << 8) | low);
                        }
                        tagData = String.fromCharCodes(chars);
                        // Дополнительная проверка: если все еще начинается с "en", убираем
                        tagData = _removeEnPrefix(tagData);
                      } catch (e) {
                        debugPrint(
                            '⚠️ [NfcScreen] Ошибка декодирования UTF-16: $e');
                        // Fallback: пробуем как UTF-8
                        tagData = utf8.decode(textBytes, allowMalformed: true);
                      }
                    } else {
                      // Для UTF-8 декодируем напрямую
                      tagData = utf8.decode(textBytes, allowMalformed: true);
                      // Дополнительная проверка: если все еще начинается с "en", убираем
                      tagData = _removeEnPrefix(tagData);
                    }

                    // Убираем "en" если есть в начале
                    tagData = _removeEnPrefix(tagData);
                    debugPrint('🔵 [NfcScreen] Извлеченный текст: $tagData');

                    // Если получили валидный текст, используем его
                    if (tagData.isNotEmpty && tagData.trim().isNotEmpty) {
                      break;
                    }
                  }
                }
              } else {
                // Для других типов записей пробуем декодировать весь payload как UTF-8
                debugPrint('🔵 [NfcScreen] Пробуем декодировать как UTF-8');
                try {
                  final decoded = utf8.decode(payload, allowMalformed: true);
                  if (decoded.isNotEmpty && decoded.trim().isNotEmpty) {
                    tagData = decoded;
                    // Убираем "en" если есть
                    tagData = _removeEnPrefix(tagData);
                    debugPrint(
                        '🔵 [NfcScreen] Извлеченные данные (UTF-8): $tagData');
                    break;
                  }
                } catch (e) {
                  debugPrint(
                      '⚠️ [NfcScreen] Ошибка декодирования как UTF-8: $e');
                }
              }
            } catch (e) {
              debugPrint('⚠️ [NfcScreen] Ошибка обработки записи $i: $e');
            }
          }
        }
      } catch (e, stackTrace) {
        debugPrint('⚠️ [NfcScreen] Ошибка чтения NDEF: $e');
        debugPrint('⚠️ [NfcScreen] Stack trace: $stackTrace');
      }

      // Если не нашли в NDEF, используем ID метки (важно для Android 15)
      if (tagData == null || tagData.isEmpty) {
        try {
          final tagId = tag.id;
          // ID в flutter_nfc_kit - это String (hex представление)
          if (tagId.isNotEmpty) {
            // Конвертируем hex ID в читаемый формат для Android 15
            try {
              // Пробуем декодировать hex ID
              final bytes = <int>[];
              for (int i = 0; i < tagId.length; i += 2) {
                if (i + 1 < tagId.length) {
                  final hexByte = tagId.substring(i, i + 2);
                  bytes.add(int.parse(hexByte, radix: 16));
                }
              }
              // Пробуем декодировать как UTF-8
              final decoded = String.fromCharCodes(bytes).trim();
              if (decoded.isNotEmpty && decoded.length > 2) {
                tagData = decoded;
                debugPrint(
                    '🔵 [NfcScreen] Данные из ID метки (декодировано): $tagData');
              } else {
                tagData = tagId;
                debugPrint('🔵 [NfcScreen] Данные из ID метки (hex): $tagData');
              }
            } catch (e) {
              // Если декодирование не удалось, используем hex как есть
              tagData = tagId;
              debugPrint(
                  '🔵 [NfcScreen] Данные из ID метки (hex, без декодирования): $tagData');
            }
          }
        } catch (e) {
          debugPrint('⚠️ [NfcScreen] Ошибка обработки ID метки: $e');
        }
      }

      // Останавливаем сессию
      await FlutterNfcKit.finish();

      if (tagData != null && tagData.isNotEmpty && tagData != _lastReadTag) {
        // Убираем префикс "en" если он есть (финальная проверка)
        final originalTagData = tagData;
        debugPrint(
            '🔵 [NfcScreen] tagData перед финальной проверкой: "$tagData" (длина: ${tagData.length}, код первого символа: ${tagData.isNotEmpty ? tagData.codeUnitAt(0) : 'N/A'})');

        // Используем функцию для удаления "en"
        tagData = _removeEnPrefix(tagData);

        _lastReadTag = tagData;
        debugPrint(
            '🔵 [NfcScreen] ✅ ФИНАЛЬНАЯ считана NFC метка: "$tagData" (было: "$originalTagData")');

        if (mounted) {
          setState(() {
            _isListening = false;
            _currentTrackTitle = tagData;
          });

          // Воспроизводим трек
          await _playTrack(tagData);
        }
      } else {
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [NfcScreen] Критическая ошибка чтения NFC метки: $e');
      debugPrint('❌ [NfcScreen] Stack trace: $stackTrace');
      try {
        await FlutterNfcKit.finish();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isListening = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Ошибка чтения метки: ${e.toString()}\nПопробуйте еще раз'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      await FlutterNfcKit.finish();
    } catch (e) {
      debugPrint('⚠️ [NfcScreen] Ошибка остановки NFC сессии: $e');
    }
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _playTrack(String title) async {
    try {
      final finalTitle = _removeEnPrefix(title);
      debugPrint(
          '▶️ [NfcScreen] Начало воспроизведения трека: "$finalTitle" (было: "$title")');
      if (_isPlaying) {
        await _audioPlayer.stop();
      }
      final streamUrl = await GuestTracksApi.getNfcStreamUrl(finalTitle);
      debugPrint(
          '🔵 [NfcScreen] Stream URL: $streamUrl (для трека: $finalTitle)');

      // Парсим URI и проверяем его валидность
      final uri = Uri.parse(streamUrl);
      debugPrint('🔵 [NfcScreen] Парсинг URI: $uri');
      debugPrint(
          '🔵 [NfcScreen] URI scheme: ${uri.scheme}, host: ${uri.host}, port: ${uri.port}, path: ${uri.path}');

      if (uri.scheme != 'http' && uri.scheme != 'https') {
        throw Exception(
            'Неподдерживаемая схема URI: ${uri.scheme}. Ожидается http или https');
      }

      // Проверяем доступность URL перед использованием
      debugPrint('🔵 [NfcScreen] Проверка доступности URL...');
      try {
        final headResponse = await http.head(uri).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⏱️ [NfcScreen] Таймаут при проверке URL');
            throw TimeoutException('Превышено время ожидания при проверке URL');
          },
        );
        debugPrint(
            '🔵 [NfcScreen] HEAD запрос: статус=${headResponse.statusCode}, content-type=${headResponse.headers['content-type']}');
        if (headResponse.statusCode != 200 && headResponse.statusCode != 206) {
          debugPrint(
              '⚠️ [NfcScreen] Неожиданный статус код: ${headResponse.statusCode}');
        }
      } catch (e) {
        debugPrint(
            '⚠️ [NfcScreen] Предупреждение при проверке URL: $e (продолжаем попытку воспроизведения)');
      }

      debugPrint('🔵 [NfcScreen] Создание AudioSource.uri...');
      final audioSource = AudioSource.uri(
        uri,
        headers: {
          'accept': 'audio/mpeg',
        },
      );
      debugPrint('🔵 [NfcScreen] AudioSource создан, установка источника...');
      try {
        await _audioPlayer.setAudioSource(audioSource);
        debugPrint('✅ [NfcScreen] Аудио источник установлен успешно');
      } catch (e, stackTrace) {
        debugPrint('❌ [NfcScreen] Ошибка при установке источника: $e');
        debugPrint('❌ [NfcScreen] Тип ошибки: ${e.runtimeType}');
        debugPrint('❌ [NfcScreen] Stack trace: $stackTrace');
        throw Exception('Не удалось загрузить аудио: $e');
      }

      // Ждем, пока плеер обработает источник
      debugPrint('⏳ [NfcScreen] Ожидание готовности плеера...');
      int attempts = 0;
      const maxAttempts = 20; // Увеличиваем до 20 попыток (4 секунды)
      bool isReady = false;

      while (attempts < maxAttempts) {
        final state = _audioPlayer.playerState;
        final processingState = state.processingState;
        debugPrint(
            '🔄 [NfcScreen] Попытка ${attempts + 1}/$maxAttempts: processingState=$processingState, playing=${state.playing}');

        if (processingState == ProcessingState.ready) {
          debugPrint('✅ [NfcScreen] Плеер готов к воспроизведению');
          isReady = true;
          break;
        }

        // Проверяем, что состояние не idle после попыток загрузки
        if (attempts > 5 && processingState == ProcessingState.idle) {
          final errorMessage =
              'Плеер не смог загрузить источник. Состояние: $processingState';
          debugPrint('❌ [NfcScreen] $errorMessage');
          throw Exception(errorMessage);
        }

        // Если состояние loading или buffering, продолжаем ждать
        if (processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering) {
          debugPrint('⏳ [NfcScreen] Плеер загружает/буферизует...');
        }

        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }

      // Проверяем финальное состояние
      final playerState = _audioPlayer.playerState;
      debugPrint(
          '🎵 [NfcScreen] Финальное состояние: playing=${playerState.playing}, processingState=${playerState.processingState}');

      if (!isReady && playerState.processingState != ProcessingState.ready) {
        final errorMsg =
            'Плеер не готов к воспроизведению после $maxAttempts попыток. Состояние: ${playerState.processingState}';
        debugPrint('❌ [NfcScreen] $errorMsg');
        throw Exception(errorMsg);
      }

      // Начинаем воспроизведение
      debugPrint('▶️ [NfcScreen] Запуск воспроизведения...');
      try {
        await _audioPlayer.play();
        debugPrint('✅ [NfcScreen] Команда play() выполнена');
      } catch (e) {
        debugPrint('❌ [NfcScreen] Ошибка при вызове play(): $e');
        throw Exception('Не удалось начать воспроизведение: $e');
      }

      // Ждем и проверяем, что воспроизведение началось
      await Future.delayed(const Duration(milliseconds: 1000));
      final stateAfterPlay = _audioPlayer.playerState;
      debugPrint(
          '🎵 [NfcScreen] Состояние плеера после play: playing=${stateAfterPlay.playing}, processingState=${stateAfterPlay.processingState}');

      if (!stateAfterPlay.playing) {
        debugPrint('⚠️ [NfcScreen] Плеер не начал воспроизведение!');
        if (stateAfterPlay.processingState == ProcessingState.idle) {
          throw Exception(
              'Ошибка обработки аудио. Проверьте формат файла и URL.');
        }
      } else {
        debugPrint('✅ [NfcScreen] Воспроизведение запущено успешно');
      }
    } on PlatformException catch (e) {
      debugPrint('❌ [NfcScreen] PlatformException: ${e.code} - ${e.message}');
      debugPrint('❌ [NfcScreen] Details: ${e.details}');
      debugPrint('❌ [NfcScreen] Stack trace: ${StackTrace.current}');
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
      debugPrint('❌ [NfcScreen] Ошибка воспроизведения: $e');
      debugPrint('❌ [NfcScreen] Тип ошибки: ${e.runtimeType}');
      debugPrint('❌ [NfcScreen] Stack trace: $stackTrace');
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
    try {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _currentTrackTitle = null;
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [NfcScreen] Ошибка при остановке трека: $e');
      // Игнорируем ошибки при остановке, так как трек может быть уже остановлен
      if (mounted) {
        setState(() {
          _currentTrackTitle = null;
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
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

  String _formatDurationFromDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PanelHeader(
              name: 'NFC',
              showBackButton: true,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.nfc,
                          size: 120,
                          color: _isNfcAvailable
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _isNfcAvailable
                              ? 'Поднесите NFC метку к устройству'
                              : 'NFC недоступен на этом устройстве',
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (_isNfcAvailable)
                          Text(
                            _isListening
                                ? 'Ожидание метки...'
                                : 'Нажмите кнопку для начала сканирования',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 32),
                        if (_isNfcAvailable)
                          ElevatedButton.icon(
                            onPressed:
                                _isListening ? _stopListening : _startListening,
                            icon: Icon(_isListening ? Icons.stop : Icons.nfc),
                            label: Text(_isListening
                                ? 'Остановить сканирование'
                                : 'Начать сканирование'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                          ),
                        if (_lastReadTag != null) ...[
                          const SizedBox(height: 24),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(
                                    _lastReadTag!,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Нижняя плашка с контролами воспроизведения
            if (_currentTrackTitle != null)
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
                                _currentTrackTitle!,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
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
                                ? (_position.inMilliseconds.toDouble()).clamp(
                                    0.0, _duration.inMilliseconds.toDouble())
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
