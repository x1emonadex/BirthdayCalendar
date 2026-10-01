import 'dart:io';

import 'package:birthday_calendar/core/database/app_database.dart';
import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';
import 'package:birthday_calendar/core/utils/leap_day_rule.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:birthday_calendar/features/birthdays/data/avatar_storage.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Р”РѕСЃС‚СѓРї Рє РґР°РЅРЅС‹Рј РґРЅРµР№ СЂРѕР¶РґРµРЅРёСЏ.
///
/// РЎР»РѕР№ РЅРµ Р·РЅР°РµС‚ РїСЂРѕ UI: РЅР° РІС‹С…РѕРґРµ вЂ” С‡РёСЃС‚С‹Рµ [Birthday] Рё [BirthdayOccurrence].
class BirthdayRepository {
  BirthdayRepository(this._db);

  final AppDatabase _db;

  static const Uuid _uuid = Uuid();

  /// Р’СЃРµ РґРЅРё СЂРѕР¶РґРµРЅРёСЏ РїСЂРѕС„РёР»СЏ СЃ СЂР°СЃСЃС‡РёС‚Р°РЅРЅС‹Рј СЂР°СЃСЃС‚РѕСЏРЅРёРµРј РґРѕ СЃРѕР±С‹С‚РёСЏ.
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

  /// Р—Р°РїРёСЃСЊ РїРѕ РёРґРµРЅС‚РёС„РёРєР°С‚РѕСЂСѓ Р»РёР±Рѕ `null`, РµСЃР»Рё РµС‘ РЅРµС‚.
  Future<Birthday?> findById(String id) async {
    final row = await (_db.select(_db.birthdayEntries)
          ..where((t) => t.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : Birthday.fromEntry(row);
  }

  /// РЎРѕР·РґР°С‘С‚ РґРµРЅСЊ СЂРѕР¶РґРµРЅРёСЏ. Р“РѕРґ СЂРѕР¶РґРµРЅРёСЏ РЅРµРѕР±СЏР·Р°С‚РµР»РµРЅ.
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
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.birthdayEntries).insert(entry.toEntry());
    return entry;
  }

  /// РћР±РЅРѕРІР»СЏРµС‚ СЃСѓС‰РµСЃС‚РІСѓСЋС‰СѓСЋ Р·Р°РїРёСЃСЊ. Р‘СЂРѕСЃРёС‚ [StateError], РµСЃР»Рё РµС‘ РЅРµС‚.
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
      throw StateError('Р”РµРЅСЊ СЂРѕР¶РґРµРЅРёСЏ СЃ id=$id РЅРµ РЅР°Р№РґРµРЅ');
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

  /// РЈРґР°Р»СЏРµС‚ Р·Р°РїРёСЃСЊ. Р’РѕР·РІСЂР°С‰Р°РµС‚ `true`, РµСЃР»Рё С‡С‚Рѕ-С‚Рѕ Р±С‹Р»Рѕ СѓРґР°Р»РµРЅРѕ.
  Future<bool> delete(String id) async {
    final count = await (_db.delete(_db.birthdayEntries)
          ..where((t) => t.id.equals(id)))
        .go();
    return count > 0;
  }

  /// РЈРґР°Р»СЏРµС‚ РІСЃРµ Р·Р°РїРёСЃРё РїСЂРѕС„РёР»СЏ. Р’РѕР·РІСЂР°С‰Р°РµС‚ РєРѕР»РёС‡РµСЃС‚РІРѕ СѓРґР°Р»С‘РЅРЅС‹С….
  Future<int> deleteAll({String? profileId}) async {
    final profile = profileId ?? await _db.ensureDefaultProfileId();
    return (_db.delete(_db.birthdayEntries)
          ..where((t) => t.profileId.equals(profile)))
        .go();
  }

