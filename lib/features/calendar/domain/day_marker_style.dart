/// Правила рисования кружка дня рождения в календаре.
///
/// Вынесены отдельно от виджета: это чистая логика, её стоит тестировать.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Зазор между секторами круга — доля оборота.
///
/// У одного праздника зазора быть не должно: круг с вырезом читался как
/// «пакман», и буква попадала прямо в этот вырез. Зазор появляется только
/// когда секторов больше одного, то есть когда круг действительно делится.
double pieGapFor(int total) {
  if (total <= 1) return 0;
  return 0.04;
}

/// Первая буква имени для подписи в кружке: «Аня» → «А».
String markerInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

/// Нужна ли подсказка-подложка под буквой.
///
/// У одноцветного круга буква просто контрастна к его цвету. У разделённого
/// под центром может оказаться граница секторов, и цвет первого сектора
/// давал бы нечитаемую надпись. Поэтому под буквой рисуется маленький
/// одноцветный круг контрастного цвета.
bool needsInitialBacking(int total) => total > 1;

/// Показывать ли букву при таком диаметре.
///
/// Ниже порога подпись сливается с числом дня.
bool showsInitial(double diameter, int total) {
  if (total == 0) return false;
  return diameter >= minDiameterForInitial;
}

/// Минимальный диаметр, на котором букву ещё можно прочесть.
const double minDiameterForInitial = 12;

/// Цвет буквы: белый на тёмном круге, тёмный на светлом.
Color initialColorOn(Color background) {
  return background.computeLuminance() > 0.55
      ? const Color(0xFF1A1A1A)
      : Colors.white;
}

/// Диаметр подложки под буквой.
///
/// Подложка заметно меньше круга, но не меньше самой буквы, иначе кисти
/// обрезают её края.
double backingDiameterFor(double diameter) => diameter * 0.62;

/// Цвет подложки под буквой в разделённом круге.
///
/// Нейтральный: на тёмной теме это почти чёрный, на светлой — белый. Свой
/// цвет круга не годится — соседние сектора слились бы с подложкой.
Color backingColor(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFF1A1A1A)
      : Colors.white;
}

/// Диаметр кружка под числом дня в годовом виде.
///
/// Ячейка там мелкая, и фиксированный круг либо наезжал на число, либо
/// превращался в точку. Поэтому круг вписывается в то, что реально осталось
/// под числом, но не шире самой ячейки.
double markerDiameterFor({
  required double cellWidth,
  required double cellHeight,
  double numberHeight = 13,
}) {
  // Под числом остаётся всё, кроме его высоты и небольшого зазора.
  final below = cellHeight - numberHeight - 1;
  if (below <= 0 || cellWidth <= 0) return 0;
  return markerDiameterClamp(
    math.min(cellWidth, below) * 0.88,
  );
}

/// Границы размера кружка: меньше десяти он не читается как круг, больше
/// шестнадцати — уже мешает соседним дням в плотной сетке.
double markerDiameterClamp(double diameter) {
  return diameter.clamp(minDiameter, maxDiameter).toDouble();
}

/// Минимальный читаемый диаметр кружка.
const double minDiameter = 10;

/// Максимальный диаметр кружка в сетке дня.
const double maxDiameter = 16;
