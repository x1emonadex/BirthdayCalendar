import 'package:birthday_calendar/features/birthdays/presentation/screens/all_birthdays_screen.dart';
import 'package:birthday_calendar/features/birthdays/presentation/screens/edit_birthday_screen.dart';
import 'package:birthday_calendar/features/birthdays/presentation/screens/home_screen.dart';
import 'package:birthday_calendar/features/calendar/presentation/calendar_screen.dart';
import 'package:birthday_calendar/features/settings/presentation/screens/settings_screen.dart';
import 'package:birthday_calendar/shared/widgets/adaptive_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'navigation_settings.dart';

/// Пути маршрутов приложения.
abstract final class AppRoutes {
  static const String home = '/home';
  static const String calendar = '/calendar';
  static const String birthdays = '/birthdays';
  static const String settings = '/settings';

  /// Маршрут создания: `/birthdays/new`.
  static const String birthdayNew = '/birthdays/new';

  /// Маршрут редактирования: `/birthdays/:id/edit`.
  static String birthdayEdit(String id) => '/birthdays/$id/edit';
}

/// Раздел нижней навигации.
class AppSection {
  const AppSection({
    required this.id,
    required this.path,
    required this.label,
    required this.icon,
  });

  /// Идентификатор для настроек порядка и видимости.
  final String id;
  final String path;
  final String label;
  final IconData icon;
}

/// Все возможные разделы. Их порядок задаёт пользователь в настройках.
const List<AppSection> allSections = [
  AppSection(
    id: TabId.home,
    path: AppRoutes.home,
    label: 'Ближайшие',
    icon: Icons.cake_outlined,
  ),
  AppSection(
    id: TabId.calendar,
    path: AppRoutes.calendar,
    label: 'Календарь',
    icon: Icons.calendar_month_outlined,
  ),
  AppSection(
    id: TabId.birthdays,
    path: AppRoutes.birthdays,
    label: 'Все',
    icon: Icons.list_alt_outlined,
  ),
  AppSection(
    id: TabId.settings,
    path: AppRoutes.settings,
    label: 'Настройки',
    icon: Icons.settings_outlined,
  ),
];

/// Разделы в порядке, заданном пользователем.
List<AppSection> sectionsFor(List<String> order) {
  final byId = {for (final section in allSections) section.id: section};
  return [
    for (final id in order)
      if (byId[id] != null) byId[id]!,
  ];
}

/// Маршрутизатор приложения.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) {
        return AdaptiveScaffold(shell: shell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.calendar,
              builder: (context, state) => const CalendarScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.birthdays,
              builder: (context, state) => const AllBirthdaysScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const EditBirthdayScreen(),
                ),
                GoRoute(
                  path: ':id/edit',
                  builder: (context, state) => const EditBirthdayScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
