import 'package:birthday_calendar/core/database/app_database.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Единственный экземпляр базы данных на всё приложение.
///
/// Riverpod вызывает `ref.onDispose` при выходе из ProviderScope — в тестах
/// контейнер уничтожается, и база закрывается автоматически.
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.defaults();
  ref.onDispose(db.close);
  return db;
});

/// Репозиторий дней рождения.
final Provider<BirthdayRepository> birthdayRepositoryProvider =
    Provider<BirthdayRepository>(
  (ref) => BirthdayRepository(ref.watch(appDatabaseProvider)),
);
