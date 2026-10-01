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
  ///
  /// Принимает готовые группы: по одной на каждый момент срабатывания.
  /// Несколько дней рождения в один день уже объединены в заголовке.
  Future<void> scheduleAll(List<ScheduledNotification> notifications);

  /// Показывает уведомление немедленно, минуя расписание.
  Future<void> showNow(ScheduledNotification notification);

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

/// Готовое к отправке уведомление: момент срабатывания, идентификатор и
/// уже собранные тексты.
class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final DateTime fireAt;
  final String title;
  final String body;
  final String payload;
}
