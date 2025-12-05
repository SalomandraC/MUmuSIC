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
    final theme = Theme.of(context);
    
    if (!context.mounted) return;
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Настройка API сервера'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Текущий адрес:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  currentUrl,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Введите новый адрес сервера:'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'http://192.168.1.100:5050',
                  border: OutlineInputBorder(),
                  helperText: 'Пример: http://10.75.231.223:5050',
                ),
                keyboardType: TextInputType.url,
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final current = await GuestTracksApi.getBaseUrl();
                  controller.text = current;
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Вернуть текущий'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await GuestTracksApi.resetBaseUrl();
              if (context.mounted) {
                Navigator.of(context).pop('reset');
              }
            },
            child: const Text('Сбросить'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                // Простая валидация URL
                if (url.startsWith('http://') || url.startsWith('https://')) {
                  Navigator.of(context).pop(url);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('URL должен начинаться с http:// или https://'),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Введите адрес сервера'),
                  ),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    if (result == 'reset') {
      await GuestTracksApi.resetBaseUrl();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL сброшен на значение по умолчанию'),
          backgroundColor: Colors.orange,
        ),
      );
    } else if (result != null && result.isNotEmpty) {
      await GuestTracksApi.setBaseUrl(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('URL сохранен: $result'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
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