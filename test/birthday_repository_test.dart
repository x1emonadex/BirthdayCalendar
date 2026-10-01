import 'package:birthday_calendar/core/database/app_database.dart';
import 'package:birthday_calendar/core/utils/leap_day_rule.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_repository.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late BirthdayRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = BirthdayRepository(db);
  });

  tearDown(() => db.close());

  DateTime ref(int y, int m, int d) => DateTime(y, m, d);

  group('профиль по умолчанию', () {
    test('создаётся автоматически при первом обращении', () async {
      final id = await db.ensureDefaultProfileId();
      expect(id, isNotEmpty);
      final profile = await db.defaultProfile();
      expect(profile, isNotNull);
      expect(profile!.name, 'Мой список');
    });

    test('повторные вызовы возвращают тот же id', () async {
      final first = await db.ensureDefaultProfileId();
      final second = await db.ensureDefaultProfileId();
      expect(first, second);
    });
  });

  group('create', () {
    test('создаёт запись с UUID и профилем', () async {
      final created = await repo.create(name: 'Иван', day: 15, month: 3);

      expect(created.id, isNotEmpty);
      expect(created.name, 'Иван');
      expect(created.day, 15);
      expect(created.month, 3);
      expect(created.birthYear, isNull);
      expect(created.note, '');
      expect(created.isImportant, isFalse);
      expect(created.profileId, await db.ensureDefaultProfileId());

      final rows = await db.select(db.birthdayEntries).get();
      expect(rows, hasLength(1));
    });

    test('обрезает пробелы в имени и заметке', () async {
      final created = await repo.create(
        name: '  Мария  ',
        day: 1,
        month: 1,
        note: '   любит торт  ',
      );
      expect(created.name, 'Мария');
      expect(created.note, 'любит торт');
    });

    test('генерирует разные id для разных записей', () async {
      final a = await repo.create(name: 'Иван', day: 1, month: 1);
      final b = await repo.create(name: 'Иван', day: 2, month: 1);
      expect(a.id, isNot(b.id));
    });
  });

  group('валидация', () {
    test('пустое имя отклоняется', () async {
      expect(
        () => repo.create(name: '   ', day: 1, month: 1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('несуществующий месяц отклоняется', () async {
      expect(
        () => repo.create(name: 'Иван', day: 1, month: 13),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repo.create(name: 'Иван', day: 1, month: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('30 февраля отклоняется', () async {
      expect(
        () => repo.create(name: 'Иван', day: 30, month: 2),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('31 апреля отклоняется', () async {
      expect(
        () => repo.create(name: 'Иван', day: 31, month: 4),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('29 февраля допускается', () async {
      final created = await repo.create(name: 'Иван', day: 29, month: 2);
      expect(created.day, 29);
    });

    test('31 декабря допускается', () async {
      final created = await repo.create(name: 'Иван', day: 31, month: 12);
      expect(created.day, 31);
    });

    test('неправдоподобный год отклоняется', () async {
      expect(
        () => repo.create(name: 'Иван', day: 1, month: 1, birthYear: 1800),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repo.create(name: 'Иван', day: 1, month: 1, birthYear: 3000),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('невалидные данные не попадают в базу', () async {
      await expectLater(
        repo.create(name: '', day: 1, month: 1),
        throwsA(isA<ArgumentError>()),
      );
      final rows = await db.select(db.birthdayEntries).get();
      expect(rows, isEmpty);
    });
  });

  group('update', () {
    test('меняет все поля', () async {
      final created = await repo.create(
        name: 'Иван',
        day: 15,
        month: 3,
        birthYear: 1990,
      );

      final updated = await repo.update(
        id: created.id,
        name: 'Иван Петров',
        day: 16,
        month: 4,
        birthYear: 1991,
        note: 'заметка',
        isImportant: true,
      );

      expect(updated.name, 'Иван Петров');
      expect(updated.day, 16);
      expect(updated.month, 4);
      expect(updated.birthYear, 1991);
      expect(updated.note, 'заметка');
      expect(updated.isImportant, isTrue);

      final fromDb = await repo.findById(created.id);
      expect(fromDb!.name, 'Иван Петров');
      expect(fromDb.isImportant, isTrue);
    });

    test('сбрасывает год рождения, если не передан', () async {
      final created = await repo.create(
        name: 'Иван',
        day: 15,
        month: 3,
        birthYear: 1990,
      );
      expect(created.birthYear, 1990);

      final updated = await repo.update(
        id: created.id,
        name: 'Иван',
        day: 15,
        month: 3,
      );
      expect(updated.birthYear, isNull);
    });

    test('несуществующий id бросает StateError', () async {
      expect(
        () => repo.update(id: 'нет-такого', name: 'Иван', day: 1, month: 1),
        throwsA(isA<StateError>()),
      );
    });

    test('не меняет профиль и дату создания', () async {
      final created = await repo.create(name: 'Иван', day: 15, month: 3);
      final updated = await repo.update(
        id: created.id,
        name: 'Иван',
        day: 15,
        month: 3,
      );
      expect(updated.profileId, created.profileId);
      // SQLite хранит даты с точностью до секунды, поэтому сравниваем
      // с округлением — микросекунды при записи не сохраняются.
      expect(
        updated.createdAt.millisecondsSinceEpoch ~/ 1000,
        created.createdAt.millisecondsSinceEpoch ~/ 1000,
      );
    });
  });

  group('delete', () {
    test('удаляет существующую запись', () async {
      final created = await repo.create(name: 'Иван', day: 15, month: 3);
      expect(await repo.delete(created.id), isTrue);
      expect(await repo.findById(created.id), isNull);
    });

    test('повторное удаление возвращает false', () async {
      final created = await repo.create(name: 'Иван', day: 15, month: 3);
      await repo.delete(created.id);
      expect(await repo.delete(created.id), isFalse);
    });

    test('удаляет все записи профиля', () async {
      await repo.create(name: 'А', day: 1, month: 1);
      await repo.create(name: 'Б', day: 2, month: 1);
      await repo.create(name: 'В', day: 3, month: 1);
      expect(await repo.count(), 3);
      expect(await repo.deleteAll(), 3);
      expect(await repo.count(), 0);
    });
  });

  group('сортировка по близости', () {
    test('сегодня → завтра → дальше', () async {
      await repo.create(name: 'Через неделю', day: 22, month: 9);
      await repo.create(name: 'Сегодня', day: 29, month: 9);
      await repo.create(name: 'Завтра', day: 30, month: 9);

      final items = await repo.list(
        query: BirthdayQuery(reference: ref(2026, 9, 29)),
      );
      expect(
        items.map((i) => i.birthday.name).toList(),
        ['Сегодня', 'Завтра', 'Через неделю'],
      );
      expect(items[0].occurrence.daysUntil, 0);
      expect(items[1].occurrence.daysUntil, 1);
    });

    test('при равном расстоянии сортирует по имени', () async {
      await repo.create(name: 'Борис', day: 29, month: 9);
      await repo.create(name: 'Анна', day: 29, month: 9);

      final items = await repo.list(
        query: BirthdayQuery(reference: ref(2026, 9, 29)),
      );
      expect(items[0].birthday.name, 'Анна');
      expect(items[1].birthday.name, 'Борис');
    });

    test('прошедший день рождения уходит на следующий год', () async {
      await repo.create(name: 'Вчера', day: 28, month: 9);
      final items = await repo.list(
        query: BirthdayQuery(reference: ref(2026, 9, 29)),
      );
      expect(items.single.occurrence.daysUntil, 364);
    });
  });

  group('сортировка по имени', () {
    test('алфавит, регистр не важен', () async {
      await repo.create(name: 'ярослав', day: 1, month: 1);
      await repo.create(name: 'Анна', day: 2, month: 1);
      await repo.create(name: 'Борис', day: 3, month: 1);

      final items = await repo.list(
        query: BirthdayQuery(
          sort: BirthdaySort.byName,
          reference: ref(2026, 1, 1),
        ),
      );
      expect(
        items.map((i) => i.birthday.name).toList(),
        ['Анна', 'Борис', 'ярослав'],
      );
    });
  });

  group('сортировка по календарной дате', () {
    test('идёт с января по декабрь', () async {
      await repo.create(name: 'Декабрь', day: 31, month: 12);
      await repo.create(name: 'Февраль', day: 10, month: 2);
      await repo.create(name: 'Июнь', day: 5, month: 6);

      final items = await repo.list(
        query: BirthdayQuery(
          sort: BirthdaySort.byCalendarDate,
          reference: ref(2026, 1, 1),
        ),
      );
      expect(
        items.map((i) => i.birthday.month).toList(),
        [2, 6, 12],
      );
    });

    test('внутри месяца сортирует по дню', () async {
      await repo.create(name: 'Поздний', day: 20, month: 3);
      await repo.create(name: 'Ранний', day: 5, month: 3);

      final items = await repo.list(
        query: BirthdayQuery(
          sort: BirthdaySort.byCalendarDate,
          reference: ref(2026, 1, 1),
        ),
      );
      expect(items[0].birthday.day, 5);
      expect(items[1].birthday.day, 20);
    });
  });

  group('сортировка «важные сверху»', () {
    test('важные опережают обычные независимо от даты', () async {
      await repo.create(name: 'Скоро', day: 30, month: 9);
      await repo.create(
        name: 'Далёкий',
        day: 1,
        month: 1,
        isImportant: true,
      );

      final items = await repo.list(
        query: BirthdayQuery(
          sort: BirthdaySort.importantFirst,
          reference: ref(2026, 9, 29),
        ),
      );
      expect(items[0].birthday.name, 'Далёкий');
      expect(items[1].birthday.name, 'Скоро');
    });

    test('внутри групп сортирует по близости', () async {
      await repo.create(name: 'Скоро', day: 30, month: 9);
      await repo.create(name: 'Потом', day: 15, month: 12);

      final items = await repo.list(
        query: BirthdayQuery(
          sort: BirthdaySort.importantFirst,
          reference: ref(2026, 9, 29),
        ),
      );
      expect(items[0].birthday.name, 'Скоро');
    });
  });

  group('поиск', () {
    setUp(() async {
      await repo.create(name: 'Иван Петров', day: 15, month: 3);
      await repo.create(name: 'Анна', day: 20, month: 4, note: 'доктор');
      await repo.create(name: 'Борис', day: 25, month: 5);
    });

    test('по имени', () async {
      final items = await repo.list(
        query: BirthdayQuery(search: 'иван', reference: ref(2026, 1, 1)),
      );
      expect(items.single.birthday.name, 'Иван Петров');
    });

    test('по части имени', () async {
      final items = await repo.list(
        query: BirthdayQuery(search: 'Петр', reference: ref(2026, 1, 1)),
      );
      expect(items.single.birthday.name, 'Иван Петров');
    });

    test('по заметке', () async {
      final items = await repo.list(
        query: BirthdayQuery(search: 'доктор', reference: ref(2026, 1, 1)),
      );
      expect(items.single.birthday.name, 'Анна');
    });

    test('не найдено — пустой список', () async {
      final items = await repo.list(
        query: BirthdayQuery(search: 'Мария', reference: ref(2026, 1, 1)),
      );
      expect(items, isEmpty);
    });

    test('пустая строка не фильтрует', () async {
      final items = await repo.list(
        query: BirthdayQuery(search: '   ', reference: ref(2026, 1, 1)),
      );
      expect(items, hasLength(3));
    });
  });

  group('фильтр «только важные»', () {
    test('оставляет только помеченные', () async {
      await repo.create(name: 'Обычный', day: 1, month: 1);
      await repo.create(name: 'Важный', day: 2, month: 1, isImportant: true);

      final items = await repo.list(
        query: BirthdayQuery(
          importantOnly: true,
          reference: ref(2026, 1, 1),
        ),
      );
      expect(items.single.birthday.name, 'Важный');
    });
  });

  group('поиск + фильтр вместе', () {
    test('применяются оба условия', () async {
      await repo.create(name: 'Анна', day: 1, month: 1);
      await repo.create(
        name: 'Анна',
        day: 2,
        month: 1,
        isImportant: true,
        note: 'важная',
      );
      await repo.create(name: 'Борис', day: 3, month: 1, isImportant: true);

      final items = await repo.list(
        query: BirthdayQuery(
          search: 'анна',
          importantOnly: true,
          reference: ref(2026, 1, 1),
        ),
      );
      expect(items, hasLength(1));
      expect(items.single.birthday.note, 'важная');
    });
  });

  group('расчёт расстояния в репозитории', () {
    test('учитывает год рождения', () async {
      final created = await repo.create(
        name: 'Иван',
        day: 29,
        month: 9,
        birthYear: 1990,
      );
      final items = await repo.list(
        query: BirthdayQuery(reference: ref(2026, 9, 29)),
      );
      final occurrence = items
          .firstWhere((i) => i.birthday.id == created.id)
          .occurrence;
      expect(occurrence.daysUntil, 0);
      expect(occurrence.yearsSinceBirth, 36);
    });

    test('без года рождения возраст null', () async {
      await repo.create(name: 'Иван', day: 29, month: 9);
      final items = await repo.list(
        query: BirthdayQuery(reference: ref(2026, 9, 29)),
      );
      expect(items.single.occurrence.yearsSinceBirth, isNull);
    });
  });

  group('правило 29 февраля в репозитории', () {
    test('по умолчанию переносит на 28 февраля', () async {
      await repo.create(name: 'Иван', day: 29, month: 2);
      final items = await repo.list(
        query: BirthdayQuery(reference: ref(2025, 2, 27)),
      );
      expect(items.single.occurrence.date, ref(2025, 2, 28));
    });

    test('настройка «1 марта» меняет дату', () async {
      await LeapDayRule.save(db, LeapDayRule.march1);
      await repo.create(name: 'Иван', day: 29, month: 2);

      final items = await repo.list(
        query: BirthdayQuery(reference: ref(2025, 2, 27)),
      );
      expect(items.single.occurrence.date, ref(2025, 3, 1));
    });

    test('в високосном году перенос не применяется', () async {
      await LeapDayRule.save(db, LeapDayRule.march1);
      await repo.create(name: 'Иван', day: 29, month: 2);

      final items = await repo.list(
        query: BirthdayQuery(reference: ref(2024, 2, 28)),
      );
      expect(items.single.occurrence.date, ref(2024, 2, 29));
    });
  });

  group('индекс для импорта', () {
    test('строит карту по id и по ключу', () async {
      final created = await repo.create(name: 'Иван', day: 15, month: 3);
      final index = await repo.buildImportIndex();

      expect(index.byId.containsKey(created.id), isTrue);
      expect(index.byKey.containsKey('иван|15|03'), isTrue);
    });

    test('ключ не зависит от регистра и лишних пробелов', () async {
      final a = await repo.create(name: 'Иван', day: 15, month: 3);
      final b = await repo.create(name: '  иван  ', day: 15, month: 3);
      expect(a.dedupKey, b.dedupKey);
    });

    test('ключ различает разные даты', () async {
      final a = await repo.create(name: 'Иван', day: 15, month: 3);
      final b = await repo.create(name: 'Иван', day: 16, month: 3);
      expect(a.dedupKey, isNot(b.dedupKey));
    });
  });

  group('count', () {
    test('считает записи', () async {
      expect(await repo.count(), 0);
      await repo.create(name: 'А', day: 1, month: 1);
      await repo.create(name: 'Б', day: 2, month: 1);
      expect(await repo.count(), 2);
    });
  });
}
