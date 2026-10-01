/// Настройки уведомлений о днях рождения.
///
/// Неизменяемый класс: UI создаёт новый через [copyWith], а не меняет
/// существующий объект. Это исключает случай, когда настройки применятся
/// наполовину.
class NotificationSettings {
  const NotificationSettings({
    this.enabled = true,
    this.daysBefore = defaultDaysBefore,
    this.hour = defaultHour,
    this.minute = defaultMinute,
    this.importantOnly = false,
  });

  /// Наборы дней по умолчанию: за неделю, за день и в день рождения.
  static const Set<int> defaultDaysBefore = {7, 1, 0};

  /// Сроки, которые показываются готовыми чипами.
  ///
  /// Всё остальное из [daysBefore] — «свои» сроки: экран показывает их
  /// отдельными чипами, но планировщик одинаково работает со всеми числами.
  static const Set<int> quickDays = {7, 1, 0};

  static const int defaultHour = 9;
  static const int defaultMinute = 0;

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

  /// Час срабатывания в местном времени, 0..23.
  final int hour;

  /// Минута срабатывания, 0..59.
  final int minute;

  /// Уведомлять только о помеченных как важные.
  final bool importantOnly;

  /// Копия с изменёнными полями.
  ///
  /// `clearDaysBefore` позволяет задать пустое множество — обычный
  /// `daysBefore: null` этого не умеет, так как null значит «не менять».
  NotificationSettings copyWith({
    bool? enabled,
    Set<int>? daysBefore,
    bool clearDaysBefore = false,
    int? hour,
    int? minute,
    bool? importantOnly,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      daysBefore: clearDaysBefore
          ? const <int>{}
          : (daysBefore ?? this.daysBefore),
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      importantOnly: importantOnly ?? this.importantOnly,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NotificationSettings &&
        other.enabled == enabled &&
        _setEquals(other.daysBefore, daysBefore) &&
        other.hour == hour &&
        other.minute == minute &&
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
    hash = (hash ^ (enabled ? 1 : 0)) & 0xFFFFFFFF;
    hash = (hash ^ hour) & 0xFFFFFFFF;
    hash = (hash ^ minute) & 0xFFFFFFFF;
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
        'hour: $hour, minute: $minute, importantOnly: $importantOnly)';
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
