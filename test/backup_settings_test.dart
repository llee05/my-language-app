import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/backup_repository.dart';
import 'package:mylanguageapp/repositories/development_repository.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';
import 'package:mylanguageapp/services/backup_file_service.dart';

void main() {
  const profile = LearnerProfile(
    name: 'Current learner',
    hskLevel: 2,
    dailyWordTarget: 10,
  );

  Future<void> pumpSettings(
    WidgetTester tester, {
    required _MemoryBackupRepository backups,
    required _MemoryBackupFileService files,
    Future<void> Function()? onBackupRestored,
    Future<void> Function()? onResetAllData,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            profile: profile,
            onProfileChanged: (_) async {},
            onResetOnboarding: () async {},
            onResetAllData: onResetAllData ?? () async {},
            onBackupRestored: onBackupRestored,
            appThemeId: AppThemeId.classic,
            onThemeChanged: (_) {},
            developmentRepository: const _DevelopmentRepository(),
            settingsRepository: _SettingsRepository(),
            backupRepository: backups,
            backupFileService: files,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Key key) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(key)),
      alignment: .5,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a backup preview before restoring', (tester) async {
    final backups = _MemoryBackupRepository();
    final files = _MemoryBackupFileService();
    var reloadCalls = 0;
    await pumpSettings(
      tester,
      backups: backups,
      files: files,
      onBackupRestored: () async => reloadCalls++,
    );

    await reveal(tester, const Key('settings-import-backup'));
    expect(find.textContaining('API keys are never included'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-import-backup')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('backup-preview-dialog')), findsOneWidget);
    expect(find.text('Backup learner · HSK 4'), findsOneWidget);
    expect(find.text('12 lessons · 240 cards'), findsOneWidget);
    expect(find.text('83 reviews · 7 sessions'), findsOneWidget);
    expect(backups.restoreCalls, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(backups.restoreCalls, 0);

    await tester.tap(find.byKey(const Key('settings-import-backup')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('backup-restore-confirm')));
    await tester.pumpAndSettle();

    expect(backups.restoreCalls, 1);
    expect(reloadCalls, 1);
    expect(find.text('Backup restored.'), findsOneWidget);
  });

  testWidgets('exports the generated backup through the file service', (
    tester,
  ) async {
    final backups = _MemoryBackupRepository();
    final files = _MemoryBackupFileService();
    await pumpSettings(tester, backups: backups, files: files);

    await reveal(tester, const Key('settings-export-backup'));
    await tester.tap(find.byKey(const Key('settings-export-backup')));
    await tester.pumpAndSettle();

    expect(backups.exportCalls, 1);
    expect(files.savedBytes, backups.bytes);
    expect(files.savedName, startsWith('tingshuo-backup-'));
    expect(files.savedName, endsWith('.json'));
    expect(find.text('Backup exported.'), findsOneWidget);
  });

  testWidgets('invalid backups never reach confirmation or restore', (
    tester,
  ) async {
    final backups = _MemoryBackupRepository()
      ..previewError = const BackupFormatException('Invalid backup file.');
    await pumpSettings(
      tester,
      backups: backups,
      files: _MemoryBackupFileService(),
    );
    await reveal(tester, const Key('settings-import-backup'));
    await tester.tap(find.byKey(const Key('settings-import-backup')));
    await tester.pumpAndSettle();
    expect(find.text('Invalid backup file.'), findsOneWidget);
    expect(find.byKey(const Key('backup-preview-dialog')), findsNothing);
    expect(backups.restoreCalls, 0);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('settings-import-backup')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('failed restore stays retryable and does not report success', (
    tester,
  ) async {
    final backups = _MemoryBackupRepository()
      ..restoreError = StateError('write failed');
    var reloads = 0;
    await pumpSettings(
      tester,
      backups: backups,
      files: _MemoryBackupFileService(),
      onBackupRestored: () async => reloads++,
    );
    await reveal(tester, const Key('settings-import-backup'));
    for (final fails in [true, false]) {
      await tester.tap(find.byKey(const Key('settings-import-backup')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('backup-restore-confirm')));
      await tester.pumpAndSettle();
      if (fails) {
        expect(
          find.text(
            'We couldn’t restore this backup. Your data was not changed.',
          ),
          findsOneWidget,
        );
        expect(find.text('Backup restored.'), findsNothing);
        expect(reloads, 0);
        backups.restoreError = null;
      } else {
        expect(find.text('Backup restored.'), findsOneWidget);
        expect(reloads, 1);
      }
    }
    expect(backups.restoreCalls, 2);
  });

  for (final fails in [false, true]) {
    testWidgets(
      'export ${fails ? 'failure' : 'cancellation'} never reports success and allows retry',
      (tester) async {
        final files = _MemoryBackupFileService()
          ..saveResult = false
          ..saveError = fails ? StateError('file unavailable') : null;
        await pumpSettings(
          tester,
          backups: _MemoryBackupRepository(),
          files: files,
        );
        await reveal(tester, const Key('settings-export-backup'));
        await tester.tap(find.byKey(const Key('settings-export-backup')));
        await tester.pumpAndSettle();
        expect(find.text('Backup exported.'), findsNothing);
        if (fails) {
          expect(find.text('We couldn’t export your backup.'), findsOneWidget);
        }
        files.saveResult = true;
        files.saveError = null;
        await tester.tap(find.byKey(const Key('settings-export-backup')));
        await tester.pumpAndSettle();
        expect(find.text('Backup exported.'), findsOneWidget);
      },
    );
  }

  for (final action in ['export', 'import']) {
    testWidgets('account reset waits for a pending backup $action', (
      tester,
    ) async {
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      final backups = _MemoryBackupRepository();
      final files = _MemoryBackupFileService()..fileOperationGate = gate;
      var resets = 0;
      await pumpSettings(
        tester,
        backups: backups,
        files: files,
        onResetAllData: () async => resets++,
      );
      await reveal(tester, const Key('settings-reset-all'));
      final reset = find.byKey(const Key('settings-reset-all'));
      final resetAction = tester.widget<OutlinedButton>(reset).onPressed!;
      await reveal(tester, Key('settings-$action-backup'));
      await tester.tap(find.byKey(Key('settings-$action-backup')));
      await tester.pump();

      expect(tester.widget<OutlinedButton>(reset).onPressed, isNull);
      resetAction();
      await tester.pump();
      expect(find.text('Reset your account?'), findsNothing);
      expect(resets, 0);

      gate.complete();
      if (action == 'import') {
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('Cancel'));
      }
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(reset).onPressed, isNotNull);
      expect(resets, 0);
    });
  }
}

class _MemoryBackupRepository implements BackupRepository {
  final bytes = Uint8List.fromList([1, 2, 3]);
  int exportCalls = 0;
  int restoreCalls = 0;
  Object? previewError;
  Object? restoreError;

  @override
  Future<Uint8List> exportBackup() async {
    exportCalls++;
    return bytes;
  }

  @override
  BackupPreview previewBackup(Uint8List bytes) {
    if (previewError != null) throw previewError!;
    return BackupPreview(
      exportedAt: DateTime.utc(2026, 9, 13),
      learnerName: 'Backup learner',
      hskLevel: 4,
      lessonCount: 12,
      cardCount: 240,
      reviewCount: 83,
      sessionCount: 7,
    );
  }

  @override
  Future<void> restoreBackup(Uint8List bytes) async {
    restoreCalls++;
    if (restoreError != null) throw restoreError!;
  }
}

class _MemoryBackupFileService implements BackupFileService {
  Completer<void>? fileOperationGate;
  Uint8List? savedBytes;
  String? savedName;
  bool saveResult = true;
  Object? saveError;

  @override
  Future<Uint8List?> chooseBackup() async {
    await fileOperationGate?.future;
    return Uint8List.fromList([4, 5, 6]);
  }

  @override
  Future<bool> saveBackup({
    required String fileName,
    required Uint8List bytes,
  }) async {
    await fileOperationGate?.future;
    savedName = fileName;
    savedBytes = bytes;
    if (saveError != null) throw saveError!;
    return saveResult;
  }
}

class _DevelopmentRepository implements DevelopmentRepository {
  const _DevelopmentRepository();

  @override
  Future<String> databasePath() async => 'test.db';

  @override
  Future<void> resetAllData() async {}
}

class _SettingsRepository implements SettingsRepository {
  LearnerSettings settings = const LearnerSettings();

  @override
  Future<LearnerSettings> load() async => settings;

  @override
  Future<void> save(LearnerSettings settings) async {
    this.settings = settings;
  }
}
