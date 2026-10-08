import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:birthday_calendar/features/birthdays/presentation/widgets/birthday_avatar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Строка списка с именем, датой и расстоянием до праздника.
class BirthdayTile extends StatelessWidget {
  const BirthdayTile({
    required this.item,
    required this.onTap,
    super.key,
  });

  final BirthdayWithOccurrence item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final birthday = item.birthday;
    final occurrence = item.occurrence;
    // Локаль указываем явно: без неё DateFormat берёт системную ('en_US'),
    // и месяц печатается по-английски — «15 September» вместо «15 сентября».
    final dateLabel = DateFormat('d MMMM', 'ru').format(occurrence.date);

    return ListTile(
      onTap: onTap,
      leading: BirthdayAvatar(birthday: birthday),
      title: Row(
        children: [
          Flexible(
            child: Text(
              birthday.name,
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (birthday.isImportant) ...[
            const SizedBox(width: 6),
            Icon(Icons.star, size: 18, color: theme.colorScheme.primary),
          ],
        ],
      ),
      subtitle: Text(
        [
          dateLabel,
          if (occurrence.yearsSinceBirth != null)
            '${occurrence.yearsSinceBirth} '
                '${BirthdayDateUtils.pluralYears(occurrence.yearsSinceBirth!)}',
        ].join(' · '),
      ),
      trailing: _DistanceLabel(days: occurrence.daysUntil),
    );
  }
}

class _DistanceLabel extends StatelessWidget {
  const _DistanceLabel({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (days == 0) {
      return Chip(
        label: const Text('Сегодня'),
        labelStyle: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
        backgroundColor: theme.colorScheme.primaryContainer,
        visualDensity: VisualDensity.compact,
      );
    }

    if (days == 1) {
      return Text(
        'Завтра',
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      );
    }

    return Text(
      '$days ${BirthdayDateUtils.pluralDays(days)}',
      style: theme.textTheme.titleSmall,
    );
  }
}
