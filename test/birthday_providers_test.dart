import 'package:birthday_calendar/core/database/app_database.dart';
import 'package:birthday_calendar/core/providers/clock_provider.dart';
import 'package:birthday_calendar/core/providers/database_provider.dart';
import 'package:birthday_calendar/core/utils/leap_day_rule.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_grouping.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:birthday_calendar/features/birthdays/presentation/providers/birthday_actions_provider.dart';
import 'package:birthday_calendar/features/birthdays/presentation/providers/birthday_list_providers.dart';
import 'package:birthday_calendar/features/profiles/presentation/current_profile_provider.dart';
import 'package:birthday_calendar/features/settings/presentation/settings_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  ProviderContainer makeContainer({DateTime? now}) {
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(
          FixedClock(now ?? DateTime(2026, 9, 29)),
        ),
      ],
    );
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = makeContainer();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<List<BirthdayWithOccurrence>> readUpcoming() {
    return container.read(upcomingBirthdaysProvider.future);
  }

  group('инфраструктурные провайдеры', () {
    test('репозиторий доступен через провайдер', () {
      expect(container.read(birthdayRepositoryProvider), isNotNull);
    });

    test('текущий профиль — «Мой список»', () async {
      final profile = await container.read(currentProfileProvider.future);
      expect(profile.name, 'Мой список');
      expect(profile.id, isNotEmpty);
    });

    test('профиль создаётся один раз', () async {
      final first = await container.read(currentProfileProvider.future);
      container.invalidate(currentProfileProvider);
      final second = await container.read(currentProfileProvider.future);
      expect(first.id, second.id);
    });

    test('правило 29 февраля по умолчанию — 28 февраля', () async {
      final rule = await container.read(leapDayRuleProvider.future);
      expect(rule, LeapDayRule.february28);
    });
  });

  group('часы', () {
    test('Clock.now возвращает текущее время', () {
      const clock = Clock();
      expect(
        clock.now().millisecondsSinceEpoch,
        closeTo(DateTime.now().millisecondsSinceEpoch, 5000),
      );
    });

    test('FixedClock всегда возвращает одно значение', () {
      final value = DateTime(2020, 5, 17);
      final clock = FixedClock(value);
      expect(clock.now(), value);
      expect(clock.now(), clock.now());
    });
  });

  group('пустые списки', () {
    test('upcoming пуст при отсутствии записей', () async {
      expect(await readUpcoming(), isEmpty);
    });

    test('allBirthdays пуст при отсутствии записей', () async {
      final items = await container.read(allBirthdaysProvider.future);
      expect(items, isEmpty);
    });

    test('разделы пуст при отсутствии записей', () async {
      final sections = await container.read(upcomingSectionsProvider.future);
      expect(sections, isEmpty);
    });
  });

  group('create через actions', () {
    test('добавляет запись и обновляет список', () async {
      final actions = container.read(birthdayActionsProvider);
      await actions.create(
        const BirthdayDraft(name: 'Иван', day: 29, month: 9),
      );

      final items = await readUpcoming();
      expect(items, hasLength(1));
      expect(items.single.birthday.name, 'Иван');
    });

    test('появляется в разделах после создания', () async {
      final actions = container.read(birthdayActionsProvider);
      await actions.create(
        const BirthdayDraft(name: 'Иван', day: 29, month: 9),
      );

      final sections = await container.read(upcomingSectionsProvider.future);
      expect(sections, hasLength(1));
      expect(sections.first.section, BirthdaySection.today);
    });

    test('возвращает созданную запись', () async {
      final actions = container.read(birthdayActionsProvider);
      final created = await actions.create(
        const BirthdayDraft(name: 'Аня', day: 1, month: 1),
      );
      expect(created.name, 'Аня');
      expect(created.id, isNotEmpty);
    });
  });

  group('update через actions', () {
    test('изменяет запись и обновляет список', () async {
      final actions = container.read(birthdayActionsProvider);
      final created = await actions.create(
        const BirthdayDraft(name: 'Иван', day: 29, month: 9),
      );

      await actions.update(
        created.id,
        const BirthdayDraft(name: 'Пётр', day: 30, month: 9),
      );

      final items = await readUpcoming();
      expect(items.single.birthday.name, 'Пётр');
      expect(items.single.occurrence.daysUntil, 1);
    });
  });

  group('delete через actions', () {
    test('удаляет запись и обновляет список', () async {
      final actions = container.read(birthdayActionsProvider);
      final created = await actions.create(
        const BirthdayDraft(name: 'Иван', day: 29, month: 9),
      );

      expect(await actions.delete(created.id), isTrue);
      expect(await readUpcoming(), isEmpty);
    });

    test('удаление несуществующего возвращает false', () async {
      final actions = container.read(birthdayActionsProvider);
      expect(await actions.delete('нет-такого'), isFalse);
    });
  });

  group('deleteAll через actions', () {
    test('очищает весь список', () async {
      final actions = container.read(birthdayActionsProvider);
      await actions.create(const BirthdayDraft(name: 'А', day: 1, month: 1));
      await actions.create(const BirthdayDraft(name: 'Б', day: 2, month: 1));
      expect(await readUpcoming(), hasLength(2));

      expect(await actions.deleteAll(), 2);
      expect(await readUpcoming(), isEmpty);
    });
  });

  group('параметры полного списка', () {
    test('изначально пустые', () {
      final query = container.read(allBirthdaysQueryProvider);
      expect(query.search, '');
      expect(query.importantOnly, isFalse);
      expect(query.sort, BirthdaySort.upcoming);
    });

    test('setSearch меняет поиск', () {
      container
          .read(allBirthdaysQueryControllerProvider.notifier)
          .setSearch('иван');
      expect(container.read(allBirthdaysQueryProvider).search, 'иван');
    });

    test('setImportantOnly переключает фильтр', () {
      container
          .read(allBirthdaysQueryControllerProvider.notifier)
          .setImportantOnly(true);
      expect(container.read(allBirthdaysQueryProvider).importantOnly, isTrue);
    });

    test('setSort меняет сортировку', () {
      container
          .read(allBirthdaysQueryControllerProvider.notifier)
          .setSort(BirthdaySort.byName);
      expect(container.read(allBirthdaysQueryProvider).sort,
          BirthdaySort.byName);
    });

    test('reset возвращает значения по умолчанию', () {
      final notifier =
          container.read(allBirthdaysQueryControllerProvider.notifier);
      notifier
        ..setSearch('иван')
        ..setImportantOnly(true)
        ..setSort(BirthdaySort.byName)
        ..reset();

      final query = container.read(allBirthdaysQueryProvider);
      expect(query.search, '');
      expect(query.importantOnly, isFalse);
      expect(query.sort, BirthdaySort.upcoming);
    });
  });

  group('влияние параметров на список', () {
    test('поиск фильтрует записи', () async {
      final actions = container.read(birthdayActionsProvider);
      await actions.create(const BirthdayDraft(name: 'Иван', day: 1, month: 1));
      await actions.create(const BirthdayDraft(name: 'Анна', day: 2, month: 1));

      container
          .read(allBirthdaysQueryControllerProvider.notifier)
          .setSearch('иван');

      final items = await container.read(allBirthdaysProvider.future);
      expect(items, hasLength(1));
      expect(items.single.birthday.name, 'Иван');
    });

    test('фильтр «важные» оставляет только важные', () async {
      final actions = container.read(birthdayActionsProvider);
      await actions.create(const BirthdayDraft(name: 'Обычный', day: 1, month: 1));
      await actions.create(
        const BirthdayDraft(name: 'Важный', day: 2, month: 1, isImportant: true),
      );

      container
          .read(allBirthdaysQueryControllerProvider.notifier)
          .setImportantOnly(true);

      final items = await container.read(allBirthdaysProvider.future);
      expect(items.single.birthday.name, 'Важный');
    });
  });

  group('upcoming ограничен десятью записями', () {
    test('не показывает больше десяти', () async {
      final actions = container.read(birthdayActionsProvider);
      for (var i = 1; i <= 15; i++) {
        await actions.create(
          BirthdayDraft(name: 'Человек $i', day: i, month: 9),
        );
      }
      final items = await readUpcoming();
      expect(items, hasLength(10));
    });
  });

  group('фиксированные часы делают результат детерминированным', () {
    test('одна и та же дата даёт один и тот же результат', () async {
      final actions = container.read(birthdayActionsProvider);
      await actions.create(
        const BirthdayDraft(name: 'Иван', day: 29, month: 9),
      );

      final first = await readUpcoming();
      final second = await readUpcoming();
      expect(
        first.single.occurrence.daysUntil,
        second.single.occurrence.daysUntil,
      );
      expect(first.single.occurrence.daysUntil, 0);
    });

    test('другой день сдвигает расстояние', () async {
      final actions = container.read(birthdayActionsProvider);
      await actions.create(
        const BirthdayDraft(name: 'Иван', day: 30, month: 9),
      );
      final items = await readUpcoming();
      expect(items.single.occurrence.daysUntil, 1);
    });
  });
}
