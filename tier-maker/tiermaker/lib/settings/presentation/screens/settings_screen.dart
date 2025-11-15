import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:RandomTierList/core/global_widgets/panel_header.dart';
import 'package:RandomTierList/settings/presentation/providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsModel = SettingsProvider.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            PanelHeader(
              name: 'Настройки',
              showBackButton: true,
              onBackClick: () => context.pop(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  children: [
                    SettingsItem(
                      text: settingsModel.appModel.isDarkTheme
                          ? 'Темная тема'
                          : 'Светлая тема',
                      trailing: Switch(
                        value: settingsModel.appModel.isDarkTheme,
                        onChanged: (value) {
                          settingsModel.setTheme(value);
                        },
                      ),
                    ),
                    // Поделиться приложением
                    SettingsItem(
                      text: 'Поделиться приложением',
                      icon: Icons.share,
                      onTap: () => _shareApp(context),
                    ),
                    // Связаться с поддержкой
                    SettingsItem(
                      text: 'Связаться с поддержкой',
                      icon: Icons.support_agent,
                      onTap: () => _contactSupport(context),
                    ),
                    SettingsItem(
                      text: 'Пользовательское соглашение',
                      icon: Icons.arrow_forward_ios,
                      onTap: () => _openUserAgreement(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareApp(BuildContext context) async {
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

  Future<void> _contactSupport(BuildContext context) async {
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

  Future<void> _openUserAgreement(BuildContext context) async {
    try {
      // Замените на реальный URL пользовательского соглашения
      final uri = Uri.parse('https://example.com/user-agreement');
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
}

/// Виджет элемента настроек
class SettingsItem extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsItem({
    super.key,
    required this.text,
    this.icon,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 61,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            if (trailing != null)
              trailing!
            else if (icon != null)
              Icon(
                icon,
                size: 24,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

