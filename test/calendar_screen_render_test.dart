import 'package:birthday_calendar/core/database/app_database.dart';
import 'package:birthday_calendar/core/providers/clock_provider.dart';
import 'package:birthday_calendar/core/providers/database_provider.dart';
import 'package:birthday_calendar/core/theme/app_theme.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_repository.dart';
import 'package:birthday_calendar/features/birthdays/presentation/widgets/birthday_avatar.dart';
import 'package:birthday_calendar/features/calendar/presentation/calendar_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// В календаре день с днём рождения отмечается фоном, а не кружком-«стикером»
/// под числом. Когда в один день несколько праздников, фон делится на доли —
/// по одной на человека. Кружок и аватар из сетки убраны.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    await initializeDateFormatting('ru');
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async => db.close());

  Widget app({ThemeData? theme}) => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 29))),
        ],
        child: MaterialApp(theme: theme, home: const CalendarScreen()),
      );

  /// Иван и Аня — на 15 сентября, Пётр — на 30 сентября.
  Future<void> seed() async {
    final repo = BirthdayRepository(db);
    await repo.create(name: 'Иван', day: 15, month: 9);
    await repo.create(name: 'Аня', day: 15, month: 9);
    await repo.create(name: 'Пётр', day: 30, month: 9);
  }

  /// Ячейка дня месяца (в месячном виде число дня встречается один раз).
  Finder cellOf(String dayText) => find
      .ancestor(of: find.text(dayText), matching: find.byType(Container))
      .first;

  /// Цвета долей фона внутри ячейки — по одному на человека.
  List<Color> segmentsIn(WidgetTester tester, Finder cell) {
    final boxes = tester.widgetList<ColoredBox>(
      find.descendant(of: cell, matching: find.byType(ColoredBox)),
    );
    return [for (final box in boxes) box.color];
  }

  /// Все непрозрачные доли фона на экране.
  List<Color> allSegments(WidgetTester tester) {
    final boxes = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
    return [for (final box in boxes) if (box.color.a > 0) box.color];
  }

  testWidgets('месячный вид делит фон дня по числу людей', (tester) async {
    await seed();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Два человека в один день — две доли.
    expect(segmentsIn(tester, cellOf('15')), hasLength(2));
    // Один человек — одна доля.
    expect(segmentsIn(tester, cellOf('30')), hasLength(1));
    // День без дней рождения остаётся без заливки.
    expect(segmentsIn(tester, cellOf('14')), isEmpty);

    // Доли должны быть видимы, а не просто присутствовать в дереве.
    final segments = find.descendant(
      of: cellOf('15'),
      matching: find.byType(ColoredBox),
    );
    expect(segments, findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      final size = tester.getSize(segments.at(i));
      expect(size.width, greaterThan(0), reason: 'доля $i шириной ноль');
      expect(size.height, greaterThan(0), reason: 'доля $i высотой ноль');
    }
  });

  testWidgets('в ячейке дня нет кружка и аватара', (tester) async {
    await seed();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: cellOf('15'),
        matching: find.byType(BirthdayAvatar),
      ),
      findsNothing,
    );
  });

  testWidgets('годовой вид делит фон дней по числу людей', (tester) async {
    await seed();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_view_month));
    await tester.pumpAndSettle();

    // 15 сентября — две доли, 30 сентября — одна; итого три.
    expect(allSegments(tester), hasLength(3));
    // Аватаров в сетке года нет вовсе.
    expect(find.byType(BirthdayAvatar), findsNothing);
  });

  testWidgets('на AMOLED доли отличимы от чёрного фона', (tester) async {
    await seed();
    await tester.pumpWidget(app(theme: AppTheme.dark(amoled: true)));
    await tester.pumpAndSettle();

    final segments = segmentsIn(tester, cellOf('15'));
    expect(segments, hasLength(2));
    for (final color in segments) {
      expect(color.a, 1.0);
      expect(
        color.computeLuminance(),
        greaterThan(0.01),
        reason: 'доля не должна сливаться с чёрным фоном',
      );
    }
  });

  testWidgets('свайп влево и вправо листает месяцы', (tester) async {
    await seed();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Открывается сентябрь 2026.
    expect(find.textContaining('сент'), findsOneWidget);

    await tester.fling(
      find.byType(CalendarScreen),
      const Offset(-300, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('окт'), findsOneWidget);

    await tester.fling(
      find.byType(CalendarScreen),
      const Offset(300, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('сент'), findsOneWidget);
  });

  testWidgets('выбор года открывается на текущем годе', (tester) async {
    await seed();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Годовой вид → нажимаем на заголовок с годом.
    await tester.tap(find.byIcon(Icons.calendar_view_month));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026'));
    await tester.pumpAndSettle();

    expect(find.text('Выберите год'), findsOneWidget);
    // Текущий год виден сразу, без прокрутки на сотню строк.
    expect(find.widgetWithText(ListTile, '2026'), findsOneWidget);
    // А начало диапазона в списке даже не построено.
    expect(find.widgetWithText(ListTile, '1926'), findsNothing);
  });
}
