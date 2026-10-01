import 'package:birthday_calendar/core/routing/app_router.dart';
import 'package:birthday_calendar/core/routing/navigation_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Экран настройки нижней навигации: порядок и видимость вкладок.
class NavigationSettingsScreen extends ConsumerWidget {
  const NavigationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(navigationControllerProvider);
    final controller = ref.read(navigationControllerProvider.notifier);
    final sections = sectionsFor(settings.tabs);

    return Scaffold(
      appBar: AppBar(title: const Text('Вкладки')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Порядок можно менять стрелками или перетаскиванием. '
              'Вкладку можно скрыть, кроме «Настроек»: '
              'вернуть их потом будет нечем.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sections.length,
            onReorderItem: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              final id = sections[oldIndex].id;
              // Сдвигаем на разницу позиций — это один ход вверх или вниз.
              final steps = newIndex > oldIndex ? newIndex - oldIndex : oldIndex - newIndex;
              for (var i = 0; i < steps; i++) {
                controller.move(id, up: newIndex < oldIndex);
              }
            },
            itemBuilder: (context, index) {
              final section = sections[index];
              final isOnly = sections.length == 1;
              // «Настройки» скрыть нельзя: это единственный вход в экран,
              // которым настраивается всё остальное, включая состав вкладок.
              final locked = section.id == TabId.settings;
              return ListTile(
                key: ValueKey(section.id),
                leading: Icon(section.icon),
                title: Text(section.label),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Выше',
                      icon: const Icon(Icons.keyboard_arrow_up),
                      onPressed: index == 0
                          ? null
                          : () => controller.move(section.id, up: true),
                    ),
                    IconButton(
                      tooltip: 'Ниже',
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: index == sections.length - 1
                          ? null
                          : () => controller.move(section.id, up: false),
                    ),
                    Switch(
                      value: true,
                      // Последнюю вкладку скрыть нельзя: навигация
                      // останется без единого пункта. И «Настройки»
                      // нельзя: иначе их больше не включить.
                      onChanged: isOnly || locked
                          ? null
                          : (value) => controller.setVisible(section.id, value),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Вернуть порядок по умолчанию'),
            onTap: controller.reset,
          ),
          const Divider(height: 32),
          const _SectionHeader('Скрытые вкладки'),
          for (final section in allSections)
            if (!settings.tabs.contains(section.id))
              ListTile(
                leading: Icon(section.icon),
                title: Text(section.label),
                trailing: TextButton(
                  onPressed: () => controller.setVisible(section.id, true),
                  child: const Text('Показать'),
                ),
              ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
