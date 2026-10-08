import 'dart:math' as math;

import 'package:birthday_calendar/features/calendar/domain/day_marker_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Заливка дня с днём рождения', () {
    const surfaceLight = Color(0xFFFEF7FF);
    const surfaceDark = Color(0xFF000000);
    const birthdayColor = Color(0xFFE57373);

    test('заливка непрозрачна — на AMOLED полупрозрачный слой пропадёт', () {
      for (final brightness in Brightness.values) {
        final tint = dayCellTint(
          birthdayColor: birthdayColor,
          surface: brightness == Brightness.dark ? surfaceDark : surfaceLight,
          brightness: brightness,
        );
        expect(tint.a, 1.0, reason: '$brightness');
      }
    });

    test('день отличается от фона и в светлой, и в тёмной теме', () {
      for (final brightness in Brightness.values) {
        final surface =
            brightness == Brightness.dark ? surfaceDark : surfaceLight;
        final tint = dayCellTint(
          birthdayColor: birthdayColor,
          surface: surface,
          brightness: brightness,
        );
        expect(tint, isNot(surface), reason: '$brightness');
        expect(
          (tint.computeLuminance() - surface.computeLuminance()).abs(),
          greaterThan(0.01),
          reason: '$brightness',
        );
      }
    });

    test('заливка сдвинута от фона в сторону цвета записи', () {
      final tint = dayCellTint(
        birthdayColor: birthdayColor,
        surface: surfaceLight,
        brightness: Brightness.light,
      );
      // Смесь лежит между фоном и цветом записи, поэтому она ближе к цвету
      // записи, чем сам фон: иначе заливка ничего не сообщала бы.
      expect(
        _distance(tint, birthdayColor),
        lessThan(_distance(surfaceLight, birthdayColor)),
      );
    });

    test('на тёмном фоне цвет записи вносится сильнее', () {
      final light = dayCellTint(
        birthdayColor: birthdayColor,
        surface: surfaceLight,
        brightness: Brightness.light,
      );
      final dark = dayCellTint(
        birthdayColor: birthdayColor,
        surface: surfaceDark,
        brightness: Brightness.dark,
      );
      expect(
        _distance(dark, surfaceDark),
        greaterThan(_distance(light, surfaceLight)),
      );
    });
  });
}

/// Евклидово расстояние между цветами в каналах RGB.
double _distance(Color a, Color b) {
  final dr = (a.r - b.r) * 255;
  final dg = (a.g - b.g) * 255;
  final db = (a.b - b.b) * 255;
  return math.sqrt(dr * dr + dg * dg + db * db);
}
