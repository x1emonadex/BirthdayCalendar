import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_grouping.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BirthdayWithOccurrence withDays(String name, int days) {
    final now = DateTime(2026);
    return BirthdayWithOccurrence(
      birthday: Birthday(
        id: name,
        profileId: 'p',
        name: name,
        day: 1,
        month: 1,
        createdAt: now,
        updatedAt: now,
      ),
      occurrence: BirthdayOccurrence(
        date: now.add(Duration(days: days)),
        daysUntil: days,
        yearsSinceBirth: null,
      ),
    );
  }

  List<String> namesOf(BirthdaySectionData section) =>
      section.items.map((i) => i.birthday.name).toList();

  group('пустой список', () {
    test('не создаёт ни одного раздела', () {
      expect(BirthdayGrouping.group([]), isEmpty);
    });
  });

  group('разделение по расстоянию', () {
    test('0 дней попадает в «сегодня»', () {
      final sections = BirthdayGrouping.group([withDays('Иван', 0)]);
      expect(sections, hasLength(1));
      expect(sections.first.section, BirthdaySection.today);
    });

    test('1–7 дней попадает в «в ближайшую неделю»', () {
      for (var days = 1; days <= 7; days++) {
        final sections = BirthdayGrouping.group([withDays('X', days)]);
        expect(
          sections.first.section,
          BirthdaySection.thisWeek,
          reason: '$days дней должно быть в неделе',
        );
      }
    });

    test('8 и больше дней попадает в «позже»', () {
      for (final days in [8, 20, 300, 364]) {
        final sections = BirthdayGrouping.group([withDays('X', days)]);
        expect(
          sections.first.section,
          BirthdaySection.later,
          reason: '$days дней должно быть в «позже»',
        );
      }
    });

    test('окно недели равно 7', () {
      expect(BirthdayGrouping.thisWeekWindow, 7);
    });
  });

  group('порядок разделов', () {
    test('всегда сегодня → неделя → позже', () {
      final sections = BirthdayGrouping.group([
        withDays('Позже', 30),
        withDays('Неделя', 3),
        withDays('Сегодня', 0),
      ]);
      expect(sections.map((s) => s.section).toList(), [
        BirthdaySection.today,
        BirthdaySection.thisWeek,
        BirthdaySection.later,
      ]);
    });

    test('пустые разделы пропускаются', () {
      final sections = BirthdayGrouping.group([withDays('Сегодня', 0)]);
      expect(sections, hasLength(1));
      expect(sections.first.section, BirthdaySection.today);
    });

    test('раздел без «сегодня» начинается с недели', () {
      final sections = BirthdayGrouping.group([
        withDays('Позже', 30),
        withDays('Неделя', 3),
      ]);
      expect(sections.first.section, BirthdaySection.thisWeek);
    });
  });

  group('внутри раздела', () {
    test('сохраняет входной порядок', () {
      final sections = BirthdayGrouping.group([
        withDays('Первый', 1),
        withDays('Второй', 2),
        withDays('Третий', 3),
      ]);
      expect(namesOf(sections.first), ['Первый', 'Второй', 'Третий']);
    });

    test('несколько записей в «сегодня»', () {
      final sections = BirthdayGrouping.group([
        withDays('Аня', 0),
        withDays('Борис', 0),
      ]);
      expect(sections.first.section, BirthdaySection.today);
      expect(sections.first.items, hasLength(2));
    });
  });

  group('переход года', () {
    test('31 декабря — сегодня, 1 января — неделя', () {
      final sections = BirthdayGrouping.group([
        withDays('Новый год', 1),
        withDays('Старый год', 0),
      ]);
      expect(sections, hasLength(2));
      expect(sections[0].section, BirthdaySection.today);
      expect(sections[1].section, BirthdaySection.thisWeek);
    });
  });

  group('конец месяца', () {
    test('последние дни месяца раскладываются по разделам', () {
      final sections = BirthdayGrouping.group([
        withDays('Сегодня', 0),
        withDays('Завтра', 1),
        withDays('Через неделю', 7),
        withDays('Через месяц', 30),
      ]);
      expect(sections, hasLength(3));
      expect(sections[0].items, hasLength(1));
      expect(sections[1].items, hasLength(2));
      expect(sections[2].items, hasLength(1));
    });
  });

  group('пустые секции', () {
    test('isEmpty работает корректно', () {
      const section = BirthdaySectionData(
        section: BirthdaySection.today,
        items: [],
      );
      expect(section.isEmpty, isTrue);
    });

    test('непустая секция — isEmpty false', () {
      final section = BirthdaySectionData(
        section: BirthdaySection.today,
        items: [withDays('Аня', 0)],
      );
      expect(section.isEmpty, isFalse);
    });
  });
}
