import 'package:birthday_calendar/features/calendar/domain/day_marker_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Зазор между секторами', () {
    test('у одного праздника зазора нет — круг без выреза', () {
      expect(pieGapFor(1), 0);
    });

    test('у двух и больше секторов зазор появляется', () {
      expect(pieGapFor(2), greaterThan(0));
      expect(pieGapFor(5), greaterThan(0));
    });

    test('зазор всегда меньше доли сектора, иначе доли не видно', () {
      for (var total = 2; total <= 12; total++) {
        expect(pieGapFor(total), lessThan(1 / total));
      }
    });
  });

  group('Подпись в кружке', () {
    test('берёт первую букву имени', () {
      expect(markerInitial('Аня'), 'А');
      expect(markerInitial('  лена '), 'Л');
    });

    test('пустое имя не даёт подписи', () {
      expect(markerInitial(''), '');
      expect(markerInitial('   '), '');
    });

    test('на мелком кружке буквы нет', () {
      expect(showsInitial(8, 1), isFalse);
    });

    test('на кружке достаточного размера буква есть', () {
      expect(showsInitial(minDiameterForInitial, 1), isTrue);
      expect(showsInitial(20, 3), isTrue);
    });

    test('без дней рождения буквы нет', () {
      expect(showsInitial(40, 0), isFalse);
    });
  });

  group('Подложка под букву', () {
    test('одноцветный круг обходится без подложки', () {
      expect(needsInitialBacking(1), isFalse);
    });

    test('разделённому кругу подложка нужна', () {
      expect(needsInitialBacking(2), isTrue);
    });

    test('подложка меньше круга, но не меньше половины', () {
      expect(backingDiameterFor(20), lessThan(20));
      expect(backingDiameterFor(20), greaterThan(10));
    });
  });

  group('Цвет подписи', () {
    test('на светлом круге тёмная буква', () {
      expect(initialColorOn(Colors.white), const Color(0xFF1A1A1A));
    });

    test('на тёмном круге светлая буква', () {
      expect(initialColorOn(Colors.black), Colors.white);
    });
  });

  group('Размер кружка в годовом виде', () {
    test('вписывается в ячейку и не наезжает на число', () {
      const cellWidth = 30.0;
      const cellHeight = 30.0;
      final diameter = markerDiameterFor(
        cellWidth: cellWidth,
        cellHeight: cellHeight,
      );
      expect(diameter, lessThanOrEqualTo(cellWidth));
      expect(diameter + 14, lessThanOrEqualTo(cellHeight));
    });

    test('в тесной ячейке остаётся читаемый минимум', () {
      final diameter = markerDiameterFor(cellWidth: 12, cellHeight: 15);
      expect(diameter, greaterThanOrEqualTo(minDiameter));
    });

    test('в просторной ячейке не разрастается', () {
      final diameter = markerDiameterFor(cellWidth: 200, cellHeight: 200);
      expect(diameter, lessThanOrEqualTo(maxDiameter));
    });

    test('в ячейке без места под кружок кружка нет', () {
      expect(markerDiameterFor(cellWidth: 30, cellHeight: 13), 0);
    });

    test('узкая ячейка ограничивает кружок своей шириной', () {
      final diameter = markerDiameterFor(cellWidth: 11, cellHeight: 40);
      expect(diameter, lessThanOrEqualTo(11));
    });
  });
}
