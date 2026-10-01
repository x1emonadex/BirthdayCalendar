import 'package:birthday_calendar/features/notifications/domain/notification_plan_builder.dart';

/// Идентификатор канала уведомлений в Android.
const String kNotificationChannelId = 'birthday_reminders';

/// Абстракция над системными уведомлениями.
///
/// Android умеет планировать напоминания в фоне, Windows — только показать
/// тост при запуске приложения. Разница спрятана за этой интерфейсом,
/// поэтому планировщик уведомлений остаётся единым.
abstract interface class NotificationService {
  /// Подготавливает плагин: инициализация, канал, часовой пояс.
  Future<void> init();

  /// Просит разрешение на уведомления. Возвращает `false`, если отказали.
  Future<bool> requestPermissions();

  /// Отменяет все ранее запланированные уведомления.
  Future<void> cancelAll();

  /// Планирует уведомления на будущее.
  Future<void> scheduleAll(List<NotificationEvent> events);

  /// Показывает уведомление немедленно, минуя расписание.
  Future<void> showNow(NotificationEvent event);

  /// Запланированные уведомления — для самопроверки и отладки.
  Future<List<PendingNotification>> pending();

  /// Умеет ли платформа планировать уведомления в фоне.
  ///
  /// На Windows это `false`: там показываем тосты при запуске.
  bool get supportsScheduling;
}

/// Уведомление, ожидающее срабатывания.
class PendingNotification {
  const PendingNotification({required this.id, required this.title});

  final int id;
  final String title;
}
