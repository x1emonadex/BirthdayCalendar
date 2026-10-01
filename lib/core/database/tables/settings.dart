import 'package:drift/drift.dart';

/// Произвольные настройки приложения в виде пары ключ-значение.
@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get settingKey => text().named('setting_key')();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {settingKey};
}
