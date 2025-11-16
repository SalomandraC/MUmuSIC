import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:RandomTierList/app/app_routes.dart';
import 'package:RandomTierList/core/global_widgets/panel_header.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final menuItems = [
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
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF3772E7),
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
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                item.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
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

