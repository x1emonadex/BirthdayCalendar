import 'package:birthday_calendar/core/database/app_database.dart';

/// Профиль владельца списка.
class Profile {
  const Profile({required this.id, required this.name});

  final String id;
  final String name;
}

/// Доступ к профилям.
class ProfileRepository {
  ProfileRepository(this._db);

  final AppDatabase _db;

  /// Профиль по умолчанию, создавая его при первом обращении.
  Future<Profile> ensureDefaultProfile() async {
    final id = await _db.ensureDefaultProfileId();
    final row = await _db.defaultProfile();
    return Profile(id: id, name: row?.name ?? kDefaultProfileName);
  }

  /// Список профилей. В v1 там всегда один — «Мой список».
  Future<List<Profile>> list() async {
    final rows = await _db.select(_db.profiles).get();
    return rows
        .map((row) => Profile(id: row.id, name: row.name))
        .toList();
  }
}
