import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';

/// Раздел списка дней рождения.
enum BirthdaySection {
  /// Празднование сегодня.
  today,

  /// Празднование завтра или в ближайшую неделю.
  thisWeek,

  /// Всё, что дальше.
  later,
}

/// Раздел с заголовком и содержимым.
class BirthdaySectionData {
  const BirthdaySectionData({required this.section, required this.items});

  final BirthdaySection section;
  final List<BirthdayWithOccurrence> items;

  bool get isEmpty => items.isEmpty;
}

/// Группировка дней рождения по близости.
///
/// Чистая функция: не обращается к `DateTime.now()` — текущая дата всегда
/// приходит аргументом. Это делает поведение предсказуемым в тестах и не
/// зависит от момента вызова.
class BirthdayGrouping {
  const BirthdayGrouping._();

  /// Сколько дней считать «ближайшей неделей», включая сегодня.
  static const int thisWeekWindow = 7;

  /// Разбивает список на три раздела в порядке: сегодня, неделя, потом.
  ///
  /// Пустые разделы отбрасываются. Порядок внутри раздела сохраняется, то
  /// есть список должен быть уже отсортирован по расстоянию до события.
  static List<BirthdaySectionData> group(List<BirthdayWithOccurrence> items) {
    final today = <BirthdayWithOccurrence>[];
    final thisWeek = <BirthdayWithOccurrence>[];
    final later = <BirthdayWithOccurrence>[];

    for (final item in items) {
      final days = item.occurrence.daysUntil;
      if (days == 0) {
        today.add(item);
      } else if (days <= thisWeekWindow) {
        thisWeek.add(item);
      } else {
        later.add(item);
      }
    }

    return [
      if (today.isNotEmpty)
        BirthdaySectionData(section: BirthdaySection.today, items: today),
      if (thisWeek.isNotEmpty)
        BirthdaySectionData(
          section: BirthdaySection.thisWeek,
          items: thisWeek,
        ),
      if (later.isNotEmpty)
        BirthdaySectionData(section: BirthdaySection.later, items: later),
    ];
  }
}
