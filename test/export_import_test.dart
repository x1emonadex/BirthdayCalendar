import 'package:birthday_calendar/core/database/app_database.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_repository.dart';
import 'package:birthday_calendar/features/export_import/data/birthday_importer.dart';
import 'package:birthday_calendar/features/export_import/data/csv_exporter.dart';
import 'package:birthday_calendar/features/export_import/data/excel_exporter.dart';
import 'package:birthday_calendar/features/export_import/data/file_export_service.dart';
import 'package:birthday_calendar/features/export_import/data/import_parser.dart';
import 'package:birthday_calendar/features/export_import/data/import_result.dart';
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

  const header = [
    'ID',
    'Имя',
    'День',
    'Месяц',
    'Год рождения',
    'Заметка',
    'Важный',
  ];

  Future<ImportResult> importRows(List<List<String>> rows) {
    return BirthdayImporter(repo).import(ImportParser.parse(rows));
  }

  group('CSV: запись', () {
    test('заголовок соответствует формату приложения', () {
      final csv = CsvExporter.build([]);
      expect(csv.trim(), 'ID;Имя;День;Месяц;Год рождения;Заметка;Важный');
    });

    test('экранирует разделитель в имени', () async {
      final created = await repo.create(name: 'Анна;Мария', day: 1, month: 1);
      expect(CsvExporter.build([created]), contains('"Анна;Мария"'));
    });

    test('экранирует кавычки', () async {
      final created = await repo.create(name: 'Он сказал "да"', day: 1, month: 1);
      expect(CsvExporter.build([created]), contains('"Он сказал ""да"""'));
    });
  });

  group('CSV: чтение', () {
    test('разбирает собственный файл', () {
      const csv = 'ID;Имя;День;Месяц;Год рождения;Заметка;Важный\n'
          'u1;Аня;15;3;1990;торт;да\n'
          'u2;Борис;1;5;;;нет\n';
      final parsed = ImportParser.parse(FileExportService.readCsv(csv));
      expect(parsed.errors, isEmpty);
      expect(parsed.candidates, hasLength(2));
      expect(parsed.candidates.first.name, 'Аня');
      expect(parsed.candidates.first.birthYear, 1990);
      expect(parsed.candidates.last.name, 'Борис');
    });

    test('понимает запятую как разделитель', () {
      const csv = 'Имя,День,Месяц\nАня,15,3\n';
      final parsed = ImportParser.parse(FileExportService.readCsv(csv));
      expect(parsed.candidates.single.name, 'Аня');
    });

    test('учитывает кавычки с точкой с запятой внутри', () {
      const csv = 'Имя;День;Месяц\n"Анна;Мария";15;3\n';
      final rows = FileExportService.readCsv(csv);
      expect(rows[1][0], 'Анна;Мария');
    });

    test('убирает BOM', () {
      const csv = '\uFEFFИмя;День;Месяц\nАня;15;3\n';
      expect(FileExportService.readCsv(csv).first.first, 'Имя');
    });

    test('обрабатывает перевод строки CRLF', () {
      const csv = 'Имя;День;Месяц\r\nАня;15;3\r\n';
      final rows = FileExportService.readCsv(csv);
      expect(rows, hasLength(2));
      expect(rows[1].first, 'Аня');
    });
  });

  group('Excel', () {
    test('заголовок и данные на месте', () async {
      await repo.create(name: 'Аня', day: 15, month: 3, birthYear: 1990);
      final all = await repo.list();
      final excel = ExcelExporter.createWorkbook(
        all.map((i) => i.birthday).toList(),
      );
      final sheet = excel[ExcelExporter.sheetName];
      expect(
        sheet.rows.first
            .map((c) => c == null ? '' : '${c.value}')
            .toList(),
        header,
      );
      expect('${sheet.rows[1][1]?.value}', 'Аня');
      expect('${sheet.rows[1][2]?.value}', '15');
      expect('${sheet.rows[1][4]?.value}', '1990');
    });

    test('пустой список даёт только заголовок', () {
      final excel = ExcelExporter.createWorkbook([]);
      expect(excel[ExcelExporter.sheetName].rows, hasLength(1));
    });

    test('выгруженный файл читается обратно', () async {
      await repo.create(name: 'Аня', day: 15, month: 3, birthYear: 1990);
      await repo.create(name: 'Борис', day: 1, month: 5);
      final all = await repo.list();
      final excel = ExcelExporter.createWorkbook(
        all.map((i) => i.birthday).toList(),
      );
      final parsed = ImportParser.parse(
        FileExportService.readTable(excel.save()!),
      );
      expect(parsed.errors, isEmpty);
      expect(parsed.candidates, hasLength(2));
    });

    test('круговой путь не создаёт дублей', () async {
      await repo.create(name: 'Аня', day: 15, month: 3, birthYear: 1990);
      final all = await repo.list();
      final excel = ExcelExporter.createWorkbook(
        all.map((i) => i.birthday).toList(),
      );
      final rows = FileExportService.readTable(excel.save()!);
      final result = await BirthdayImporter(repo).import(
        ImportParser.parse(rows),
      );
      expect(result.createdCount, 0);
      expect(result.updatedCount, 1);
      expect(await repo.count(), 1);
    });
  });

  group('импорт: создание', () {
    test('создаёт запись без ID в файле', () async {
      final result = await importRows([
        header,
        ['', 'Аня', '15', '3', '1990', '', 'нет'],
      ]);
      expect(result.createdCount, 1);
      expect(await repo.count(), 1);
    });

    test('сохраняет ID из файла', () async {
      await importRows([
        header,
        ['my-uuid', 'Аня', '15', '3', '', '', 'нет'],
      ]);
      final items = await repo.list();
      expect(items.single.birthday.id, 'my-uuid');
    });

    test('создаёт несколько записей', () async {
      final result = await importRows([
        header,
        ['', 'Аня', '15', '3', '', '', 'нет'],
        ['', 'Борис', '1', '5', '', '', 'нет'],
        ['', 'Вера', '2', '7', '', '', 'нет'],
      ]);
      expect(result.createdCount, 3);
      expect(await repo.count(), 3);
    });
  });

  group('импорт: обновление по ID', () {
    test('тот же ID обновляет запись', () async {
      final created = await repo.create(name: 'Старое', day: 1, month: 1);
      final result = await importRows([
        header,
        [created.id, 'Новое', '2', '2', '', '', 'нет'],
      ]);
      expect(result.updatedCount, 1);
      expect(result.outcomes.single.match, ImportMatch.updatedById);
      final items = await repo.list();
      expect(items.single.birthday.name, 'Новое');
      expect(await repo.count(), 1);
    });
  });

  group('импорт: обновление по имени и дате', () {
    test('другая машина, тот же человек', () async {
      await repo.create(name: 'Аня', day: 15, month: 3, note: 'старое');
      final result = await importRows([
        header,
        ['other-uuid', 'аня', '15', '3', '1990', 'новое', 'да'],
      ]);
      expect(result.updatedCount, 1);
      expect(result.outcomes.single.match, ImportMatch.updatedByKey);
      final items = await repo.list();
      expect(items.single.birthday.note, 'новое');
      expect(items.single.birthday.birthYear, 1990);
      expect(items.single.birthday.isImportant, isTrue);
    });

    test('разный регистр и пробелы не мешают', () async {
      await repo.create(name: 'Аня', day: 15, month: 3);
      final result = await importRows([
        header,
        ['', '  АНЯ  ', '15', '3', '', '', 'нет'],
      ]);
      expect(result.updatedCount, 1);
      expect(await repo.count(), 1);
    });

    test('разные даты — разные записи', () async {
      await repo.create(name: 'Аня', day: 15, month: 3);
      final result = await importRows([
        header,
        ['', 'Аня', '16', '3', '', '', 'нет'],
      ]);
      expect(result.createdCount, 1);
      expect(await repo.count(), 2);
    });
  });

  group('импорт: смешанные случаи', () {
    test('часть создаётся, часть обновляется', () async {
      final existing = await repo.create(name: 'Аня', day: 15, month: 3);
      final result = await importRows([
        header,
        [existing.id, 'Аня', '15', '3', '', '', 'нет'],
        ['', 'Новый', '1', '1', '', '', 'нет'],
      ]);
      expect(result.createdCount, 1);
      expect(result.updatedCount, 1);
      expect(await repo.count(), 2);
    });

    test('дубли внутри файла не создают вторую запись', () async {
      final result = await importRows([
        header,
        ['', 'Аня', '15', '3', '', '', 'нет'],
        ['', 'аня', '15', '3', '1990', '', 'нет'],
      ]);
      expect(result.createdCount, 1);
      expect(result.updatedCount, 1);
      expect(await repo.count(), 1);
    });

    test('плохая строка не отменяет хорошие', () async {
      final result = await importRows([
        header,
        ['', 'Хорошая', '1', '1', '', '', 'нет'],
        ['', 'Плохая', '99', '1', '', '', 'нет'],
      ]);
      expect(result.createdCount, 1);
      expect(result.errors, hasLength(1));
    });
  });

  group('отчёт импорта', () {
    test('считает строки и итоги', () async {
      final result = await importRows([
        header,
        ['', 'Аня', '1', '1', '', '', 'нет'],
        ['', 'Плохая', '99', '1', '', '', 'нет'],
      ]);
      expect(result.totalRows, 2);
      expect(result.successCount, 1);
      expect(result.hasErrors, isTrue);
    });

    test('номер строки соответствует файлу', () async {
      final result = await importRows([
        header,
        ['', 'Аня', '1', '1', '', '', 'нет'],
        ['', 'Плохая', '99', '1', '', '', 'нет'],
      ]);
      expect(result.errors.single.rowNumber, 2);
      expect(result.errors.single.toString(), contains('Строка 2'));
    });
  });
}
