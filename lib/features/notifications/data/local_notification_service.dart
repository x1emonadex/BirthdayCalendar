import 'package:birthday_calendar/features/notifications/data/notification_service.dart';
import 'package:birthday_calendar/features/notifications/domain/notification_plan_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Реализация уведомлений через `flutter_local_notifications`.
///
/// Единственная реализация для Android и Windows. Различие платформ спрятано
/// здесь: Android планирует через AlarmManager, Windows — через WinRT, но
/// интерфейс для обоих одинаковый.
class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;

  @override
  bool get supportsScheduling {
    return !kIsWeb;
  }

  @override
  Future<void> init() async {
    if (_initialized) return;

    // База часовых поясов нужна, чтобы TZDateTime понимал локальное время.
    tzdata.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      // Если системный пояс определить не удалось, остаёмся на UTC:
      // уведомления всё равно сработают, просто могут сместиться.
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Windows требует идентификатор приложения. Он должен быть стабильным
    // между запусками, иначе ОС не соберёт уведомления в одну группу.
    const settings = InitializationSettings(
      android: androidSettings,
      windows: WindowsInitializationSettings(
        appName: 'Дни рождения',
        appUserModelId: 'com.bdays.birthday_calendar',
        guid: '8a1f5c3e-6b2d-4e7a-9c15-3b8f2a6d1e04',
      ),
    );

    await _plugin.initialize(settings: settings);
    _initialized = true;

    await _createChannel();
  }

  @override
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    // На Android ниже 13 разрешение выдаётся автоматически.
    final granted = await android.requestNotificationsPermission();
    return granted ?? true;
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // Windows отменяет уведомления только у приложений с package identity
      // (упакованных как MSIX). У обычной сборки метод бросает исключение.
      // Старые уведомления при этом не мешают: идентификаторы стабильные,
      // поэтому повторное планирование перезаписывает их, а не плодит.
    }
  }

  @override
  Future<void> scheduleAll(List<NotificationEvent> events) async {
    if (kIsWeb) return;

    for (final event in events) {
      await _plugin.zonedSchedule(
        id: event.id,
        title: event.title,
        body: event.body,
        scheduledDate: tz.TZDateTime.from(event.fireAt, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: event.birthdayId,
      );
    }
  }

  @override
  Future<void> showNow(NotificationEvent event) async {
    await _plugin.show(
      id: event.id,
      title: event.title,
      body: event.body,
      notificationDetails: _details,
      payload: event.birthdayId,
    );
  }

  @override
  Future<List<PendingNotification>> pending() async {
    final requests = await _plugin.pendingNotificationRequests();
    return requests
        .map((r) => PendingNotification(id: r.id, title: r.title ?? ''))
        .toList();
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          kNotificationChannelId,
          'Напоминания о днях рождения',
          channelDescription:
              'Уведомления за неделю, за день и в день рождения',
          importance: Importance.high,
          priority: Priority.high,
        ),
        windows: WindowsNotificationDetails(),
      );

  /// Канал создаётся явно: без него Android 8+ молча игнорирует уведомления.
  Future<void> _createChannel() async {
    if (kIsWeb) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        kNotificationChannelId,
        'Напоминания о днях рождения',
        description: 'Уведомления о днях рождения',
        importance: Importance.high,
      ),
    );
  }
}
