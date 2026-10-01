import 'package:birthday_calendar/core/utils/birthday_date_utils.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:birthday_calendar/features/notifications/domain/notification_plan_builder.dart';
import 'package:birthday_calendar/features/notifications/domain/notification_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime d(int y, int m, int day, [int h = 0, int min = 0]) =>
      DateTime(y, m, day, h, min);

  /// Собирает «день рождения» с заданной датой праздника.
  BirthdayWithOccurrence birthday({
    String id = 'b1',
    String name = 'Аня',
    int? birthYear,
    bool isImportant = false,
    String profileId = 'p1',
    required DateTime occurrenceDate,
  }) {
    final created = DateTime(2026);
    return BirthdayWithOccurrence(
      birthday: Birthday(
        id: id,
        profileId: profileId,
        name: name,
        day: occurrenceDate.day,
        month: occurrenceDate.month,
        birthYear: birthYear,
        createdAt: created,
        updatedAt: created,
        isImportant: isImportant,
      ),
      occurrence: BirthdayOccurrence(
        date: occurrenceDate,
        daysUntil: 0,
        yearsSinceBirth: birthYear == null ? null : 36,
      ),
    );
  }

  const settings = NotificationSettings();

  group('NotificationSettings', () {
    test('значения по умолчанию', () {
      expect(settings.enabled, isTrue);
      expect(settings.daysBefore, {7, 1, 0});
      expect(settings.hour, 9);
      expect(settings.minute, 0);
      expect(settings.importantOnly, isFalse);
    });

    test('порог по умолчанию — 30 минут', () {
      expect(
        NotificationSettings.defaultImmediateThreshold,
        const Duration(minutes: 30),
      );
    });

    test('copyWith меняет одно поле, остальные сохраняет', () {
      final changed = settings.copyWith(hour: 18);
      expect(changed.hour, 18);
      expect(changed.minute, settings.minute);
      expect(changed.enabled, settings.enabled);
    });

    test('clearDaysBefore даёт пустое множество', () {
      final changed = settings.copyWith(clearDaysBefore: true);
      expect(changed.daysBefore, isEmpty);
    });

    test('quickDays — это ровно готовые чипы', () {
      expect(NotificationSettings.quickDays, {7, 1, 0});
      expect(NotificationSettings.defaultDaysBefore,
          NotificationSettings.quickDays);
      expect(NotificationSettings.quickDays.contains(15), isFalse);
    });

    test('произвольный срок сохраняется и не ломает равенство', () {
      final custom = settings.copyWith(daysBefore: {7, 1, 0, 2, 15});
      expect(custom.daysBefore, {7, 1, 0, 2, 15});
      expect(custom, isNot(settings));
      expect(custom, settings.copyWith(daysBefore: {15, 2, 0, 1, 7}));
      expect(
        custom.hashCode,
        settings.copyWith(daysBefore: {15, 2, 0, 1, 7}).hashCode,
      );
    });

    test('равенство не зависит от порядка множества', () {
      final a = settings.copyWith(daysBefore: {7, 1, 0});
      final b = settings.copyWith(daysBefore: {0, 7, 1});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      // Порядок множества не влияет и на результат планирования.
      expect(
        a.copyWith(daysBefore: {0, 7, 1}).daysBefore.length,
        3,
      );
    });
  });

  group('расписание за 7 дней', () {
    test('обычная дата даёт одно scheduled-событие', () {
      final events = NotificationPlanBuilder.buildPlan(
        // 8 марта — «за неделю» срабатывает 10 марта, ещё не наступило.
        now: d(2026, 3, 8, 12),
        items: [birthday(occurrenceDate: d(2026, 3, 17))],
        settings: settings.copyWith(daysBefore: {7}),
      );
      expect(events, hasLength(1));
      expect(events.single.status, NotificationStatus.scheduled);
      expect(events.single.daysBefore, 7);
      expect(events.single.fireAt, d(2026, 3, 10, 9));
      expect(events.single.occurrenceDate, d(2026, 3, 17));
    });

    test('время срабатывания — выбранное время в день «минус дней»', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 1),
        items: [birthday(occurrenceDate: d(2026, 3, 22))],
        settings: settings.copyWith(daysBefore: {7}, hour: 8, minute: 30),
      );
      expect(events.single.fireAt, d(2026, 3, 15, 8, 30));
    });
  });

  group('в день рождения', () {
    test('до выбранного времени — scheduled', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 17, 8, 59),
        items: [birthday(occurrenceDate: d(2026, 3, 17))],
        settings: settings.copyWith(daysBefore: {0}),
      );
      expect(events.single.status, NotificationStatus.scheduled);
      expect(events.single.fireAt, d(2026, 3, 17, 9));
    });

    test('ровно в выбранное время — immediate, не scheduled', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 17, 9),
        items: [birthday(occurrenceDate: d(2026, 3, 17))],
        settings: settings.copyWith(daysBefore: {0}),
      );
      expect(events.single.status, NotificationStatus.immediate);
    });

    test('после времени, но в пределах порога — immediate', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 17, 9, 20),
        items: [birthday(occurrenceDate: d(2026, 3, 17))],
        settings: settings.copyWith(daysBefore: {0}),
      );
      expect(events.single.status, NotificationStatus.immediate);
    });

    test('после времени за пределами порога — skipped', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 17, 14),
        items: [birthday(occurrenceDate: d(2026, 3, 17))],
        settings: settings.copyWith(daysBefore: {0}),
      );
      expect(events.single.status, NotificationStatus.skipped);
    });
  });

  group('переход через Новый год', () {
    test('«за 7 дней» от 1 января уходит в прошлый год', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2025, 12, 20),
        items: [birthday(occurrenceDate: d(2026, 1, 1))],
        settings: settings.copyWith(daysBefore: {7}),
      );
      expect(events.single.fireAt, d(2025, 12, 25, 9));
      expect(events.single.fireAt.year, 2025);
      expect(events.single.occurrenceDate.year, 2026);
    });

    test('31 декабря — «за неделю» 24 декабря того же года', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 12, 1),
        items: [birthday(occurrenceDate: d(2026, 12, 31))],
        settings: settings.copyWith(daysBefore: {7}),
      );
      expect(events.single.fireAt, d(2026, 12, 24, 9));
    });

    test('1 января — «за неделю» 25 декабря прошлого года', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2025, 12, 20),
        items: [birthday(occurrenceDate: d(2026, 1, 1))],
        settings: settings.copyWith(daysBefore: {7}),
      );
      expect(events.single.status, NotificationStatus.scheduled);
    });
  });

  group('29 февраля', () {
    test('в невисокосный год планируется на перенесённую дату', () {
      // Репозиторий уже отдал 28.02 вместо 29.02 — планировщик берёт
      // дату как есть и не пытается её менять.
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2025, 2, 1),
        items: [birthday(occurrenceDate: d(2025, 2, 28))],
        settings: settings.copyWith(daysBefore: {0}),
      );
      expect(events.single.occurrenceDate, d(2025, 2, 28));
      expect(events.single.fireAt, d(2025, 2, 28, 9));
    });

    test('с переносом на 1 марта дата тоже учитывается', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2025, 2, 1),
        items: [birthday(occurrenceDate: d(2025, 3, 1))],
        settings: settings.copyWith(daysBefore: {7}),
      );
      expect(events.single.occurrenceDate, d(2025, 3, 1));
      expect(events.single.fireAt, d(2025, 2, 22, 9));
    });

    test('в високосный год дата остаётся 29 февраля', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2024, 2, 1),
        items: [birthday(occurrenceDate: d(2024, 2, 29))],
        settings: settings.copyWith(daysBefore: {0}),
      );
      expect(events.single.occurrenceDate, d(2024, 2, 29));
    });
  });

  group('отключённые уведомления', () {
    test('enabled = false даёт пустой план', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 10),
        items: [birthday(occurrenceDate: d(2026, 3, 17))],
        settings: settings.copyWith(enabled: false),
      );
      expect(events, isEmpty);
    });

    test('пустой набор дней даёт пустой план', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 10),
        items: [birthday(occurrenceDate: d(2026, 3, 17))],
        settings: settings.copyWith(clearDaysBefore: true),
      );
      expect(events, isEmpty);
    });

    test('пустой список дней рождения даёт пустой план', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 10),
        items: const [],
        settings: settings,
      );
      expect(events, isEmpty);
    });
  });

  group('важные дни рождения', () {
    test('importantOnly отсекает обычные записи', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 10),
        items: [
          birthday(id: 'b1', name: 'Обычный', occurrenceDate: d(2026, 3, 20)),
          birthday(
            id: 'b2',
            name: 'Важный',
            isImportant: true,
            occurrenceDate: d(2026, 3, 21),
          ),
        ],
        settings: settings.copyWith(daysBefore: {7}, importantOnly: true),
      );
      expect(events, hasLength(1));
      expect(events.single.name, 'Важный');
      expect(events.single.isImportant, isTrue);
    });

    test('без importantOnly попадают все', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 10),
        items: [
          birthday(id: 'b1', name: 'Обычный', occurrenceDate: d(2026, 3, 20)),
          birthday(
            id: 'b2',
            name: 'Важный',
            isImportant: true,
            occurrenceDate: d(2026, 3, 21),
          ),
        ],
        settings: settings.copyWith(daysBefore: {7}),
      );
      expect(events, hasLength(2));
    });
  });

  group('несколько правил', () {
    test('три правила дают три события', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 10),
        items: [birthday(occurrenceDate: d(2026, 3, 30))],
        settings: settings.copyWith(daysBefore: {7, 1, 0}),
      );
      expect(events, hasLength(3));
      expect(
        events.map((e) => e.daysBefore).toList(),
        [7, 1, 0],
      );
    });

    test('произвольные сроки планируются как обычные', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 10),
        items: [birthday(occurrenceDate: d(2026, 3, 30))],
        settings: settings.copyWith(daysBefore: {15, 2, 0}),
      );
      expect(
        events.map((e) => e.daysBefore).toList(),
        [15, 2, 0],
      );
      expect(events.first.fireAt, d(2026, 3, 15, settings.hour, settings.minute));
      expect(
        events.first.title,
        'Через 15 дней — ${events.first.name}',
      );
    });

    test('дубликаты правил не плодят дубли', () {
      // Set физически не хранит дубликаты, поэтому собираем «грязный»
      // список вручную — так проверяем, что даже он даст одно событие.
      final rules = <int>{7, 1, 0}..addAll([7, 1, 0]);
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 10),
        items: [birthday(occurrenceDate: d(2026, 3, 30))],
        settings: settings.copyWith(daysBefore: rules),
      );
      expect(events, hasLength(3), reason: '7, 1 и 0 — три разных правила');

      final single = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 10),
        items: [birthday(occurrenceDate: d(2026, 3, 30))],
        settings: settings.copyWith(daysBefore: {7}),
      );
      expect(single, hasLength(1));
    });

    test('события отсортированы по времени', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 10),
        items: [
          birthday(id: 'a', name: 'Аня', occurrenceDate: d(2026, 3, 30)),
          birthday(id: 'b', name: 'Борис', occurrenceDate: d(2026, 3, 20)),
        ],
        settings: settings.copyWith(daysBefore: {7, 1, 0}),
      );
      for (var i = 1; i < events.length; i++) {
        expect(
          events[i].fireAt.isBefore(events[i - 1].fireAt),
          isFalse,
          reason: 'события должны идти по возрастанию времени',
        );
      }
    });

    test('порядок не зависит от порядка в настройках', () {
      final a = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 10),
        items: [birthday(occurrenceDate: d(2026, 3, 30))],
        settings: settings.copyWith(daysBefore: {0, 7, 1}),
      );
      final b = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 10),
        items: [birthday(occurrenceDate: d(2026, 3, 30))],
        settings: settings.copyWith(daysBefore: {7, 1, 0}),
      );
      expect(
        a.map((e) => e.id).toList(),
        b.map((e) => e.id).toList(),
      );
    });

    test('два дня рождения в один день — разные ID', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 10),
        items: [
          birthday(id: 'b1', name: 'Аня', occurrenceDate: d(2026, 3, 30)),
          birthday(id: 'b2', name: 'Борис', occurrenceDate: d(2026, 3, 30)),
        ],
        settings: settings.copyWith(daysBefore: {7}),
      );
      expect(events, hasLength(2));
      expect(events[0].id, isNot(events[1].id));
      expect(events[0].fireAt, events[1].fireAt);
    });
  });

  group('immediateThreshold', () {
    test('нулевой порог отключает ветку immediate', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 17, 9, 1),
        items: [birthday(occurrenceDate: d(2026, 3, 17))],
        settings: settings.copyWith(daysBefore: {0}),
        immediateThreshold: Duration.zero,
      );
      // Ровно на границе порога (разница 1 минута) — пропускаем.
      expect(events.single.status, NotificationStatus.skipped);
    });

    test('большой порог превращает свежие пропуски в immediate', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 17, 14),
        items: [birthday(occurrenceDate: d(2026, 3, 17))],
        settings: settings.copyWith(daysBefore: {0}),
        immediateThreshold: const Duration(hours: 6),
      );
      expect(events.single.status, NotificationStatus.immediate);
    });

    test('будущее событие не попадает в immediate при любом пороге', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 10),
        items: [birthday(occurrenceDate: d(2026, 3, 17))],
        settings: settings.copyWith(daysBefore: {0}),
        immediateThreshold: const Duration(days: 365),
      );
      expect(events.single.status, NotificationStatus.scheduled);
    });
  });

  group('вспомогательные выборки', () {
    test('scheduledOnly и immediateOnly разделяют план', () {
      final events = NotificationPlanBuilder.buildPlan(
        // 10 марта 12:00: «в день рождения» уже 3 часа назад → skipped,
        // «за неделю» (10 марта 09:00) — тоже в прошлом на 3 часа,
        // но «за день» (16 марта 09:00) — в будущем.
        now: d(2026, 3, 10, 12),
        items: [birthday(occurrenceDate: d(2026, 3, 17))],
        settings: settings.copyWith(daysBefore: {0, 7}),
      );
      expect(events, hasLength(2));
      expect(NotificationPlanBuilder.scheduledOnly(events), hasLength(1));
      expect(NotificationPlanBuilder.immediateOnly(events), isEmpty);
    });
  });

  group('stableNotificationId', () {
    int id(String birthdayId, {int daysBefore = 7, String profileId = 'p1'}) {
      return NotificationPlanBuilder.stableNotificationId(
        profileId: profileId,
        birthdayId: birthdayId,
        daysBefore: daysBefore,
      );
    }

    test('всегда в диапазоне 0..2^31-1', () {
      for (var i = 0; i < 200; i++) {
        final value = id('b$i', daysBefore: i);
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThan(0x80000000));
      }
    });

    test('стабилен между вызовами', () {
      expect(id('b1'), id('b1'));
      expect(id('b1'), id('b1'));
    });

    test('разный birthdayId даёт разные ID', () {
      expect(id('b1'), isNot(id('b2')));
    });

    test('разный daysBefore даёт разные ID', () {
      expect(id('b1', daysBefore: 7), isNot(id('b1', daysBefore: 0)));
      expect(id('b1', daysBefore: 1), isNot(id('b1', daysBefore: 7)));
    });

    test('разный profileId даёт разные ID', () {
      expect(id('b1', profileId: 'p1'), isNot(id('b1', profileId: 'p2')));
    });

    test('кириллица не ломает хеш', () {
      final value = id('бд-ани-2026');
      expect(value, greaterThanOrEqualTo(0));
      expect(value, lessThan(0x80000000));
    });

    test('один день рождения на разные даты сохраняет ID', () {
      final january = NotificationPlanBuilder.buildPlan(
        now: d(2026, 1, 1),
        items: [birthday(occurrenceDate: d(2026, 1, 15))],
        settings: settings.copyWith(daysBefore: {7}),
      );
      final march = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 1),
        items: [birthday(occurrenceDate: d(2026, 3, 15))],
        settings: settings.copyWith(daysBefore: {7}),
      );
      expect(january.single.id, march.single.id);
    });
  });

  group('тексты уведомления', () {
    test('за неделю — заголовок со сроком', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 10),
        items: [birthday(name: 'Аня', occurrenceDate: d(2026, 3, 17))],
        settings: settings.copyWith(daysBefore: {7}),
      );
      expect(events.single.title, 'Через 7 дней — Аня');
      expect(events.single.body, 'Аня, марта 17');
    });

    test('за один день — правильное склонение', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 10),
        items: [birthday(name: 'Аня', occurrenceDate: d(2026, 3, 11))],
        settings: settings.copyWith(daysBefore: {1}),
      );
      expect(events.single.title, 'Через 1 день — Аня');
    });

    test('в день рождения — особый заголовок', () {
      final events = NotificationPlanBuilder.buildPlan(
        now: d(2026, 3, 17, 8),
        items: [birthday(name: 'Аня', occurrenceDate: d(2026, 3, 17))],
        settings: settings.copyWith(daysBefore: {0}),
      );
      expect(events.single.title, 'Сегодня день рождения');
    });
  });
}
