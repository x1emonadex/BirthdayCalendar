import 'dart:io';

import 'package:birthday_calendar/core/database/app_database.dart';
import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';
import 'package:birthday_calendar/core/utils/leap_day_rule.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:birthday_calendar/features/birthdays/data/avatar_storage.dart';
import 'package:birthday_calendar/features/birthdays/data/avatar_color.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Доступ к данным дней рождения.
///
/// Слой не знает про UI: на выходе — чистые [Birthday] и [BirthdayOccurrence].
class BirthdayRepository {
  BirthdayRepository(this._db);

  final AppDatabase _db;

  static const Uuid _uuid = Uuid();

  /// Все дни рождения профиля с рассчитанным расстоянием до события.
  Future<List<BirthdayWithOccurrence>> list({
    BirthdayQuery query = const BirthdayQuery(),
    String? profileId,
  }) async {
    final profile = profileId ?? await _db.ensureDefaultProfileId();
    final rule = await LeapDayRule.load(_db);
    final reference = query.reference ?? DateTime.now();

    final rows = await _filteredRows(query, profile);
    final result = <BirthdayWithOccurrence>[];

    for (final row in rows) {
      final birthday = Birthday.fromEntry(row);
      result.add(
        BirthdayWithOccurrence(
          birthday: birthday,
          occurrence: BirthdayDateUtils.nextOccurrence(
            month: birthday.month,
            day: birthday.day,
            birthYear: birthday.birthYear,
            reference: reference,
            fallback: _toFallback(rule),
          ),
        ),
      );
    }

    _sort(result, query.sort);
    return result;
  }

