import 'package:birthday_calendar/core/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:birthday_calendar/core/routing/navigation_settings.dart';

/// Каркас приложения с адаптивной навигацией.
///
/// На узких экранах (телефон) используется нижняя [NavigationBar],
/// на широких (Windows, планшет) — боковой [NavigationRail].
class AdaptiveScaffold extends ConsumerWidget {
  const AdaptiveScaffold({required this.shell, super.key});

  final StatefulNavigationShell shell;

  static const double railBreakpoint = 700;

  void _goBranch(List<AppSection> sections, int index) {
    final section = sections[index];
    // Ветки в роутере всегда идут в порядке allSections, а навигация — в
    // порядке, заданном пользователем. Поэтому переводим одно в другое,
    // иначе после перестановки нажатие вело бы не туда.
    final branch = allSections.indexWhere((s) => s.id == section.id);
    if (branch < 0) return;
    shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(navigationControllerProvider).tabs;
    final sections = sectionsFor(order);

    // shell.currentIndex — это индекс ветки роутера (фиксированный порядок),
    // а selectedIndex должен быть позицией в навигации (порядок
    // пользователя). Переводим ветку в раздел и обратно.
    var branch = shell.currentIndex;
    if (branch < 0 || branch >= allSections.length) branch = 0;
    final currentId = allSections[branch].id;
    var currentIndex = sections.indexWhere((s) => s.id == currentId);
    if (currentIndex < 0) currentIndex = 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= railBreakpoint;

        if (useRail) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: currentIndex,
                  onDestinationSelected: (i) => _goBranch(sections, i),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final section in sections)
                      NavigationRailDestination(
                        icon: Icon(section.icon),
                        label: Text(section.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: shell),
              ],
            ),
          );
        }

        return Scaffold(
          body: shell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (i) => _goBranch(sections, i),
            destinations: [
              for (final section in sections)
                NavigationDestination(
                  icon: Icon(section.icon),
                  label: section.label,
                ),
            ],
          ),
        );
      },
    );
  }
}
