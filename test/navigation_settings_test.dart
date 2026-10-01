import 'package:birthday_calendar/core/routing/navigation_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('вкладку «Настройки» нельзя скрыть', () {
    test('прямое скрытие отклоняется', () async {
      const before = NavigationSettings();
      expect(
        canHideTab(before, TabId.settings),
        isFalse,
        reason: 'иначе настройки не вернуть',
      );
      expect(
        withVisibility(before, TabId.settings, false).tabs,
        before.tabs,
      );
    });

    test('скрыть можно любую другую вкладку', () {
      const before = NavigationSettings();
      final after = withVisibility(before, TabId.home, false);
      expect(after.tabs, isNot(contains(TabId.home)));
      expect(after.tabs, contains(TabId.settings));
    });

    test('последнюю оставшуюся вкладку скрыть нельзя', () {
      const only = NavigationSettings(tabs: [TabId.calendar]);
      expect(canHideTab(only, TabId.calendar), isFalse);
      expect(withVisibility(only, TabId.calendar, false).tabs, [TabId.calendar]);
    });

    test('показать скрытую вкладку можно всегда', () {
      const hidden = NavigationSettings(tabs: [TabId.home, TabId.settings]);
      final after = withVisibility(hidden, TabId.calendar, true);
      expect(after.tabs, contains(TabId.calendar));
    });
  });

  group('разбор сохранённых настроек', () {
    test('неизвестные вкладки отбрасываются', () {
      final result = NavigationSettingsCodec.decode('["home","что-то"]');
      expect(result.tabs, isNot(contains('что-то')));
      expect(result.tabs, contains(TabId.home));
    });

    test('отсутствующие вкладки добавляются в конец', () {
      final result = NavigationSettingsCodec.decode('["calendar"]');
      expect(result.tabs.first, TabId.calendar);
      expect(result.tabs, containsAll(TabId.defaultOrder));
    });

    test('«Настройки» не пропадают из сохранённого списка', () {
      final result = NavigationSettingsCodec.decode('["home"]');
      expect(result.tabs, contains(TabId.settings));
    });

    test('пустое значение даёт порядок по умолчанию', () {
      expect(
        NavigationSettingsCodec.decode(null).tabs,
        TabId.defaultOrder,
      );
      expect(
        NavigationSettingsCodec.decode('[]').tabs,
        TabId.defaultOrder,
      );
    });
  });
}
