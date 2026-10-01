import 'dart:convert';
import 'dart:io';

import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_repository.dart';
import 'package:birthday_calendar/core/providers/database_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Сохраняет и восстанавливает список в обычный файл.
///
/// Это замена кнопке «удалить всё»: данные не нужно выбрасывать, если
/// хочется их перенести на другое устройство или просто подстраховаться.
class BackupService {
  BackupService(this._repository);

  final BirthdayRepository _repository;

  /// Имя файла копии по умолчанию.
  static const String suggestedName = 'дни_рождения.json';

  /// Сохраняет текущий список в выбранный пользователем файл.
  ///
  /// Возвращает `null`, если пользователь отказался от сохранения.
  Future<File?> saveBackup() async {
    final items = await _repository.list();

    final rows = <Map<String, Object?>>[
      for (final item in items)
        {
          'name': item.birthday.name,
          'day': item.birthday.day,
          'month': item.birthday.month,
          'birthYear': item.birthday.birthYear,
          'note': item.birthday.note,
          'isImportant': item.birthday.isImportant,
        },
    ];

    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Резервная копия', extensions: ['json']),
      ],
    );
    if (location == null) return null;

    final file = File(location.path);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'birthdays': rows,
      }),
      flush: true,
    );
    return file;
  }

  /// Читает копию и заменяет текущий список её содержимым.
  ///
  /// Возвращает `null`, если пользователь отказался или файл не выбран.
  Future<List<Birthday>?> restoreBackup() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Резервная копия', extensions: ['json']),
      ],
    );
    if (file == null) return null;

    final restored = await _readInto(File(file.path));

    // Копия полностью заменяет список: смешивать старую и новую записи
    // было бы неожиданно для пользователя.
    await _repository.deleteAll();

    final created = <Birthday>[];
    for (final candidate in restored) {
      created.add(
        await _repository.create(
          name: candidate.name,
          day: candidate.day,
          month: candidate.month,
          birthYear: candidate.birthYear,
          note: candidate.note,
          isImportant: candidate.isImportant,
        ),
      );
    }
    return created;
  }

  /// Разбирает файл копии. Плохие строки пропускаются, а не ломают импорт.
  Future<List<Birthday>> _readInto(File file) async {
    final result = <Birthday>[];

    List<dynamic> rows;
    try {
      final content = await file.readAsString();
      final root = jsonDecode(content) as Map<String, dynamic>;
      final list = root['birthdays'];
      if (list is! List) return result;
      rows = list;
    } catch (_) {
      return result;
    }

    final now = DateTime.now();
    // Заглушка нужна только ради copyWith: реальные значения подставляются
    // ниже, а идентификатор у копии всё равно создаётся заново.
    final stub = Birthday(
      id: '',
      profileId: '',
      name: '',
      day: 1,
      month: 1,
      createdAt: now,
      updatedAt: now,
    );

    for (final row in rows) {
      if (row is! Map) continue;

      final name = (row['name'] as String?)?.trim() ?? '';
      final day = (row['day'] as num?)?.toInt() ?? 0;
      final month = (row['month'] as num?)?.toInt() ?? 0;
      if (name.isEmpty || day < 1 || day > 31 || month < 1 || month > 12) {
        continue;
      }

      final year = (row['birthYear'] as num?)?.toInt();
      result.add(
        stub.copyWith(
          name: name,
          day: day,
          month: month,
          birthYear: year,
          clearBirthYear: year == null,
          note: (row['note'] as String?) ?? '',
          isImportant: row['isImportant'] as bool? ?? false,
        ),
      );
    }
    return result;
  }
}

/// Провайдер сервиса резервных копий.
final Provider<BackupService> backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(birthdayRepositoryProvider)),
);
