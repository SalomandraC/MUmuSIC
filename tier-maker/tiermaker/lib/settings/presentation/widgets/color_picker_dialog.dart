import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String colorToHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

Color? colorFromHex(String input) {
  final hex = input.replaceAll('#', '').trim();
  if (hex.length != 6) return null;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}

/// Простой выбор цвета без сторонних пакетов:
/// быстрые образцы, слайдеры тон/насыщенность/яркость и ввод HEX.
Future<Color?> showColorPickerDialog(
  BuildContext context, {
  required String title,
  required Color initial,
}) {
  return showDialog<Color>(
    context: context,
    builder: (context) => _ColorPickerDialog(title: title, initial: initial),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  final String title;
  final Color initial;

  const _ColorPickerDialog({required this.title, required this.initial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  static const List<Color> _swatches = [
    Color(0xFF000000), Color(0xFF424242), Color(0xFF9E9E9E), Color(0xFFFFFFFF),
    Color(0xFFF44336), Color(0xFFFF7400), Color(0xFFFFC107), Color(0xFF8BC34A),
    Color(0xFF009688), Color(0xFF03A9F4), Color(0xFF3F51B5), Color(0xFF9C27B0),
    Color(0xFFE91E63), Color(0xFFF2918A), Color(0xFF795548), Color(0xFF1E1B2E),
  ];

  late HSVColor _hsv;
  late final TextEditingController _hexController;

  Color get _color => _hsv.toColor();

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
    _hexController = TextEditingController(text: colorToHex(widget.initial));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _set(HSVColor hsv, {bool updateHex = true}) {
    setState(() => _hsv = hsv);
    if (updateHex) _hexController.text = colorToHex(hsv.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outline),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final swatch in _swatches)
                  InkWell(
                    onTap: () => _set(HSVColor.fromColor(swatch)),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _GradientSlider(
              label: 'Тон',
              value: _hsv.hue / 360,
              colors: [
                for (var h = 0; h <= 360; h += 60)
                  HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
              ],
              onChanged: (v) => _set(_hsv.withHue(v * 360)),
            ),
            _GradientSlider(
              label: 'Насыщенность',
              value: _hsv.saturation,
              colors: [
                _hsv.withSaturation(0).toColor(),
                _hsv.withSaturation(1).toColor(),
              ],
              onChanged: (v) => _set(_hsv.withSaturation(v)),
            ),
            _GradientSlider(
              label: 'Яркость',
              value: _hsv.value,
              colors: [
                _hsv.withValue(0).toColor(),
                _hsv.withValue(1).toColor(),
              ],
              onChanged: (v) => _set(_hsv.withValue(v)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hexController,
              decoration: const InputDecoration(
                labelText: 'HEX',
                hintText: '#FF7400',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
                LengthLimitingTextInputFormatter(7),
              ],
              onChanged: (text) {
                final color = colorFromHex(text);
                if (color != null) {
                  _set(HSVColor.fromColor(color), updateHex: false);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_color),
          child: const Text('Готово'),
        ),
      ],
    );
  }
}

class _GradientSlider extends StatelessWidget {
  final String label;
  final double value;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  const _GradientSlider({
    required this.label,
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        SizedBox(
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: LinearGradient(colors: colors),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: theme.colorScheme.onSurface,
                  overlayColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                child: Slider(
                  value: value.clamp(0.0, 1.0),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
