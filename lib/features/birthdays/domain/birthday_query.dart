import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';

/// Как сортировать и фильтровать список дней рождения.
enum BirthdaySort {
  /// Ближайшие сверху: сегодня → завтра → через неделю → дальше.
  upcoming,

  /// По имени, по алфавиту.
  byName,

  /// По дате в году: 1 января → 31 декабря.
  byCalendarDate,

  /// Важные сверху, затем остальные по близости.
  importantFirst,
}

/// Параметры выборки списка дней рождения.
class BirthdayQuery {
  const BirthdayQuery({
    this.search = '',
    this.importantOnly = false,
    this.sort = BirthdaySort.upcoming,
    this.reference,
  });

  /// Поисковая строка по имени или заметке.
  final String search;

  /// Показывать только помеченные как важные.
  final bool importantOnly;

  /// Порядок сортировки.
  final BirthdaySort sort;

  /// Отсчётная дата для расчёта «через сколько дней». По умолчанию — сегодня.
  final DateTime? reference;

  BirthdayQuery copyWith({
    String? search,
    bool? importantOnly,
    BirthdaySort? sort,
    DateTime? reference,
  }) {
    return BirthdayQuery(
      search: search ?? this.search,
      importantOnly: importantOnly ?? this.importantOnly,
      sort: sort ?? this.sort,
      reference: reference ?? this.reference,
    );
  }
}

/// День рождения вместе с рассчитанным расстоянием до него.
class BirthdayWithOccurrence {
  const BirthdayWithOccurrence({required this.birthday, required this.occurrence});

  final Birthday birthday;
  final BirthdayOccurrence occurrence;
}
