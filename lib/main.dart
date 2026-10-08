import 'package:birthday_calendar/app.dart';
import 'package:birthday_calendar/features/notifications/data/notification_refresh_task.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  // Плагины, в том числе фоновая задача, требуют готового движка.
  WidgetsFlutterBinding.ensureInitialized();

  // DateFormat с явной локалью ('ru') без этого вызова бросает
  // LocaleDataException. Инициализируем один раз на всё приложение.
  initializeDateFormatting('ru');

  // Периодическая задача пересчитывает расписание уведомлений, пока
  // приложение закрыто. Планировщик работы в фоне есть только на Android,
  // поэтому на остальных платформах задачу не ставим.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await registerNotificationRefreshTask();
    } catch (error) {
      debugPrint('Не удалось поставить фоновую задачу: $error');
    }
  }

  runApp(const ProviderScope(child: BirthdayApp()));
}
