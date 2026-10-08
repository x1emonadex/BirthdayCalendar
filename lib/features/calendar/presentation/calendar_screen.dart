import 'package:birthday_calendar/core/providers/clock_provider.dart';
import 'package:birthday_calendar/core/routing/app_router.dart';
import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';
import 'package:birthday_calendar/core/utils/leap_day_rule.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:birthday_calendar/features/birthdays/presentation/providers/birthday_list_providers.dart';
import 'package:birthday_calendar/features/birthdays/presentation/widgets/birthday_avatar.dart';
import 'package:birthday_calendar/features/calendar/domain/calendar_month.dart';
import 'package:birthday_calendar/features/calendar/domain/day_marker_style.dart';
import 'package:birthday_calendar/features/settings/presentation/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Вкладка «Календарь»: месячная сетка и годовой обзор.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month;
  bool _yearView = false;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    _month = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _shiftYear(int delta) {
    setState(() => _month = DateTime(_month.year + delta, _month.month));
  }

  void _goToday() {
    final now = ref.read(clockProvider).now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _yearView = false;
    });
  }

  void _showDay(CalendarDay day) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _DaySheet(day: day),
    );
  }

  /// Выбор года из списка: стрелки листают по одному, а диалог — сразу.
  ///
  /// Диапазон широкий в обе стороны: раньше он обрывался на десяти годах
  /// вперёд, и до 2040-х было не добраться ни списком, ни стрелками.
  Future<void> _pickYear() async {
    final now = ref.read(clockProvider).now();
    final first = now.year - 100;
    final last = now.year + 100;
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => _YearPicker(
        current: _month.year,
        first: first,
        last: last,
      ),
    );
    if (chosen == null) return;
    setState(() => _month = DateTime(chosen, _month.month));
  }

  /// Выбор месяца: год при этом не меняется.
  Future<void> _pickMonth() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => _MonthPicker(current: _month.month),
    );
    if (chosen == null) return;
    setState(() => _month = DateTime(_month.year, chosen));
  }


  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider).now();
    final all = ref.watch(allYearsBirthdaysProvider);
    final leapRule = ref.watch(leapDayRuleProvider).valueOrNull ??
        LeapDayRule.defaultRule;
    final fallback = leapRule.fallback;

    return Scaffold(
      appBar: AppBar(
        // В годовом режиме виден весь год, в месячном — конкретный месяц.
        // Заголовок нажимаемый: стрелки листают по одному месяцу или году,
        // а по нажатию можно выбрать сразу.
        title: InkWell(
          onTap: _yearView ? _pickYear : _pickMonth,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _yearView
                      ? '${_month.year}'
                      // Короткое название месяца: на узком экране
                      // «Февраля 2026» обрезалось многоточием.
                      : DateFormat('MMM yyyy', 'ru').format(_month),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: _yearView ? 'Показать месяц' : 'Показать год',
            icon: Icon(
              _yearView ? Icons.grid_view : Icons.calendar_view_month,
            ),
            onPressed: () => setState(() => _yearView = !_yearView),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: _yearView ? 'Предыдущий год' : 'Предыдущий месяц',
            onPressed: () => _yearView ? _shiftYear(-1) : _shiftMonth(-1),
          ),
          TextButton(onPressed: _goToday, child: const Text('Сегодня')),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: _yearView ? 'Следующий год' : 'Следующий месяц',
            onPressed: () => _yearView ? _shiftYear(1) : _shiftMonth(1),
          ),
        ],
      ),
      body: all.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Ошибка: $error')),
        data: (items) {
          if (_yearView) {
            final yearItems = occurrencesInYear(
              items,
              _month.year,
              fallback: fallback,
            );
            return _YearView(
              items: yearItems,
              today: now,
              // Месяцы строим для выбранного года, а не для текущего:
              // иначе стрелки меняли бы заголовок, оставляя сетку прежней.
              year: _month.year,
              onDayTap: _showDay,
            );
          }

          final month = CalendarMonth.build(
            _month,
            items: occurrencesInYear(items, _month.year, fallback: fallback),
            today: now,
          );
          return Column(
            children: [
              const _WeekdayHeader(),
              Expanded(
                child: _MonthGrid(month: month, onDayTap: _showDay),
              ),
              _MonthList(month: month),
            ],
          );
        },
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          for (final name in names)
            Expanded(
              child: Center(
                child: Text(
                  name,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Месячная сетка с фиксированной высотой ячеек.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.onDayTap});

  final CalendarMonth month;
  final void Function(CalendarDay day) onDayTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 2.0;
        final width = (constraints.maxWidth - spacing * 7) / 7;
        final height = width * 1.2;

        return SingleChildScrollView(
          child: Column(
            children: [
              for (var week = 0; week < 6; week++)
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Builder(
                        builder: (context) {
                          final day = month.days[week * 7 + i];
                          return SizedBox(
                            width: width,
                            height: height,
                            child: Padding(
                              padding: const EdgeInsets.all(spacing),
                              child: _MonthCell(
                                day: day,
                                onDayTap: onDayTap,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({required this.day, required this.onDayTap});

  final CalendarDay day;
  final void Function(CalendarDay day) onDayTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Редактирование доступно только из текущего месяца: в серых ячейках
    // дата принадлежит соседнему месяцу.
    final onTap = day.hasBirthdays && !day.isOutsideMonth
        ? () => onDayTap(day)
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: _DayCellBackground(
        birthdays: day.birthdays,
        surface: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: day.isToday
            ? Border.all(color: scheme.primary, width: 2)
            : null,
        child: Text(
          '${day.date.day}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: day.isOutsideMonth ? scheme.outline : scheme.onSurface,
            fontWeight: day.isToday ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }
}

/// Список дней рождения выбранного месяца под сеткой.
class _MonthList extends StatelessWidget {
  const _MonthList({required this.month});

  final CalendarMonth month;

  @override
  Widget build(BuildContext context) {
    final items = month.birthdays;
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 170),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final years = item.occurrence.yearsSinceBirth;
          return ListTile(
            dense: true,
            leading: BirthdayAvatar(birthday: item.birthday),
            title: Text(item.birthday.name),
            subtitle: years == null
                ? null
                : Text('$years ${BirthdayDateUtils.pluralYears(years)}'),
            onTap: () => context.go(AppRoutes.birthdayEdit(item.birthday.id)),
          );
        },
      ),
    );
  }
}

/// Диалог с днями рождения конкретного дня.
class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.day});

  final CalendarDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = DateFormat('d MMMM', 'ru').format(day.date);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(label, style: theme.textTheme.titleMedium),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final item in day.birthdays)
                  ListTile(
                    leading: BirthdayAvatar(birthday: item.birthday),
                    title: Text(item.birthday.name),
                    subtitle: item.occurrence.yearsSinceBirth == null
                        ? null
                        : Text(
                            '${item.occurrence.yearsSinceBirth} '
                            '${BirthdayDateUtils.pluralYears(item.occurrence.yearsSinceBirth!)}',
                          ),
                    trailing: item.birthday.isImportant
                        ? Icon(
                            Icons.star,
                            size: 18,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go(AppRoutes.birthdayEdit(item.birthday.id));
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Выбор года одним списком, а не по одному стрелками.
class _YearPicker extends StatefulWidget {
  const _YearPicker({
    required this.current,
    required this.first,
    required this.last,
  });

  final int current;
  final int first;
  final int last;

  @override
  State<_YearPicker> createState() => _YearPickerState();
}

class _YearPickerState extends State<_YearPicker> {
  /// Высота строки списка. Нужна, чтобы посчитать, куда прокрутить список:
  /// без известной высоты прокрутка встала бы в произвольное место.
  static const double _rowHeight = 56;

  /// Высота видимой части списка.
  static const double _viewportHeight = 320;

  late final List<int> _years = List.generate(
    widget.last - widget.first + 1,
    (i) => widget.first + i,
  );

  late final ScrollController _controller = ScrollController(
    initialScrollOffset: _initialOffset(),
  );

  /// Ставит текущий год в середину списка.
  ///
  /// Диапазон — сто лет в обе стороны, и без этого список открывался бы на
  /// самой ранней дате: до сегодняшнего года пришлось бы листать сотню строк.
  double _initialOffset() {
    final index = _years.indexOf(widget.current);
    if (index < 0) return 0;
    final centered = index * _rowHeight - (_viewportHeight - _rowHeight) / 2;
    return centered < 0 ? 0 : centered;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Выберите год'),
      children: [
        // Ширина задана жёстко: SimpleDialog измеряет детей по внутренним
        // размерам, а ленивый список этого не умеет — без явной ширины
        // диалог падает при раскладке.
        SizedBox(
          width: 280,
          height: _viewportHeight,
          child: ListView.builder(
            controller: _controller,
            itemExtent: _rowHeight,
            itemCount: _years.length,
            itemBuilder: (context, index) {
              final year = _years[index];
              return ListTile(
                title: Text('$year'),
                selected: year == widget.current,
                onTap: () => Navigator.of(context).pop(year),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Выбор месяца: год при этом не меняется.
class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.current});

  final int current;

  static const List<String> _names = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Выберите месяц',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (var i = 0; i < _names.length; i++)
            ListTile(
              title: Text(_names[i]),
              selected: i + 1 == current,
              onTap: () => Navigator.of(context).pop(i + 1),
            ),
        ],
      ),
    );
  }
}

/// Годовой вид: двенадцать месяцев, по три в ряд, на одном экране.
class _YearView extends StatelessWidget {
  const _YearView({
    required this.items,
    required this.today,
    required this.onDayTap,
    required this.year,
  });

  final List<BirthdayWithOccurrence> items;
  final DateTime today;
  final int year;
  final void Function(CalendarDay day) onDayTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 6.0;
        final width = (constraints.maxWidth - spacing * 2) / 3;
        final height = (constraints.maxHeight - spacing * 3) / 4;

        return SingleChildScrollView(
          child: Column(
            children: [
              for (var row = 0; row < 4; row++)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var col = 0; col < 3; col++)
                      SizedBox(
                        width: width,
                        height: height,
                        // Отступ только между колонками: под последней колонкой
                        // и под последней строкой его быть не должно, иначе
                        // содержимое шире и выше экрана на `spacing`, и годовой
                        // вид приходится доскроллить.
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: col == 2 ? 0 : spacing,
                            bottom: row == 3 ? 0 : spacing,
                          ),
                          child: _MiniMonth(
                            month: CalendarMonth.build(
                              DateTime(year, row * 3 + col + 1),
                              items: items,
                              today: today,
                            ),
                            onDayTap: onDayTap,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Один месяц в годовом виде.
class _MiniMonth extends StatelessWidget {
  const _MiniMonth({required this.month, required this.onDayTap});

  final CalendarMonth month;
  final void Function(CalendarDay day) onDayTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        // Плотная ступень + контур вместо полупрозрачной заливки. На чёрном
        // фоне AMOLED полупрозрачный слой почти не виден, и месяцы
        // сливались в один блок.
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
        child: Column(
          children: [
            Text(
              month.title.split(' ').first,
              style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 4),
            const _MiniWeekdays(),
            const SizedBox(height: 4),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Шесть недель делят высоту поровну, чтобы сетка
                  // не растягивалась на больших экранах.
                  final cellHeight = constraints.maxHeight / 6;
                  return Column(
                    children: [
                      for (var week = 0; week < 6; week++)
                        SizedBox(
                          height: cellHeight,
                          child: Row(
                            children: [
                              for (var i = 0; i < 7; i++)
                                Expanded(
                                  child: _MiniDay(
                                    day: month.days[week * 7 + i],
                                    onTap: onDayTap,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniWeekdays extends StatelessWidget {
  const _MiniWeekdays();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return Row(
      children: [
        for (final name in names)
          Expanded(
            child: Center(
              child: Text(
                name,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// День в годовом виде: число на фоне, поделённом по числу праздников.
class _MiniDay extends StatelessWidget {
  const _MiniDay({required this.day, required this.onTap});

  final CalendarDay day;
  final void Function(CalendarDay day) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: day.hasBirthdays ? () => onTap(day) : null,
      borderRadius: BorderRadius.circular(6),
      child: _DayCellBackground(
        birthdays: day.birthdays,
        // Фон мини-месяца, а не общий фон экрана: к нему подмешивается цвет
        // записи, иначе заливка не совпала бы с подложкой.
        surface: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
        child: Text(
          '${day.date.day}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: day.isOutsideMonth
                ? scheme.outline.withValues(alpha: 0.35)
                : day.isToday
                    ? scheme.primary
                    : scheme.onSurface,
            fontWeight: day.isToday || day.hasBirthdays
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Фон ячейки дня: поделён на доли по числу людей с днём рождения.
///
/// Отдельного кружка под числом больше нет. Раньше он рисовался под датой
/// (а при фотографии — как аватар), торчал из ячейки и мешал читать число.
/// Теперь число людей видно по числу долей фона, а цвет каждой доли — это
/// цвет своей записи.
class _DayCellBackground extends StatelessWidget {
  const _DayCellBackground({
    required this.birthdays,
    required this.surface,
    required this.borderRadius,
    required this.child,
    this.border,
  });

  final List<BirthdayWithOccurrence> birthdays;

  /// Подложка, с которой смешивается цвет записи. В месячном виде это фон
  /// экрана, в годовом — фон мини-месяца.
  final Color surface;

  final BorderRadius borderRadius;
  final BoxBorder? border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _birthdayColors(birthdays, theme.colorScheme);

    return Container(
      decoration: BoxDecoration(borderRadius: borderRadius, border: border),
      // Скругление нужно и долям фона: иначе углы ячейки торчат квадратами
      // поверх закруглённой рамки.
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (colors.isNotEmpty)
            Row(
              // Обязательно stretch: ColoredBox без ребёнка при
              // выравнивании по центру схлопывается в нулевую высоту, и
              // заливки не видно вовсе.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final color in colors)
                  Expanded(
                    child: ColoredBox(
                      color: dayCellTint(
                        birthdayColor: color,
                        surface: surface,
                        brightness: theme.brightness,
                      ),
                    ),
                  ),
              ],
            ),
          Center(child: child),
        ],
      ),
    );
  }
}

/// Цвета долей фона — по одному на человека, без склейки.
///
/// Доли не схлопываются даже при совпадении цветов: число долей должно
/// показывать число людей, а не число разных оттенков.
List<Color> _birthdayColors(
  List<BirthdayWithOccurrence> birthdays,
  ColorScheme scheme,
) {
  return [for (final item in birthdays) _birthdayColor(item, scheme)];
}

/// Цвет записи для разметки календаря: свой цвет аватара либо акцент темы.
///
/// Свой цвет запись получает сразу при создании, поэтому доли фона почти
/// всегда цветные; акцент — запасной вариант для старых записей без цвета.
Color _birthdayColor(BirthdayWithOccurrence item, ColorScheme scheme) {
  final value = item.birthday.avatarColorValue;
  return value != null ? Color(value) : scheme.primary;
}
