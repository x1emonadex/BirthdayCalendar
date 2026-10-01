import 'package:birthday_calendar/core/routing/navigation_settings_screen.dart';
import 'package:birthday_calendar/core/theme/theme_settings_screen.dart';
import 'package:birthday_calendar/core/utils/leap_day_rule.dart';
import 'package:birthday_calendar/features/export_import/presentation/screens/export_import_screen.dart';
import 'package:birthday_calendar/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:birthday_calendar/features/settings/presentation/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Экран настроек: оформление, уведомления, обмен данными и резервные копии.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rule = ref.watch(leapDayRuleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          const _SectionHeader('29 февраля'),
          rule.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
            error: (error, stack) => ListTile(title: Text('Ошибка: $error')),
            data: (current) => RadioGroup<LeapDayRule>(
              groupValue: current,
              onChanged: (value) => _saveRule(ref, value),
              child: const Column(
                children: [
                  RadioListTile<LeapDayRule>(
                    value: LeapDayRule.february28,
                    title: Text('Отмечать 28 февраля'),
                  ),
                  RadioListTile<LeapDayRule>(
                    value: LeapDayRule.march1,
                    title: Text('Отмечать 1 марта'),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      'В високосные годы 29 февраля празднуется как есть — '
                      'настройка влияет только на обычные годы.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 32),
          const _SectionHeader('Интерфейс'),
          ListTile(
            leading: const Icon(Icons.view_carousel_outlined),
            title: const Text('Вкладки'),
            subtitle: const Text('Порядок и состав нижней навигации'),
            onTap: () => _open(context, const NavigationSettingsScreen()),
          ),
          const Divider(height: 32),
          const _SectionHeader('Оформление'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Тема и цвет'),
            onTap: () => _open(context, const ThemeSettingsScreen()),
          ),
          const Divider(height: 32),
          const _SectionHeader('Уведомления'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Напоминания'),
            subtitle: const Text('За 7 дней, за день и в день рождения'),
            onTap: () => _open(context, const NotificationSettingsScreen()),
          ),
          const Divider(height: 32),
          const _SectionHeader('Обмен данными'),
          ListTile(
            leading: const Icon(Icons.sync_alt),
            title: const Text('Перенос и копия'),
            subtitle: const Text('Excel, CSV и резервная копия'),
            onTap: () => _open(context, const ExportImportScreen()),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => screen),
    );
  }

  Future<void> _saveRule(WidgetRef ref, LeapDayRule? value) async {
    if (value == null) return;
    await ref.read(settingsRepositoryProvider).saveLeapDayRule(value);
    ref.invalidate(leapDayRuleProvider);
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
