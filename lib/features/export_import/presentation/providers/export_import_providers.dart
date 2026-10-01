import 'package:birthday_calendar/core/providers/database_provider.dart';
import 'package:birthday_calendar/features/birthdays/domain/birthday_query.dart';
import 'package:birthday_calendar/features/export_import/data/birthday_importer.dart';
import 'package:birthday_calendar/features/export_import/data/csv_exporter.dart';
import 'package:birthday_calendar/features/export_import/data/excel_exporter.dart';
import 'package:birthday_calendar/features/export_import/data/file_export_service.dart';
import 'package:birthday_calendar/features/export_import/data/import_parser.dart';
import 'package:birthday_calendar/features/export_import/data/import_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Единственный экземпляр файлового сервиса.
final Provider<FileExportService> fileExportServiceProvider =
    Provider<FileExportService>((ref) => const FileExportService());

/// Импортер, собранный на том же репозитории, что и экраны.
final Provider<BirthdayImporter> birthdayImporterProvider =
    Provider<BirthdayImporter>(
  (ref) => BirthdayImporter(ref.watch(birthdayRepositoryProvider)),
);

/// Состояние операций обмена файлами.
class TransferState {
  const TransferState({this.busy = false, this.lastResult});

  final bool busy;

  /// Последний результат импорта — для показа отчёта.
  final ImportResult? lastResult;
}

/// Управляет экспортом и импортом.
class TransferController extends Notifier<TransferState> {
  @override
  TransferState build() => const TransferState();

  /// Выгружает все записи в выбранном формате.
  ///
  /// Возвращает `null`, если пользователь отказался от сохранения.
  Future<ExportResult?> exportAll(ExportFormat format) async {
    if (state.busy) return null;
      state = const TransferState(busy: true);

    try {
      final repository = ref.read(birthdayRepositoryProvider);
      final service = ref.read(fileExportServiceProvider);

      final all = await repository.list(
        query: const BirthdayQuery(sort: BirthdaySort.byCalendarDate),
      );
      final birthdays = all.map((i) => i.birthday).toList();

      final result = await service.exportAndShare(
        excel: ExcelExporter.createWorkbook(birthdays),
        csv: CsvExporter.build(birthdays),
        format: format,
      );
      return result;
    } finally {
      state = const TransferState();
    }
  }

  /// Открывает файл, разбирает и импортирует его.
  ///
  /// Возвращает отчёт или `null`, если файл не был выбран либо не
  /// распознан как Excel/CSV.
  Future<ImportResult?> importFromFile() async {
    if (state.busy) return null;
    state = const TransferState(busy: true);

    try {
      final service = ref.read(fileExportServiceProvider);
      final importer = ref.read(birthdayImporterProvider);

      final bytes = await service.pickAndRead(
        extensions: ['xlsx', 'csv', 'txt'],
        label: 'Дни рождения',
      );
      if (bytes == null) return null;

      final parsed = ImportParser.parse(FileExportService.readTable(bytes));

      final result = await importer.import(parsed);
      state = TransferState(lastResult: result);
      return result;
    } finally {
      if (state.busy) state = TransferState(lastResult: state.lastResult);
    }
  }

}

final NotifierProvider<TransferController, TransferState>
    transferControllerProvider =
    NotifierProvider<TransferController, TransferState>(
  TransferController.new,
);
