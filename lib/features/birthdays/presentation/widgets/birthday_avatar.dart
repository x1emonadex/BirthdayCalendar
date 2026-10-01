import 'dart:io';

import 'package:birthday_calendar/features/birthdays/data/avatar_storage.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:flutter/material.dart';

/// Аватар дня рождения: фото, цвет или первая буква имени.
class BirthdayAvatar extends StatefulWidget {
  const BirthdayAvatar({
    required this.birthday,
    this.size = 40,
    this.showInitial = true,
    super.key,
  });

  final Birthday birthday;
  final double size;

  /// Показывать ли букву в кружке календаря.
  ///
  /// В месячной сетке буква помогает узнать праздник, в годовом виде круг
  /// мельче и подпись только мешает читать число дня.
  final bool showInitial;

  @override
  State<BirthdayAvatar> createState() => _BirthdayAvatarState();
}

class _BirthdayAvatarState extends State<BirthdayAvatar> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BirthdayAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Перечитываем файл, только если сменилось имя файла: иначе на каждый
    // rebuild диск не дёргаем.
    if (oldWidget.birthday.avatarFileName !=
        widget.birthday.avatarFileName) {
      _load();
    }
  }

  Future<void> _load() async {
    final name = widget.birthday.avatarFileName;
    if (name == null) {
      if (mounted) {
        setState(() => _file = null);
      }
      return;
    }
    final file = await AvatarStorage.resolve(name);
    if (!mounted) return;
    setState(() => _file = file);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final birthday = widget.birthday;
    final colorValue = birthday.avatarColorValue;

    final background = colorValue != null
        ? Color(colorValue)
        : scheme.primaryContainer;
    final foreground = colorValue != null
        ? _contrastingForeground(Color(colorValue))
        : scheme.onPrimaryContainer;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipOval(
        child: _file != null
            ? Image.file(
                _file!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(background, foreground),
              )
            : _fallback(background, foreground),
      ),
    );
  }

  Widget _fallback(Color background, Color foreground) {
    final name = widget.birthday.name.trim();
    final letter = name.isEmpty ? '?' : name[0].toUpperCase();
    return ColoredBox(
      color: background,
      child: Center(
        child: widget.showInitial
            ? Text(
                letter,
                style: TextStyle(
                  color: foreground,
                  fontSize: widget.size * 0.45,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  /// Белый или чёрный текст — в зависимости от яркости фона.
  static Color _contrastingForeground(Color background) {
    return background.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;
  }
}
