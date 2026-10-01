import 'package:flutter/material.dart';

/// Диалог выбора произвольного цвета.
///
/// Своя реализация вместо готовых пакетов: нужен только HSV-ползунок и
/// образец, а лишняя зависимость ради этого не нужна.
class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({required this.initial, super.key});

  /// Текущий цвет в формате ARGB.
  final int initial;

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(Color(widget.initial));
  }

  Color get _color => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    final hex = _color.toARGB32().toRadixString(16).padLeft(8, '0');

    return AlertDialog(
      title: const Text('Выберите цвет'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Slider(
              label: 'Оттенок',
              value: _hsv.hue,
              max: 360,
              gradient: LinearGradient(
                colors: [
                  for (var i = 0; i <= 6; i++)
                    HSVColor.fromAHSV(1, i * 60, 1, 1).toColor(),
                ],
              ),
              onChanged: (value) =>
                  setState(() => _hsv = _hsv.withHue(value)),
            ),
            _Slider(
              label: 'Насыщенность',
              value: _hsv.saturation,
              max: 1,
              gradient: LinearGradient(
                colors: [
                  HSVColor.fromAHSV(1, _hsv.hue, 0, 1).toColor(),
                  HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
                ],
              ),
              onChanged: (value) =>
                  setState(() => _hsv = _hsv.withSaturation(value)),
            ),
            _Slider(
              label: 'Яркость',
              value: _hsv.value,
              max: 1,
              gradient: LinearGradient(
                colors: [
                  HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 0).toColor(),
                  HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
                ],
              ),
              onChanged: (value) =>
                  setState(() => _hsv = _hsv.withValue(value)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.palette_outlined),
                const SizedBox(width: 12),
                Text(
                  '#${hex.substring(2).toUpperCase()}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_color),
          child: const Text('Применить'),
        ),
      ],
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.max,
    required this.gradient,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final Gradient gradient;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Container(
          height: 28,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: gradient,
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 28,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: Theme.of(context).colorScheme.onSurface,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value.clamp(0, max),
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
