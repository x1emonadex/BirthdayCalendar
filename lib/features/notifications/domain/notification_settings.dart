/// Время напоминания в сутках.
///
/// Отдельный класс, а не пара чисел: времён может быть несколько, их
/// сортируют и включают-выключают по одному.
class NotificationTime {
  const NotificationTime(this.hour, this.minute, {this.enabled = true});

  /// Время по умолчанию — девять утра.
  static const NotificationTime defaultTime = NotificationTime(9, 0);

  /// Час срабатывания в местном времени, 0..23.
  final int hour;

  /// Минута срабатывания, 0..59.
  final int minute;

  /// Выключенное время остаётся в списке, но не планируется: так его можно
  /// вернуть, не вспоминая, на сколько оно было поставлено.
  final bool enabled;

  /// Минуты от начала суток — по ним времена сравниваются и сортируются.
  int get minutesOfDay => hour * 60 + minute;

  /// «09:00»
  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  NotificationTime copyWith({int? hour, int? minute, bool? enabled}) {
    return NotificationTime(
      hour ?? this.hour,
      minute ?? this.minute,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationTime &&
      other.hour == hour &&
      other.minute == minute &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(hour, minute, enabled);

  @override
  String toString() => enabled ? label : '$label (выключено)';
}

/// Настройки уведомлений о днях рождения.
///
/// Неизменяемый класс: UI создаёт новый через [copyWith], а не меняет
/// существующий объект. Это исключает случай, когда настройки применятся
/// наполовину.
class NotificationSettings {
  const NotificationSettings({
    this.enabled = true,
    this.daysBefore = defaultDaysBefore,
    this.times = defaultTimes,
    this.importantOnly = false,
  });

  /// Наборы дней по умолчанию: за неделю, за день и в день рождения.
  static const Set<int> defaultDaysBefore = {7, 1, 0};

  /// Сроки, которые показываются готовыми чипами.
  ///
  /// Всё остальное из [daysBefore] — «свои» сроки: экран показывает их
  /// отдельными чипами, но планировщик одинаково работает со всеми числами.
  static const Set<int> quickDays = {7, 1, 0};

  /// Время по умолчанию — одно, девять утра.
  static const List<NotificationTime> defaultTimes = [
    NotificationTime.defaultTime,
  ];

  /// Сколько времён можно задать.
  ///
  /// Ограничение не техническое: больше шести напоминаний в сутки об одном и
  /// том же — уже не напоминание, а спам. Заодно список не растёт бесконечно.
  static const int maxTimes = 6;

  /// Порог, до которого просроченное уведомление показывается сразу.
  ///
  /// Внутренняя константа, а не настройка: пользователь не может осмысленно
  /// выбрать «15 минут вместо 30». Живёт здесь, а не в конструкторе, чтобы
  /// не попадать в JSON и не занимать место в настройках интерфейса.
  static const Duration defaultImmediateThreshold = Duration(minutes: 30);

  /// Выключены ли уведомления полностью.
  final bool enabled;

  /// За сколько дней до праздника присылать напоминание.
  final Set<int> daysBefore;

  /// Во сколько присылать напоминание. Времён может быть несколько — тогда в
  /// эти моменты придут отдельные уведомления.
  final List<NotificationTime> times;

  /// Уведомлять только о помеченных как важные.
  final bool importantOnly;

  /// Времена, которые действительно планируются.
  List<NotificationTime> get activeTimes =>
      times.where((time) => time.enabled).toList();

  /// Приводит список времён в порядок: без повторов, по возрастанию.
  ///
  /// Два одинаковых времени дали бы одно и то же уведомление и один и тот же
  /// идентификатор, поэтому дубли убираем сразу. Включённое время важнее
  /// выключенного с тем же значением.
  static List<NotificationTime> normalizeTimes(List<NotificationTime> times) {
    final byMinute = <int, NotificationTime>{};
    for (final time in times) {
      final existing = byMinute[time.minutesOfDay];
      if (existing == null || (time.enabled && !existing.enabled)) {
        byMinute[time.minutesOfDay] = time;
      }
    }
    return byMinute.values.toList()
      ..sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
  }

  /// Копия с изменёнными полями.
  ///
  /// `clearDaysBefore` позволяет задать пустое множество — обычный
  /// `daysBefore: null` этого не умеет, так как null значит «не менять».
  NotificationSettings copyWith({
    bool? enabled,
    Set<int>? daysBefore,
    bool clearDaysBefore = false,
    List<NotificationTime>? times,
    bool? importantOnly,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      daysBefore: clearDaysBefore
          ? const <int>{}
          : (daysBefore ?? this.daysBefore),
      times: times == null ? this.times : normalizeTimes(times),
      importantOnly: importantOnly ?? this.importantOnly,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NotificationSettings &&
        other.enabled == enabled &&
        _setEquals(other.daysBefore, daysBefore) &&
        _timesEqual(other.times, times) &&
        other.importantOnly == importantOnly;
  }

  @override
  int get hashCode {
    // Object.hash на разных запусках даёт разный результат для строк, а
    // hashCode здесь используется для сравнения состояния в UI. Поэтому
    // считаем вручную, без строк и без List внутри.
    var hash = 0x811c9dc5;
    for (final value in _sortedDays) {
      hash = (hash ^ value) & 0xFFFFFFFF;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    for (final time in times) {
      hash = (hash ^ time.hour) & 0xFFFFFFFF;
      hash = (hash ^ time.minute) & 0xFFFFFFFF;
      hash = (hash ^ (time.enabled ? 1 : 0)) & 0xFFFFFFFF;
    }
    hash = (hash ^ (enabled ? 1 : 0)) & 0xFFFFFFFF;
    hash = (hash ^ (importantOnly ? 1 : 0)) & 0xFFFFFFFF;
    return hash;
  }

  /// Отсортированная копия — порядок множества не влияет на хеш.
  List<int> get _sortedDays {
    final list = daysBefore.toList()..sort();
    return list;
  }

  @override
  String toString() {
    return 'NotificationSettings(enabled: $enabled, daysBefore: $_sortedDays, '
        'times: $times, importantOnly: $importantOnly)';
  }
}

/// Сравнение множеств по содержимому.
///
/// `Set` в Dart сравнивается по идентичности, а не по содержимому, поэтому
/// `a == b` для двух одинаковых множеств даёт `false`. Своё сравнение
/// обязательно для корректной проверки изменений в UI.
bool _setEquals(Set<int> a, Set<int> b) {
  if (a.length != b.length) return false;
  for (final value in a) {
    if (!b.contains(value)) return false;
  }
  return true;
}

/// Сравнение списков времён по содержимому — по той же причине, что и множеств.
bool _timesEqual(List<NotificationTime> a, List<NotificationTime> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
