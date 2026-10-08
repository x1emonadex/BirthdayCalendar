import 'dart:async';

import 'package:birthday_calendar/core/providers/clock_provider.dart';
import 'package:birthday_calendar/core/providers/database_provider.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:birthday_calendar/features/birthdays/presentation/providers/birthday_list_providers.dart';
import 'package:birthday_calendar/features/widget/home_widget_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Данные для создания или обновления дня рождения.
class BirthdayDraft {
  const BirthdayDraft({
    required this.name,
    required this.day,
    required this.month,
    this.birthYear,
    this.note = '',
    this.isImportant = false,
  });

  final String name;
  final int day;
  final int month;
  final int? birthYear;
  final String note;
  final bool isImportant;

  BirthdayDraft copyWith({
    String? name,
    int? day,
    int? month,
    int? birthYear,
    bool clearBirthYear = false,
    String? note,
    bool? isImportant,
  }) {
    return BirthdayDraft(
      name: name ?? this.name,
      day: day ?? this.day,
      month: month ?? this.month,
      birthYear: clearBirthYear ? null : (birthYear ?? this.birthYear),
      note: note ?? this.note,
      isImportant: isImportant ?? this.isImportant,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BirthdayDraft &&
        other.name == name &&
        other.day == day &&
        other.month == month &&
        other.birthYear == birthYear &&
        other.note == note &&
        other.isImportant == isImportant;
  }

  @override
  int get hashCode =>
      Object.hash(name, day, month, birthYear, note, isImportant);
}

/// Действия над записями: создание, обновление, удаление.
///
/// После каждого изменения инвалидирует списки, чтобы экраны подхватили
/// новое состояние. Виджеты работают только через этот провайдер и не
/// обращаются к репозиторию напрямую.
class BirthdayActions {
  BirthdayActions(this._ref);

  final Ref _ref;

  Future<Birthday> create(BirthdayDraft draft) async {
    final repository = _ref.read(birthdayRepositoryProvider);
    final created = await repository.create(
      name: draft.name,
      day: draft.day,
      month: draft.month,
      birthYear: draft.birthYear,
      note: draft.note,
      isImportant: draft.isImportant,
    );
    _invalidateLists();
    return created;
  }

  Future<Birthday> update(String id, BirthdayDraft draft) async {
    final repository = _ref.read(birthdayRepositoryProvider);
    final updated = await repository.update(
      id: id,
      name: draft.name,
      day: draft.day,
      month: draft.month,
      birthYear: draft.birthYear,
      note: draft.note,
      isImportant: draft.isImportant,
    );
    _invalidateLists();
    return updated;
  }

  Future<bool> delete(String id) async {
    final repository = _ref.read(birthdayRepositoryProvider);
    final deleted = await repository.delete(id);
    if (deleted) _invalidateLists();
    return deleted;
  }

  /// Возвращает удалённую запись — для плашки «Вернуть».
  Future<void> restore(Birthday birthday) async {
    await _ref.read(birthdayRepositoryProvider).restore(birthday);
    _invalidateLists();
  }

  Future<int> deleteAll() async {
    final repository = _ref.read(birthdayRepositoryProvider);
    final count = await repository.deleteAll();
    if (count > 0) _invalidateLists();
    return count;
  }

  void _invalidateLists() {
    _ref.invalidate(allBirthdaysProvider);
    _ref.invalidate(upcomingBirthdaysProvider);
    _ref.invalidate(upcomingSectionsProvider);
    // Календарь тоже читает дни рождения. Без этой строки новая запись
    // появлялась в списке, но не в календаре до перезапуска приложения.
    _ref.invalidate(allYearsBirthdaysProvider);
    // Виджет на рабочем столе показывает те же данные — обновляем и его.
    unawaited(
      syncHomeWidget(
        repository: _ref.read(birthdayRepositoryProvider),
        now: _ref.read(clockProvider).now(),
      ),
    );
  }
}

final Provider<BirthdayActions> birthdayActionsProvider =
    Provider<BirthdayActions>(BirthdayActions.new);
