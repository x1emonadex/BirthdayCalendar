import 'dart:math' as math;

/// Как отмечать 29 февраля, когда год невисокосный.
enum LeapDayFallback {
  /// Отмечать 28 февраля.
  february28,

  /// Отмечать 1 марта.
  march1;
}

/// Результат расчёта: ближайший день рождения и расстояние до него.
class BirthdayOccurrence {
  const BirthdayOccurrence({
    required this.date,
    required this.daysUntil,
    required this.yearsSinceBirth,
  });

  /// Дата празднования в ближайшем будущем (с учётом правила 29 февраля).
  final DateTime date;

  /// Сколько дней от [reference] до [date]. `0` — сегодня.
  final int daysUntil;

  /// Исполнилось лет на [date]; `null`, если год рождения не указан.
  final int? yearsSinceBirth;

  bool get isToday => daysUntil == 0;

  bool get isTomorrow => daysUntil == 1;
}

/// Чистые функции работы с датами дней рождения.
///
/// Не зависят от Flutter, Drift и любого другого слоя — поэтому их удобно
/// тестировать обычным `flutter test`.
class BirthdayDateUtils {
  const BirthdayDateUtils._();

  /// `true`, если [year] — високосный год по григорианскому правилу.
  static bool isLeapYear(int year) {
    if (year % 400 == 0) return true;
    if (year % 100 == 0) return false;
    return year % 4 == 0;
  }

  /// Обрезает [date] до полуночи локального времени.
  static DateTime atMidnight(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Дата празднования в [year] с учётом [fallback] для 29 февраля.
  ///
  /// В високосный год 29 февраля существует и празднуется как есть; иначе
  /// переносится на 28 февраля или 1 марта — по настройке.
  static DateTime celebrationDateInYear(
    int year,
    int month,
    int day, {
    LeapDayFallback fallback = LeapDayFallback.february28,
  }) {
    if (month == 2 && day == 29 && !isLeapYear(year)) {
      return switch (fallback) {
        LeapDayFallback.february28 => DateTime(year, 2, 28),
        LeapDayFallback.march1 => DateTime(year, 3, 1),
      };
    }
    return DateTime(year, month, day);
  }

  /// Ближайший день рождения начиная с [reference] включительно.
  ///
  /// [birthYear] необязателен и влияет только на [BirthdayOccurrence.yearsSinceBirth].
  /// [reference] по умолчанию — сегодня; передаётся явно, чтобы расчёт был
  /// детерминированным и тестируемым.
  static BirthdayOccurrence nextOccurrence({
    required int month,
    required int day,
    int? birthYear,
    required DateTime reference,
    LeapDayFallback fallback = LeapDayFallback.february28,
  }) {
    final today = atMidnight(reference);
    final thisYear = celebrationDateInYear(
      today.year,
      month,
      day,
      fallback: fallback,
    );

    // «Сегодня» подходит, поэтому уходим на следующий год только когда
    // празднование в этом году строго раньше сегодняшнего дня.
    final targetYear = thisYear.isBefore(today) ? today.year + 1 : today.year;

    final date = celebrationDateInYear(
      targetYear,
      month,
      day,
      fallback: fallback,
    );

    final daysUntil = date.difference(today).inDays;

    // Возраст на [targetYear]-й день рождения равен разнице годов и не
    // зависит от переноса 29 февраля: родившийся 29.02.2000 отмечает и
    // 28.02, и 01.03 своего 25-летия одинаково.
    final years = birthYear == null ? null : targetYear - birthYear;

    return BirthdayOccurrence(
      date: date,
      daysUntil: daysUntil,
      yearsSinceBirth: years,
    );
  }

  /// Возраст на дату [date] для человека, родившегося [birthYear].
  ///
  /// Считается по календарному году: на день рождения в этом году возраст
  /// увеличивается. Если день рождения в текущем году ещё не наступил,
  /// возраст на год меньше.
  static int ageAt({
    required int birthYear,
    required int month,
    required int day,
    required DateTime date,
    LeapDayFallback fallback = LeapDayFallback.february28,
  }) {
    final today = atMidnight(date);
    var age = today.year - birthYear;

    final thisYearBirthday = celebrationDateInYear(
      today.year,
      month,
      day,
      fallback: fallback,
    );
    if (thisYearBirthday.isAfter(today)) {
      age -= 1;
    }
    return math.max(0, age);
  }

  /// Склонение русского слова «день» / «дня» / «дней».
  ///
  /// Возвращает только числительное: `1 день`, `2 дня`, `5 дней`.
  static String pluralDays(int count) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    if (mod100 >= 11 && mod100 <= 19) return 'дней';
    if (mod10 == 1) return 'день';
    if (mod10 >= 2 && mod10 <= 4) return 'дня';
    return 'дней';
  }

  /// Склонение слова «год» / «года» / «лет».
  static String pluralYears(int count) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    if (mod100 >= 11 && mod100 <= 19) return 'лет';
    if (mod10 == 1) return 'год';
    if (mod10 >= 2 && mod10 <= 4) return 'года';
    return 'лет';
  }
}
