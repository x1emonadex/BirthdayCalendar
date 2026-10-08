import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Иконка приложения: торт со свечой на фиолетовом фоне.
///
/// Рисуется кодом, а не лежит картинкой: так её можно пересобрать под любой
/// размер и поправить одним изменением, а не перерисовывать в редакторе.
class AppIconPainter extends CustomPainter {
  const AppIconPainter({this.adaptive = false});

  /// `true` — слой переднего плана адаптивной иконки: без фона и с отступом
  /// под обрезку. Безопасная зона адаптивной иконки — центральные 72 из 108,
  /// поэтому рисунок занимает две трети канвы.
  final bool adaptive;

  static const List<Color> _background = [
    Color(0xFF8B6CFF),
    Color(0xFF5B2FD6),
  ];
  static const Color _tier = Color(0xFFFFFFFF);
  static const Color _icing = Color(0xFFDCD0FF);
  static const Color _candle = Color(0xFFFFD98A);
  static const Color _wick = Color(0xFF6B4E2E);
  static const Color _flameOuter = Color(0xFFFF8A3D);
  static const Color _flameInner = Color(0xFFFFD166);

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    if (!adaptive) {
      canvas.drawRect(
        full,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _background,
          ).createShader(full),
      );
    }

    final content = size.shortestSide * (adaptive ? 0.66 : 0.84);
    final left = (size.width - content) / 2;
    final top = (size.height - content) / 2;

    double x(double v) => left + content * v;
    double y(double v) => top + content * v;
    double s(double v) => content * v;

    // Пламя: острие сверху, низ скруглён. Треугольник получался, когда обе
    // стороны сходились в точку и снизу.
    canvas.drawPath(
      _flame(x(0.5), y(0.06), s(0.075), s(0.215)),
      Paint()..color = _flameOuter,
    );
    canvas.drawPath(
      _flame(x(0.5), y(0.13), s(0.035), s(0.115)),
      Paint()..color = _flameInner,
    );

    // Фитиль — короткая тёмная чёрточка между свечой и пламенем.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x(0.494), y(0.255), x(0.506), y(0.305)),
        Radius.circular(s(0.006)),
      ),
      Paint()..color = _wick,
    );

    // Свеча — узкая и высокая: с широкой короткой свечой пламя казалось
    // непропорционально большим.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x(0.468), y(0.30), x(0.532), y(0.52)),
        Radius.circular(s(0.018)),
      ),
      Paint()..color = _candle,
    );

    // Ярусы торта: нижний шире верхнего, между ними просвет — иначе они
    // сливаются в один белый прямоугольник.
    _drawTier(
      canvas,
      Rect.fromLTRB(x(0.30), y(0.53), x(0.70), y(0.68)),
      s(0.03),
    );
    _drawTier(
      canvas,
      Rect.fromLTRB(x(0.19), y(0.70), x(0.81), y(0.90)),
      s(0.035),
    );
  }

  /// Пламя: острие сверху, низ скруглён.
  Path _flame(double cx, double top, double halfWidth, double height) {
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

  void _drawTier(Canvas canvas, Rect rect, double radius) {
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rrect, Paint()..color = _tier);

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.3),
      Paint()..color = _icing,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(AppIconPainter oldDelegate) =>
      oldDelegate.adaptive != adaptive;
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
  const res =
      r'E:\BirthdayCalendar\birthday_calendar\android\app\src\main\res';
  const scratch = r'C:\Users\Admin\AppData\Local\hermes\cache\scratch';

  test('рисует иконки приложения', () async {
    const legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    const adaptive = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432};

    for (final entry in legacy.entries) {
      await _write(
        '$res\\mipmap-${entry.key}\\ic_launcher.png',
        entry.value,
        adaptive: false,
      );
    }
    for (final entry in adaptive.entries) {
      await _write(
        '$res\\mipmap-${entry.key}\\ic_launcher_foreground.png',
        entry.value,
        adaptive: true,
      );
    }

    // Крупные копии — посмотреть глазами.
    await _write('$scratch\\icon_full_512.png', 512, adaptive: false);
    await _write('$scratch\\icon_fg_512.png', 512, adaptive: true);
  });
}
