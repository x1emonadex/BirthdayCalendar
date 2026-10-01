import 'package:birthday_calendar/core/providers/clock_provider.dart';
import 'package:birthday_calendar/core/providers/database_provider.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_grouping.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Параметры полного списка: поиск, фильтр «важные», сортировка.
///
/// Отдельный провайдер, чтобы при изменении поиска пересчитывался только
/// список, а не всё дерево приложения.
class AllBirthdaysQuery {
  const AllBirthdaysQuery({
    this.search = '',
    this.importantOnly = false,
    this.sort = BirthdaySort.upcoming,
  });

  final String search;
  final bool importantOnly;
  final BirthdaySort sort;

  AllBirthdaysQuery copyWith({
    String? search,
    bool? importantOnly,
    BirthdaySort? sort,
  }) {
    return AllBirthdaysQuery(
      search: search ?? this.search,
      importantOnly: importantOnly ?? this.importantOnly,
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AllBirthdaysQuery &&
        other.search == search &&
        other.importantOnly == importantOnly &&
        other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(search, importantOnly, sort);
}

/// Контроллер параметров списка: UI меняет его методы, читает через
/// [allBirthdaysQueryProvider].
final allBirthdaysQueryControllerProvider =
    NotifierProvider<AllBirthdaysQueryNotifier, AllBirthdaysQuery>(
  AllBirthdaysQueryNotifier.new,
);

class AllBirthdaysQueryNotifier extends Notifier<AllBirthdaysQuery> {
  @override
  AllBirthdaysQuery build() => const AllBirthdaysQuery();

  void setSearch(String value) =>
      state = state.copyWith(search: value);

  void setImportantOnly(bool value) =>
      state = state.copyWith(importantOnly: value);

  void setSort(BirthdaySort value) => state = state.copyWith(sort: value);

  void reset() => state = const AllBirthdaysQuery();
}

/// Параметры полного списка для чтения из UI.
final Provider<AllBirthdaysQuery> allBirthdaysQueryProvider =
    Provider<AllBirthdaysQuery>((ref) => ref.watch(allBirthdaysQueryControllerProvider));

/// Все дни рождения с учётом поиска, фильтров и сортировки.
final FutureProvider<List<BirthdayWithOccurrence>> allBirthdaysProvider =
    FutureProvider<List<BirthdayWithOccurrence>>((ref) async {
  final query = ref.watch(allBirthdaysQueryControllerProvider);
  final repository = ref.watch(birthdayRepositoryProvider);
  final now = ref.watch(clockProvider).now();

  return repository.list(
    query: BirthdayQuery(
      search: query.search,
      importantOnly: query.importantOnly,
      sort: query.sort,
      reference: now,
    ),
  );
});

/// Ближайшие дни рождения для главного экрана.
final FutureProvider<List<BirthdayWithOccurrence>> upcomingBirthdaysProvider =
    FutureProvider<List<BirthdayWithOccurrence>>((ref) async {
  final repository = ref.watch(birthdayRepositoryProvider);
  final now = ref.watch(clockProvider).now();

  final all = await repository.list(
    query: BirthdayQuery(sort: BirthdaySort.upcoming, reference: now),
  );
  return all.take(10).toList();
});

/// Ближайшие дни рождения, разбитые на разделы.
final FutureProvider<List<BirthdaySectionData>> upcomingSectionsProvider =
    FutureProvider<List<BirthdaySectionData>>((ref) async {
  final items = await ref.watch(upcomingBirthdaysProvider.future);
  return BirthdayGrouping.group(items);
});

/// Все дни рождения без ограничения по количеству.
///
/// Нужен календарю: сетка за месяц показывает все события, а
/// [upcomingBirthdaysProvider] ограничен десятью записями и на далёкие
/// месяцы не распространяется.
final FutureProvider<List<BirthdayWithOccurrence>> allYearsBirthdaysProvider =
    FutureProvider<List<BirthdayWithOccurrence>>((ref) async {
  final repository = ref.watch(birthdayRepositoryProvider);
  final now = ref.watch(clockProvider).now();

  return repository.list(
    query: BirthdayQuery(
      sort: BirthdaySort.byCalendarDate,
      reference: now,
    ),
  );
});

/// Одна запись по идентификатору — для экрана редактирования.
final FutureProviderFamily<BirthdayWithOccurrence?, String>
    birthdayByIdProvider = FutureProvider.family(
  (ref, id) async {
    final repository = ref.watch(birthdayRepositoryProvider);
    final now = ref.watch(clockProvider).now();
    final birthday = await repository.findById(id);
    if (birthday == null) return null;

    final items = await repository.list(query: BirthdayQuery(reference: now));
    for (final item in items) {
      if (item.birthday.id == id) return item;
    }
    return null;
  },
);
