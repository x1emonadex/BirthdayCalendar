import 'package:birthday_calendar/core/providers/clock_provider.dart';
import 'package:birthday_calendar/core/providers/database_provider.dart';
import 'package:birthday_calendar/features/notifications/presentation/providers/notification_providers.dart';
import 'package:birthday_calendar/features/widget/home_widget_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

/// Имя задачи, которое придёт в обработчик.
const String kNotificationRefreshTask = 'birthday-notification-refresh';

/// Уникальное имя: повторная регистрация обновляет ту же задачу, а не плодит
/// новые.
const String kNotificationRefreshTaskId = 'birthday-notification-refresh';

/// Как часто пересчитывать расписание.
///
/// Двенадцать часов — компромисс: чаще система всё равно не даст (минимум
/// 15 минут, и она сама решает, когда запускать), а реже означало бы, что
/// после прошедшего дня рождения напоминания на следующий год появляются с
/// заметной задержкой.
const Duration kNotificationRefreshInterval = Duration(hours: 12);

/// Точка входа фоновой задачи.
///
/// Функция обязана быть верхнеуровневой и помеченной `vm:entry-point`: система
/// запускает её в отдельном изоляте, и без пометки движок не найдёт её после
/// сборки в релизе.
@pragma('vm:entry-point')
void notificationRefreshDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await refreshNotificationSchedule();
      return true;
    } catch (_) {
      // Вернуть false — попросить систему повторить попытку по её правилам.
      return false;
    }
  });
}

/// Пересчитывает расписание уведомлений, не открывая приложение.
///
/// Работает в фоновом изоляте, где своего контейнера провайдеров нет, —
/// поэтому создаём отдельный. Он открывает ту же базу и закрывает её при
/// уничтожении, а планирование остаётся ровно тем же кодом, что и в
/// приложении: второй реализации, которая могла бы разойтись с первой, нет.
Future<void> refreshNotificationSchedule() async {
  final container = ProviderContainer();
  try {
    final service = container.read(notificationServiceProvider);
    await service.init();
    await container.read(notificationSchedulerProvider).refresh();

    // Заодно обновляем виджет: приложение закрыто, и без этого счётчик дней
    // на рабочем столе застыл бы на моменте последнего запуска.
    await syncHomeWidget(
      repository: container.read(birthdayRepositoryProvider),
      now: container.read(clockProvider).now(),
    );
  } finally {
    container.dispose();
  }
}

/// Ставит периодическую задачу пересчёта расписания.
///
/// Без неё расписание устаревает: оно строится на ближайшее вхождение, и
/// после того как дата прошла, следующее появится только при следующем
/// запуске приложения.
Future<void> registerNotificationRefreshTask() async {
  await Workmanager().initialize(notificationRefreshDispatcher);
  await Workmanager().registerPeriodicTask(
    kNotificationRefreshTaskId,
    kNotificationRefreshTask,
    frequency: kNotificationRefreshInterval,
    // update, а не keep: частота должна применяться и к уже стоящей задаче,
    // иначе после смены интервала на устройстве осталась бы старая.
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}
