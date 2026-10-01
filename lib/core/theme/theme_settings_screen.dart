import 'package:birthday_calendar/core/theme/theme_preferences.dart';
import 'package:birthday_calendar/core/theme/theme_provider.dart';
import 'package:birthday_calendar/core/theme/widgets/color_picker_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Экран выбора темы и цвета оформления.
class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Оформление')),
      body: ListView(
        children: [
          const _SectionHeader('Тема'),
          RadioGroup<ThemeModePreference>(
            groupValue: settings.mode,
            onChanged: (value) {
              if (value != null) controller.setMode(value);
            },
            child: const Column(
              children: [
                RadioListTile<ThemeModePreference>(
                  value: ThemeModePreference.system,
                  title: Text('Как в системе'),
                ),
                RadioListTile<ThemeModePreference>(
                  value: ThemeModePreference.light,
                  title: Text('Светлая'),
                  subtitle: Text('Белые поверхности, тёмный текст'),
                ),
                RadioListTile<ThemeModePreference>(
                  value: ThemeModePreference.dark,
                  title: Text('Тёмная'),
                  subtitle: Text('Серые панели на тёмном фоне'),
                ),
                RadioListTile<ThemeModePreference>(
                  value: ThemeModePreference.amoled,
                  title: Text('AMOLED'),
                  subtitle: Text(
                    'Чёрный фон и панели ступенью светлее — '
                    'для OLED-экранов',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          const _SectionHeader('Цвет'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Акцентный цвет применяется ко всем элементам интерфейса. '
              'Любой другой цвет — кнопкой ниже.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final accent in AccentColor.values)
                  if (accent != AccentColor.custom)
                    _ColorSwatch(
                      color: Color(accent.seedValue),
                      tooltip: accent.name,
                      selected: settings.accent == accent,
                      onTap: () => controller.setAccent(accent),
                    ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _CustomColorButton(
              color: Color(settings.customSeedColor),
              selected: settings.accent == AccentColor.custom,
              onPressed: () =>
                  _pickCustomColor(context, settings, controller),
            ),
          ),
          const SizedBox(height: 32),
          const _Preview(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static Future<void> _pickCustomColor(
    BuildContext context,
    ThemeSettings settings,
    ThemeController controller,
  ) async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(
        initial: settings.customSeedColor,
      ),
    );
    if (color == null) return;
    await controller.setCustomColor(color);
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.onSurface : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

/// Кнопка выбора произвольного цвета.
///
/// Раньше «свой цвет» был последним кругом в палитре, и он ничем не
/// отличался от готовых цветов: непонятно было, что он открывает палитру.
/// Теперь это отдельная кнопка с подписью, круг в ней показывает текущий
/// выбранный цвет, а рамка — что акцент сейчас именно пользовательский.
class _CustomColorButton extends StatelessWidget {
  const _CustomColorButton({
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hex = color.toARGB32().toRadixString(16).substring(2).toUpperCase();

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.outlineVariant),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Свой цвет', style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '#$hex',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle : Icons.tune,
            size: 20,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// Наглядный пример того, как выглядит выбранное оформление.
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Предпросмотр', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: const Text('А'),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Аня'),
                            Text('через 3 дня'),
                          ],
                        ),
                      ),
                      const Chip(label: Text('Сегодня')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Кнопка'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
