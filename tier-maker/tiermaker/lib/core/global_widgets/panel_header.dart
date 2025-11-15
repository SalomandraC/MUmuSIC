import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PanelHeader extends StatelessWidget {
  final String name;
  final bool showBackButton;
  final VoidCallback? onBackClick;
  final Color? textColor;

  const PanelHeader({
    super.key,
    required this.name,
    this.showBackButton = false,
    this.onBackClick,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTextColor = textColor ?? theme.colorScheme.onBackground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        spacing: 40,
        children: [
          if (showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBackClick ?? () => context.pop(),
              color: effectiveTextColor,
            ),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.titleLarge?.copyWith(
                color: effectiveTextColor,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
