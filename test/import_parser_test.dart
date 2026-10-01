import 'package:birthday_calendar/features/export_import/data/import_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const header = ['ID', 'Имя', 'День', 'Месяц', 'Год рождения', 'Заметка', 'Важный'];

  group('заголовки', () {
    test('читает стандартный формат приложения', () {
      final out = ImportParser.parse([header, ['', 'Аня', '15', '3', '', '', 'нет']]);
      expect(out.errors, isEmpty);
      expect(out.candidates.single.name, 'Аня');
    });

    test('понимает синонимы колонок', () {
      final out = ImportParser.parse([
        ['name', 'день', 'month', 'год рождения', 'примечание', 'важно'],
        ['Борис', '1', '5', '1990', 'доктор', 'да'],
      ]);
      expect(out.errors, isEmpty);
      final c = out.candidates.single;
      expect(c.name, 'Борис');
      expect(c.day, 1);
      expect(c.month, 5);
      expect(c.birthYear, 1990);
      expect(c.note, 'доктор');
      expect(c.isImportant, isTrue);
    });

    test('игнорирует регистр и лишние пробелы', () {
      final out = ImportParser.parse([
        ['  ИМЯ ', ' ДЕНЬ ', 'Месяц'],
        ['Аня', '1', '1'],
      ]);
      expect(out.errors, isEmpty);
      expect(out.candidates.single.name, 'Аня');
    });

    test('ошибка при отсутствии обязательных колонок', () {
      final out = ImportParser.parse([
        ['Имя', 'Заметка'],
        ['Аня', 'что-то'],
      ]);
      expect(out.candidates, isEmpty);
      expect(out.errors, hasLength(1));
      expect(out.errors.single.message, contains('день'));
    });

    test('пустой файл даёт ошибку', () {
      final out = ImportParser.parse([]);
      expect(out.candidates, isEmpty);
      expect(out.errors.single.message, 'Файл пуст');
    });

    test('файл только с заголовком не даёт кандидатов', () {
      final out = ImportParser.parse([header]);
      expect(out.candidates, isEmpty);
      expect(out.errors, isEmpty);
    });
  });

  group('разбор строк', () {
    test('читает все поля', () {
      final out = ImportParser.parse([
        header,
        ['uuid-1', 'Аня', '15', '3', '1990', 'любит торт', 'да'],
      ]);
      final c = out.candidates.single;
      expect(c.id, 'uuid-1');
      expect(c.name, 'Аня');
      expect(c.day, 15);
      expect(c.month, 3);
      expect(c.birthYear, 1990);
      expect(c.note, 'любит торт');
      expect(c.isImportant, isTrue);
    });

    test('пустой год рождения остаётся null', () {
      final out = ImportParser.parse([header, ['', 'Аня', '1', '1', '', '', 'нет']]);
      expect(out.candidates.single.birthYear, isNull);
    });

    test('пробелы вокруг значений обрезаются', () {
      final out = ImportParser.parse([header, ['', ' Аня ', ' 1 ', ' 2 ', '', '', '']]);
      expect(out.candidates.single.name, 'Аня');
      expect(out.candidates.single.day, 1);
    });
  });

  group('значения «важный»', () {
    for (final value in ['да', '1', 'true', 'ДА', 'yes', 'важно', '*']) {
      test('«$value» — истина', () {
        final out = ImportParser.parse([header, ['', 'Аня', '1', '1', '', '', value]]);
        expect(out.candidates.single.isImportant, isTrue);
      });
    }

    for (final value in ['нет', '0', 'false', 'no', '']) {
      test('«$value» — ложь', () {
        final out = ImportParser.parse([header, ['', 'Аня', '1', '1', '', '', value]]);
        expect(out.candidates.single.isImportant, isFalse);
      });
    }
  });

  group('ошибки строк', () {
    test('пустое имя', () {
      final out = ImportParser.parse([header, ['', '  ', '1', '1', '', '', 'нет']]);
      expect(out.candidates, isEmpty);
      expect(out.errors.single.message, 'пустое имя');
    });

    test('день не число', () {
      final out = ImportParser.parse([header, ['', 'Аня', 'abc', '1', '', '', '']]);
      expect(out.errors.single.message, contains('не число'));
    });

    test('месяц вне диапазона', () {
      final out = ImportParser.parse([header, ['', 'Аня', '1', '13', '', '', '']]);
      expect(out.errors.single.message, contains('неверный месяц'));
    });

    test('30 февраля отклоняется', () {
      final out = ImportParser.parse([header, ['', 'Аня', '30', '2', '', '', '']]);
      expect(out.errors.single.message, contains('нет 30-го дня'));
    });

    test('31 апреля отклоняется', () {
      final out = ImportParser.parse([header, ['', 'Аня', '31', '4', '', '', '']]);
      expect(out.errors.single.message, contains('нет 31-го дня'));
    });

    test('29 февраля допускается', () {
      final out = ImportParser.parse([header, ['', 'Аня', '29', '2', '', '', '']]);
      expect(out.errors, isEmpty);
      expect(out.candidates.single.day, 29);
    });

    test('неправдоподобный год отклоняется', () {
      final out = ImportParser.parse([header, ['', 'Аня', '1', '1', '1500', '', '']]);
      expect(out.errors.single.message, contains('неправдоподобный год'));
    });

    test('плохая строка не мешает хорошим', () {
      final out = ImportParser.parse([
        header,
        ['', 'Хорошая', '1', '1', '', '', ''],
        ['', 'Плохая', '99', '1', '', '', ''],
        ['', 'Тоже хорошая', '2', '1', '', '', ''],
      ]);
      expect(out.candidates, hasLength(2));
      expect(out.errors, hasLength(1));
      expect(out.errors.single.rowNumber, 2);
    });

    test('пустые строки пропускаются', () {
      final out = ImportParser.parse([
        header,
        ['', 'Аня', '1', '1', '', '', ''],
        ['', '', '', '', '', '', ''],
      ]);
      expect(out.candidates, hasLength(1));
      expect(out.errors, isEmpty);
    });
  });

  group('ключ дедупликации', () {
    test('не зависит от регистра и пробелов', () {
      final a = ImportParser.parse([header, ['', ' Иван ', '15', '3', '', '', '']])
          .candidates
          .single;
      final b = ImportParser.parse([header, ['', 'иван', '15', '3', '', '', '']])
          .candidates
          .single;
      expect(a.dedupKey, b.dedupKey);
    });

    test('разные даты дают разные ключи', () {
      final a = ImportParser.parse([header, ['', 'Иван', '15', '3', '', '', '']])
          .candidates
          .single;
      final b = ImportParser.parse([header, ['', 'Иван', '16', '3', '', '', '']])
          .candidates
          .single;
      expect(a.dedupKey, isNot(b.dedupKey));
    });
  });
}
