import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:mumusic/core/api/guest_tracks_api.dart';
import 'package:mumusic/core/audio/player_service.dart';
import 'package:mumusic/core/audio/player_track.dart';
import 'package:mumusic/core/global_widgets/panel_header.dart';

const MethodChannel _nfcChannel = MethodChannel('com.example.mumusic/nfc');

class NfcScreen extends StatefulWidget {
  const NfcScreen({super.key});

  @override
  State<NfcScreen> createState() => _NfcScreenState();
}

/// Экран чтения NFC-меток.
///
/// Почему раньше после первой удачной метки появлялась ошибка:
/// после чтения вызывался `FlutterNfcKit.finish()`, который выключает
/// reader mode. Метка при этом ещё лежит у телефона (или её подносят снова
/// до нажатия кнопки), и Android обрабатывает её сам — показывает системное
/// «NFC-метка не поддерживается». Кроме того, любая ошибка с текстом
/// «not supported» (например, «NDEF not supported on current tag»)
/// выдавалась как «устройство не поддерживает NFC».
///
/// Теперь на Android сканирование идёт непрерывно, пока экран открыт:
/// reader mode не выключается между метками, а одна и та же метка
/// не перезапускает трек, пока лежит у телефона.
class _NfcScreenState extends State<NfcScreen> with WidgetsBindingObserver {
  /// Сколько метка должна отсутствовать, чтобы её повторное
  /// прикладывание снова запустило трек.
  static const Duration _sameTagCooldown = Duration(seconds: 3);

  NFCAvailability? _availability;
  bool _isListening = false;
  bool _wantListening = false;
  int _scanSession = 0;
  String? _lastReadTag;
  String? _lastTagId;
  DateTime? _lastTagSeenAt;

  bool get _isNfcAvailable => _availability == NFCAvailability.available;

