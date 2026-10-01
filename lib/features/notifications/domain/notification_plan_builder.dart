import 'dart:convert';

import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:birthday_calendar/features/notifications/domain/notification_settings.dart';

/// Что сделать с уведомлением.
enum NotificationStatus {
  /// Назначено на будущее — планируем в системе.
  scheduled,

  /// Время почти наступило — показываем сразу, не планируя.
  immediate,

  /// Время ушло, а порог не выдержан — пропускаем.
  skipped,
}

/// Тексты одного уведомления.
class NotificationText {
  const NotificationText({required this.title, required this.body});

  final String title;
  final String body;
}

/// Одно уведомление в расписании.
class NotificationEvent {
  const NotificationEvent({
    required this.id,
    required this.birthdayId,
    required this.profileId,
    required this.name,
    required this.daysBefore,
    required this.occurrenceDate,
    required this.fireAt,
    required this.status,
    this.isImportant = false,
  });

  /// Стабильный идентификатор: не меняется между запусками приложения.
  final int id;

  final String birthdayId;
  final String profileId;
  final String name;

  /// За сколько дней до праздника это уведомление.
  final int daysBefore;

  /// Дата праздника с учётом переноса 29 февраля.
  final DateTime occurrenceDate;

  /// Момент срабатывания в местном времени.
  final DateTime fireAt;

  final NotificationStatus status;
  final bool isImportant;

  /// Дата в формате «марта 15» — так читается в уведомлении на русском.
  String get dateLabel {
    return '${monthNames[occurrenceDate.month - 1]} ${occurrenceDate.day}';
  }

  /// Заголовок уведомления — зависит от того, когда оно сработало.
  String get title {
    if (daysBefore == 0) return 'Сегодня день рождения';
    return 'Через $daysBefore '
        '${BirthdayDateUtils.pluralDays(daysBefore)} — $name';
  }

  String get body => '$name, $dateLabel';

  /// Собирает тексты уведомления из нескольких событий одного дня.
  ///
  /// Раньше каждое событие планировалось отдельным уведомлением, но Android
  /// показывал только последнее: несколько дней рождения в один день
  /// выглядели как одна запись. Теперь события с одинаковым [fireAt]
  /// объединяются в одно уведомление, где перечислены все имени.
  /// Месяцы родительного падежа для дат в уведомлениях.
  static const List<String> monthNames = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  @override
  String toString() =>
      'NotificationEvent($name, $daysBefore дн., $fireAt, $status)';
}

/// Чистый планировщик уведомлений.
///
/// Не зависит от Flutter, Drift и плагина уведомлений: на входе дата,
/// список дней рождения и настройки, на выходе — готовый план. Так его
/// можно полностью покрыть тестами без устройства и эмулятора.
class NotificationPlanBuilder {
  const NotificationPlanBuilder._();

  /// Строит расписание уведомлений.
  ///
  /// [immediateThreshold] — до какого момента просроченное уведомление
  /// ещё считается «почти сейчас» и показывается немедленно.
  static List<NotificationEvent> buildPlan({
    required DateTime now,
    required List<BirthdayWithOccurrence> items,
    required NotificationSettings settings,
    Duration immediateThreshold =
        NotificationSettings.defaultImmediateThreshold,
  }) {
    if (!settings.enabled) return const [];

    // Правила сортируем по убыванию: расписание идёт от самого раннего
    // («за неделю») к самому позднему («в день рождения»), независимо от
    // порядка, в котором пользователь выбирал чипы в настройках.
    final rules = settings.daysBefore.toList()
      ..sort((a, b) => b.compareTo(a));

    final events = <NotificationEvent>[];

    for (final item in items) {
      final birthday = item.birthday;

      if (settings.importantOnly && !birthday.isImportant) continue;

      // Дата праздника уже приведена к реальной: перенос 29 февраля
      // применён в репозитории, здесь ничего не меняем.
      final date = item.occurrence.date;

      for (final daysBefore in rules) {
        if (daysBefore < 0) continue;

        final fireAt = DateTime(
          date.year,
          date.month,
          date.day,
          settings.hour,
          settings.minute,
        ).subtract(Duration(days: daysBefore));

        events.add(
          NotificationEvent(
            id: stableNotificationId(
              profileId: birthday.profileId,
              birthdayId: birthday.id,
              daysBefore: daysBefore,
            ),
            birthdayId: birthday.id,
            profileId: birthday.profileId,
            name: birthday.name,
            daysBefore: daysBefore,
            occurrenceDate: date,
            fireAt: fireAt,
            status: _statusOf(fireAt, now, immediateThreshold),
            isImportant: birthday.isImportant,
          ),
        );
      }
    }

    // Порядок детерминирован: по времени срабатывания, затем по имени.
    // Иначе перезапуск приложения мог бы переставить уведомления местами.
    events.sort((a, b) {
      final byTime = a.fireAt.compareTo(b.fireAt);
      if (byTime != 0) return byTime;
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) return byName;
      return a.daysBefore.compareTo(b.daysBefore);
    });

    return events;
  }

  /// Только те события, которые нужно отдать системе как запланированные.
  static List<NotificationEvent> scheduledOnly(
    List<NotificationEvent> events,
  ) {
    return events
        .where((e) => e.status == NotificationStatus.scheduled)
        .toList();
  }

  /// Только те события, которые показываются немедленно.
  static List<NotificationEvent> immediateOnly(
    List<NotificationEvent> events,
  ) {
    return events
        .where((e) => e.status == NotificationStatus.immediate)
        .toList();
  }

  /// Собирает тексты уведомления из нескольких событий одного момента.
  ///
  /// Раньше каждое событие планировалось отдельным уведомлением, но Android
  /// показывал только последнее: несколько дней рождения в один день
  /// выглядели как одна запись. Теперь события с одинаковым
  /// [NotificationEvent.fireAt] объединяются в одно уведомление, где
  /// перечислены все имена.
  ///
  /// Дата праздника берётся из самих событий, а не передаётся отдельно:
  /// так её нельзя перепутать с датой срабатывания.
  static NotificationText textFor(List<NotificationEvent> events) {
    final names = <String>[];
    for (final event in events) {
      if (!names.contains(event.name)) names.add(event.name);
    }
    names.sort();

    final when = events.first;
    final occurrence = when.occurrenceDate;
    final date =
        '${NotificationEvent.monthNames[occurrence.month - 1]} '
        '${occurrence.day}';
    final title = when.daysBefore == 0
        ? 'Сегодня день рождения'
        : 'Через ${when.daysBefore} '
            '${BirthdayDateUtils.pluralDays(when.daysBefore)}';

    if (names.length == 1) {
      return NotificationText(
        title: when.daysBefore == 0 ? title : '$title — ${names.first}',
        body: '${names.first}, $date',
      );
    }
    return NotificationText(
      title: '$title: ${names.length} '
          '${BirthdayDateUtils.pluralDays(names.length)}',
      body: '${names.join(', ')}, $date',
    );
  }

  /// Группирует события, которые должны сработать в один момент.
  ///
  /// Несколько дней рождения могут выпасть на одну дату. Если показать
  /// отдельное уведомление для каждого, Android отобразит только
  /// последнее, и часть имён просто пропадёт. Поэтому события с
  /// одинаковым [NotificationEvent.fireAt] собираются в одну группу.
  static Map<DateTime, List<NotificationEvent>> groupByFireAt(
    List<NotificationEvent> events,
  ) {
    final grouped = <DateTime, List<NotificationEvent>>{};
    for (final event in events) {
      grouped.putIfAbsent(event.fireAt, () => []).add(event);
    }
    return grouped;
  }

  /// Определяет статус по времени срабатывания.
  ///
  /// Порядок проверок важен: сначала «в будущем», и только потом порог.
  /// Иначе отрицательная разница `now - fireAt` у будущих событий
  /// удовлетворила бы условию `immediate`.
  static NotificationStatus _statusOf(
    DateTime fireAt,
    DateTime now,
    Duration immediateThreshold,
  ) {
    if (fireAt.isAfter(now)) return NotificationStatus.scheduled;
    if (now.difference(fireAt) <= immediateThreshold) {
      return NotificationStatus.immediate;
    }
    return NotificationStatus.skipped;
  }

  /// Стабильный идентификатор уведомления: FNV-1a по UTF-8 байтам строки.
  ///
  /// Почему не `hash()`: он не гарантирует одинаковый результат между
  /// запусками процесса, и перезапуск приложения создавал бы новые
  /// уведомления вместо перезаписи старых.
  ///
  /// Приведение к unsigned идёт на каждом шаге — иначе на больших значениях
  /// Dart выдаёт отрицательный int. Финальная маска оставляет результат в
  /// диапазоне 0..2^31-1, который требует `flutter_local_notifications`.
  static int stableNotificationId({
    required String profileId,
    required String birthdayId,
    required int daysBefore,
  }) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode('$profileId:$birthdayId:$daysBefore')) {
      hash = (hash ^ byte) & 0xFFFFFFFF;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }
}