  /// Запись по идентификатору либо `null`, если её нет.
  Future<Birthday?> findById(String id) async {
    final row = await (_db.select(_db.birthdayEntries)
          ..where((t) => t.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : Birthday.fromEntry(row);
  }

  /// Создаёт день рождения. Год рождения необязателен.
  Future<Birthday> create({
    required String name,
    required int day,
    required int month,
    int? birthYear,
    String note = '',
    bool isImportant = false,
    String? profileId,
    String? id,
  }) async {
    _validate(name: name, day: day, month: month, birthYear: birthYear);
    final profile = profileId ?? await _db.ensureDefaultProfileId();
    final now = DateTime.now();

    final entry = Birthday(
      id: (id == null || id.isEmpty) ? _uuid.v4() : id,
      profileId: profile,
      name: name.trim(),
      day: day,
      month: month,
      birthYear: birthYear,
      note: note.trim(),
      isImportant: isImportant,
      avatarColorValue: AvatarColor.random(),
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.birthdayEntries).insert(entry.toEntry());
    return entry;
  }

  /// Обновляет существующую запись. Бросит [StateError], если её нет.
  Future<Birthday> update({
    required String id,
    required String name,
    required int day,
    required int month,
    int? birthYear,
    String note = '',
    bool isImportant = false,
  }) async {
    _validate(name: name, day: day, month: month, birthYear: birthYear);
    final current = await findById(id);
    if (current == null) {
      throw StateError('День рождения с id=$id не найден');
    }

    final updated = current.copyWith(
      name: name.trim(),
      day: day,
      month: month,
      birthYear: birthYear,
      clearBirthYear: birthYear == null,
      note: note.trim(),
      isImportant: isImportant,
      updatedAt: DateTime.now(),
    );

    await (_db.update(_db.birthdayEntries)
          ..where((t) => t.id.equals(id)))
        .write(updated.toEntry());
    return updated;
  }

  /// Удаляет запись. Возвращает `true`, если что-то было удалено.
  Future<bool> delete(String id) async {
    final count = await (_db.delete(_db.birthdayEntries)
          ..where((t) => t.id.equals(id)))
        .go();
    return count > 0;
  }

  /// Удаляет все записи профиля. Возвращает количество удалённых.
  Future<int> deleteAll({String? profileId}) async {
    final profile = profileId ?? await _db.ensureDefaultProfileId();
    return (_db.delete(_db.birthdayEntries)
          ..where((t) => t.profileId.equals(profile)))
        .go();
  }

  /// Записи, готовые к импорту: поиск дублей по UUID и по нормированным
  /// имени с датой.
  Future<ImportIndex> buildImportIndex({String? profileId}) async {
    final profile = profileId ?? await _db.ensureDefaultProfileId();
    final rows = await (_db.select(_db.birthdayEntries)
          ..where((t) => t.profileId.equals(profile)))
        .get();

    final byId = <String, Birthday>{};
    final byKey = <String, Birthday>{};
    for (final row in rows) {
      final birthday = Birthday.fromEntry(row);
      byId[birthday.id] = birthday;
      // Дубли по ключу оставляем: первая wins, остальные считаются дублями.
      byKey.putIfAbsent(birthday.dedupKey, () => birthday);
    }
    return ImportIndex(byId: byId, byKey: byKey);
  }

  /// Количество записей в профиле.
  Future<int> count({String? profileId}) async {
    final profile = profileId ?? await _db.ensureDefaultProfileId();
    final countExpr = _db.birthdayEntries.id.count();
    final query = _db.selectOnly(_db.birthdayEntries)
      ..addColumns([countExpr])
      ..where(_db.birthdayEntries.profileId.equals(profile));
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  Future<List<BirthdayEntry>> _filteredRows(
    BirthdayQuery query,
    String profileId,
  ) async {
    final statement = _db.select(_db.birthdayEntries)
      ..where((t) => t.profileId.equals(profileId));

    if (query.importantOnly) {
      statement.where((t) => t.isImportant.equals(true));
    }

    var rows = await statement.get();

    // Поиск делаем в Dart, а не через SQL LIKE/lower(): функция lower() в
    // SQLite работает только с ASCII и не понимает кириллицу, поэтому
    // Р·Р°РїСЂРѕСЃ В«РёРІР°РЅВ» РЅРµ РЅР°С€С‘Р» Р±С‹ В«РРІР°РЅВ».
    final search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      rows = rows.where((row) {
        return row.name.toLowerCase().contains(search) ||
            row.note.toLowerCase().contains(search);
      }).toList();
    }
    return rows;
  }

  void _sort(List<BirthdayWithOccurrence> items, BirthdaySort sort) {
    switch (sort) {
      case BirthdaySort.upcoming:
        items.sort((a, b) {
          final byDays =
              a.occurrence.daysUntil.compareTo(b.occurrence.daysUntil);
          if (byDays != 0) return byDays;
          return a.birthday.name
              .toLowerCase()
              .compareTo(b.birthday.name.toLowerCase());
        });
      case BirthdaySort.byName:
        items.sort(
          (a, b) => a.birthday.name
              .toLowerCase()
              .compareTo(b.birthday.name.toLowerCase()),
        );
      case BirthdaySort.byCalendarDate:
        items.sort((a, b) {
          final byMonth = a.birthday.month.compareTo(b.birthday.month);
          if (byMonth != 0) return byMonth;
          return a.birthday.day.compareTo(b.birthday.day);
        });
      case BirthdaySort.importantFirst:
        items.sort((a, b) {
          if (a.birthday.isImportant != b.birthday.isImportant) {
            return a.birthday.isImportant ? -1 : 1;
          }
          return a.occurrence.daysUntil.compareTo(b.occurrence.daysUntil);
        });
    }
  }

  LeapDayFallback _toFallback(LeapDayRule rule) {
    return switch (rule) {
      LeapDayRule.february28 => LeapDayFallback.february28,
      LeapDayRule.march1 => LeapDayFallback.march1,
    };
  }

  void _validate({
    required String name,
    required int day,
    required int month,
    int? birthYear,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('РРјСЏ РЅРµ РјРѕР¶РµС‚ Р±С‹С‚СЊ РїСѓСЃС‚С‹Рј');
    }
    if (month < 1 || month > 12) {
      throw ArgumentError(
        'Месяц должен быть в диапазоне 1..12, получено $month',
      );
    }
    if (day < 1 || day > 31) {
      throw ArgumentError(
        'День должен быть в диапазоне 1..31, получено $day',
      );
    }
    // 30 февраля и 31 апреля не существуют; 29 февраля допускаем —
    // его перенос на 1 марта или 28 февраля обрабатывается отдельно.
    final maxDay = _daysInMonth(month, birthYear ?? 2024);
    final allowed = month == 2 && day == 29 ? 29 : maxDay;
    if (day > allowed) {
      throw ArgumentError('В месяце $month нет $day-го дня');
    }
    final now = DateTime.now();
    if (birthYear != null && (birthYear < 1900 || birthYear > now.year)) {
      throw ArgumentError(
        'Год рождения должен быть в диапазоне 1900..${now.year}',
      );
    }
  }

  int _daysInMonth(int month, int year) {
    const lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && BirthdayDateUtils.isLeapYear(year)) return 29;
    return lengths[month - 1];
  }

  /// Привязывает к записи фотографию аватара.
  ///
  /// Файл копируется в каталог приложения, в базу попадает только имя.
  /// Старый аватар удаляется после успешного сохранения нового.
  Future<Birthday> setAvatarFile(String id, File file) async {
    final current = await findById(id);
    if (current == null) {
      throw StateError('День рождения с id=$id не найден');
    }

    final fileName = await AvatarStorage.save(id, file);
    final oldFile = current.avatarFileName;

    final updated = current.copyWith(
      avatarFileName: fileName,
      clearAvatarColorValue: true,
      updatedAt: DateTime.now(),
    );
    await (_db.update(_db.birthdayEntries)..where((t) => t.id.equals(id)))
        .write(updated.toEntry());

    // Файл аватара называется по id записи, поэтому при замене фотографии
    // новое имя совпадает со старым. Удалять «старый» файл в этом случае
    // нельзя — иначе снесём только что сохранённую фотографию.
    if (oldFile != null && oldFile != fileName) {
      await AvatarStorage.delete(oldFile);
    }
    return updated;
  }

  /// Задаёт цвет аватара и убирает фотографию, если она была.
  Future<Birthday> setAvatarColor(String id, int colorValue) async {
    final current = await findById(id);
    if (current == null) {
      throw StateError('День рождения с id=$id не найден');
    }

    final oldFile = current.avatarFileName;
    final updated = current.copyWith(
      avatarColorValue: colorValue,
      clearAvatarFileName: true,
      updatedAt: DateTime.now(),
    );
    await (_db.update(_db.birthdayEntries)..where((t) => t.id.equals(id)))
        .write(updated.toEntry());

    if (oldFile != null) await AvatarStorage.delete(oldFile);
    return updated;
  }

  /// Возвращает запись к стандартному аватару: убирает фото и цвет.
  Future<Birthday> clearAvatar(String id) async {
    final current = await findById(id);
    if (current == null) {
      throw StateError('День рождения с id=$id не найден');
    }

    final oldFile = current.avatarFileName;
    final updated = current.copyWith(
      clearAvatarFileName: true,
      clearAvatarColorValue: true,
      updatedAt: DateTime.now(),
    );
    await (_db.update(_db.birthdayEntries)..where((t) => t.id.equals(id)))
        .write(updated.toEntry());

    if (oldFile != null) await AvatarStorage.delete(oldFile);
    return updated;
  }
}

/// РРЅРґРµРєСЃ СЃСѓС‰РµСЃС‚РІСѓСЋС‰РёС… Р·Р°РїРёСЃРµР№ РґР»СЏ СЃРѕРїРѕСЃС‚Р°РІР»РµРЅРёСЏ РїСЂРё РёРјРїРѕСЂС‚Рµ.
class ImportIndex {
  const ImportIndex({required this.byId, required this.byKey});

  /// Записи по UUID — точное совпадение.
  final Map<String, Birthday> byId;

  /// Записи по нормированным имени и дате — эвристика для дублей.
  final Map<String, Birthday> byKey;
}
