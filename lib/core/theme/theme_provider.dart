import 'dart:convert';

import 'package:birthday_calendar/core/theme/theme_preferences.dart';
import 'package:birthday_calendar/features/settings/data/settings_repository.dart';
import 'package:birthday_calendar/features/settings/presentation/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ, под которым настройки оформления лежат в AppSettings.
const String kThemeSettingsKey = 'theme_settings';

/// Загруженные настройки оформления.
final FutureProvider<ThemeSettings> themeSettingsProvider =
    FutureProvider<ThemeSettings>(
  (ref) async {
    final repository = ref.watch(settingsRepositoryProvider);
    return ThemeSettingsCodec.decode(await repository.read(kThemeSettingsKey));
  },
);

/// Применяет и сохраняет настройки оформления.
class ThemeController extends Notifier<ThemeSettings> {
  @override
  ThemeSettings build() => const ThemeSettings();

  /// Загружает сохранённые значения. Вызывается один раз при старте.
  Future<void> load() async {
    final repository = ref.read(settingsRepositoryProvider);
    state = ThemeSettingsCodec.decode(
      await repository.read(kThemeSettingsKey),
    );
  }

  Future<void> setMode(ThemeModePreference mode) =>
      _save(state.copyWith(mode: mode));

  Future<void> setAccent(AccentColor accent) =>
      _save(state.copyWith(accent: accent));

  /// Сохраняет произвольный seed-цвет и включает режим «Свой цвет».
  Future<void> setCustomColor(Color color) => _save(
        state.copyWith(
          accent: AccentColor.custom,
          customSeedColor: color.toARGB32(),
        ),
      );

  Future<void> _save(ThemeSettings next) async {
    state = next;
    await ThemeSettingsCodec.save(ref.read(settingsRepositoryProvider), next);
  }
}

final NotifierProvider<ThemeController, ThemeSettings> themeControllerProvider =
    NotifierProvider<ThemeController, ThemeSettings>(ThemeController.new);

/// Преобразование настроек оформления в формат базы.
abstract final class ThemeSettingsCodec {
  static ThemeSettings decode(String? raw) {
    if (raw == null || raw.isEmpty) return const ThemeSettings();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ThemeSettings(
        mode: ThemeModePreference.fromStored(map['mode'] as String?),
        accent: AccentColor.fromStored(map['accent'] as String?),
        customSeedColor: (map['customSeedColor'] as num?)?.toInt() ??
            ThemeSettings.defaultCustomSeedColor,
      );
    } catch (_) {
      // Повреждённые настройки не должны ломать запуск приложения.
      return const ThemeSettings();
    }
  }

  static String encode(ThemeSettings settings) {
    return jsonEncode({
      'mode': settings.mode.storedValue,
      'accent': settings.accent.storedValue,
      'customSeedColor': settings.customSeedColor,
    });
  }

  static Future<void> save(
    SettingsRepository repository,
    ThemeSettings settings,
  ) {
    return repository.write(kThemeSettingsKey, encode(settings));
  }
}

/// Преобразует режим в перечисление Flutter.
extension ThemeModePreferenceX on ThemeModePreference {
  ThemeMode get materialMode {
    return switch (this) {
      ThemeModePreference.system => ThemeMode.system,
      ThemeModePreference.light => ThemeMode.light,
      ThemeModePreference.dark => ThemeMode.dark,
      // AMOLED — это всегда тёмная схема, просто с чистым чёрным фоном.
      ThemeModePreference.amoled => ThemeMode.dark,
    };
  }
}
