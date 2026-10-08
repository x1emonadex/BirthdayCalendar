import 'package:birthday_calendar/core/database/app_database.dart';
import 'package:birthday_calendar/core/providers/clock_provider.dart';
import 'package:birthday_calendar/core/providers/database_provider.dart';
import 'package:birthday_calendar/core/theme/app_theme.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_repository.dart';
import 'package:birthday_calendar/features/calendar/presentation/calendar_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// День с днём рождения обязан быть виден в сетке цветом, а не только
/// кружком под числом: на это жаловались в годовом виде, где заливка была
/// нейтральной ступенью и месяц выглядел пустым.
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

  /// Две записи в сентябре 2026: 15-го и 30-го.
  Future<void> seed() async {
    final repo = BirthdayRepository(db);
    await repo.create(name: 'Иван', day: 15, month: 9);
    await repo.create(name: 'Аня', day: 30, month: 9);
  }

  /// Цвета заливки всех ячеек-`Container` без прозрачных.
  List<Color> tintedCells(WidgetTester tester) {
    final result = <Color>[];
    for (final container in tester.widgetList<Container>(
      find.byType(Container),
    )) {
      final decoration = container.decoration;
      if (decoration is BoxDecoration &&
          decoration.color != null &&
          decoration.color != Colors.transparent) {
        result.add(decoration.color!);
      }
    }
    return result;
  }

  /// Цвет заливки конкретного дня месяца (по числу в сетке).
  Color? dayTint(WidgetTester tester, String dayText) {
    final containers = tester.widgetList<Container>(
      find.ancestor(of: find.text(dayText), matching: find.byType(Container)),
    );
    for (final container in containers) {
      final decoration = container.decoration;
      if (decoration is BoxDecoration && decoration.color != null) {
        return decoration.color;
      }
    }
    return null;
  }

  testWidgets('месячный вид заливает дни с днями рождения', (tester) async {
    await seed();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final scheme =
        Theme.of(tester.element(find.byType(CalendarScreen))).colorScheme;

    expect(dayTint(tester, '15'), isNotNull);
    expect(dayTint(tester, '15'), isNot(scheme.surface));
    expect(dayTint(tester, '30'), isNotNull);
    // Пустой день остаётся без заливки.
    expect(dayTint(tester, '14'), isNull);
  });

  testWidgets('годовой вид заливает дни с днями рождения цветом',
      (tester) async {
    await seed();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Переключаемся на год.
    await tester.tap(find.byIcon(Icons.calendar_view_month));
    await tester.pumpAndSettle();

    // Ровно две залитые ячейки: 15 и 30 сентября.
    expect(tintedCells(tester), hasLength(2));
  });

  testWidgets('на AMOLED заливка отличима от чёрного фона', (tester) async {
    await seed();
    await tester.pumpWidget(app(theme: AppTheme.dark(amoled: true)));
    await tester.pumpAndSettle();

    final tints = tintedCells(tester);
    expect(tints, hasLength(2));
    for (final tint in tints) {
      expect(
        tint.computeLuminance(),
        greaterThan(0.01),
        reason: 'заливка не должна сливаться с чёрным фоном',
      );
    }
  });
}
