import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import 'tables/birthdays.dart';
import 'tables/profiles.dart';
import 'tables/settings.dart';

part 'app_database.g.dart';

/// Имя профиля, который создаётся автоматически при первом запуске.
const String kDefaultProfileName = 'Мой список';

/// Ключ настройки: как отмечать 29 февраля в невисокосном году.
const String kLeapDayRuleKey = 'leap_day_rule';

@DriftDatabase(tables: [Profiles, BirthdayEntries, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// Бэкенд хранилища для платформ, где нужен реальный файл на диске.
  factory AppDatabase.defaults() => AppDatabase(
        driftDatabase(name: 'birthday_calendar'),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaultProfile();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Аватары и их цвета появились во второй версии схемы.
            // Столбцы добавляются с NULL, поэтому существующие записи
            // остаются валидными и получают стандартный аватар.
            await m.addColumn(birthdayEntries, birthdayEntries.avatarFileName);
            await m.addColumn(
              birthdayEntries,
              birthdayEntries.avatarColorValue,
            );
          }
        },
      );

  /// Возвращает профиль по умолчанию, создавая его при первом обращении.
  Future<String> ensureDefaultProfileId() async {
    final existing = await defaultProfile();
    if (existing != null) return existing.id;
    return _insertProfile(kDefaultProfileName);
  }

  /// Профиль с именем [kDefaultProfileName], либо `null`, если его ещё нет.
  Future<Profile?> defaultProfile() {
    return (select(profiles)
          ..where((p) => p.name.equals(kDefaultProfileName))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Читает строковую настройку. Возвращает `null`, если ключ отсутствует.
  Future<String?> readSetting(String key) async {
    final row = await (select(appSettings)
          ..where((s) => s.settingKey.equals(key))
          ..limit(1))
        .getSingleOrNull();
    return row?.value;
  }

  /// Записывает строковую настройку, заменяя прежнее значение.
  Future<void> writeSetting(String key, String value) async {
    await into(appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(settingKey: key, value: value),
        );
  }

  Future<String> _insertProfile(String name) async {
    final id = const Uuid().v4();
    await into(profiles).insert(
      ProfilesCompanion.insert(
        id: id,
        name: name,
        createdAt: DateTime.now(),
      ),
    );
    return id;
  }

  Future<void> _seedDefaultProfile() => _insertProfile(kDefaultProfileName);
}

QueryExecutor _open() => driftDatabase(name: 'birthday_calendar');
