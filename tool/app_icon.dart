import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Иконка приложения: календарь с обведённым днём и тортом.
///
/// Рисуется кодом, а не лежит картинкой: так её можно пересобрать под любой
/// размер и поправить одним изменением, а не перерисовывать в редакторе.
/// Запуск: flutter test tool/app_icon.dart — файл пишет готовые PNG прямо в
/// android/app/src/main/res.
class AppIconPainter extends CustomPainter {
  const AppIconPainter({this.adaptive = false, this.circleRow = 1});

  /// `true` — слой переднего плана адаптивной иконки. Лаунчер обрезает её по
  /// своей форме, поэтому рисунок вписывается в безопасную зону и получается
  /// мельче, чем в обычной иконке.
  final bool adaptive;

  /// В каком ряду сетки обведён день: 0 — верхний, 1 — средний.
  final int circleRow;

  static const Color _card = Color(0xFFFFFFFF);
  static const Color _cardEdge = Color(0xFFDCDCE8);
  static const Color _header = Color(0xFF8B7BF0);
  static const Color _cell = Color(0xFFA9B2F0);
  static const Color _circle = Color(0xFFFF4D6D);
  static const Color _tier = Color(0xFFFF7C87);
  static const Color _icing = Color(0xFFFFF0DA);
  static const Color _candle = Color(0xFFFFC24B);
  static const Color _wick = Color(0xFF6B4E2E);
  static const Color _flame = Color(0xFFFF8A3D);

  /// Клетка сетки, зазор и её скругление.
  ///
  /// Зазор шире клетки не для красоты: кружок вокруг дня — окружность,
  /// описанная вокруг квадрата, её диаметр в 1.4 раза больше стороны, и при
  /// плотной сетке он неизбежно налезал бы на соседние дни.
  static const double _cellSize = 0.105;
  static const double _gap = 0.045;
  static const double _cellRadius = 0.03;

  @override
  void paint(Canvas canvas, Size size) {
    // Фона нет: подложку не рисуем вовсе, вокруг календаря прозрачно.
    final content = size.shortestSide * (adaptive ? 0.74 : 0.98);
    final left = (size.width - content) / 2;
    final top = (size.height - content) / 2;
    double x(double v) => left + content * v;
    double y(double v) => top + content * v;
    double s(double v) => content * v;

    _calendar(canvas, x, y, s);
    _cake(canvas, x, y, s);
  }

