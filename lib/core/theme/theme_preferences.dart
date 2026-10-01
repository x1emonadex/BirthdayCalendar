/// Как выбирать светлую, тёмную или AMOLED-тему.
enum ThemeModePreference {
  /// Следовать системной настройке.
  system('system'),

  /// Всегда светлая.
  light('light'),

  /// Всегда тёмная.
  dark('dark'),

  /// Чёрный фон для OLED-экранов.
  ///
  /// Отдельный режим, а не просто тёмная тема: фон уезжает в чистый чёрный,
  /// а поверхности поднимаются на один-два тона, чтобы панели и карточки
  /// не проваливались в фон и оставались различимыми.
  amoled('amoled');

  const ThemeModePreference(this.storedValue);

  final String storedValue;

  static const ThemeModePreference defaultMode = ThemeModePreference.system;

  static ThemeModePreference fromStored(String? value) {
    return ThemeModePreference.values.firstWhere(
      (mode) => mode.storedValue == value,
      orElse: () => defaultMode,
    );
  }
}

/// Цветовой акцент приложения.
enum AccentColor {
  purple('purple', 0xFF7C4DFF),
  blue('blue', 0xFF1976D2),
  teal('teal', 0xFF00897B),
  green('green', 0xFF43A047),
  orange('orange', 0xFFF57C00),
  pink('pink', 0xFFD81B60),

  /// Произвольный цвет, выбранный пользователем в палитре.
  custom('custom', 0xFF7C4DFF);

  const AccentColor(this.storedValue, this.seedValue);

  /// Значение для сохранения в базе настроек.
  final String storedValue;

  /// Seed-цвет, из которого Material 3 строит всю схему.
  final int seedValue;

  static const AccentColor defaultAccent = AccentColor.purple;

  static AccentColor fromStored(String? value) {
    return AccentColor.values.firstWhere(
      (color) => color.storedValue == value,
      orElse: () => defaultAccent,
    );
  }
}

/// Настройки оформления.
class ThemeSettings {
  const ThemeSettings({
    this.mode = ThemeModePreference.defaultMode,
    this.accent = AccentColor.defaultAccent,
    this.customSeedColor = defaultCustomSeedColor,
  });

  /// Значение по умолчанию для произвольного цвета — тот же фиолетовый.
  static const int defaultCustomSeedColor = 0xFF7C4DFF;

  final ThemeModePreference mode;
  final AccentColor accent;

  /// Произвольный seed-цвет, выбранный пользователем.
  ///
  /// Используется, только если в палитре выбран пункт «Свой цвет».
  final int customSeedColor;

  ThemeSettings copyWith({
    ThemeModePreference? mode,
    AccentColor? accent,
    int? customSeedColor,
  }) {
    return ThemeSettings(
      mode: mode ?? this.mode,
      accent: accent ?? this.accent,
      customSeedColor: customSeedColor ?? this.customSeedColor,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ThemeSettings &&
        other.mode == mode &&
        other.accent == accent &&
        other.customSeedColor == customSeedColor;
  }

  @override
  int get hashCode => Object.hash(mode, accent, customSeedColor);

  /// Seed-цвет, который реально применяется к теме.
  int get effectiveSeedColor {
    if (accent == AccentColor.custom) return customSeedColor;
    return accent.seedValue;
  }
}
