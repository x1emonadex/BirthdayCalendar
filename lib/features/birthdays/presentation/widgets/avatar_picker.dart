import 'dart:io';

import 'package:birthday_calendar/features/birthdays/data/avatar_storage.dart';
import 'package:birthday_calendar/features/birthdays/data/birthday_model.dart';
import 'package:flutter/material.dart';

/// Блок выбора аватара: фото, цвет или стандартный.
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    required this.onPickPhoto,
    required this.onPickColor,
    required this.onReset,
    this.birthday,
    this.pendingFilePath,
    this.pendingColor,
    super.key,
  });

  /// Сохранённый аватар — для показа текущего состояния.
  final Birthday? birthday;

  /// Файл, выбранный но ещё не сохранённый.
  final String? pendingFilePath;

  /// Цвет, выбранный но ещё не сохранённый.
  final int? pendingColor;

  final VoidCallback onPickPhoto;
  final VoidCallback onPickColor;
  final VoidCallback onReset;

  bool get _hasAvatar {
    if (pendingFilePath != null || pendingColor != null) return true;
    return birthday?.hasCustomAvatar ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Preview(
          filePath: pendingFilePath ?? _savedPath,
          colorValue: pendingColor ?? birthday?.avatarColorValue,
          letter: _letter,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Аватар', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickPhoto,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Фото'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickColor,
                      icon: const Icon(Icons.palette_outlined, size: 18),
                      label: const Text('Цвет'),
                    ),
                  ),
                ],
              ),
              if (_hasAvatar) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Убрать аватар'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String? get _savedPath {
    return birthday?.avatarFileName;
  }

  String get _letter {
    final name = birthday?.name.trim() ?? '';
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.letter,
    this.filePath,
    this.colorValue,
  });

  final String letter;
  final String? filePath;
  final int? colorValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background =
        colorValue != null ? Color(colorValue!) : scheme.primaryContainer;
    final foreground = colorValue != null
        ? (background.computeLuminance() > 0.5
            ? Colors.black87
            : Colors.white)
        : scheme.onPrimaryContainer;

    Widget fallback() {
      return ColoredBox(
        color: background,
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              color: foreground,
              fontSize: 32,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 80,
      height: 80,
      child: ClipOval(
        child: filePath == null
            ? fallback()
            : _isAbsolute(filePath!)
                ? Image.file(
                    File(filePath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback(),
                  )
                : _SavedImage(
                    fileName: filePath!,
                    fallback: (_) => fallback(),
                  ),
      ),
    );
  }

  /// `pendingFilePath` — абсолютный путь, `avatarFileName` — только имя.
  static bool _isAbsolute(String path) {
    return path.contains(RegExp(r'^[A-Za-z]:[\\/]')) || path.startsWith('/');
  }
}

/// Показывает сохранённый аватар, имя файла которого известно, а путь — нет.
class _SavedImage extends StatelessWidget {
  const _SavedImage({required this.fileName, required this.fallback});

  final String fileName;
  final WidgetBuilder fallback;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _resolve(),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) return fallback(context);
        return Image.file(file, fit: BoxFit.cover);
      },
    );
  }

  Future<File?> _resolve() async {
    return AvatarStorage.resolve(fileName);
  }
}
