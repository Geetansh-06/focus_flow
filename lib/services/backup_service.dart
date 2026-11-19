
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../database/database_helper.dart';

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  // EXPORT BACKUP
  Future<String> exportBackup() async {
    try {
      final backupData =
      await DatabaseHelper.instance.exportBackupData();

      final jsonString = const JsonEncoder.withIndent('  ')
          .convert(backupData);

      final bytes = Uint8List.fromList(
        utf8.encode(jsonString),
      );

      final result = await FilePicker.saveFile(
        dialogTitle: 'Save FocusFlow Backup',
        fileName:
        'focusflow_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        bytes: bytes,
        mimeType: 'application/json',
      );

      if (result == null) {
        return 'cancelled';
      }

      return 'success';
    } catch (e) {
      throw Exception('Backup export failed: $e');
    }
  }

  // IMPORT / RESTORE BACKUP
  // true = restored successfully
  // false = user cancelled file picker
  Future<bool> restoreBackup() async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Select FocusFlow Backup',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      // User cancelled file selection.
      if (file == null) {
        return false;
      }

      // Check selected file extension.
      if (!file.name.toLowerCase().endsWith('.json')) {
        throw const FormatException(
          'Please select a valid JSON backup file.',
        );
      }

      // Read selected file.
      final fileBytes = await file.readAsBytes();

      if (fileBytes.isEmpty) {
        throw const FormatException(
          'Selected backup file is empty.',
        );
      }

      // Convert bytes into JSON.
      final jsonString = utf8.decode(fileBytes);
      final decodedData = jsonDecode(jsonString);

      // Check JSON structure.
      if (decodedData is! Map<String, dynamic>) {
        throw const FormatException(
          'Invalid backup file format.',
        );
      }

      // Validate and restore database backup.
      // DatabaseHelper performs app name, version and
      // table structure validation before restoring.
      await DatabaseHelper.instance.restoreBackupData(
        decodedData,
      );

      return true;
    } on FormatException {
      rethrow;
    } catch (e) {
      throw Exception('Backup restore failed: $e');
    }
  }
}
