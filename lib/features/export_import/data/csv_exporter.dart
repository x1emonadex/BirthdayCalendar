import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:birthday_calendar/features/export_import/data/import_parser.dart';

/// Формирует CSV по [birthdays].
class CsvExporter {
  const CsvExporter._();

  /// Возвращает содержимое CSV-файла.
  ///
  /// Разделитель — точка с запятой: так Excel в русской локали открывает файл
  /// двойным кликом без мастера импорта. Кодировка — UTF-8 с BOM, иначе
  /// кириллица превратится в квадраты.
  static String build(List<Birthday> birthdays) {
    final buffer = StringBuffer();
    buffer.writeln(ExportColumns.all.map(_escape).join(';'));

    for (final b in birthdays) {
      buffer.writeln(
        [
          _escape(b.id),
          _escape(b.name),
          b.day.toString(),
          b.month.toString(),
          b.birthYear?.toString() ?? '',
          _escape(b.note),
          b.isImportant ? 'да' : 'нет',
        ].join(';'),
      );
    }
    return buffer.toString();
  }

  /// Экранирует значение: кавычки, переводы строк и сам разделитель.
  static String _escape(String value) {
    final needsQuotes = value.contains(';') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }
}