  void _calendar(
    Canvas canvas,
    double Function(double) x,
    double Function(double) y,
    double Function(double) s,
  ) {
    final card = RRect.fromRectAndRadius(
      Rect.fromLTRB(x(0.12), y(0.20), x(0.88), y(0.87)),
      Radius.circular(s(0.085)),
    );

    // Кольца рисуем первыми: они должны уходить под шапку, а не лежать на ней.
    for (final cx in [0.29, 0.43, 0.57, 0.71]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x(cx - 0.012), y(0.13), x(cx + 0.012), y(0.245)),
          Radius.circular(s(0.012)),
        ),
        Paint()..color = _card,
      );
    }

    canvas.drawRRect(card, Paint()..color = _card);

    // Волосяная обводка: без неё на светлых обоях белая карточка пропадает —
    // белое на белом — и от иконки остаются одни квадратики.
    canvas.drawRRect(
      card,
      Paint()
        ..color = _cardEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = s(0.008),
    );

    canvas.save();
    canvas.clipRRect(card);
    canvas.drawRect(
      Rect.fromLTRB(x(0.12), y(0.20), x(0.88), y(0.315)),
      Paint()..color = _header,
    );
    canvas.restore();

    const gridLeft = 0.16;
    const gridTop = 0.39;

    Rect cellRect(int row, int col) => Rect.fromLTWH(
      x(gridLeft + col * (_cellSize + _gap)),
      y(gridTop + row * (_cellSize + _gap)),
      s(_cellSize),
      s(_cellSize),
    );

    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            cellRect(row, col),
            Radius.circular(s(_cellRadius)),
          ),
          Paint()..color = _cell,
        );
      }
    }

    // Обведён один день — как обводят дату в бумажном календаре.
    final target = cellRect(circleRow, 1);
    // Овал должен накрыть клетку целиком вместе с её скруглёнными углами:
    // при вытянутом по горизонтали овале для этого нужен запас побольше.
    const radius = _cellSize * 0.7071 - _cellRadius * (1.4142 - 1) + 0.0117;
    canvas.drawPath(
      _handDrawnCircle(target.center, s(radius)),
      Paint()
        ..color = _circle
        ..style = PaintingStyle.stroke
        ..strokeWidth = s(0.017)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Кружок «от руки»: вытянутый по горизонтали овал с нахлёстом вверху —
  /// конец штриха заходит внутрь и не смыкается с началом.
  Path _handDrawnCircle(Offset center, double radius) {
    const segments = 80;
    // Штрих начинается слева сверху, идёт по часовой и заходит за начало.
    const startAngle = -1.95;
    const sweep = 6.283185307179586 + 0.32;
    final path = Path();

    for (var i = 0; i <= segments; i++) {
      final t = startAngle + sweep * i / segments;
      // Две волны разной частоты: одной мало — линия выглядит вычерченной
      // циркулем, тремя — уже каракулями.
      final wobble =
          1 + 0.025 * math.sin(3 * t + 0.8) + 0.015 * math.sin(7 * t + 1.6);
      final rr = radius * wobble;
      final point = Offset(
        center.dx + rr * math.cos(t) * 1.08,
        center.dy + rr * math.sin(t) * 0.94,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }

  /// Торт: два яруса с волнистой глазурью, свеча с фитилём и пламя.
  void _cake(
    Canvas canvas,
    double Function(double) x,
    double Function(double) y,
    double Function(double) s,
  ) {
    Rect r(double l, double t, double right, double bottom) =>
        Rect.fromLTRB(x(l), y(t), x(right), y(bottom));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        r(0.60, 0.765, 0.86, 0.805),
        Radius.circular(s(0.018)),
      ),
      Paint()..color = _card,
    );

    final tiers = [
      r(0.66, 0.585, 0.80, 0.67),
      r(0.625, 0.665, 0.835, 0.77),
    ];
    final radii = [0.014, 0.016];

    for (var i = 0; i < tiers.length; i++) {
      final rect = tiers[i];
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(s(radii[i])));
      canvas.drawRRect(rrect, Paint()..color = _tier);

      // Волнистая кромка глазури: без неё ярус читается бруском.
      final icingHeight = rect.height * 0.34;
      const drops = 2;
      final path = Path()
        ..moveTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.top + icingHeight);

      final step = rect.width / drops;
      for (var d = drops - 1; d >= 0; d--) {
        final x2 = rect.left + step * (d + 1);
        final x1 = rect.left + step * d;
        path.quadraticBezierTo(
          (x1 + x2) / 2,
          rect.top + icingHeight * 2.2,
          x1,
          rect.top + icingHeight,
        );
      }
      path.close();

      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawPath(path, Paint()..color = _icing);
      canvas.restore();
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        r(0.722, 0.535, 0.738, 0.59),
        Radius.circular(s(0.007)),
      ),
      Paint()..color = _candle,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        r(0.726, 0.526, 0.734, 0.54),
        Radius.circular(s(0.004)),
      ),
      Paint()..color = _wick,
    );

    final flame = r(0.714, 0.478, 0.746, 0.534);
    canvas.drawPath(
      _flamePath(flame.center.dx, flame.top, flame.width / 2, flame.height),
      Paint()..color = _flame,
    );
  }

  /// Пламя: острие сверху, низ скруглён — не треугольник.
  Path _flamePath(double cx, double top, double halfWidth, double height) {
    return Path()
      ..moveTo(cx, top)
      ..cubicTo(
        cx + halfWidth,
        top + height * 0.35,
        cx + halfWidth * 0.95,
        top + height,
        cx,
        top + height,
      )
      ..cubicTo(
        cx - halfWidth * 0.95,
        top + height,
        cx - halfWidth,
        top + height * 0.35,
        cx,
        top,
      )
      ..close();
  }

  @override
  bool shouldRepaint(AppIconPainter oldDelegate) =>
      oldDelegate.adaptive != adaptive || oldDelegate.circleRow != circleRow;
}

Future<void> _write(String path, int size, {required bool adaptive}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  AppIconPainter(adaptive: adaptive).paint(
    canvas,
    Size(size.toDouble(), size.toDouble()),
  );
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(data!.buffer.asUint8List());
  // ignore: avoid_print
  print('WROTE $path');
}

void main() {
  const res = r'E:\BirthdayCalendar\birthday_calendar\android\app\src\main\res';
  const scratch = r'C:\Users\Admin\AppData\Local\hermes\cache\scratch';

  test('рисует иконки приложения', () async {
    // Обычная иконка: её показывают версии Android до 8.
    const legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final entry in legacy.entries) {
      await _write(
        '$res\\mipmap-${entry.key}\\ic_launcher.png',
        entry.value,
        adaptive: false,
      );
    }

    // Передний план адаптивной иконки: 108dp холста, из них видно 72dp.
    const adaptive = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432};
    for (final entry in adaptive.entries) {
      await _write(
        '$res\\mipmap-${entry.key}\\ic_launcher_foreground.png',
        entry.value,
        adaptive: true,
      );
    }

    // Крупная копия — посмотреть глазами.
    await _write('$scratch\\app_icon_512.png', 512, adaptive: false);
  });
}
