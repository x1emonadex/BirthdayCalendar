import 'package:birthday_calendar/core/routing/app_router.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:birthday_calendar/features/birthdays/presentation/providers/birthday_actions_provider.dart';
import 'package:birthday_calendar/features/birthdays/presentation/providers/birthday_list_providers.dart';
import 'package:birthday_calendar/features/birthdays/presentation/widgets/birthday_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Полный список с поиском, фильтром «важные» и сортировкой.
class AllBirthdaysScreen extends ConsumerStatefulWidget {
  const AllBirthdaysScreen({super.key});

  @override
  ConsumerState<AllBirthdaysScreen> createState() =>
      _AllBirthdaysScreenState();
}

class _AllBirthdaysScreenState extends ConsumerState<AllBirthdaysScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(allBirthdaysQueryProvider);
    final items = ref.watch(allBirthdaysProvider);
    final controller = ref.read(allBirthdaysQueryControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Все дни рождения'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: controller.setSearch,
              decoration: InputDecoration(
                hintText: 'Поиск по имени или заметке',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          controller.setSearch('');
                        },
                      ),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Только важные',
            isSelected: query.importantOnly,
            icon: Icon(
              query.importantOnly ? Icons.star : Icons.star_border,
            ),
            onPressed: () =>
                controller.setImportantOnly(!query.importantOnly),
          ),
          PopupMenuButton<BirthdaySort>(
            tooltip: 'Сортировка',
            icon: const Icon(Icons.sort),
            initialValue: query.sort,
            onSelected: controller.setSort,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: BirthdaySort.upcoming,
                child: Text('По близости'),
              ),
              PopupMenuItem(
                value: BirthdaySort.byName,
                child: Text('По имени'),
              ),
              PopupMenuItem(
                value: BirthdaySort.byCalendarDate,
                child: Text('По дате в году'),
              ),
              PopupMenuItem(
                value: BirthdaySort.importantFirst,
                child: Text('Важные сверху'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go(AppRoutes.birthdayNew),
        child: const Icon(Icons.add),
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Ошибка загрузки:\n$error')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  query.search.isEmpty
                      ? 'Список пуст'
                      : 'Ничего не найдено по запросу «${query.search}»',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              return Dismissible(
                key: ValueKey(item.birthday.id),
                direction: DismissDirection.endToStart,
                background: _DeleteBackground(),
                confirmDismiss: (_) => _confirmDelete(context, item.birthday.id),
                onDismissed: (_) => ref
                    .read(birthdayActionsProvider)
                    .delete(item.birthday.id),
                child: BirthdayTile(
                  item: item,
                  onTap: () => context.go(AppRoutes.birthdayEdit(item.birthday.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      color: scheme.errorContainer,
      child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
    );
  }
}
