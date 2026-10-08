import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:birthday_calendar/features/widget/home_widget_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  BirthdayWithOccurrence on(String name, DateTime date, {int? daysUntil}) {
    final stamp = DateTime(2026);
    return BirthdayWithOccurrence(
      birthday: Birthday(
        id: name,
        profileId: 'p',
        name: name,
        day: date.day,
        month: date.month,
        createdAt: stamp,
        updatedAt: stamp,
      ),
      occurrence: BirthdayOccurrence(
        date: date,
        daysUntil: daysUntil ?? date.difference(DateTime(2026, 9, 9)).inDays,
        yearsSinceBirth: null,
      ),
    );
  }

  group('подпись даты в виджете', () {
    test('сегодня и завтра — словами', () {
      expect(widgetDateLabel(on('А', DateTime(2026, 9, 9), daysUntil: 0).occurrence), 'Сегодня');
      expect(widgetDateLabel(on('А', DateTime(2026, 9, 10), daysUntil: 1).occurrence), 'Завтра');
    });

    test('дальше — число и месяц по-русски', () {
      expect(
        widgetDateLabel(on('А', DateTime(2026, 9, 15), daysUntil: 6).occurrence),
        '15 сентября',
      );
    });
  });

  group('строки виджета', () {
    test('собирает людей с одной датой в одну строку', () {
      final lines = nextBirthdayLines([
        on('Алада', DateTime(2026, 9, 9), daysUntil: 0),
        on('Лимон', DateTime(2026, 9, 9), daysUntil: 0),
        on('Иван', DateTime(2026, 9, 15), daysUntil: 6),
      ]);

      expect(lines, ['Сегодня: Алада, Лимон', '15 сентября: Иван']);
    });

    test('показывает не больше трёх дат', () {
      final lines = nextBirthdayLines([
        on('А', DateTime(2026, 9, 9), daysUntil: 0),
        on('Б', DateTime(2026, 9, 10), daysUntil: 1),
        on('В', DateTime(2026, 9, 11), daysUntil: 2),
        on('Г', DateTime(2026, 9, 12), daysUntil: 3),
      ]);

      expect(lines, hasLength(3));
      expect(lines.last, '11 сентября: В');
    });

    test('пустой список не даёт строк', () {
      expect(nextBirthdayLines(const []), isEmpty);
    });

    test('порядок записей сохраняется', () {
      final lines = nextBirthdayLines([
        on('Первый', DateTime(2026, 9, 9), daysUntil: 0),
        on('Второй', DateTime(2026, 9, 20), daysUntil: 11),
      ]);
      expect(lines, ['Сегодня: Первый', '20 сентября: Второй']);
    });
  });
}
