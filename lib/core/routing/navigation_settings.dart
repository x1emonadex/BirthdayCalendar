import 'dart:convert';

import 'package:birthday_calendar/features/settings/data/settings_repository.dart';
import 'package:birthday_calendar/features/settings/presentation/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ, под которым порядок вкладок лежит в AppSettings.
const String kNavigationSettingsKey = 'navigation_tabs';

/// Идентификаторы вкладок нижней навигации.
class TabId {
  const TabId._();

  static const String home = 'home';
  static const String calendar = 'calendar';
  static const String birthdays = 'birthdays';
  static const String settings = 'settings';

  /// Порядок по умолчанию: то, что мы показывали изначально.
  static const List<String> defaultOrder = [home, calendar, birthdays, settings];
}

/// Настройки нижней навигации: какие вкладки видны и в каком порядке.
class NavigationSettings {
  const NavigationSettings({this.tabs = TabId.defaultOrder});

  /// Список идентификаторов вкладок в порядке отображения.
  final List<String> tabs;

  bool get isEmpty => tabs.isEmpty;

  NavigationSettings copyWith({List<String>? tabs}) {
    return NavigationSettings(tabs: tabs ?? this.tabs);
  }

  @override
  bool operator ==(Object other) {
    if (other is! NavigationSettings) return false;
    if (other.tabs.length != tabs.length) return false;
    for (var i = 0; i < tabs.length; i++) {
      if (other.tabs[i] != tabs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(tabs);
}

final NotifierProvider<NavigationController, NavigationSettings>
    navigationControllerProvider =
    NotifierProvider<NavigationController, NavigationSettings>(
  NavigationController.new,
);

/// Читатель настроек из базы.
final Provider<NavigationSettings> navigationSettingsProvider =
    Provider<NavigationSettings>((ref) => const NavigationSettings());

/// Управляет составом и порядком вкладок.
class NavigationController extends Notifier<NavigationSettings> {
  @override
  NavigationSettings build() => const NavigationSettings();

  /// Загружает сохранённый порядок. Вызывается один раз при старте.
  Future<void> load() async {
    final repository = ref.read(settingsRepositoryProvider);
    state = NavigationSettingsCodec.decode(
      await repository.read(kNavigationSettingsKey),
    );
  }

  /// Показывает или скрывает вкладку. Последнюю видимую скрыть нельзя —
  /// иначе навигации станет некуда деться.
  Future<void> setVisible(String id, bool visible) async {
    final current = List<String>.from(state.tabs);
    if (visible) {
      if (current.contains(id)) return;
      current.add(id);
    } else {
      if (!current.contains(id) || current.length == 1) return;
      current.remove(id);
    }
    await _save(NavigationSettings(tabs: current));
  }

  /// Сдвигает вкладку на одну позицию вверх или вниз.
  Future<void> move(String id, {required bool up}) async {
    final current = List<String>.from(state.tabs);
    final index = current.indexOf(id);
    if (index < 0) return;

    final target = up ? index - 1 : index + 1;
    if (target < 0 || target >= current.length) return;

    final moved = current.removeAt(index);
    current.insert(target, moved);
    await _save(NavigationSettings(tabs: current));
  }

  /// Возвращает состав и порядок по умолчанию.
  Future<void> reset() async {
    await _save(const NavigationSettings());
  }

  Future<void> _save(NavigationSettings next) async {
    state = next;
    await NavigationSettingsCodec.save(
      ref.read(settingsRepositoryProvider),
      next,
    );
  }
}

/// Преобразование настроек навигации в формат базы.
abstract final class NavigationSettingsCodec {
  static NavigationSettings decode(String? raw) {
    if (raw == null || raw.isEmpty) return const NavigationSettings();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      // Отсекаем неизвестные идентификаторы: после обновления приложения
      // в базе может остаться вкладка, которой больше нет.
      final tabs = list
          .map((e) => e as String)
          .where(TabId.defaultOrder.contains)
          .toSet()
          .toList();

      if (tabs.isEmpty) return const NavigationSettings();
      // Сохраняем порядок из настроек, а недостающие добавляем в конце.
      final result = List<String>.from(tabs);
      for (final id in TabId.defaultOrder) {
        if (!result.contains(id)) result.add(id);
      }
      return NavigationSettings(tabs: result);
    } catch (_) {
      return const NavigationSettings();
    }
  }

  static String encode(NavigationSettings settings) {
    return jsonEncode(settings.tabs);
  }

  static Future<void> save(
    SettingsRepository repository,
    NavigationSettings settings,
  ) {
    return repository.write(kNavigationSettingsKey, encode(settings));
  }
}
