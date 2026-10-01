import 'package:birthday_calendar/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  // DateFormat с явной локалью ('ru') без этого вызова бросает
  // LocaleDataException. Инициализируем один раз на всё приложение.
  initializeDateFormatting('ru');

  runApp(const ProviderScope(child: BirthdayApp()));
}
