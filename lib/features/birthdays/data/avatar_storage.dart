import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Хранит фотографии пользователей для профилей.
///
/// Файлы лежат в подпапке `avatars` каталога приложения. Путь из
/// `image_picker` временный, поэтому изображение копируется к нам.
class AvatarStorage {
  const AvatarStorage._();

  static const String folderName = 'avatars';

  /// Сохраняет выбранное фото под [birthdayId] и возвращает имя файла.
  ///
  /// Перезаписывает предыдущий аватар того же человека.
  static Future<String> save(String birthdayId, File source) async {
    final dir = await _folder();
    final target = File('${dir.path}/$birthdayId.png');
    await source.copy(target.path);
    return target.uri.pathSegments.last;
  }

  /// Удаляет сохранённый аватар, если он был.
  static Future<void> delete(String? fileName) async {
    if (fileName == null) return;
    final file = await _resolve(fileName);
    if (await file.exists()) await file.delete();
  }

  /// Возвращает файл аватара либо `null`, если его нет.
  static Future<File?> resolve(String? fileName) async {
    if (fileName == null) return null;
    final file = await _resolve(fileName);
    if (!await file.exists()) return null;
    return file;
  }

  static Future<File> _resolve(String fileName) async {
    final dir = await _folder();
    return File('${dir.path}/$fileName');
  }

  static Future<Directory> _folder() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$folderName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
