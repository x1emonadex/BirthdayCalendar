import 'package:birthday_calendar/features/birthdays/data/birthday_repository.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:birthday_calendar/features/export_import/data/import_parser.dart';
import 'package:birthday_calendar/features/export_import/data/import_result.dart';

/// Импортирует записи из разобранного файла.
class BirthdayImporter {
  const BirthdayImporter(this._repository);

  final BirthdayRepository _repository;

  /// Порядок сопоставления:
  /// 1. Совпал UUID — обновляем.
  /// 2. Совпали нормализованные имя и дата — обновляем.
  /// 3. Иначе создаём новую запись.
  ///
  /// Одна ошибка не прерывает импорт: строка попадает в
  /// [ImportResult.errors], остальные обрабатываются.
  Future<ImportResult> import(
    ParseOutcome parsed, {
    String? profileId,
  }) async {
    final index = await _repository.buildImportIndex(profileId: profileId);

    // Индексы обновляем по ходу импорта: если в самом файле есть две
    // одинаковые строки, вторая станет обновлением первой, а не дублем.
    final byId = Map<String, Birthday>.from(index.byId);
    final byKey = Map<String, Birthday>.from(index.byKey);

    final outcomes = <ImportOutcome>[];
    final errors = <ImportError>[...parsed.errors];

    for (var i = 0; i < parsed.candidates.length; i++) {
      final candidate = parsed.candidates[i];
      final rowNumber = i + 1;

      try {
        outcomes.add(
          await _apply(candidate, byId, byKey, profileId),
        );
      } on ArgumentError catch (e) {
        errors.add(ImportError(rowNumber: rowNumber, message: _msg(e)));
      } on StateError catch (e) {
        errors.add(ImportError(rowNumber: rowNumber, message: _msg(e)));
      }
    }

    return ImportResult(
      outcomes: outcomes,
      errors: errors,
      totalRows: parsed.candidates.length + parsed.errors.length,
    );
  }

  Future<ImportOutcome> _apply(
    ImportCandidate candidate,
    Map<String, Birthday> byId,
    Map<String, Birthday> byKey,
    String? profileId,
  ) async {
    // 1. Точное совпадение по UUID.
    if (candidate.id != null && byId.containsKey(candidate.id)) {
      final existing = byId[candidate.id]!;
      final updated = await _repository.update(
        id: existing.id,
        name: candidate.name,
        day: candidate.day,
        month: candidate.month,
        birthYear: candidate.birthYear,
        note: candidate.note,
        isImportant: candidate.isImportant,
      );
      _remember(updated, byId, byKey);
      return ImportOutcome(match: ImportMatch.updatedById, candidate: candidate);
    }

    // 2. Совпадение по нормализованному имени и дате.
    final key = candidate.dedupKey;
    if (byKey.containsKey(key)) {
      final existing = byKey[key]!;
      final updated = await _repository.update(
        id: existing.id,
        name: candidate.name,
        day: candidate.day,
        month: candidate.month,
        birthYear: candidate.birthYear,
        note: candidate.note,
        isImportant: candidate.isImportant,
      );
      _remember(updated, byId, byKey);
      return ImportOutcome(match: ImportMatch.updatedByKey, candidate: candidate);
    }

    // 3. Новая запись. Сохраняем UUID из файла, если он есть, чтобы
    // повторный импорт того же файла обновлял запись, а не создавал дубль.
    final created = await _create(candidate, profileId);
    _remember(created, byId, byKey);
    return ImportOutcome(match: ImportMatch.created, candidate: candidate);
  }

  Future<Birthday> _create(
    ImportCandidate candidate,
    String? profileId,
  ) async {
    return _repository.create(
      name: candidate.name,
      day: candidate.day,
      month: candidate.month,
      birthYear: candidate.birthYear,
      note: candidate.note,
      isImportant: candidate.isImportant,
      profileId: profileId,
      id: candidate.id,
    );
  }

  void _remember(
    Birthday birthday,
    Map<String, Birthday> byId,
    Map<String, Birthday> byKey,
  ) {
    byId[birthday.id] = birthday;
    byKey[birthday.dedupKey] = birthday;
  }

  /// Достаёт текст ошибки из исключения: `Invalid argument(s): 30` → `30`.
  static String _msg(Object error) {
    final text = error.toString();
    final match = RegExp(r':\s*(.+)$').firstMatch(text);
    return match?.group(1)?.trim() ?? text;
  }
}
