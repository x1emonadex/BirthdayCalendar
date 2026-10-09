import 'package:birthday_calendar/features/notifications/domain/notification_settings.dart';
import 'package:birthday_calendar/features/notifications/presentation/providers/notification_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('настройки уведомлений в JSON', () {
    test('круговой путь сохраняет времена', () {
      const settings = NotificationSettings(
        times: [
          NotificationTime(8, 30),
          NotificationTime(19, 0, enabled: false),
        ],
      );

      final decoded = NotificationSettingsCodec.decode(
        NotificationSettingsCodec.encode(settings),
      );

      expect(decoded.times, settings.times);
      expect(decoded.times.last.enabled, isFalse);
    });

    test('старый формат с одним временем читается как список', () {
      // Так настройки лежали до появления нескольких времён: двумя числами.
      // Если читать их как «времён нет», у всех, кто уже поставил напоминание,
      // оно бы молча сбросилось на девять утра.
      const old = '{"enabled":true,"daysBefore":[7,1],"hour":18,"minute":45,'
          '"importantOnly":false}';

      final decoded = NotificationSettingsCodec.decode(old);

      expect(decoded.times, const [NotificationTime(18, 45)]);
      expect(decoded.daysBefore, {7, 1});
    });

    test('испорченный JSON даёт значения по умолчанию', () {
      expect(
        NotificationSettingsCodec.decode('{это не json').times,
        NotificationSettings.defaultTimes,
      );
    });

    test('время вне суток отбрасывается', () {
      const broken =
          '{"times":[{"hour":25,"minute":0},{"hour":10,"minute":15}]}';

      expect(
        NotificationSettingsCodec.decode(broken).times,
        const [NotificationTime(10, 15)],
      );
    });

    test('без времён берётся время по умолчанию', () {
      expect(
        NotificationSettingsCodec.decode('{"enabled":true}').times,
        NotificationSettings.defaultTimes,
      );
    });
  });
}
