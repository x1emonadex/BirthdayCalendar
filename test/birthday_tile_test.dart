import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:birthday_calendar/features/birthdays/presentation/widgets/birthday_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Дата в списке должна быть русской. Без явной локали DateFormat берёт
/// системную ('en_US'), и месяц печатался как «September».
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  testWidgets('месяц в строке списка пишется по-русски', (tester) async {
    final stamp = DateTime(2026);
    final birthday = Birthday(
      id: '1',
      profileId: 'p',
      name: 'Иван',
      day: 15,
      month: 9,
      createdAt: stamp,
      updatedAt: stamp,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BirthdayTile(
            item: BirthdayWithOccurrence(
              birthday: birthday,
              occurrence: BirthdayOccurrence(
                date: DateTime(2026, 9, 15),
                daysUntil: 3,
                yearsSinceBirth: null,
              ),
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('сентября'), findsOneWidget);
    expect(find.textContaining('September'), findsNothing);
  });
}
