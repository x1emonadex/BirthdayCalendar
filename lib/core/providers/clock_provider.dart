import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Источник текущего времени.
///
/// Позволяет подменять «сейчас» в тестах, не завися от системных часов.
class Clock {
  const Clock();

  DateTime now() => DateTime.now();
}

/// Часы, которые всегда возвращают одну и ту же дату.
///
/// Используются в тестах для детерминированной проверки группировки и сортировки.
class FixedClock implements Clock {
  const FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

final Provider<Clock> clockProvider = Provider<Clock>((ref) => const Clock());
