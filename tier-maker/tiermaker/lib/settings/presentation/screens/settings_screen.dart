import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';    
import 'package:RandomTierList/core/global_widgets/panel_header.dart';
import 'package:RandomTierList/settings/presentation/providers/settings_provider.dart';
import 'package:RandomTierList/theme/theme.dart';
import 'package:RandomTierList/settings/presentation/widgets/setting_support_functions.dart';
import 'package:RandomTierList/core/api/guest_tracks_api.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsModel = SettingsProvider.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            PanelHeader(
              name: 'Настройки',
              showBackButton: true,
              textColor: theme.colorScheme.primary,
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
                        thumbColor: MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return settingsModel.appModel.isDarkTheme
                                  ? AppTheme.primaryColorLight
                                  : AppTheme.primaryColor; 
                            }
                            return Colors.grey.shade400;
                          },
                        ),
                        trackColor: MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return (settingsModel.appModel.isDarkTheme
                                      ? AppTheme.primaryColorLight
                                      : AppTheme.primaryColor)
                                  .withOpacity(0.5);
                            }
                            return Colors.grey.withOpacity(0.3);
                          },
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    SettingsItem(
                      text: 'Поделиться приложением',
                      icon: Icons.share,
                      onTap: () => shareApp(context),
                    ),        
                    SettingsItem(
                      text: 'Связаться с поддержкой',
                      icon: Icons.support_agent,
                      onTap: () => contactSupport(context),
                    ),
                    SettingsItem(
                      text: 'Пользовательское соглашение',
                      icon: Icons.arrow_forward_ios,
                      onTap: () => openUserAgreement(context),
                    ),
                    SettingsItem(
                      text: 'Настройка API сервера',
                      icon: Icons.settings_ethernet,
                      onTap: () => showApiUrlSettings(context),
                    ),
                    SettingsItem(
                      text: 'Тест подключения к бэкенду',
                      icon: Icons.cloud_sync,
                      onTap: () => testBackendConnection(context),
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
}

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

