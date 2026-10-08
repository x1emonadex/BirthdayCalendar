import 'package:birthday_calendar/core/providers/clock_provider.dart';
import 'package:birthday_calendar/core/providers/database_provider.dart';
import 'package:birthday_calendar/core/routing/app_router.dart';
import 'package:birthday_calendar/core/routing/navigation_settings.dart';
import 'package:birthday_calendar/core/theme/app_theme.dart';
import 'package:birthday_calendar/core/theme/theme_preferences.dart';
import 'package:birthday_calendar/core/theme/theme_provider.dart';
import 'package:birthday_calendar/features/notifications/presentation/providers/notification_providers.dart';
import 'package:birthday_calendar/features/widget/home_widget_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Корневой виджет приложения.
class BirthdayApp extends ConsumerStatefulWidget {
  const BirthdayApp({super.key});

  @override
  ConsumerState<BirthdayApp> createState() => _BirthdayAppState();
}

class _BirthdayAppState extends ConsumerState<BirthdayApp> {
  @override
  void initState() {
    super.initState();
    // Расписание всегда пересчитывается при запуске: оно могло устареть
    // из-за смены даты, настроек или перезагрузки телефона. Ошибки
    // игнорируем — приложение должно запуститься и без уведомлений.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(themeControllerProvider.notifier).load();
      } catch (error) {
        debugPrint('Не удалось загрузить настройки темы: $error');
      }

      try {
        await ref.read(navigationControllerProvider.notifier).load();
      } catch (error) {
        debugPrint('Не удалось загрузить настройки вкладок: $error');
      }

      try {
        final service = ref.read(notificationServiceProvider);
        await service.init();
        await service.requestPermissions();
        await ref.read(notificationSchedulerProvider).refresh();
      } catch (error, stack) {
        debugPrint('Не удалось настроить уведомления: $error\n$stack');
      }

      // Виджет на рабочем столе мог устареть, пока приложение было закрыто.
      try {
        await syncHomeWidget(
          repository: ref.read(birthdayRepositoryProvider),
          now: ref.read(clockProvider).now(),
        );
      } catch (error) {
        debugPrint('Не удалось обновить виджет: $error');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = ref.watch(themeControllerProvider);
    final accent = themeSettings.accent;
    final customSeed = themeSettings.customSeedColor;
    final amoled = themeSettings.mode == ThemeModePreference.amoled;
    // Тёмная тема включает и тёмные системные панели: иначе статус-бар и
    // «нижний» жест остаются светлыми и выглядят чужеродно на AMOLED.
    final darkSystemBars = switch (themeSettings.mode) {
      ThemeModePreference.dark || ThemeModePreference.amoled => true,
      ThemeModePreference.system => false,
      ThemeModePreference.light => false,
    };

    return MaterialApp.router(
      title: 'Дни рождения',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(
        accent: accent,
        customSeedColor: customSeed,
      ),
      darkTheme: AppTheme.dark(
        accent: accent,
        customSeedColor: customSeed,
        amoled: amoled,
      ),
      themeMode: themeSettings.mode.materialMode,
      routerConfig: appRouter,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                darkSystemBars ? Brightness.light : Brightness.dark,
            statusBarBrightness:
                darkSystemBars ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: darkSystemBars
                ? AppTheme.amoledSurfaceLow
                : Colors.transparent,
            systemNavigationBarIconBrightness:
                darkSystemBars ? Brightness.light : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          // Формы в Android растягиваются за пределы экрана, когда список
          // доскроллен до края. Отключаем эффект на уровне приложения,
          // иначе пришлось бы повторять настройку в каждом списке.
          child: ScrollConfiguration(
            behavior: const _NoOverscrollBehavior(),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

/// Поведение прокрутки без «резинового» эффекта на Android.
class _NoOverscrollBehavior extends ScrollBehavior {
  const _NoOverscrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };

  /// Отключает растяжение содержимого за границы прокручиваемой области.
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // На Android системная физика включает glow-эффект и rubber banding.
    // Заменяем её на ту же физику без растяжения.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const ClampingScrollPhysics();
    }
    return super.getScrollPhysics(context);
  }
}
