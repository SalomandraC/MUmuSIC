import 'package:flutter/material.dart';
import 'package:mumusic/app/models/app_model.dart';
import 'package:mumusic/app/state/app_model_provider.dart';
import 'package:mumusic/core/global_widgets/panel_header.dart';
import 'package:mumusic/settings/presentation/widgets/color_picker_dialog.dart';
import 'package:mumusic/theme/app_palette.dart';
import 'package:mumusic/theme/theme.dart';

/// Выбор цветовой схемы: готовые пресеты и редактор своей схемы
/// с живым предпросмотром.
class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  /// Черновик своей схемы; применяется сразу при каждом изменении
  AppPalette? _custom;

  AppModel get _appModel => AppModelProvider.of(context);

  Future<void> _apply(AppPalette palette) => _appModel.setPalette(palette);

  Future<void> _editColor(
    String title,
    Color current,
    AppPalette Function(AppPalette, Color) update,
  ) async {
    final picked = await showColorPickerDialog(
      context,
      title: title,
      initial: current,
    );
    if (picked == null || !mounted) return;
    final base = _custom ?? _appModel.palette.toCustom();
    setState(() => _custom = update(base, picked));
    await _apply(_custom!);
  }

  @override
  Widget build(BuildContext context) {
    final appModel = AppModelProvider.of(context);
    final current = appModel.palette;
    final custom = _custom ?? (current.isCustom ? current : current.toCustom());
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PanelHeader(
              name: 'Цветовая схема',
              showBackButton: true,
              onBackClick: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Container(
                color: theme.colorScheme.surface,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Готовые схемы', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: AppPalette.presets.length,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.15,
                      ),
                      itemBuilder: (context, index) {
                        final preset = AppPalette.presets[index];
                        return _PalettePreview(
                          palette: preset,
                          selected: current.id == preset.id,
                          onTap: () {
                            setState(() => _custom = null);
                            _apply(preset);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text('Своя схема', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Начинается с текущей схемы. Изменения применяются сразу.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 150,
                      child: _PalettePreview(
                        palette: custom,
                        selected: current.isCustom,
                        onTap: () => _apply(custom),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ColorRow(
                      label: 'Фон экрана',
                      color: custom.background,
                      onTap: () => _editColor('Фон экрана', custom.background,
                          (p, c) => p.copyWith(background: c)),
                    ),
                    _ColorRow(
                      label: 'Фон списков и карточек',
                      color: custom.surface,
                      onTap: () => _editColor('Фон списков', custom.surface,
                          (p, c) => p.copyWith(surface: c)),
                    ),
                    _ColorRow(
                      label: 'Акцент (кнопки, плеер)',
                      color: custom.accent,
                      onTap: () => _editColor('Акцент', custom.accent,
                          (p, c) => p.copyWith(accent: c)),
                    ),
                    _ColorRow(
                      label: 'Текст и иконки',
                      color: custom.text,
                      onTap: () => _editColor('Текст и иконки', custom.text,
                          (p, c) => p.copyWith(text: c)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Тёмная основа',
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(
                        'Влияет на диалоги, клавиатуру и системные элементы',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: custom.isDark,
                      onChanged: (value) {
                        setState(() => _custom = custom.copyWith(isDark: value));
                        _apply(_custom!);
                      },
                    ),
                    if (_contrastWarning(custom) case final warning?)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber,
                                color: theme.colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                warning,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
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

  /// Предупреждаем, если текст плохо читается на фоне (контраст < 3:1)
  String? _contrastWarning(AppPalette palette) {
    final a = palette.text.computeLuminance();
    final b = palette.surface.computeLuminance();
    final ratio = (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
    if (ratio < 3) {
      return 'Текст плохо читается на фоне списков (контраст ${ratio.toStringAsFixed(1)}:1). '
          'Сделайте один из цветов светлее или темнее.';
    }
    return null;
  }
}

class _ColorRow extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ColorRow({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(label, style: theme.textTheme.bodyLarge),
      subtitle: Text(
        colorToHex(color),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFamily: 'monospace',
        ),
      ),
      trailing: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.outline),
        ),
      ),
    );
  }
}

/// Мини-превью схемы: шапка на фоне, список на поверхности, акцентная кнопка.
class _PalettePreview extends StatelessWidget {
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _PalettePreview({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewTheme = AppTheme.fromPalette(palette);
    final onBackground = contrastOn(palette.background);

    return Material(
      color: palette.background,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? theme.colorScheme.secondary : Colors.transparent,
              width: 3,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        palette.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onBackground,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle, color: onBackground, size: 18),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: palette.surface,
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final width in [0.8, 0.55])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: FractionallySizedBox(
                            widthFactor: width,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: palette.text.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(Icons.play_circle_filled,
                              color: palette.accent, size: 26),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: previewTheme
                                    .sliderTheme.inactiveTrackColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: 0.4,
                                child: Container(color: palette.accent),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