  String _removeEnPrefix(String text) {
    if (text.isEmpty) return text;
    var cleaned = text;
    while (cleaned.isNotEmpty && cleaned.codeUnitAt(0) < 32) {
      debugPrint(
          '[NfcScreen] Удален невидимый символ: 0x${cleaned.codeUnitAt(0).toRadixString(16)}');
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
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    await _checkNfcAvailability();
    final fromIntent = await _checkNfcIntent();
    // На Android сразу начинаем слушать, чтобы метку не перехватила система.
    // На iOS сканирование открывает системный диалог, поэтому только по кнопке.
    if (mounted && _isNfcAvailable && (Platform.isAndroid || fromIntent)) {
      _startListening();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wantListening = false;
    _scanSession++;
    FlutterNfcKit.finish().catchError((_) {});
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Reader mode привязан к активному окну — при сворачивании
      // останавливаем сессию, но запоминаем, что слушать нужно.
      final shouldResume = _wantListening;
      _stopListening();
      _wantListening = shouldResume;
    } else if (state == AppLifecycleState.resumed) {
      // Пользователь мог включить/выключить NFC в настройках
      _checkNfcAvailability().then((_) {
        if (mounted && _wantListening && !_isListening && _isNfcAvailable) {
          _startListening();
        }
      });
    }
  }

  Future<bool> _checkNfcIntent() async {
    try {
      // Проверяем, был ли перехвачен NFC intent от Android
      final hasIntent = await _nfcChannel.invokeMethod<bool>('getNfcIntent');
      return hasIntent == true;
    } catch (e) {
      debugPrint('⚠️ [NfcScreen] Ошибка проверки NFC intent: $e');
      return false;
    }
  }

  Future<void> _checkNfcAvailability() async {
    NFCAvailability? availability;
    try {
      availability = await FlutterNfcKit.nfcAvailability;
    } catch (e) {
      // Ошибка канала не означает, что NFC нет: не блокируем UI
      debugPrint('⚠️ [NfcScreen] Ошибка проверки доступности NFC: $e');
      availability = NFCAvailability.available;
    }
    debugPrint('🔵 [NfcScreen] NFC доступность: $availability');
    if (mounted) {
      setState(() {
        _availability = availability;
      });
    }
  }

  Future<void> _startListening() async {
    if (_isListening) return;
    await _checkNfcAvailability();
    if (!mounted) return;

    if (!_isNfcAvailable) {
      _showMessage(_availabilityMessage(_availability), Colors.red);
      return;
    }

    final session = ++_scanSession;
    setState(() {
      _wantListening = true;
      _isListening = true;
    });

    while (mounted && _wantListening && session == _scanSession) {
      NFCTag tag;
      try {
        tag = await FlutterNfcKit.poll(
          // Длинный таймаут: по таймауту плагин выключает reader mode,
          // и в этот момент метку снова может перехватить система
          timeout: const Duration(minutes: 10),
          iosMultipleTagMessage: 'Обнаружено несколько меток',
          iosAlertMessage: 'Поднесите NFC метку к устройству',
        );
      } on PlatformException catch (e) {
        if (session != _scanSession) return;
        debugPrint('❌ [NfcScreen] Ошибка poll: ${e.code} ${e.message}');
        if (e.code == '408') continue; // таймаут — просто ждём дальше
        if (e.code == '409') break; // отмена пользователем (iOS)
        if (e.code == '404') {
          // NFC выключили во время сканирования
          await _checkNfcAvailability();
          if (!_isNfcAvailable) {
            _showMessage(_availabilityMessage(_availability), Colors.red);
            break;
          }
        } else {
          _showMessage(_describeNfcError(e), Colors.orange);
        }
        await Future.delayed(const Duration(seconds: 1));
        continue;
      } catch (e) {
        if (session != _scanSession) return;
        debugPrint('❌ [NfcScreen] Ошибка poll: $e');
        _showMessage('Ошибка чтения метки: $e', Colors.orange);
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }
      if (session != _scanSession) return;

      debugPrint('🔵 [NfcScreen] Метка: ${tag.type}, id=${tag.id}, '
          'ndef=${tag.ndefAvailable}');

      final now = DateTime.now();
      final isSameTag = tag.id == _lastTagId &&
          _lastTagSeenAt != null &&
          now.difference(_lastTagSeenAt!) < _sameTagCooldown;
      _lastTagId = tag.id;
      _lastTagSeenAt = now;

      if (!isSameTag) {
        final tagData = await _readTagData(tag);
        if (session != _scanSession) return;
        if (tagData != null && tagData.isNotEmpty) {
          debugPrint('🔵 [NfcScreen] ✅ Считана метка: "$tagData"');
          setState(() {
            _lastReadTag = tagData;
          });
          unawaited(_playTrack(tagData));
        } else {
          _showMessage('На метке нет данных о треке', Colors.orange);
        }
      }

      if (!Platform.isAndroid) {
        // На iOS каждая сессия — отдельный системный диалог
        await FlutterNfcKit.finish(iosAlertMessage: 'Готово');
        break;
      }
      // Небольшая пауза, чтобы не крутить цикл, пока метка лежит у телефона
      await Future.delayed(const Duration(milliseconds: 700));
    }

    if (mounted && session == _scanSession) {
      setState(() {
        _isListening = false;
        _wantListening = false;
      });
    }
  }

  Future<void> _stopListening() async {
    _wantListening = false;
    _scanSession++;
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

  String _availabilityMessage(NFCAvailability? availability) {
    switch (availability) {
      case NFCAvailability.not_supported:
        return 'Это устройство не поддерживает NFC';
      case NFCAvailability.disabled:
        return 'NFC выключен. Включите NFC в настройках устройства.';
      default:
        return 'NFC недоступен';
    }
  }

  /// Коды ошибок flutter_nfc_kit: 404 — NFC выключен, 405 — метка не
  /// поддерживает операцию, 406 — метка не считана, 408 — таймаут,
  /// 409 — отмена, 500/503 — метку убрали во время чтения.
  String _describeNfcError(PlatformException e) {
    switch (e.code) {
      case '405':
        return 'Эта метка не поддерживает NDEF. Запишите на неё текст с названием трека.';
      case '406':
      case '503':
      case '500':
        return 'Метку убрали слишком быстро. Подержите её 1–2 секунды.';
      default:
        return 'Ошибка чтения метки: ${e.message ?? e.code}';
    }
  }

  void _showMessage(String text, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 4),
          backgroundColor: color,
        ),
      );
  }

  /// Достаёт название трека из NDEF-записей, а если их нет — из ID метки.
  Future<String?> _readTagData(NFCTag tag) async {
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


    return tagData == null ? null : _removeEnPrefix(tagData);
  }

  Future<void> _playTrack(String title) async {
    final finalTitle = _removeEnPrefix(title);
    try {
      await PlayerService.instance.playSingle(
        PlayerTrack(
          id: 'nfc:$finalTitle',
          title: finalTitle,
          artist: 'NFC метка',
          resolveSource: () => GuestTracksApi.getNfcStreamUrl(finalTitle),
        ),
      );
    } catch (e) {
      debugPrint('❌ [NfcScreen] Ошибка воспроизведения: $e');
      _showMessage(
        'Ошибка воспроизведения: $e\nПроверьте подключение к серверу',
        Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checking = _availability == null;

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
                  child: SingleChildScrollView(
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
                          checking
                              ? 'Проверка NFC...'
                              : _isNfcAvailable
                                  ? 'Поднесите NFC метку к устройству'
                                  : _availabilityMessage(_availability),
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (_isNfcAvailable)
                          Text(
                            _isListening
                                ? 'Ожидание метки... Можно прикладывать метки одну за другой'
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
                          )
                        else if (_availability == NFCAvailability.disabled)
                          OutlinedButton.icon(
                            onPressed: _checkNfcAvailability,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Проверить снова'),
                          ),
                        if (_lastReadTag != null) ...[
                          const SizedBox(height: 24),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _lastReadTag!,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
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
          ],
        ),
      ),
    );
  }
}
