import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime d(int y, int m, int d) => DateTime(y, m, d);

  group('isLeapYear', () {
    test('високосные годы', () {
      expect(BirthdayDateUtils.isLeapYear(2024), isTrue);
      expect(BirthdayDateUtils.isLeapYear(2020), isTrue);
      expect(BirthdayDateUtils.isLeapYear(2000), isTrue);
    });

    test('невисокосные годы', () {
      expect(BirthdayDateUtils.isLeapYear(2023), isFalse);
      expect(BirthdayDateUtils.isLeapYear(2025), isFalse);
      expect(BirthdayDateUtils.isLeapYear(1900), isFalse,
          reason: '1900 делится на 100, но не на 400');
      expect(BirthdayDateUtils.isLeapYear(2100), isFalse);
    });
  });

  group('celebrationDateInYear — обычные даты', () {
    test('дата не меняется', () {
      expect(
        BirthdayDateUtils.celebrationDateInYear(2025, 3, 15),
        d(2025, 3, 15),
      );
      expect(
        BirthdayDateUtils.celebrationDateInYear(2025, 1, 1),
        d(2025, 1, 1),
      );
      expect(
        BirthdayDateUtils.celebrationDateInYear(2025, 12, 31),
        d(2025, 12, 31),
      );
    });
  });

  group('celebrationDateInYear — 29 февраля', () {
    test('в високосный год остаётся 29 февраля', () {
      expect(
        BirthdayDateUtils.celebrationDateInYear(2024, 2, 29),
        d(2024, 2, 29),
      );
      expect(
        BirthdayDateUtils.celebrationDateInYear(
          2024,
          2,
          29,
          fallback: LeapDayFallback.march1,
        ),
        d(2024, 2, 29),
        reason: 'в високосный год перенос не применяется',
      );
    });

    test('в невисокосный год переносится на 28 февраля', () {
      expect(
        BirthdayDateUtils.celebrationDateInYear(2025, 2, 29),
        d(2025, 2, 28),
      );
    });

    test('в невисокосный год переносится на 1 марта', () {
      expect(
        BirthdayDateUtils.celebrationDateInYear(
          2025,
          2,
          29,
          fallback: LeapDayFallback.march1,
        ),
        d(2025, 3, 1),
      );
    });
  });

  group('nextOccurrence — базовые случаи', () {
    test('день рождения сегодня: дней 0', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 3,
        day: 15,
        reference: d(2025, 3, 15),
      );
      expect(r.daysUntil, 0);
      expect(r.date, d(2025, 3, 15));
      expect(r.isToday, isTrue);
      expect(r.isTomorrow, isFalse);
    });

    test('день рождения завтра: дней 1', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 3,
        day: 16,
        reference: d(2025, 3, 15),
      );
      expect(r.daysUntil, 1);
      expect(r.date, d(2025, 3, 16));
      expect(r.isTomorrow, isTrue);
    });

    test('день рождения вчера: уходим на следующий год', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 3,
        day: 14,
        reference: d(2025, 3, 15),
      );
      expect(r.date, d(2026, 3, 14));
      expect(r.daysUntil, 364);
    });

    test('осталось 10 дней', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 12,
        day: 25,
        reference: d(2025, 12, 15),
      );
      expect(r.daysUntil, 10);
      expect(r.date, d(2025, 12, 25));
    });
  });

  group('nextOccurrence — переход через Новый год', () {
    test('день рождения 1 января, сегодня 31 декабря', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 1,
        day: 1,
        reference: d(2025, 12, 31),
      );
      expect(r.date, d(2026, 1, 1));
      expect(r.daysUntil, 1);
    });

    test('день рождения 31 декабря, сегодня 1 января', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 12,
        day: 31,
        reference: d(2025, 1, 1),
      );
      expect(r.date, d(2025, 12, 31));
      expect(r.daysUntil, 364);
    });

    test('день рождения 1 января, сегодня тоже 1 января', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 1,
        day: 1,
        reference: d(2025, 1, 1),
      );
      expect(r.date, d(2025, 1, 1));
      expect(r.daysUntil, 0, reason: 'сегодня подходит, а не следующий год');
    });
  });

  group('nextOccurrence — 29 февраля', () {
    test('за день до 28 февраля в невисокосном году', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 2,
        day: 29,
        reference: d(2025, 2, 27),
      );
      expect(r.date, d(2025, 2, 28));
      expect(r.daysUntil, 1);
    });

    test('в день переноса на 1 марта', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 2,
        day: 29,
        reference: d(2025, 2, 27),
        fallback: LeapDayFallback.march1,
      );
      expect(r.date, d(2025, 3, 1));
      expect(r.daysUntil, 2);
    });

    test('после 28 февраля уходим на следующий год', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 2,
        day: 29,
        reference: d(2025, 3, 1),
      );
      // 2026 невисокосный → снова 28 февраля.
      expect(r.date, d(2026, 2, 28));
      expect(r.daysUntil, 364);
    });

    test('в високосном году 29 февраля — настоящая дата', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 2,
        day: 29,
        reference: d(2024, 2, 28),
      );
      expect(r.date, d(2024, 2, 29));
      expect(r.daysUntil, 1);
    });

    test('переход 2028 → 2029 учитывает високосность', () {
      // 2028 високосный: 29 февраля существует.
      final leap = BirthdayDateUtils.nextOccurrence(
        month: 2,
        day: 29,
        reference: d(2028, 2, 29),
      );
      expect(leap.daysUntil, 0, reason: 'сегодня 29.02.2028');

      // На следующий день праздник уже прошёл.
      final after = BirthdayDateUtils.nextOccurrence(
        month: 2,
        day: 29,
        reference: d(2028, 3, 1),
      );
      expect(after.date, d(2029, 2, 28));
    });
  });

  group('nextOccurrence — конец месяца и длины месяцев', () {
    test('31 января с 1 февраля — почти год', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 1,
        day: 31,
        reference: d(2025, 2, 1),
      );
      expect(r.date, d(2026, 1, 31));
      expect(r.daysUntil, 364);
    });

    test('30 апреля с 1 мая', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 4,
        day: 30,
        reference: d(2025, 5, 1),
      );
      expect(r.date, d(2026, 4, 30));
    });
  });

  group('nextOccurrence — возраст', () {
    test('возраст без года рождения равен null', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 3,
        day: 15,
        reference: d(2025, 3, 15),
      );
      expect(r.yearsSinceBirth, isNull);
    });

    test('день рождения: возраст меняется в этот день', () {
      final onBirthday = BirthdayDateUtils.nextOccurrence(
        month: 3,
        day: 15,
        birthYear: 1990,
        reference: d(2025, 3, 15),
      );
      expect(onBirthday.yearsSinceBirth, 35);

      final dayBefore = BirthdayDateUtils.nextOccurrence(
        month: 3,
        day: 15,
        birthYear: 1990,
        reference: d(2025, 3, 14),
      );
      expect(dayBefore.yearsSinceBirth, 35);

      final dayAfter = BirthdayDateUtils.nextOccurrence(
        month: 3,
        day: 15,
        birthYear: 1990,
        reference: d(2025, 3, 16),
      );
      expect(dayAfter.date, d(2026, 3, 15));
      expect(dayAfter.yearsSinceBirth, 36,
          reason: 'в этом году праздник прошёл, ближайший — в 2026, '
              'где исполнится 36');
    });

    test('вне дня рождения возраст на год меньше', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 12,
        day: 31,
        birthYear: 1990,
        reference: d(2025, 6, 1),
      );
      expect(r.date, d(2025, 12, 31));
      expect(r.yearsSinceBirth, 35);
    });

    test('29 февраля: возраст по годам, независимо от переноса', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 2,
        day: 29,
        birthYear: 2000,
        reference: d(2025, 2, 27),
      );
      expect(r.date, d(2025, 2, 28));
      expect(r.yearsSinceBirth, 25);
    });

    test('перенос на 1 марта: тот же возраст', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 2,
        day: 29,
        birthYear: 2000,
        reference: d(2025, 2, 27),
        fallback: LeapDayFallback.march1,
      );
      expect(r.date, d(2025, 3, 1));
      expect(r.yearsSinceBirth, 25);
    });
  });

  group('nextOccurrence — время суток игнорируется', () {
    test('вечер 31 декабря не должен ломать расчёт', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 1,
        day: 1,
        reference: DateTime(2025, 12, 31, 23, 59, 59),
      );
      expect(r.daysUntil, 1);
      expect(r.date, d(2026, 1, 1));
    });

    test('полночь считается сегодняшним днём', () {
      final r = BirthdayDateUtils.nextOccurrence(
        month: 6,
        day: 10,
        reference: DateTime(2025, 6, 10, 0, 0, 0),
      );
      expect(r.daysUntil, 0);
    });
  });

  group('ageAt', () {
    test('в день рождения возраст новый', () {
      expect(
        BirthdayDateUtils.ageAt(
          birthYear: 1990,
          month: 3,
          day: 15,
          date: d(2025, 3, 15),
        ),
        35,
      );
    });

    test('за день до дня рождения возраст старый', () {
      expect(
        BirthdayDateUtils.ageAt(
          birthYear: 1990,
          month: 3,
          day: 15,
          date: d(2025, 3, 14),
        ),
        34,
      );
    });

    test('29 февраля в невисокосном году', () {
      expect(
        BirthdayDateUtils.ageAt(
          birthYear: 2000,
          month: 2,
          day: 29,
          date: d(2025, 2, 28),
        ),
        25,
      );
      expect(
        BirthdayDateUtils.ageAt(
          birthYear: 2000,
          month: 2,
          day: 29,
          date: d(2025, 2, 27),
        ),
        24,
      );
    });

    test('перенос на 1 марта откладывает возраст', () {
      expect(
        BirthdayDateUtils.ageAt(
          birthYear: 2000,
          month: 2,
          day: 29,
          date: d(2025, 2, 28),
          fallback: LeapDayFallback.march1,
        ),
        24,
      );
      expect(
        BirthdayDateUtils.ageAt(
          birthYear: 2000,
          month: 2,
          day: 29,
          date: d(2025, 3, 1),
          fallback: LeapDayFallback.march1,
        ),
        25,
      );
    });

    test('не отрицательный для будущего года рождения', () {
      expect(
        BirthdayDateUtils.ageAt(
          birthYear: 2030,
          month: 1,
          day: 1,
          date: d(2025, 6, 1),
        ),
        0,
      );
    });
  });

  group('склонение числительных', () {
    test('день / дня / дней', () {
      expect(BirthdayDateUtils.pluralDays(1), 'день');
      expect(BirthdayDateUtils.pluralDays(2), 'дня');
      expect(BirthdayDateUtils.pluralDays(5), 'дней');
      expect(BirthdayDateUtils.pluralDays(11), 'дней');
      expect(BirthdayDateUtils.pluralDays(21), 'день');
      expect(BirthdayDateUtils.pluralDays(22), 'дня');
      expect(BirthdayDateUtils.pluralDays(25), 'дней');
      expect(BirthdayDateUtils.pluralDays(101), 'день');
      expect(BirthdayDateUtils.pluralDays(111), 'дней');
    });

    test('год / года / лет', () {
      expect(BirthdayDateUtils.pluralYears(1), 'год');
      expect(BirthdayDateUtils.pluralYears(2), 'года');
      expect(BirthdayDateUtils.pluralYears(5), 'лет');
      expect(BirthdayDateUtils.pluralYears(11), 'лет');
      expect(BirthdayDateUtils.pluralYears(21), 'год');
      expect(BirthdayDateUtils.pluralYears(34), 'года');
      expect(BirthdayDateUtils.pluralYears(101), 'год');
    });

    test('ноль дней', () {
      expect(BirthdayDateUtils.pluralDays(0), 'дней');
    });
  });
}
