import 'package:birthday_calendar/features/notifications/domain/notification_plan_builder.dart';
import 'package:birthday_calendar/features/notifications/data/notification_service.dart';
import 'package:birthday_calendar/features/notifications/domain/notification_settings.dart';
import 'package:birthday_calendar/features/notifications/presentation/providers/notification_providers.dart';
import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';
import 'package:birthday_calendar/features/settings/presentation/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Экран настроек уведомлений.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _saving = false;

  Future<void> _apply(NotificationSettings next) async {
    setState(() => _saving = true);
    try {
      await NotificationSettingsCodec.save(
        ref.read(settingsRepositoryProvider),
        next,
      );
      ref.invalidate(notificationSettingsProvider);
      ref.invalidate(notificationPlanProvider);
      // Сразу пересчитываем расписание, чтобы настройка имела эффект без
      // перезапуска приложения.
      await ref.read(notificationSchedulerProvider).refresh();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Ошибка: $error')),
        data: (current) {
          // Всё, кроме трёх готовых сроков. Свои сроки показываем в том же
          // списке чипов: добавить и убрать можно одним и тем же жестом,
          // иначе пользователю пришлось бы искать их в другом разделе.
          final customDays = current.daysBefore
              .where((d) => !NotificationSettings.quickDays.contains(d))
              .toList()
            ..sort((a, b) => b.compareTo(a));
          return ListView(
            children: [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              title: const Text('Уведомления'),
              subtitle: const Text('Напоминать о днях рождения'),
              value: current.enabled,
              onChanged: (value) => _apply(current.copyWith(enabled: value)),
            ),
            if (current.enabled) ...[
              const Divider(),
              const _Hint(
                'Напомнить за',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DaysChip(
                      label: '7 дней',
                      selected: current.daysBefore.contains(7),
                      onTap: () => _apply(
                        current.copyWith(
                          daysBefore: _toggle(current.daysBefore, 7),
                        ),
                      ),
                    ),
                    _DaysChip(
                      label: '1 день',
                      selected: current.daysBefore.contains(1),
                      onTap: () => _apply(
                        current.copyWith(
                          daysBefore: _toggle(current.daysBefore, 1),
                        ),
                      ),
                    ),
                    _DaysChip(
                      label: 'В день рождения',
                      selected: current.daysBefore.contains(0),
                      onTap: () => _apply(
                        current.copyWith(
                          daysBefore: _toggle(current.daysBefore, 0),
                        ),
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Свой срок'),
                      onPressed: _saving ? null : () => _addCustomDays(context, current),
                    ),
                  ],
                ),
              ),
              if (customDays.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final days in customDays)
                        _DaysChip(
                          label: _daysLabel(days),
                          selected: true,
                          onTap: () => _apply(
                            current.copyWith(
                              daysBefore: _toggle(current.daysBefore, days),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const Divider(),
              const _Hint('Когда напоминать'),
              for (var index = 0; index < current.times.length; index++)
                _TimeTile(
                  time: current.times[index],
                  // Последнее время убрать нельзя: без времён напоминания
                  // превратились бы в настройку, которая молча ничего не делает.
                  canRemove: current.times.length > 1,
                  onPick: () => _pickTime(context, current, index),
                  onToggle: (value) => _apply(
                    current.copyWith(
                      times: _replace(
                        current.times,
                        index,
                        current.times[index].copyWith(enabled: value),
                      ),
                    ),
                  ),
                  onRemove: () => _apply(
                    current.copyWith(times: _without(current.times, index)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Добавить время'),
                    onPressed: _saving ||
                            current.times.length >= NotificationSettings.maxTimes
                        ? null
                        : () => _addTime(context, current),
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                title: const Text('Только важные'),
                value: current.importantOnly,
                onChanged: (value) =>
                    _apply(current.copyWith(importantOnly: value)),
              ),
              const Divider(),
              const _Hint('Проверка'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _showTest,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Показать тестовое уведомление'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _recalculate,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Пересчитать расписание'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
            ],
          );
        },
      ),
    );
  }

  static Set<int> _toggle(Set<int> current, int value) {
    final next = Set<int>.from(current);
    if (!next.remove(value)) next.add(value);
    return next;
  }

  static String _daysLabel(int days) {
    return '$days ${BirthdayDateUtils.pluralDays(days)}';
  }

  /// Спрашивает число дней и добавляет его к выбранным срокам.
  Future<void> _addCustomDays(
    BuildContext context,
    NotificationSettings current,
  ) async {
    final days = await showDialog<int>(
      context: context,
      builder: (context) => const _CustomDaysDialog(),
    );
    if (days == null || !mounted) return;
    await _apply(
      current.copyWith(daysBefore: _toggle(current.daysBefore, days)),
    );
  }

  /// Меняет одно время в списке, сохраняя его место.
  static List<NotificationTime> _replace(
    List<NotificationTime> times,
    int index,
    NotificationTime value,
  ) {
    final next = List<NotificationTime>.from(times);
    next[index] = value;
    return next;
  }

  static List<NotificationTime> _without(
    List<NotificationTime> times,
    int index,
  ) {
    return List<NotificationTime>.from(times)..removeAt(index);
  }

  /// Меняет время одной из строк.
  Future<void> _pickTime(
    BuildContext context,
    NotificationSettings current,
    int index,
  ) async {
    final time = current.times[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
    );
    if (picked == null || !mounted) return;
    await _apply(
      current.copyWith(
        times: _replace(
          current.times,
          index,
          time.copyWith(hour: picked.hour, minute: picked.minute),
        ),
      ),
    );
  }

  /// Спрашивает время и добавляет его к списку.
  Future<void> _addTime(
    BuildContext context,
    NotificationSettings current,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: NotificationTime.defaultTime.hour,
        minute: NotificationTime.defaultTime.minute,
      ),
    );
    if (picked == null || !mounted) return;

    final added = NotificationTime(picked.hour, picked.minute);
    // Если такое время уже есть, но выключено, — включаем его, а не заводим
    // второе: два одинаковых времени дали бы одно и то же уведомление.
    final existing = current.times.indexWhere(
      (time) => time.minutesOfDay == added.minutesOfDay,
    );
    final next = existing >= 0
        ? _replace(current.times, existing, added)
        : [...current.times, added];

    await _apply(current.copyWith(times: next));
  }

  Future<void> _showTest() async {
    final now = DateTime.now();
    final event = ScheduledNotification(
      id: NotificationPlanBuilder.stableNotificationId(
        profileId: 'test',
        birthdayId: 'test',
        daysBefore: 0,
        minuteOfDay: 0,
      ),
      fireAt: now,
      title: 'Тестовое уведомление',
      body: 'Так выглядит напоминание о дне рождения.',
      payload: 'test',
    );
    await ref.read(notificationSchedulerProvider).showTest(event);
    _snack('Тестовое уведомление отправлено');
  }

  Future<void> _recalculate() async {
    setState(() => _saving = true);
    try {
      final count = await ref.read(notificationSchedulerProvider).refresh();
      _snack('Запланировано уведомлений: $count');
    } catch (error) {
      _snack('Не удалось пересчитать: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// Диалог ввода произвольного числа дней.
class _CustomDaysDialog extends StatefulWidget {
  const _CustomDaysDialog();

  @override
  State<_CustomDaysDialog> createState() => _CustomDaysDialogState();
}

class _CustomDaysDialogState extends State<_CustomDaysDialog> {
  final _controller = TextEditingController();
  String? _error;

  /// Дальше года бесполезно: планировщик всё равно хранит конкретную дату.
  static const int maxDays = 365;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null) {
      setState(() => _error = 'Введите число дней');
      return;
    }
    if (value < 1) {
      setState(() => _error = 'Минимальный срок — 1 день');
      return;
    }
    if (value > maxDays) {
      setState(() => _error = 'Не больше $maxDays дней');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Свой срок'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'За сколько дней',
          hintText: 'например, 2, 15 или 30',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Добавить')),
      ],
    );
  }
}

/// Строка одного времени напоминания: само время, выключатель и удаление.
class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.time,
    required this.canRemove,
    required this.onPick,
    required this.onToggle,
    required this.onRemove,
  });

  final NotificationTime time;
  final bool canRemove;
  final VoidCallback onPick;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 8),
      leading: Icon(
        Icons.schedule,
        color: time.enabled ? theme.colorScheme.primary : null,
      ),
      title: Text(
        time.label,
        style: time.enabled ? null : TextStyle(color: theme.disabledColor),
      ),
      subtitle: time.enabled ? null : const Text('Выключено'),
      onTap: onPick,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(value: time.enabled, onChanged: onToggle),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: canRemove
                ? 'Удалить время'
                : 'Последнее время убрать нельзя',
            onPressed: canRemove ? onRemove : null,
          ),
        ],
      ),
    );
  }
}

class _DaysChip extends StatelessWidget {
  const _DaysChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
