import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:birthday_calendar/features/export_import/data/import_parser.dart';
import 'package:excel/excel.dart';

/// Собирает таблицу дней рождения для выгрузки в Excel.
class ExcelExporter {
  const ExcelExporter._();

  /// Заголовок листа.
  static const String sheetName = 'Дни рождения';

  /// Формирует книгу Excel по [birthdays].
  static Excel createWorkbook(List<Birthday> birthdays) {
    final excel = Excel.createExcel();
    // createExcel() создаёт пустой лист Sheet1. Удаляем его: иначе в файле
    // окажется лишний пустой лист, а при импорте мы прочитаем именно его.
    excel.delete('Sheet1');
    final sheet = excel[sheetName];

    // Заголовок: имена колонок в том же порядке, что читает ImportParser.
    sheet.appendRow(ExportColumns.all.map(TextCellValue.new).toList());

    for (final b in birthdays) {
      sheet.appendRow([
        TextCellValue(b.id),
        TextCellValue(b.name),
        IntCellValue(b.day),
        IntCellValue(b.month),
        b.birthYear == null ? null : IntCellValue(b.birthYear!),
        TextCellValue(b.note),
        TextCellValue(b.isImportant ? 'да' : 'нет'),
      ]);
    }

    _format(sheet, birthdays.length);
    return excel;
  }

  /// Расставляет ширину колонок, чтобы значения не обрезались.
  static void _format(Sheet sheet, int dataRows) {
    for (var column = 0; column < ExportColumns.all.length; column++) {
      var longest = 10;
      for (var row = 0; row <= dataRows; row++) {
        final cell = sheet.rows[row][column];
        final length = cell?.value?.toString().length ?? 0;
        if (length > longest) longest = length;
      }
      sheet.setColumnWidth(column, (longest + 2).clamp(10, 40).toDouble());
    }
  }
}
