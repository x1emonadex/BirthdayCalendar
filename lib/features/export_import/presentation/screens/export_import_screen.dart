import 'package:birthday_calendar/features/export_import/data/file_export_service.dart';
import 'package:birthday_calendar/features/export_import/data/import_result.dart';
import 'package:birthday_calendar/features/export_import/presentation/providers/export_import_providers.dart';
import 'package:birthday_calendar/features/settings/data/backup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Экран обмена файлами: выгрузка в Excel/CSV и загрузка обратно.
class ExportImportScreen extends ConsumerWidget {
  const ExportImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transferControllerProvider);
    final controller = ref.read(transferControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Перенос и копия')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Перенос данных',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Excel и CSV — чтобы посмотреть в таблице, отправить другу или '
            'перенести на другое устройство. Импорт дополняет список: '
            'совпавшие записи обновляются, новые добавляются.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.busy
                      ? null
                      : () => _runExport(context, controller, ExportFormat.xlsx),
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('Excel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.busy
                      ? null
                      : () => _runExport(context, controller, ExportFormat.csv),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('CSV'),
                ),
              ),
            ],
          ),
          const Divider(height: 40),
          Text(
            'Импорт из таблицы',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Подойдёт файл Excel или CSV, в том числе чужой. Совпадения '
            'находятся по ID и по имени с датой, чтобы не создавать дубликаты.',
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: state.busy
                ? null
                : () => _runImport(context, controller),
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Выбрать Excel или CSV'),
          ),
          const Divider(height: 40),
          const _BackupSection(),
          if (state.busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Future<void> _runExport(
    BuildContext context,
    TransferController controller,
    ExportFormat format,
  ) async {
    final result = await controller.exportAll(format);
    if (!context.mounted) return;
    _reportExport(context, result);
  }

  Future<void> _runImport(
    BuildContext context,
    TransferController controller,
  ) async {
    final result = await controller.importFromFile();
    if (!context.mounted) return;
    _reportImport(context, result);
  }

  void _reportExport(BuildContext context, ExportResult? result) {
    if (result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Файл сохранён: ${result.path}')),
    );
  }

  void _reportImport(BuildContext context, ImportResult? result) {
    if (result == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Импорт завершён'),
        content: _ImportReport(result: result),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}

/// Резервная копия: страховка от потери данных, а не обмен.
///
/// Отдельный от импорта в том, что файл JSON хранит только записи и
/// восстановление **заменяет** список целиком. Если бы копия читалась тем же
/// импортом, она бы дополняла список и не смогла бы вернуть его к состоянию
/// на момент сохранения.
class _BackupSection extends ConsumerWidget {
  const _BackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Резервная копия', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Страховка на случай, если список случайно испортился. '
          'Восстановление заменяет текущий список содержимым копии.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _save(context, ref),
                icon: const Icon(Icons.save_alt_outlined),
                label: const Text('Сохранить копию'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _restore(context, ref),
                icon: const Icon(Icons.settings_backup_restore),
                label: const Text('Восстановить'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'В отличие от Excel и CSV, копия не годна для переноса '
                  'на другое устройство: она хранит только записи, без '
                  'фотографий. Для переноса используйте Excel или CSV.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final file = await ref.read(backupServiceProvider).saveBackup();
    if (!context.mounted) return;
    _snack(
      context,
      file == null ? 'Сохранение отменено' : 'Копия сохранена',
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Заменить текущий список?'),
        content: const Text(
          'Все записи, которых нет в копии, будут удалены. '
          'Отменить это нельзя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Заменить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final restored = await ref.read(backupServiceProvider).restoreBackup();
    if (!context.mounted) return;
    _snack(
      context,
      restored == null
          ? 'Восстановление отменено'
          : restored.isEmpty
              ? 'В копии нет записей'
              : 'Восстановлено записей: ${restored.length}',
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// Тело диалога с итогами импорта.
class _ImportReport extends StatelessWidget {
  const _ImportReport({required this.result});

  final ImportResult result;

  @override
  Widget build(BuildContext context) {
    final rows = <String>[
      'Добавлено: ${result.createdCount}',
      'Обновлено: ${result.updatedCount}',
      'Пропущено: ${result.skippedCount}',
      if (result.hasErrors) 'Ошибок: ${result.errors.length}',
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(row),
          ),
        if (result.hasErrors) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final e in result.errors)
                  Text(e.toString(),
                      style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
