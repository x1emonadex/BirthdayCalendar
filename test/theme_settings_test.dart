import 'package:birthday_calendar/core/theme/app_theme.dart';
import 'package:birthday_calendar/core/theme/theme_preferences.dart';
import 'package:birthday_calendar/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('разбор и сохранение режима', () {
    test('известные значения', () {
      expect(ThemeModePreference.fromStored('system'), ThemeModePreference.system);
      expect(ThemeModePreference.fromStored('light'), ThemeModePreference.light);
      expect(ThemeModePreference.fromStored('dark'), ThemeModePreference.dark);
      expect(ThemeModePreference.fromStored('amoled'), ThemeModePreference.amoled);
    });

    test('неизвестное и пустое значение даёт режим по умолчанию', () {
      expect(ThemeModePreference.fromStored(null), ThemeModePreference.system);
      expect(ThemeModePreference.fromStored('нечто'), ThemeModePreference.system);
    });

    test('AMOLED переживает круг сохранения', () {
      const settings = ThemeSettings(mode: ThemeModePreference.amoled);
      final decoded = ThemeSettingsCodec.decode(ThemeSettingsCodec.encode(settings));
      expect(decoded.mode, ThemeModePreference.amoled);
      expect(decoded, settings);
    });

    test('AMOLED в базе — это всегда тёмная схема Flutter', () {
      expect(ThemeModePreference.amoled.materialMode, ThemeMode.dark);
    });
  });

  group('поверхности AMOLED', () {
    final amoled = AppTheme.dark(amoled: true);
    final normal = AppTheme.dark();
    final scheme = amoled.colorScheme;

    test('фон чисто чёрный', () {
      expect(scheme.surface, AppTheme.amoledSurface);
      expect(scheme.surface.computeLuminance(), lessThan(0.01));
    });

    test('каждая следующая ступень светлее предыдущей', () {
      final steps = <Color>[
        scheme.surface,
        scheme.surfaceContainerLow,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ];
      for (var i = 1; i < steps.length; i++) {
        expect(
          steps[i].computeLuminance(),
          greaterThan(steps[i - 1].computeLuminance()),
          reason: 'ступень $i должна быть светлее предыдущей',
        );
      }
    });

    test('ступени различимы глазом, а не на процент', () {
      // Соседние ступени обязаны отличаться заметно: именно на этом держится
      // читаемость панелей на OLED.
      final surface = scheme.surface.computeLuminance();
      final card = scheme.surfaceContainerHigh.computeLuminance();
      expect(card - surface, greaterThan(0.004));
    });

    test('карточка и панель не проваливаются в фон', () {
      final card = amoled.cardTheme.color;
      expect(card, AppTheme.amoledSurfaceMid);
      expect(
        card!.computeLuminance(),
        greaterThan(scheme.surface.computeLuminance()),
      );
    });

    test('нижняя навигация и чипы отличаются от фона', () {
      expect(
        amoled.navigationBarTheme.backgroundColor,
        AppTheme.amoledSurfaceLow,
      );
      expect(amoled.chipTheme.backgroundColor, AppTheme.amoledSurfaceMid);
      expect(
        amoled.snackBarTheme.backgroundColor,
        AppTheme.amoledSurfaceHigh,
      );
    });

    test('обычная тёмная тема не трогается', () {
      expect(normal.cardTheme.color, isNull);
      expect(
        normal.colorScheme.surface,
        isNot(AppTheme.amoledSurface),
      );
    });

    test('светлая тема AMOLED-флаг не получает', () {
      final light = AppTheme.light();
      expect(light.brightness, Brightness.light);
      expect(light.colorScheme.surface, isNot(AppTheme.amoledSurface));
    });
  });

  group('акцент и контраст', () {
    test('текст на чёрном остаётся светлым', () {
      final scheme = AppTheme.dark(amoled: true).colorScheme;
      expect(
        scheme.onSurface.computeLuminance(),
        greaterThan(scheme.surface.computeLuminance() + 0.5),
      );
    });

    test('AMOLED строится из того же акцента, что и обычная тёмная', () {
      for (final accent in AccentColor.values) {
        expect(
          AppTheme.dark(accent: accent, amoled: true).colorScheme.primary,
          AppTheme.dark(accent: accent).colorScheme.primary,
          reason: accent.name,
        );
      }
    });

    test('произвольный цвет применяется и в AMOLED', () {
      const custom = 0xFF00A0B0;
      expect(
        AppTheme.dark(
          accent: AccentColor.custom,
          customSeedColor: custom,
          amoled: true,
        ).colorScheme.primary,
        AppTheme.dark(
          accent: AccentColor.custom,
          customSeedColor: custom,
        ).colorScheme.primary,
      );
    });
  });

  group('плашка-снэкбар читается', () {
    // Раньше цвет текста плашки жёстко брался из onSurface, а фон оставался
    // inverseSurface. В тёмной теме это светлое на светлом: плашка выходила
    // белой и пустой. Проверяем контраст для каждой темы.
    void check(ThemeData theme, String name) {
      final scheme = theme.colorScheme;
      final background =
          theme.snackBarTheme.backgroundColor ?? scheme.inverseSurface;
      final foreground = theme.snackBarTheme.contentTextStyle?.color ??
          scheme.onInverseSurface;
      expect(
        _contrastRatio(background, foreground),
        greaterThan(4.5),
        reason: '$name: текст не читается на фоне плашки',
      );
    }

    test('светлая тема', () => check(AppTheme.light(), 'светлая'));
    test('тёмная тема', () => check(AppTheme.dark(), 'тёмная'));
    test('AMOLED', () => check(AppTheme.dark(amoled: true), 'AMOLED'));
  });
}

/// Отношение контраста по WCAG: (L1 + 0.05) / (L2 + 0.05).
double _contrastRatio(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}
