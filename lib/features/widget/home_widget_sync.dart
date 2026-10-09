import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_repository.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

/// Имя класса виджета из AndroidManifest.
const String kBirthdayWidgetProvider = 'BirthdayWidgetProvider';

/// Ключи, под которыми тексты лежат в общих настройках виджета.
const String kWidgetTitleKey = 'widget_title';
const String kWidgetLineKeyPrefix = 'widget_line_';

/// Сколько строк с ближайшими датами отдаём виджету.
///
/// Пять — по числу строк в разметке виджета. Сколько из них показать, решает
/// настройка виджета на стороне Android, поэтому данные готовим на все.
const int kWidgetMaxLines = 5;

/// Подпись даты в виджете: «Сегодня», «Завтра» или «15 сентября».
///
/// Сегодня и завтра важнее числа, а дальше число понятнее срока: «через 45
/// дней» ничего не говорит о том, когда это.
String widgetDateLabel(BirthdayOccurrence occurrence) {
  if (occurrence.daysUntil == 0) return 'Сегодня';
  if (occurrence.daysUntil == 1) return 'Завтра';
  return DateFormat('d MMMM', 'ru').format(occurrence.date);
}

/// Строки виджета: ближайшие даты и кто в них.
///
/// Дни рождения, выпавшие на одну дату, собираются в одну строку: иначе три
/// строки виджета занял бы один и тот же день с разными именами, а остальные
/// даты не поместились бы.
List<String> nextBirthdayLines(
  List<BirthdayWithOccurrence> items, {
  int maxLines = kWidgetMaxLines,
}) {
  final keys = <String>[];
  final labels = <String>[];
  final names = <List<String>>[];

  for (final item in items) {
    final date = item.occurrence.date;
    final key = '${date.year}-${date.month}-${date.day}';
    var index = keys.indexOf(key);

    if (index < 0) {
      if (keys.length >= maxLines) break;
      keys.add(key);
      labels.add(widgetDateLabel(item.occurrence));
      names.add(<String>[]);
      index = keys.length - 1;
    }
    names[index].add(item.birthday.name);
  }

  return [
    for (var i = 0; i < labels.length; i++)
      '${labels[i]}: ${names[i].join(', ')}',
  ];
}

/// Кладёт в виджет ближайшие дни рождения.
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

    final lines = items.isEmpty
        ? const ['Список пуст', 'Добавьте записи']
        : nextBirthdayLines(items);

    await HomeWidget.saveWidgetData<String>(
      kWidgetTitleKey,
      items.isEmpty ? 'Дни рождения' : 'Ближайшие дни рождения',
    );
    for (var i = 0; i < kWidgetMaxLines; i++) {
      await HomeWidget.saveWidgetData<String>(
        '$kWidgetLineKeyPrefix${i + 1}',
        i < lines.length ? lines[i] : '',
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
