import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:RandomTierList/app/app_routes.dart';
import 'package:RandomTierList/app/state/app_model_provider.dart';
import 'package:RandomTierList/core/global_widgets/panel_header.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appModel = AppModelProvider.of(context);
    final isGuest = appModel.isGuest;

    Future<void> _handleLogout() async {
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Выход из аккаунта'),
          content: Text(
            isGuest
                ? 'Вы действительно хотите выйти из гостевой сессии?'
                : 'Вы действительно хотите выйти из аккаунта?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Выйти'),
            ),
          ],
        ),
      );

      if (shouldLogout == true && context.mounted) {
        await appModel.setGuestMode(true);
        if (context.mounted) {
          context.go(AppRoutes.auth);
        }
      }
    }

    final menuItems = [
      MenuItem(
        icon: Icons.cloud,
        title: 'Сеть',
        onTap: () {
          context.push(AppRoutes.network);
        },
      ),
      MenuItem(
        icon: Icons.nfc,
        title: 'NFC',
        onTap: () {
          context.push(AppRoutes.nfc);
        },
      ),
      MenuItem(
        icon: Icons.queue_music,
        title: 'Моя медиатека',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нажмите "Моя медиатека"')),
          );
        },
      ),
      MenuItem(
        icon: Icons.library_music,
        title: 'Плейлисты',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Плейлисты (в разработке)')),
          );
        },
      ),
      MenuItem(
        icon: Icons.favorite_border,
        title: 'Избранное',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нажмите "Избранное"')),
          );
        },
      ),
      MenuItem(
        icon: Icons.settings,
        title: 'Настройки',
        onTap: () {
          context.push(AppRoutes.settings);
        },
      ),
      MenuItem(
        icon: Icons.logout,
        title: 'Выход',
        onTap: _handleLogout,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PanelHeader(
              name: 'MUmuSIC',
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                  itemCount: menuItems.length,
                  itemBuilder: (context, index) {
                    return MenuItemWidget(item: menuItems[index]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Модель элемента меню
class MenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

/// Виджет элемента меню
class MenuItemWidget extends StatelessWidget {
  final MenuItem item;

  const MenuItemWidget({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.primary;

    return InkWell(
      onTap: item.onTap,
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 26,
              color: iconColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                item.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: textColor,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 24,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
