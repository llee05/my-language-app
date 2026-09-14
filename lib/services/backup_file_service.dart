import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

abstract interface class BackupFileService {
  Future<bool> saveBackup({required String fileName, required Uint8List bytes});

  Future<Uint8List?> chooseBackup();
}

class FilePickerBackupFileService implements BackupFileService {
  const FilePickerBackupFileService();

  static const _maxBackupBytes = 50 * 1024 * 1024;

  @override
  Future<bool> saveBackup({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Export TingShuo backup',
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    return uri != null;
  }

  @override
  Future<Uint8List?> chooseBackup() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose a TingShuo backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file != null && await file.length() > _maxBackupBytes) {
      throw StateError('The selected backup is too large.');
    }
    return file?.readAsBytes();
  }
}
