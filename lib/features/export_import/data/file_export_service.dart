import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Формат выгрузки.
enum ExportFormat {
  xlsx('Excel', 'xlsx'),
  csv('CSV', 'csv');

  const ExportFormat(this.label, this.extension);

  final String label;
  final String extension;
}

/// Куда сохранён файл и как его передать пользователю.
class ExportResult {
  const ExportResult({required this.path, required this.format});

  final String path;
  final ExportFormat format;
}

/// Единый сервис работы с файлами для Android и Windows.
///
/// UI не знает, где создаётся файл и как отправляется: на Windows
/// предлагается выбор папки, на Android файл уходит в системное меню
/// «Поделиться».
class FileExportService {
  const FileExportService();

  /// Создаёт файл и предлагает пользователю его сохранить или отправить.
  ///
  /// Возвращает `null`, если пользователь отказался.
  Future<ExportResult?> exportAndShare({
    required Excel excel,
    required String csv,
    required ExportFormat format,
  }) async {
    final bytes = switch (format) {
      ExportFormat.xlsx => excel.save() ?? _utf8WithBom(csv),
      ExportFormat.csv => _utf8WithBom(csv),
    };
    final fileName = 'день_рождения.${format.extension}';

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return _saveOnDesktop(fileName, bytes, format);
    }
    return _shareFromTemp(fileName, bytes, format);
  }

  /// Сохраняет файл через диалог выбора папки.
  Future<ExportResult?> _saveOnDesktop(
    String fileName,
    List<int> bytes,
    ExportFormat format,
  ) async {
    final directory = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: [
        XTypeGroup(
          label: format == ExportFormat.xlsx ? 'Книга Excel' : 'Текст CSV',
          extensions: [format.extension],
        ),
      ],
    );
    if (directory == null) return null;

    final file = File(directory.path);
    await file.writeAsBytes(bytes, flush: true);
    return ExportResult(path: file.path, format: format);
  }

  /// Кладёт файл во временную папку и открывает системное меню «Поделиться».
  Future<ExportResult?> _shareFromTemp(
    String fileName,
    List<int> bytes,
    ExportFormat format,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Дни рождения',
      ),
    );

    return ExportResult(path: file.path, format: format);
  }

  /// Открывает диалог выбора файла и читает его содержимое.
  Future<List<int>?> pickAndRead({
    required List<String> extensions,
    required String label,
  }) async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: label, extensions: extensions),
      ],
    );
    if (file == null) return null;
    return file.readAsBytes();
  }

  /// Читает .xlsx и возвращает строки листа, включая заголовок.
  static List<List<String>> readExcel(Excel excel) {
    // Берём первый непустой лист: createExcel() добавляет пустой Sheet1,
    // и он оказывается первым в карте таблиц.
    Sheet? sheet;
    for (final candidate in excel.tables.values) {
      if (candidate.rows.isNotEmpty) {
        sheet = candidate;
        break;
      }
    }
    if (sheet == null) return const [];
    return sheet.rows
        .map(
          (row) => row
              .map((cell) => cell?.value?.toString() ?? '')
              .toList(),
        )
        .toList();
  }

  /// Определяет формат по содержимому и возвращает строки таблицы.
  ///
  /// XLSX — это zip-архив, поэтому файл начинается с сигнатуры «PK».
  /// Всё остальное считаем текстом: CSV или UTF-8 дамп таблицы.
  static List<List<String>> readTable(List<int> bytes) {
    if (bytes.isEmpty) return const [];

    final isZip = bytes.length > 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    if (isZip) {
      return readExcel(Excel.decodeBytes(bytes));
    }

    return readCsv(String.fromCharCodes(_stripBomBytes(bytes)));
  }

  /// Разбирает CSV: умеет запятую и точку с запятой, понимает кавычки.
  static List<List<String>> readCsv(String content) {
    final text = _stripBom(content);
    final delimiter = _detectDelimiter(text);
    return _parseDelimited(text, delimiter);
  }

  /// Кодирует строку в UTF-8 с BOM — иначе Excel не увидит кириллицу.
  static List<int> _utf8WithBom(String value) {
    return [0xEF, 0xBB, 0xBF, ...utf8.encode(value)];
  }

  static String _stripBom(String value) {
    if (value.isNotEmpty && value.codeUnitAt(0) == 0xFEFF) {
      return value.substring(1);
    }
    return value;
  }

  static List<int> _stripBomBytes(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return bytes.sublist(3);
    }
    return bytes;
  }

  /// Разделитель выбираем по первой строке: где больше разделителей.
  static String _detectDelimiter(String text) {
    final firstLine = text.split('\n').first;
    final semicolons = ';'.allMatches(firstLine).length;
    final commas = ','.allMatches(firstLine).length;
    return semicolons >= commas ? ';' : ',';
  }

  static List<List<String>> _parseDelimited(String text, String delimiter) {
    final rows = <List<String>>[];
    var current = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];

      if (inQuotes) {
        if (ch == '"') {
          // Две кавычки подряд — экранированная кавычка внутри значения.
          if (i + 1 < text.length && text[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(ch);
        }
        continue;
      }

      if (ch == '"') {
        inQuotes = true;
      } else if (ch == delimiter) {
        current.add(buffer.toString());
        buffer.clear();
      } else if (ch == '\r') {
        // Окончание строки Windows: игнорируем, ждём \n.
      } else if (ch == '\n') {
        current.add(buffer.toString());
        rows.add(current);
        current = <String>[];
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }

    // Последняя строка без завершающего перевода.
    if (buffer.isNotEmpty || current.isNotEmpty) {
      current.add(buffer.toString());
      rows.add(current);
    }

    return rows;
  }
}
