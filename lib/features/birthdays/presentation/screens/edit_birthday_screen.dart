import 'dart:io';

import 'package:birthday_calendar/core/routing/app_router.dart';
import 'package:birthday_calendar/core/providers/database_provider.dart';
import 'package:birthday_calendar/core/theme/widgets/color_picker_dialog.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:birthday_calendar/features/birthdays/presentation/providers/birthday_actions_provider.dart';
import 'package:birthday_calendar/features/birthdays/presentation/providers/birthday_list_providers.dart';
import 'package:birthday_calendar/features/birthdays/presentation/widgets/avatar_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Экран создания и редактирования дня рождения.
class EditBirthdayScreen extends ConsumerStatefulWidget {
  const EditBirthdayScreen({super.key});

  @override
  ConsumerState<EditBirthdayScreen> createState() =>
      _EditBirthdayScreenState();
}

class _EditBirthdayScreenState extends ConsumerState<EditBirthdayScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  final _yearController = TextEditingController();

  int? _day;
  int? _month;
  bool _isImportant = false;
  bool _saving = false;
  bool _initialized = false;
  Birthday? _loaded;

  /// Аватар применяется сразу при выборе, но сохраняется только вместе
  /// с формой — иначе отмена правки оставила бы файл в базе.
  String? _pendingAvatarFile;
  int? _pendingAvatarColor;
  bool _avatarChanged = false;

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _fillFrom(Birthday? existing) {
    if (_initialized || existing == null) return;
    _initialized = true;
    _nameController.text = existing.name;
    _noteController.text = existing.note;
    _isImportant = existing.isImportant;
    _day = existing.day;
    _month = existing.month;
    _loaded = existing;
    if (existing.birthYear != null) {
      _yearController.text = existing.birthYear.toString();
    }
    setState(() {});
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pendingAvatarFile = picked.path;
      _pendingAvatarColor = null;
      _avatarChanged = true;
    });
  }

  Future<void> _pickColor() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(
        initial: _pendingAvatarColor ??
            _loaded?.avatarColorValue ??
            Theme.of(context).colorScheme.primary.toARGB32(),
      ),
    );
    if (color == null || !mounted) return;
    setState(() {
      _pendingAvatarColor = color.toARGB32();
      _pendingAvatarFile = null;
      _avatarChanged = true;
    });
  }

  void _resetAvatar() {
    setState(() {
      _pendingAvatarFile = null;
      _pendingAvatarColor = null;
      _avatarChanged = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = GoRouterState.of(context).pathParameters['id'];
    if (id != null) {
      ref.listen(birthdayByIdProvider(id), (_, next) {
        next.whenData(
          (item) => _fillFrom(
            item?.birthday,
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(id == null ? 'Новый день рождения' : 'Редактирование'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AvatarPicker(
              birthday: _loaded,
              pendingFilePath: _pendingAvatarFile,
              pendingColor: _pendingAvatarColor,
              onPickPhoto: _pickPhoto,
              onPickColor: _pickColor,
              onReset: _resetAvatar,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Имя',
                hintText: 'Например, Анна',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Укажите имя';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('day-$_day'),
                    initialValue: _day,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'День'),
                    items: [
                      for (var d = 1; d <= 31; d++)
                        DropdownMenuItem(value: d, child: Text('$d')),
                    ],
                    onChanged: (value) => setState(() => _day = value),
                    validator: (value) =>
                        value == null ? 'Выберите день' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('month-$_month'),
                    initialValue: _month,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Месяц'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Январь')),
                      DropdownMenuItem(value: 2, child: Text('Февраль')),
                      DropdownMenuItem(value: 3, child: Text('Март')),
                      DropdownMenuItem(value: 4, child: Text('Апрель')),
                      DropdownMenuItem(value: 5, child: Text('Май')),
                      DropdownMenuItem(value: 6, child: Text('Июнь')),
                      DropdownMenuItem(value: 7, child: Text('Июль')),
                      DropdownMenuItem(value: 8, child: Text('Август')),
                      DropdownMenuItem(value: 9, child: Text('Сентябрь')),
                      DropdownMenuItem(value: 10, child: Text('Октябрь')),
                      DropdownMenuItem(value: 11, child: Text('Ноябрь')),
                      DropdownMenuItem(value: 12, child: Text('Декабрь')),
                    ],
                    onChanged: (value) => setState(() => _month = value),
                    validator: (value) =>
                        value == null ? 'Выберите месяц' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Год рождения (необязательно)',
                hintText: '1990',
                helperText: 'Без года возраст не показывается',
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                final year = int.tryParse(text);
                if (year == null) return 'Введите число';
                final now = DateTime.now();
                if (year < 1900 || year > now.year) {
                  return 'От 1900 до ${now.year}';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Заметка',
                hintText: 'Любимый торт, подарок…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Важный день рождения'),
              subtitle: const Text('Показывать выше в списке'),
              value: _isImportant,
              onChanged: (value) => setState(() => _isImportant = value),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(id == null ? 'Добавить' : 'Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_day == null || _month == null) {
      _showError('Выберите день и месяц');
      return;
    }

    setState(() => _saving = true);
    final yearText = _yearController.text.trim();
    final draft = BirthdayDraft(
      name: _nameController.text.trim(),
      day: _day!,
      month: _month!,
      birthYear: yearText.isEmpty ? null : int.tryParse(yearText),
      note: _noteController.text.trim(),
      isImportant: _isImportant,
    );

    try {
      final actions = ref.read(birthdayActionsProvider);
      final id = GoRouterState.of(context).pathParameters['id'];
      Birthday? saved;
      if (id == null) {
        saved = await actions.create(draft);
      } else {
        saved = await actions.update(id, draft);
      }

      // Аватар сохраняем после основной записи: у новой записи ещё нет id,
      // а имя файла строим именно из него.
      if (_avatarChanged) {
        final repository = ref.read(birthdayRepositoryProvider);
        if (_pendingAvatarFile != null) {
          await repository.setAvatarFile(
            saved.id,
            File(_pendingAvatarFile!),
          );
        } else if (_pendingAvatarColor != null) {
          await repository.setAvatarColor(saved.id, _pendingAvatarColor!);
        } else {
          await repository.clearAvatar(saved.id);
        }
      }
      if (mounted) context.go(AppRoutes.birthdays);
    } on ArgumentError catch (error) {
      _showError(_messageOf(error));
    } on StateError catch (error) {
      _showError(_messageOf(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _messageOf(Object error) {
    final text = error.toString();
    final match = RegExp(r':\s*(.+)$').firstMatch(text);
    return match?.group(1) ?? text;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
