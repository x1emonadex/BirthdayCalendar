import 'package:birthday_calendar/core/utils/month_names.dart';
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

/// Как подписывать группы в полном списке.
enum MonthHeaderStyle {
  /// Без подписей: список идёт не по датам, подписи повторялись бы.
  none,

  /// «Сентябрь 2026» — список идёт по ближайшим датам.
  monthAndYear,

  /// «Сентябрь» — список идёт по месяцам года, год у месяцев разный.
  monthOnly,
}

/// Строка полного списка: либо подпись месяца, либо запись.
sealed class BirthdayListRow {
  const BirthdayListRow();
}

/// Подпись месяца перед группой записей.
class MonthHeaderRow extends BirthdayListRow {
  const MonthHeaderRow(this.label);

  final String label;
}

/// Одна запись списка.
class BirthdayRow extends BirthdayListRow {
  const BirthdayRow(this.item);

  final BirthdayWithOccurrence item;
}

/// Как подписывать список при такой сортировке.
///
/// По имени и «важные сверху» даты идут вперемешку, и подписи месяцев
/// повторялись бы через строку — там они только мешают.
MonthHeaderStyle headerStyleFor(BirthdaySort sort) {
  return switch (sort) {
    BirthdaySort.upcoming => MonthHeaderStyle.monthAndYear,
    BirthdaySort.byCalendarDate => MonthHeaderStyle.monthOnly,
    BirthdaySort.byName || BirthdaySort.importantFirst => MonthHeaderStyle.none,
  };
}

/// Вставляет подписи месяцев в список.
///
/// Чистая функция: список приходит уже отсортированным, порядок сохраняется.
List<BirthdayListRow> withMonthHeaders(
  List<BirthdayWithOccurrence> items, {
  MonthHeaderStyle style = MonthHeaderStyle.monthAndYear,
}) {
  if (style == MonthHeaderStyle.none) {
    return [for (final item in items) BirthdayRow(item)];
  }

  final rows = <BirthdayListRow>[];
  int? lastYear;
  int? lastMonth;

  for (final item in items) {
    final date = item.occurrence.date;
    if (date.year != lastYear || date.month != lastMonth) {
      rows.add(
        MonthHeaderRow(
          style == MonthHeaderStyle.monthAndYear
              ? monthTitle(date.year, date.month)
              : monthName(date.month),
        ),
      );
      lastYear = date.year;
      lastMonth = date.month;
    }
    rows.add(BirthdayRow(item));
  }

  return rows;
}
