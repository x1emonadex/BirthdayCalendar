import 'package:birthday_calendar/features/export_import/data/import_result.dart';

/// Имена колонок в файлах экспорта.
abstract final class ExportColumns {
  static const String id = 'ID';
  static const String name = 'Имя';
  static const String day = 'День';
  static const String month = 'Месяц';
  static const String birthYear = 'Год рождения';
  static const String note = 'Заметка';
  static const String isImportant = 'Важный';

  static const List<String> all = [
    id,
    name,
    day,
    month,
    birthYear,
    note,
    isImportant,
  ];

  /// Признак: важна ли запись.
  static const String importantKey = 'isImportant';

  /// Варианты заголовков, которые распознаются при импорте.
  static const Map<String, List<String>> aliases = {
    'id': ['id', 'uuid', 'ид'],
    'name': ['имя', 'name', 'фио', 'фамилия имя'],
    'day': ['день', 'day', 'число'],
    'month': ['месяц', 'month'],
    'birthYear': ['год рождения', 'год', 'birthyear', 'годрождения'],
    'note': ['заметка', 'примечание', 'note', 'комментарий'],
    'isImportant': ['важный', 'важно', 'important', 'звезда'],
  };

  /// Приводит заголовок к каноническому имени колонки либо `null`.
  static String? normalize(String header) {
    final cleaned = _clean(header);
    for (final entry in aliases.entries) {
      for (final alias in entry.value) {
        if (_clean(alias) == cleaned) return entry.key;
      }
    }
    return null;
  }

  /// Убирает лишние пробелы, приводит к нижнему регистру.
  static String _clean(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }
}

/// Результат разбора файла.
class ParseOutcome {
  const ParseOutcome({required this.candidates, required this.errors});

  final List<ImportCandidate> candidates;
  final List<ImportError> errors;
}

/// Разбирает содержимое файла в кандидаты на импорт.
class ImportParser {
  const ImportParser._();

  /// Обязательные колонки: без них файл не имеет смысла.
  static const Set<String> required = {'name', 'day', 'month'};

  /// Разбирает строки файла. Первая строка считается заголовком.
  ///
  /// Одна плохая строка не прерывает импорт — она попадает в ошибки.
  static ParseOutcome parse(List<List<String>> rows) {
    if (rows.isEmpty) {
      return const ParseOutcome(
        candidates: [],
        errors: [ImportError(rowNumber: 0, message: 'Файл пуст')],
      );
    }

    final mapping = _mapColumns(rows.first);
    final missing = required.where((c) => !mapping.containsKey(c)).toList();

    if (missing.isNotEmpty) {
      final names = missing
          .map((c) => ExportColumns.aliases[c]!.first)
          .join(', ');
      return ParseOutcome(
        candidates: const [],
        errors: [
          ImportError(
            rowNumber: 0,
            message: 'В файле нет обязательных колонок: $names',
          ),
        ],
      );
    }

    final candidates = <ImportCandidate>[];
    final errors = <ImportError>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((cell) => cell.trim().isEmpty)) continue;

      try {
        candidates.add(_parseRow(row, mapping));
      } on FormatException catch (e) {
        errors.add(ImportError(rowNumber: i, message: e.message));
      }
    }

    return ParseOutcome(candidates: candidates, errors: errors);
  }

  static Map<String, int> _mapColumns(List<String> header) {
    final mapping = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      final normalized = ExportColumns.normalize(header[i]);
      if (normalized == null) continue;
      // Первое вхождение колонки побеждает: повторы игнорируем.
      mapping.putIfAbsent(normalized, () => i);
    }
    return mapping;
  }

  static ImportCandidate _parseRow(
    List<String> row,
    Map<String, int> mapping,
  ) {
    String cell(String column) {
      final index = mapping[column];
      if (index == null || index >= row.length) return '';
      return row[index].trim();
    }

    final name = cell('name');
    if (name.isEmpty) {
      throw const FormatException('пустое имя');
    }

    final day = _parseInt(cell('day'), 'день');
    final month = _parseInt(cell('month'), 'месяц');

    if (day < 1 || day > 31) {
      throw FormatException('неверный день: $day');
    }
    if (month < 1 || month > 12) {
      throw FormatException('неверный месяц: $month');
    }

    // 30 февраля и 31 апреля не существуют. 29 февраля допускаем: его
    // перенос на 28 февраля или 1 марта обрабатывается отдельно.
    final maxDay = _daysInMonth(month);
    final allowed = month == 2 && day == 29 ? 29 : maxDay;
    if (day > allowed) {
      throw FormatException('в месяце $month нет $day-го дня');
    }

    final yearText = cell('birthYear');
    int? birthYear;
    if (yearText.isNotEmpty) {
      birthYear = _parseInt(yearText, 'год рождения');
      if (birthYear < 1900 || birthYear > 2100) {
        throw FormatException('неправдоподобный год рождения: $birthYear');
      }
    }

    final id = cell('id');
    return ImportCandidate(
      id: id.isEmpty ? null : id,
      name: name,
      day: day,
      month: month,
      birthYear: birthYear,
      note: cell('note'),
      isImportant: _parseBool(cell(ExportColumns.importantKey)),
    );
  }

  static int _parseInt(String value, String what) {
    if (value.isEmpty) {
      throw FormatException('не заполнено поле «$what»');
    }
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw FormatException('«$what» не число: $value');
    }
    return parsed;
  }

  /// Понимает «да», «1», «true», «важно» — всё, что считается истиной.
  static bool _parseBool(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return false;
    return v == '1' ||
        v == 'true' ||
        v == 'да' ||
        v == 'yes' ||
        v == 'y' ||
        v == 'важно' ||
        v == 'важный' ||
        v == '*';
  }

  static int _daysInMonth(int month) {
    const lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return lengths[month - 1];
  }
}
