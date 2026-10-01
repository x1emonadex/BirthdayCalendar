import 'package:birthday_calendar/features/birthdays/data/avatar_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('цвет новой записи', () {
    test('берётся из палитры', () {
      for (var i = 0; i < 30; i++) {
        expect(AvatarColor.palette, contains(AvatarColor.random()));
      }
    });

    test('цвета различимы между собой', () {
      expect(
        AvatarColor.palette.toSet().length,
        AvatarColor.palette.length,
        reason: 'повторов в палитре быть не должно',
      );
    });

    test('не слишком тёмные и не слишком светлые', () {
      // Слишком тёмный круг не виден на чёрном фоне календаря,
      // слишком светлый не читается с белой подписью внутри.
      for (final value in AvatarColor.palette) {
        final color = Color(value);
        expect(color.computeLuminance(), greaterThan(0.12));
        expect(color.computeLuminance(), lessThan(0.75));
      }
    });

    test('на всех цветах есть контрастная подпись', () {
      for (final value in AvatarColor.palette) {
        final color = Color(value);
        final foreground = color.computeLuminance() > 0.55
            ? const Color(0xFF1A1A1A)
            : Colors.white;
        expect(
          (color.computeLuminance() - foreground.computeLuminance()).abs(),
          greaterThan(0.25),
          reason: 'подпись не читается на $value',
        );
      }
    });

    test('выдаётся не один и тот же цвет подряд', () {
      final drawn = <int>{};
      for (var i = 0; i < 60; i++) {
        drawn.add(AvatarColor.random());
      }
      expect(drawn.length, greaterThan(1), reason: 'цвет обязан меняться');
    });
  });
}
