import 'package:drift/drift.dart';

import 'profiles.dart';

/// День рождения.
///
/// День и месяц хранятся отдельными числами, а не датой: у дня рождения нет
/// года в calendrical-смысле, и такая схема исключает проблемы с часовыми
/// поясами и повторением события каждый год.
@DataClassName('BirthdayEntry')
class BirthdayEntries extends Table {
  TextColumn get id => text()();

  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text().withLength(min: 1, max: 200)();

  IntColumn get day => integer().check(const CustomExpression('day BETWEEN 1 AND 31'))();

  IntColumn get month =>
      integer().check(const CustomExpression('month BETWEEN 1 AND 12'))();

  /// Необязательный: без него возраст не отображается.
  IntColumn get birthYear => integer().nullable()();

  TextColumn get note => text().withDefault(const Constant(''))();

  BoolColumn get isImportant => boolean().withDefault(const Constant(false))();

  /// Имя файла аватара в каталоге приложения. `null` — стандартный.
  TextColumn get avatarFileName => text().nullable()();

  /// Цвет аватара, если пользователь выбрал свой вместо фото.
  IntColumn get avatarColorValue => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
