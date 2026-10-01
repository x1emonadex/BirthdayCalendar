import 'dart:convert';

import 'package:birthday_calendar/core/providers/clock_provider.dart';
import 'package:birthday_calendar/core/providers/database_provider.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:birthday_calendar/features/notifications/data/local_notification_service.dart';
import 'package:birthday_calendar/features/notifications/data/notification_service.dart';
import 'package:birthday_calendar/features/notifications/domain/notification_plan_builder.dart';
import 'package:birthday_calendar/features/notifications/domain/notification_settings.dart';
import 'package:birthday_calendar/features/settings/data/settings_repository.dart';
import 'package:birthday_calendar/features/settings/presentation/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ, под которым настройки уведомлений лежат в AppSettings.
const String kNotificationSettingsKey = 'notification_settings';

/// Реализация уведомлений для текущей платформы.
final Provider<NotificationService> notificationServiceProvider =
    Provider<NotificationService>((ref) => LocalNotificationService());

/// Загруженные настройки уведомлений.
final FutureProvider<NotificationSettings> notificationSettingsProvider =
    FutureProvider<NotificationSettings>(
  (ref) async {
    final repository = ref.watch(settingsRepositoryProvider);
    final stored = await repository.read(kNotificationSettingsKey);
    return NotificationSettingsCodec.decode(stored);
  },
);

/// Готовый план уведомлений на текущий момент.
final FutureProvider<List<NotificationEvent>> notificationPlanProvider =
    FutureProvider<List<NotificationEvent>>((ref) async {
  final settings = await ref.watch(notificationSettingsProvider.future);
  if (!settings.enabled) return const [];

  final repository = ref.watch(birthdayRepositoryProvider);
  final now = ref.watch(clockProvider).now();

  final items = await repository.list(
    query: BirthdayQuery(
      sort: BirthdaySort.upcoming,
      importantOnly: settings.importantOnly,
      reference: now,
    ),
  );

  return NotificationPlanBuilder.buildPlan(
    now: now,
    items: items,
    settings: settings,
  );
});

/// Пересчитывает расписание: отменяет старое и ставит новое.
class NotificationScheduler {
  NotificationScheduler(this._ref);

  final Ref _ref;

  /// Возвращает число запланированных уведомлений.
  Future<int> refresh() async {
    final service = _ref.read(notificationServiceProvider);
    final events = await _ref.read(notificationPlanProvider.future);

    await service.cancelAll();

    final scheduled = NotificationPlanBuilder.scheduledOnly(events);
    if (scheduled.isNotEmpty) await service.scheduleAll(build(scheduled));

    // Просроченные уведомления показываем сразу: на обеих платформах
    // ждать их нельзя, а пользователь всё равно должен узнать о празднике.
    final immediate = NotificationPlanBuilder.immediateOnly(events);
    if (immediate.isNotEmpty) {
      for (final notification in build(immediate)) {
        await service.showNow(notification);
      }
    }

    return (await service.pending()).length;
  }

  /// Схлопывает события одного момента в готовые уведомления.
  ///
  /// Идентификатор берётся у первого события группы: он уже учитывает
  /// срок в днях и остаётся стабильным между запусками.
  static List<ScheduledNotification> build(List<NotificationEvent> events) {
    final result = <ScheduledNotification>[];
    NotificationPlanBuilder.groupByFireAt(events).forEach((fireAt, group) {
      final text = NotificationPlanBuilder.textFor(group);
      result.add(
        ScheduledNotification(
          id: group.first.id,
          fireAt: fireAt,
          title: text.title,
          body: text.body,
          payload: group.first.birthdayId,
        ),
      );
    });
    return result;
  }

  /// Планирует всё и сразу показывает уведомление — для кнопки «Проверить».
  Future<void> showTest(ScheduledNotification notification) async {
    final service = _ref.read(notificationServiceProvider);
    await service.showNow(notification);
  }

  /// Просит разрешение на уведомления.
  Future<bool> requestPermissions() {
    return _ref.read(notificationServiceProvider).requestPermissions();
  }

  /// Убирает все уведомления.
  Future<void> cancelAll() {
    return _ref.read(notificationServiceProvider).cancelAll();
  }
}

final Provider<NotificationScheduler> notificationSchedulerProvider =
    Provider<NotificationScheduler>(NotificationScheduler.new);

/// Сохраняет и восстанавливает настройки в формате JSON.
///
/// Кодек живёт здесь, а не в самом `NotificationSettings`, чтобы модель
/// оставалась чистой и не тянула зависимость от JSON.
abstract final class NotificationSettingsCodec {
  static NotificationSettings decode(String? raw) {
    if (raw == null || raw.isEmpty) return const NotificationSettings();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return NotificationSettings(
        enabled: map['enabled'] as bool? ?? true,
        daysBefore: (map['daysBefore'] as List<dynamic>?)
                ?.map((e) => (e as num).toInt())
                .toSet() ??
            NotificationSettings.defaultDaysBefore,
        hour: (map['hour'] as num?)?.toInt() ?? 9,
        minute: (map['minute'] as num?)?.toInt() ?? 0,
        importantOnly: map['importantOnly'] as bool? ?? false,
      );
    } catch (_) {
      // Повреждённые настройки не должны ломать запуск приложения.
      return const NotificationSettings();
    }
  }

  static String encode(NotificationSettings settings) {
    final days = settings.daysBefore.toList()..sort();
    return jsonEncode({
      'enabled': settings.enabled,
      'daysBefore': days,
      'hour': settings.hour,
      'minute': settings.minute,
      'importantOnly': settings.importantOnly,
    });
  }

  static Future<void> save(
    SettingsRepository repository,
    NotificationSettings settings,
  ) {
    return repository.write(kNotificationSettingsKey, encode(settings));
  }
}
