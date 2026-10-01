import 'package:drift/drift.dart';

/// Профиль владельца списка. В v1 создаётся автоматически один («Мой список»),
/// но таблица нужна уже сейчас, чтобы позже добавить профили без миграции
/// основной таблицы [BirthdayEntries].
@DataClassName('Profile')
class Profiles extends Table {
  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
