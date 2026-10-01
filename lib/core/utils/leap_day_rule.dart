import 'package:birthday_calendar/core/database/app_database.dart';
import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';

/// Правило отмечания 29 февраля в невисокосном году.
enum LeapDayRule {
  /// Отмечать 28 февраля.
  february28('feb28'),

  /// Отмечать 1 марта.
  march1('mar01');

  const LeapDayRule(this.storedValue);

  /// Значение, которое сохраняется в таблице настроек.
  final String storedValue;

  static const LeapDayRule defaultRule = LeapDayRule.february28;

  /// Тот же выбор в виде, который принимает чистая логика дат.
  LeapDayFallback get fallback => switch (this) {
        LeapDayRule.february28 => LeapDayFallback.february28,
        LeapDayRule.march1 => LeapDayFallback.march1,
      };

  /// Разбирает значение из настроек; при неизвестном — [defaultRule].
  static LeapDayRule fromStored(String? value) {
    return LeapDayRule.values.firstWhere(
      (rule) => rule.storedValue == value,
      orElse: () => defaultRule,
    );
  }

  /// Читает правило из базы, откатываясь к [defaultRule].
  static Future<LeapDayRule> load(AppDatabase db) async {
    final stored = await db.readSetting(kLeapDayRuleKey);
    return LeapDayRule.fromStored(stored);
  }

  /// Сохраняет правило в базу.
  static Future<void> save(AppDatabase db, LeapDayRule rule) {
    return db.writeSetting(kLeapDayRuleKey, rule.storedValue);
  }
}
