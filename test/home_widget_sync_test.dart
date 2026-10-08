import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:birthday_calendar/features/widget/home_widget_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  group('текст срока для виджета', () {
    test('сегодня и прошедшее — «Сегодня день рождения»', () {
      expect(nextWhenLabel(0), 'Сегодня день рождения');
      expect(nextWhenLabel(-1), 'Сегодня день рождения');
    });

    test('завтра', () {
      expect(nextWhenLabel(1), 'Завтра день рождения');
    });

    test('склонения дней', () {
      expect(nextWhenLabel(2), 'Через 2 дня');
      expect(nextWhenLabel(3), 'Через 3 дня');
      expect(nextWhenLabel(5), 'Через 5 дней');
      expect(nextWhenLabel(11), 'Через 11 дней');
      expect(nextWhenLabel(21), 'Через 21 день');
      expect(nextWhenLabel(22), 'Через 22 дня');
    });
  });

  group('строка «кто и когда»', () {
    test('имя и дата пишутся по-русски', () {
      final stamp = DateTime(2026);
      final birthday = Birthday(
        id: '1',
        profileId: 'p',
        name: 'Иван',
        day: 15,
        month: 9,
        createdAt: stamp,
        updatedAt: stamp,
      );

      expect(
        nextWhoLabel(birthday, DateTime(2026, 9, 15)),
        'Иван, 15 сентября',
      );
    });
  });
}
