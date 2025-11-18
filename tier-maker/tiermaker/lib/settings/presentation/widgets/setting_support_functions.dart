import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:RandomTierList/core/api/guest_tracks_api.dart';

Future<void> shareApp(BuildContext context) async {
    try {
      await Share.share(
        'Попробуйте Tier Maker - создавайте тир-листы!',
        subject: 'Tier Maker',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при попытке поделиться')),
        );
      }
    }
  }

  Future<void> contactSupport(BuildContext context) async {
    try {
      final email = 'kazak.petrushin@yandex.ru';
      final subject = Uri.encodeComponent('Поддержка Tier Maker');
      final body = Uri.encodeComponent('Здравствуйте,\n\n');
      final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Email: $email')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при открытии почты')),
        );
      }
    }
  }

  Future<void> openUserAgreement(BuildContext context) async {
    try {
      final uri = Uri.parse('https://docs.flutter.dev/');
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть соглашение')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при открытии соглашения')),
        );
      }
    }
  }

  Future<void> showApiUrlSettings(BuildContext context) async {
    final currentUrl = await GuestTracksApi.getBaseUrl();
    final controller = TextEditingController(text: currentUrl);
    
    if (!context.mounted) return;
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Настройка API сервера'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Введите адрес сервера:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'http://192.168.31.200:5050',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                Navigator.of(context).pop(url);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      if (result == 'reset') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL сброшен на значение по умолчанию')),
        );
      } else {
        await GuestTracksApi.setBaseUrl(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('URL сохранен: $result')),
        );
      }
    }
  }

  Future<void> testBackendConnection(BuildContext context) async {
    // Показываем индикатор загрузки
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Проверка подключения...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    // Выполняем проверку
    final isConnected = await GuestTracksApi.checkConnection();
    
    // Также вызываем полную проверку для логов
    await GuestTracksApi.testConnection();

    if (!context.mounted) return;

    // Показываем результат
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isConnected ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isConnected 
                    ? '✅ Подключение успешно' 
                    : '❌ Ошибка подключения',
              ),
            ),
          ],
        ),
        backgroundColor: isConnected ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }