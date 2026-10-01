import 'dart:math' as math;

import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';

/// Переносит дни рождения на конкретный год.
///
/// Список из репозитория содержит ближайшее вхождение от «сегодня», поэтому
/// запись с 4 января в 2026-м показалась бы и в 2027-м, и в 2025-м. Календарь
/// листает произвольные годы, поэтому даты вхождения пересчитываются, а
/// возраст считается на дату праздника, а не на «сегодня».
List<BirthdayWithOccurrence> occurrencesInYear(
  List<BirthdayWithOccurrence> items,
  int year, {
  LeapDayFallback fallback = LeapDayFallback.february28,
}) {
  return items.map((item) {
    final b = item.birthday;
    final date = BirthdayDateUtils.celebrationDateInYear(
      year,
      b.month,
      b.day,
      fallback: fallback,
    );
    final birthYear = b.birthYear;
    return BirthdayWithOccurrence(
      birthday: b,
      occurrence: BirthdayOccurrence(
        date: date,
        daysUntil: 0,
        yearsSinceBirth: birthYear == null ? null : math.max(0, year - birthYear),
      ),
    );
  }).toList();
}

/// День месяца с отмеченными днями рождения.
class CalendarDay {
  const CalendarDay({
    required this.date,
    required this.birthdays,
    this.isToday = false,
    this.isOutsideMonth = false,
  });

  final DateTime date;

  /// Дни рождения, приходящиеся на этот день.
  final List<BirthdayWithOccurrence> birthdays;

  final bool isToday;

  /// День из соседнего месяца — показывается приглушённо.
  final bool isOutsideMonth;

  bool get hasBirthdays => birthdays.isNotEmpty;

  /// Есть ли среди событий важное.
  bool get hasImportant => birthdays.any((b) => b.birthday.isImportant);
}

/// Разобранный месяц: сетка из шести строк по семь дней.
class CalendarMonth {
  const CalendarMonth({required this.month, required this.days});

  /// Первый день месяца.
  final DateTime month;

  final List<CalendarDay> days;

  /// Название месяца для заголовка, например «Сентябрь 2026».
  String get title => '${_monthNames[month.month - 1]} ${month.year}';

  /// Все дни рождения месяца, отсортированные по дате.
  List<BirthdayWithOccurrence> get birthdays {
    final result = <BirthdayWithOccurrence>[];
    for (final day in days) {
      if (day.isOutsideMonth) continue;
      result.addAll(day.birthdays);
    }
    result.sort((a, b) {
      final byDay = a.birthday.day.compareTo(b.birthday.day);
      if (byDay != 0) return byDay;
      final byName =
          a.birthday.name.toLowerCase().compareTo(
                b.birthday.name.toLowerCase(),
              );
      return byName;
    });
    return result;
  }

  /// Строит сетку месяца.
  ///
  /// Месяц всегда содержит 42 дня (шесть недель), чтобы высота сетки не
  /// прыгала при переключении месяцев.
  static CalendarMonth build(
    DateTime month, {
    required List<BirthdayWithOccurrence> items,
    required DateTime today,
  }) {
    final firstOfMonth = DateTime(month.year, month.month);
    final todayOnly = DateTime(today.year, today.month, today.day);

    // Неделя начинается с понедельника: сдвигаем назад до нужного дня.
    // DateTime.weekday: понедельник = 1.
    final leading = (firstOfMonth.weekday - 1) % 7;
    final gridStart = firstOfMonth.subtract(Duration(days: leading));

    // Раскладываем события по дате, привязанной к выбранному месяцу.
    // occurrence.date указывает на ближайшее наступление, поэтому для
    // календаря берём только месяц и день и подставляем год сетки.
    final byDate = <String, List<BirthdayWithOccurrence>>{};
    for (final item in items) {
      final occurrence = item.occurrence.date;
      if (occurrence.month != firstOfMonth.month) continue;
      byDate
          .putIfAbsent('${firstOfMonth.year}-${occurrence.month}-'
              '${occurrence.day}', () => [])
          .add(item);
    }

    final days = <CalendarDay>[];
    for (var i = 0; i < 42; i++) {
      final date = DateTime(
        gridStart.year,
        gridStart.month,
        gridStart.day + i,
      );
      final key = '${date.year}-${date.month}-${date.day}';
      days.add(
        CalendarDay(
          date: date,
          birthdays: byDate[key] ?? const [],
          isToday: date == todayOnly,
          isOutsideMonth: date.month != firstOfMonth.month,
        ),
      );
    }

    return CalendarMonth(month: firstOfMonth, days: days);
  }

  static const List<String> _monthNames = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];
}
