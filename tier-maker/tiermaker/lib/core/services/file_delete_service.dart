import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Надёжное удаление аудиофайлов.
///
/// На Android 11+ файл в общей папке «Загрузки», созданный прошлой установкой
/// приложения, нельзя удалить через [File.delete]: система отвечает ошибкой
/// доступа или «файл не найден». В этом случае удаляем через MediaStore
/// (нативный канал в MainActivity), при необходимости с подтверждением
/// пользователя.
class FileDeleteService {
  static const MethodChannel _channel =
      MethodChannel('com.example.mumusic/files');

  /// Возвращает, когда файла по [path] больше нет.
  /// Если файла уже не было, это не ошибка.
  static Future<void> delete(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      debugPrint('ℹ️ [FileDeleteService] Файла уже нет: $path');
      return;
    }

    try {
      await file.delete();
      return;
    } on FileSystemException catch (e) {
      debugPrint('⚠️ [FileDeleteService] File.delete не удался: $e');
      if (!await file.exists()) return;
      if (!Platform.isAndroid) rethrow;
    }

    bool deleted;
    try {
      deleted =
          await _channel.invokeMethod<bool>('deleteFile', {'path': path}) ??
              false;
    } on PlatformException catch (e) {
      throw Exception('Нет доступа к файлу: ${e.message ?? e.code}');
    } on MissingPluginException {
      throw Exception('Удаление файла недоступно (пересоберите приложение)');
    }

    if (!deleted && await file.exists()) {
      throw Exception('Удаление отменено или нет доступа к файлу');
    }
  }
}