  /// Р—Р°РїРёСЃРё, РіРѕС‚РѕРІС‹Рµ Рє РёРјРїРѕСЂС‚Сѓ: РїРѕРёСЃРє РґСѓР±Р»РµР№ РїРѕ UUID Рё РїРѕ РЅРѕСЂРјРёСЂРѕРІР°РЅРЅС‹Рј
  /// РёРјРµРЅРё СЃ РґР°С‚РѕР№.
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
      // Р”СѓР±Р»Рё РїРѕ РєР»СЋС‡Сѓ РѕСЃС‚Р°РІР»СЏРµРј: РїРµСЂРІР°СЏ wins, РѕСЃС‚Р°Р»СЊРЅС‹Рµ СЃС‡РёС‚Р°СЋС‚СЃСЏ РґСѓР±Р»СЏРјРё.
      byKey.putIfAbsent(birthday.dedupKey, () => birthday);
    }
    return ImportIndex(byId: byId, byKey: byKey);
  }

  /// РљРѕР»РёС‡РµСЃС‚РІРѕ Р·Р°РїРёСЃРµР№ РІ РїСЂРѕС„РёР»Рµ.
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

    // РџРѕРёСЃРє РґРµР»Р°РµРј РІ Dart, Р° РЅРµ С‡РµСЂРµР· SQL LIKE/lower(): С„СѓРЅРєС†РёСЏ lower() РІ
    // SQLite СЂР°Р±РѕС‚Р°РµС‚ С‚РѕР»СЊРєРѕ СЃ ASCII Рё РЅРµ РїРѕРЅРёРјР°РµС‚ РєРёСЂРёР»Р»РёС†Сѓ, РїРѕСЌС‚РѕРјСѓ
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
        'РњРµСЃСЏС† РґРѕР»Р¶РµРЅ Р±С‹С‚СЊ РІ РґРёР°РїР°Р·РѕРЅРµ 1..12, РїРѕР»СѓС‡РµРЅРѕ $month',
      );
    }
    if (day < 1 || day > 31) {
      throw ArgumentError(
        'Р”РµРЅСЊ РґРѕР»Р¶РµРЅ Р±С‹С‚СЊ РІ РґРёР°РїР°Р·РѕРЅРµ 1..31, РїРѕР»СѓС‡РµРЅРѕ $day',
      );
    }
    // 30 С„РµРІСЂР°Р»СЏ Рё 31 Р°РїСЂРµР»СЏ РЅРµ СЃСѓС‰РµСЃС‚РІСѓСЋС‚; 29 С„РµРІСЂР°Р»СЏ РґРѕРїСѓСЃРєР°РµРј вЂ”
    // РµРіРѕ РїРµСЂРµРЅРѕСЃ РЅР° 1 РјР°СЂС‚Р° РёР»Рё 28 С„РµРІСЂР°Р»СЏ РѕР±СЂР°Р±Р°С‚С‹РІР°РµС‚СЃСЏ РѕС‚РґРµР»СЊРЅРѕ.
    final maxDay = _daysInMonth(month, birthYear ?? 2024);
    final allowed = month == 2 && day == 29 ? 29 : maxDay;
    if (day > allowed) {
      throw ArgumentError('Р’ РјРµСЃСЏС†Рµ $month РЅРµС‚ $day-РіРѕ РґРЅСЏ');
    }
    final now = DateTime.now();
    if (birthYear != null && (birthYear < 1900 || birthYear > now.year)) {
      throw ArgumentError(
        'Р“РѕРґ СЂРѕР¶РґРµРЅРёСЏ РґРѕР»Р¶РµРЅ Р±С‹С‚СЊ РІ РґРёР°РїР°Р·РѕРЅРµ 1900..${now.year}',
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

    if (oldFile != null) await AvatarStorage.delete(oldFile);
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

  /// Р—Р°РїРёСЃРё РїРѕ UUID вЂ” С‚РѕС‡РЅРѕРµ СЃРѕРІРїР°РґРµРЅРёРµ.
  final Map<String, Birthday> byId;

  /// Р—Р°РїРёСЃРё РїРѕ РЅРѕСЂРјРёСЂРѕРІР°РЅРЅС‹Рј РёРјРµРЅРё Рё РґР°С‚Рµ вЂ” СЌРІСЂРёСЃС‚РёРєР° РґР»СЏ РґСѓР±Р»РµР№.
  final Map<String, Birthday> byKey;
}
