import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_repository.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

/// Имя класса виджета из AndroidManifest.
const String kBirthdayWidgetProvider = 'BirthdayWidgetProvider';

/// Ключи, под которыми тексты лежат в общих настройках виджета.
const String kWidgetWhenKey = 'next_when';
const String kWidgetWhoKey = 'next_who';

/// Строка «когда» для виджета: «Сегодня день рождения», «Через 3 дня».
///
/// Чистая функция: тесты проверяют её напрямую, а виджет получает готовый
/// текст и не повторяет правила склонений на стороне Android.
String nextWhenLabel(int daysUntil) {
  if (daysUntil <= 0) return 'Сегодня день рождения';
  if (daysUntil == 1) return 'Завтра день рождения';
  return 'Через $daysUntil ${BirthdayDateUtils.pluralDays(daysUntil)}';
}

/// Строка «кто и когда»: «Иван, 15 сентября».
String nextWhoLabel(Birthday birthday, DateTime date) {
  return '${birthday.name}, ${DateFormat('d MMMM', 'ru').format(date)}';
}

/// Кладёт в виджет ближайший день рождения.
///
/// На платформах без виджета ничего не делает: вызывающий код не должен
/// обрастать проверками платформы.
Future<void> syncHomeWidget({
  required BirthdayRepository repository,
  required DateTime now,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  try {
    final items = await repository.list(
      query: BirthdayQuery(sort: BirthdaySort.upcoming, reference: now),
    );

    if (items.isEmpty) {
      await HomeWidget.saveWidgetData<String>(kWidgetWhenKey, 'Список пуст');
      await HomeWidget.saveWidgetData<String>(
        kWidgetWhoKey,
        'Добавьте дни рождения',
      );
    } else {
      final next = items.first;
      await HomeWidget.saveWidgetData<String>(
        kWidgetWhenKey,
        nextWhenLabel(next.occurrence.daysUntil),
      );
      await HomeWidget.saveWidgetData<String>(
        kWidgetWhoKey,
        nextWhoLabel(next.birthday, next.occurrence.date),
      );
    }

    await HomeWidget.updateWidget(
      name: kBirthdayWidgetProvider,
      androidName: kBirthdayWidgetProvider,
    );
  } catch (error) {
    // Виджет — украшение: без него приложение обязано работать.
    debugPrint('Не удалось обновить виджет: $error');
  }
}
