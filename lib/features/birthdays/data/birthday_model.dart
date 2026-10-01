import 'package:birthday_calendar/core/database/app_database.dart';

/// Доменная модель дня рождения.
///
/// Отдельный класс вместо строки Drift (`BirthdayEntry`), чтобы логика дат и
/// слои выше БД не зависели от сгенерированного кода.
class Birthday {
  const Birthday({
    required this.id,
    required this.profileId,
    required this.name,
    required this.day,
    required this.month,
    this.birthYear,
    this.note = '',
    this.isImportant = false,
    this.avatarFileName,
    this.avatarColorValue,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String profileId;
  final String name;
  final int day;
  final int month;
  final int? birthYear;
  final String note;
  final bool isImportant;

  /// Имя файла аватара в каталоге приложения; `null` — стандартный.
  final String? avatarFileName;

  /// Цвет аватара, когда пользователь выбрал цвет вместо фото.
  final int? avatarColorValue;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Есть ли у записи собственный аватар.
  bool get hasCustomAvatar =>
      avatarFileName != null || avatarColorValue != null;

  /// Запись дня рождения ровно 29 февраля.
  bool get isLeapDay => day == 29 && month == 2;

  /// Ключ для поиска дублей при импорте: нормализованные имя + день + месяц.
  String get dedupKey =>
      '${name.trim().toLowerCase()}|${day.toString().padLeft(2, '0')}|'
      '${month.toString().padLeft(2, '0')}';

  Birthday copyWith({
    String? id,
    String? profileId,
    String? name,
    int? day,
    int? month,
    int? birthYear,
    bool clearBirthYear = false,
    String? note,
    bool? isImportant,
    String? avatarFileName,
    bool clearAvatarFileName = false,
    int? avatarColorValue,
    bool clearAvatarColorValue = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Birthday(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      day: day ?? this.day,
      month: month ?? this.month,
      birthYear: clearBirthYear ? null : (birthYear ?? this.birthYear),
      note: note ?? this.note,
      isImportant: isImportant ?? this.isImportant,
      avatarFileName: clearAvatarFileName
          ? null
          : (avatarFileName ?? this.avatarFileName),
      avatarColorValue: clearAvatarColorValue
          ? null
          : (avatarColorValue ?? this.avatarColorValue),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Конвертирует доменную модель в строку Drift.
  BirthdayEntry toEntry() => BirthdayEntry(
        id: id,
        profileId: profileId,
        name: name,
        day: day,
        month: month,
        birthYear: birthYear,
        note: note,
        isImportant: isImportant,
        avatarFileName: avatarFileName,
        avatarColorValue: avatarColorValue,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// Создаёт модель из строки Drift.
  factory Birthday.fromEntry(BirthdayEntry entry) => Birthday(
        id: entry.id,
        profileId: entry.profileId,
        name: entry.name,
        day: entry.day,
        month: entry.month,
        birthYear: entry.birthYear,
        note: entry.note,
        isImportant: entry.isImportant,
        avatarFileName: entry.avatarFileName,
        avatarColorValue: entry.avatarColorValue,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
      );
}
