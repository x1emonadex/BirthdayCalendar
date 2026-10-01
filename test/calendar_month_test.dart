import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:birthday_calendar/features/calendar/domain/calendar_month.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BirthdayWithOccurrence on(
    String name,
    DateTime date, {
    bool important = false,
  }) {
    final stamp = DateTime(2026);
    return BirthdayWithOccurrence(
      birthday: Birthday(
        id: name,
        profileId: 'p',
        name: name,
        day: date.day,
        month: date.month,
        isImportant: important,
        createdAt: stamp,
        updatedAt: stamp,
      ),
      occurrence: BirthdayOccurrence(
        date: date,
        daysUntil: date.difference(DateTime(2026)).inDays,
        yearsSinceBirth: null,
      ),
    );
  }

  CalendarMonth build(
    DateTime month,
    List<BirthdayWithOccurrence> items, {
    DateTime? today,
  }) => CalendarMonth.build(
    month,
    items: items,
    today: today ?? DateTime(2026, 9, 30),
  );

  group('сетка всегда 6 недель', () {
    test('42 дня, подряд, с понедельника', () {
      final m = build(DateTime(2026, 9), const []);

      expect(m.days, hasLength(42));
      expect(m.days.first.date.weekday, DateTime.monday);
      for (var i = 1; i < m.days.length; i++) {
        final diff = m.days[i].date.difference(m.days[i - 1].date);
        expect(diff.inDays, 1);
      }
    });

    test('сетка всегда начинается с понедельника', () {
      // 1 сентября 2026 — вторник; месяц, начинающийся в понедельник;
      // месяц, начинающийся в воскресенье.
      for (final month in [
        DateTime(2026, 9),
        DateTime(2026, 6),
        DateTime(2026, 11),
        DateTime(2027, 3),
      ]) {
        final m = build(month, const []);
        expect(m.days.first.date.weekday, DateTime.monday, reason: '$month');
        final leading = m.days.indexWhere((d) => !d.isOutsideMonth);
        expect(m.days[leading].date.day, 1, reason: '$month');
      }
    });
  });

  group('дни недели под выбранным месяцем', () {
    test('1 сентября 2026 попадает на вторник', () {
      final m = build(DateTime(2026, 9), const []);
      final first = m.days.firstWhere((d) => d.date.day == 1);
      expect(first.date.weekday, DateTime.tuesday);
      expect(first.isOutsideMonth, isFalse);
    });

    test('дни перед 1-м числом относятся к прошлому месяцу', () {
      final m = build(DateTime(2026, 9), const []);
      for (final day in m.days.takeWhile((d) => d.isOutsideMonth)) {
        expect(day.date.month, 8);
        expect(day.isOutsideMonth, isTrue);
      }
    });

    test('дни после конца месяца относятся к следующему', () {
      final m = build(DateTime(2026, 9), const []);
      for (final day
          in m.days.skipWhile((d) => !d.isOutsideMonth).skip(31)) {
        expect(day.date.month, 10);
      }
    });
  });

  group('разметка дней рождения', () {
    test('попадают в ячейку с датой, а не в соседнюю', () {
      final m = build(DateTime(2026, 9), [
        on('Иван', DateTime(2026, 9, 15)),
        on('Пётр', DateTime(2026, 9, 30)),
      ]);

      expect(m.days[15].date, DateTime(2026, 9, 15));
      expect(
        m.days[15].birthdays.map((b) => b.birthday.name),
        ['Иван'],
      );
      expect(
        m.days[30].birthdays.map((b) => b.birthday.name),
        ['Пётр'],
      );
    });

    test('два дня рождения в один день попадают в одну ячейку', () {
      final m = build(DateTime(2026, 9), [
        on('Иван', DateTime(2026, 9, 15)),
        on('Аня', DateTime(2026, 9, 15)),
      ]);

      final cell = m.days.firstWhere((d) => d.date.day == 15);
      expect(cell.birthdays, hasLength(2));
      expect(cell.hasBirthdays, isTrue);
    });

    test('день рождения соседнего месяца не попадает в сетку', () {
      final m = build(DateTime(2026, 9), [
        on('Иван', DateTime(2026, 8, 31)),
        on('Пётр', DateTime(2026, 10, 1)),
      ]);
      expect(m.days.every((d) => d.birthdays.isEmpty), isTrue);
    });

    test('важный день рождения помечается', () {
      final m = build(DateTime(2026, 9), [
        on('Иван', DateTime(2026, 9, 15), important: true),
      ]);
      final cell = m.days.firstWhere((d) => d.date.day == 15);
      expect(cell.hasImportant, isTrue);
    });
  });

  group('сегодняшний день', () {
    test('отмечается ровно один раз', () {
      final m = build(DateTime(2026, 9), const [], today: DateTime(2026, 9, 15));
      final marked = m.days.where((d) => d.isToday);
      expect(marked, hasLength(1));
      expect(marked.first.date, DateTime(2026, 9, 15));
    });

    test('не отмечается, если сегодня другой месяц', () {
      final m = build(DateTime(2026, 9), const [], today: DateTime(2026, 3, 1));
      expect(m.days.every((d) => !d.isToday), isTrue);
    });
  });

  group('список месяца', () {
    test('сортирует по дню, затем по имени', () {
      final m = build(DateTime(2026, 9), [
        on('Пётр', DateTime(2026, 9, 20)),
        on('Аня', DateTime(2026, 9, 5)),
        on('Борис', DateTime(2026, 9, 5)),
      ]);

      expect(
        m.birthdays.map((b) => b.birthday.name),
        ['Аня', 'Борис', 'Пётр'],
      );
    });

    test('время суток в дате не влияет на попадание в ячейку', () {
      final m = build(DateTime(2026, 9), [
        on('Иван', DateTime(2026, 9, 15, 18, 30)),
      ]);
      final cell = m.days.firstWhere((d) => d.date.day == 15);
      expect(cell.birthdays.map((b) => b.birthday.name), ['Иван']);
    });
  });

  group('переход через Новый год', () {
    test('декабрь: последняя неделя января попадает в сетку', () {
      final m = build(DateTime(2026, 12), const []);
      expect(m.days.first.date, DateTime(2026, 11, 30));
      expect(m.days.last.date, DateTime(2027, 1, 10));
    });

    test('январь: последняя неделя декабря попадает в сетку', () {
      final m = build(DateTime(2027, 1), const []);
      expect(m.days.first.date, DateTime(2026, 12, 28));
      expect(m.days.last.date, DateTime(2027, 2, 7));
    });
  });

  group('заголовок месяца', () {
    test('использует русские названия и год', () {
      expect(build(DateTime(2026, 9), const []).title, 'Сентябрь 2026');
      expect(build(DateTime(2027, 1), const []).title, 'Январь 2027');
    });
  });

  group('перенос на выбранный год', () {
    List<BirthdayWithOccurrence> items = [
      on('Аня', DateTime(2026, 1, 4)),
      on('Иван', DateTime(2026, 8, 18)),
    ];

    test('запись January попадает в январь любого года', () {
      for (final year in [2025, 2026, 2027]) {
        final moved = occurrencesInYear(items, year);
        final date = moved.first.occurrence.date;
        expect(date, DateTime(year, 1, 4), reason: '$year');
      }
    });

    test('прошлый год не остаётся в будущем', () {
      // Без пересчёта 4 января 2026-го «повисло» бы в 2025-м.
      final moved = occurrencesInYear(items, 2025);
      expect(moved.every((i) => i.occurrence.date.year == 2025), isTrue);
      expect(moved.first.occurrence.date.isBefore(DateTime(2025, 12, 31)),
          isTrue);
    });

    test('возраст считается на год, а не от сегодняшнего', () {
      final moved = occurrencesInYear(
        [
          BirthdayWithOccurrence(
            birthday: Birthday(
              id: '1',
              profileId: 'p',
              name: 'Иван',
              day: 1,
              month: 1,
              birthYear: 1990,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
            occurrence: BirthdayOccurrence(
              date: DateTime(2026, 1, 1),
              daysUntil: 100,
              yearsSinceBirth: 36,
            ),
          ),
        ],
        2030,
      );
      expect(moved.single.occurrence.yearsSinceBirth, 40);
    });

    test('без года рождения возраст остаётся пустым', () {
      final moved = occurrencesInYear(items, 2030);
      expect(moved.every((i) => i.occurrence.yearsSinceBirth == null), isTrue);
    });

    test('29 февраля переносится по правилу', () {
      final leap = [on('Пётр', DateTime(2024, 2, 29))];

      expect(
        occurrencesInYear(leap, 2026).single.occurrence.date,
        DateTime(2026, 2, 28),
      );
      expect(
        occurrencesInYear(
          leap,
          2026,
          fallback: LeapDayFallback.march1,
        ).single.occurrence.date,
        DateTime(2026, 3, 1),
      );
      expect(
        occurrencesInYear(leap, 2028).single.occurrence.date,
        DateTime(2028, 2, 29),
      );
    });
  });
}
