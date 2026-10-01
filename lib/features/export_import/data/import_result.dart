import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';

/// Как запись из файла сопоставляется с уже существующей.
enum ImportMatch {
  /// В базе нет ни записи с таким UUID, ни похожей по имени и дате.
  created,

  /// Найдена запись с тем же UUID — обновлена.
  updatedById,

  /// UUID не совпал, но имя и дата совпали — обновлена.
  updatedByKey,

  /// Похожая запись найдена, но автообновление отключено.
  skipped,
}

/// Одна запись, прочитанная из файла.
class ImportCandidate {
  const ImportCandidate({
    required this.name,
    required this.day,
    required this.month,
    this.birthYear,
    this.note = '',
    this.isImportant = false,
    this.id,
  });

  /// UUID из файла. Может отсутствовать — тогда создаём новый.
  final String? id;
  final String name;
  final int day;
  final int month;
  final int? birthYear;
  final String note;
  final bool isImportant;

  String get dedupKey =>
      '${name.trim().toLowerCase()}|${day.toString().padLeft(2, '0')}|'
      '${month.toString().padLeft(2, '0')}';
}

/// Итог одной записанной записи.
class ImportOutcome {
  const ImportOutcome({required this.match, required this.candidate});

  final ImportMatch match;
  final ImportCandidate candidate;

  String get name => candidate.name;
}

/// Результат импорта файла.
class ImportResult {
  const ImportResult({
    required this.outcomes,
    required this.errors,
    this.totalRows = 0,
  });

  final List<ImportOutcome> outcomes;

  /// Строки, которые не удалось прочитать: номер и причина.
  final List<ImportError> errors;

  /// Сколько строк было в файле целиком.
  final int totalRows;

  int get createdCount =>
      outcomes.where((o) => o.match == ImportMatch.created).length;

  int get updatedCount => outcomes
      .where(
        (o) =>
            o.match == ImportMatch.updatedById ||
            o.match == ImportMatch.updatedByKey,
      )
      .length;

  int get skippedCount =>
      outcomes.where((o) => o.match == ImportMatch.skipped).length;

  int get successCount => createdCount + updatedCount;

  bool get hasErrors => errors.isNotEmpty;
}

/// Ошибка чтения одной строки.
class ImportError {
  const ImportError({required this.rowNumber, required this.message});

  /// Номер строки в файле, начиная с 1. Строка заголовка не считается.
  final int rowNumber;

  final String message;

  @override
  String toString() => 'Строка $rowNumber: $message';
}

/// Строка для экспорта в таблицу.
class ExportRow {
  const ExportRow({required this.birthday});

  final Birthday birthday;
}
