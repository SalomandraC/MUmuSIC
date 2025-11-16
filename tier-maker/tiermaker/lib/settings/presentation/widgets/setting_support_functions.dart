import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось открыть соглашение')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при открытии соглашения')),
        );
      }
    }
  }