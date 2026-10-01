import 'package:birthday_calendar/core/routing/app_router.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_grouping.dart';
import 'package:birthday_calendar/features/birthdays/presentation/providers/birthday_list_providers.dart';
import 'package:birthday_calendar/features/birthdays/presentation/widgets/birthday_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Главный экран: ближайшие дни рождения по разделам.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(upcomingSectionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ближайшие')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.birthdayNew),
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: sections.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorView(error: error),
        data: (data) {
          if (data.isEmpty) return const _EmptyView();
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final section = data[index];
              return _Section(
                section: section,
                onTap: (id) => context.go(AppRoutes.birthdayEdit(id)),
              );
            },
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section, required this.onTap});

  final BirthdaySectionData section;
  final void Function(String id) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            switch (section.section) {
              BirthdaySection.today => 'Сегодня',
              BirthdaySection.thisWeek => 'В ближайшие 7 дней',
              BirthdaySection.later => 'Позже',
            },
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        for (final item in section.items)
          BirthdayTile(
            item: item,
            onTap: () => onTap(item.birthday.id),
          ),
        const SizedBox(height: 8),
        const Divider(),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cake_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('Пока пусто', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Добавьте дни рождения, чтобы не пропустить праздник.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Не удалось загрузить данные:\n$error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
