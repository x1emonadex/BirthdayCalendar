import 'package:birthday_calendar/core/providers/database_provider.dart';
import 'package:birthday_calendar/core/utils/leap_day_rule.dart';
import 'package:birthday_calendar/features/settings/data/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

/// Правило отмечания 29 февраля.
final FutureProvider<LeapDayRule> leapDayRuleProvider =
    FutureProvider<LeapDayRule>(
  (ref) => ref.watch(settingsRepositoryProvider).loadLeapDayRule(),
);
