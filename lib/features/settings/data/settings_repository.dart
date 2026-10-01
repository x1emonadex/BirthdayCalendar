import 'package:birthday_calendar/core/database/app_database.dart';
import 'package:birthday_calendar/core/utils/leap_day_rule.dart';

/// Доступ к настройкам приложения.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<LeapDayRule> loadLeapDayRule() => LeapDayRule.load(_db);

  Future<void> saveLeapDayRule(LeapDayRule rule) =>
      LeapDayRule.save(_db, rule);

  /// Произвольная строковая настройка.
  Future<String?> read(String key) => _db.readSetting(key);

  /// Записывает произвольную строковую настройку.
  Future<void> write(String key, String value) =>
      _db.writeSetting(key, value);
}
