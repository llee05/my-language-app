import 'dart:convert';
import 'dart:typed_data';

import '../database/migrations.dart';
import '../local_database.dart';

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupPreview {
  const BackupPreview({
    required this.exportedAt,
    required this.learnerName,
    required this.hskLevel,
    required this.lessonCount,
    required this.cardCount,
    required this.reviewCount,
    required this.sessionCount,
  });

  final DateTime exportedAt;
  final String learnerName;
  final int hskLevel;
  final int lessonCount;
  final int cardCount;
  final int reviewCount;
  final int sessionCount;
}

abstract interface class BackupRepository {
  Future<Uint8List> exportBackup();
  BackupPreview previewBackup(Uint8List bytes);
  Future<void> restoreBackup(Uint8List bytes);
}

class SqliteBackupRepository implements BackupRepository {
  const SqliteBackupRepository([this._clock]);

  static const _format = 'tingshuo-backup';
  static const _formatVersion = 1;
  static const _maxBackupBytes = 50 * 1024 * 1024;
  static const _optionalColumnDefaults = <String, Object?>{
    'lessons.is_sentence_practice': 0,
    'learner_settings.button_animation_style': 'combined',
  };

  final DateTime Function()? _clock;

  static const Map<String, List<String>> _columns = {
    'learner_profiles': [
      'id',
      'name',
      'hsk_level',
      'daily_word_target',
      'created_at',
      'updated_at',
    ],
    'learner_settings': [
      'learner_id',
      'show_pinyin',
      'sound_enabled',
      'reminder_enabled',
      'reminder_hour',
      'pronunciation_engine',
      'pronunciation_voice_id',
      'kokoro_voice_ids',
      'theme_id',
      'button_animation_style',
    ],
    'lessons': [
      'id',
      'lesson_title',
      'theme',
      'hsk_level',
      'is_listed',
      'is_sentence_practice',
    ],
    'cards': [
      'id',
      'lesson_id',
      'chinese',
      'pinyin',
      'english_meaning',
      'part_of_speech',
      'hsk_level',
      'example_sentence_chinese',
      'example_sentence_pinyin',
      'example_sentence_english',
      'quiz_options',
      'correct_answer',
      'example_source',
      'example_source_id',
      'example_translation_id',
    ],
    'lesson_sessions': [
      'id',
      'learner_id',
      'lesson_id',
      'started_at',
      'completed_at',
      'current_card_index',
      'cards_reviewed',
      'correct_answers',
    ],
    'review_history': [
      'id',
      'learner_id',
      'card_id',
      'session_id',
      'reviewed_at',
      'rating',
      'was_correct',
      'response_time_ms',
      'submission_key',
    ],
    'card_progress': [
      'learner_id',
      'card_id',
      'repetitions',
      'lapses',
      'interval_days',
      'ease_factor',
      'due_at',
      'last_reviewed_at',
      'times_seen',
      'correct_answers',
      'incorrect_answers',
      'mastery',
    ],
    'daily_review_sessions': [
      'id',
      'learner_id',
      'session_date',
      'queued_card_ids',
      'current_position',
      'completed_at',
    ],
  };

  @override
  Future<Uint8List> exportBackup() => LocalDatabase.use((db) async {
    final tables = await db.transaction((txn) async {
      final result = <String, List<Map<String, Object?>>>{};
      for (final entry in _columns.entries) {
        result[entry.key] = await txn.query(
          entry.key,
          columns: entry.value,
          orderBy: _orderByFor(entry.key),
        );
      }
      return result;
    });
    final profiles = tables['learner_profiles']!;
    if (profiles.length != 1) {
      throw StateError('Complete learner setup before creating a backup.');
    }
    final document = <String, Object?>{
      'format': _format,
      'formatVersion': _formatVersion,
      'databaseSchemaVersion': databaseSchemaVersion,
      'exportedAt': (_clock?.call() ?? DateTime.now())
          .toUtc()
          .toIso8601String(),
      'data': tables,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(document)));
  });

  @override
  BackupPreview previewBackup(Uint8List bytes) {
    final snapshot = _decode(bytes);
    return snapshot.preview;
  }

  @override
  Future<void> restoreBackup(Uint8List bytes) async {
    final snapshot = _decode(bytes);
    await LocalDatabase.use((db) async {
      await db.transaction((txn) async {
        for (final table in const [
          'daily_review_sessions',
          'review_history',
          'card_progress',
          'lesson_sessions',
          'learner_settings',
          'learner_profiles',
          'cards',
          'lessons',
        ]) {
          await txn.delete(table);
        }

        for (final table in const [
          'lessons',
          'cards',
          'learner_profiles',
          'learner_settings',
          'lesson_sessions',
          'review_history',
          'card_progress',
          'daily_review_sessions',
        ]) {
          for (final row in snapshot.tables[table]!) {
            await txn.insert(table, row);
          }
        }

        // A restored profile should open directly even if onboarding had been
        // reset on this installation before the import.
        await txn.delete(
          'app_data',
          where: 'key = ?',
          whereArgs: ['onboarding_required'],
        );
      });
    });
  }

  _BackupSnapshot _decode(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > _maxBackupBytes) {
      throw const BackupFormatException(
        'This backup file is empty or too large.',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const BackupFormatException('This is not a valid TingShuo backup.');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != _format ||
        decoded['formatVersion'] != _formatVersion) {
      throw const BackupFormatException(
        'This backup format is not supported by this version of TingShuo.',
      );
    }

    final exportedAtRaw = decoded['exportedAt'];
    final rawData = decoded['data'];
    if (exportedAtRaw is! String || rawData is! Map<String, dynamic>) {
      throw const BackupFormatException('This TingShuo backup is incomplete.');
    }
    final exportedAt = DateTime.tryParse(exportedAtRaw);
    if (exportedAt == null) {
      throw const BackupFormatException(
        'This TingShuo backup has an invalid date.',
      );
    }

    final tables = <String, List<Map<String, Object?>>>{};
    for (final entry in _columns.entries) {
      final rawRows = rawData[entry.key];
      if (rawRows is! List) {
        throw const BackupFormatException(
          'This TingShuo backup is incomplete.',
        );
      }
      final rows = <Map<String, Object?>>[];
      for (final rawRow in rawRows) {
        if (rawRow is! Map<String, dynamic> ||
            entry.value.any(
              (column) =>
                  !rawRow.containsKey(column) &&
                  !_optionalColumnDefaults.containsKey('${entry.key}.$column'),
            )) {
          throw const BackupFormatException(
            'This TingShuo backup contains invalid records.',
          );
        }
        rows.add({
          for (final column in entry.value)
            column:
                rawRow[column] ??
                _optionalColumnDefaults['${entry.key}.$column'],
        });
      }
      tables[entry.key] = rows;
    }

    final profiles = tables['learner_profiles']!;
    if (profiles.length != 1) {
      throw const BackupFormatException(
        'This backup does not contain one complete learner profile.',
      );
    }
    final profile = profiles.single;
    final name = profile['name'];
    final hskLevel = profile['hsk_level'];
    final dailyTarget = profile['daily_word_target'];
    if (profile['id'] != 1 ||
        name is! String ||
        name.trim().isEmpty ||
        hskLevel is! int ||
        hskLevel < 1 ||
        hskLevel > 6 ||
        dailyTarget is! int ||
        dailyTarget <= 0 ||
        tables['learner_settings']!.length > 1) {
      throw const BackupFormatException(
        'This backup contains an invalid learner profile or settings.',
      );
    }

    return _BackupSnapshot(
      tables: tables,
      preview: BackupPreview(
        exportedAt: exportedAt,
        learnerName: name.trim(),
        hskLevel: hskLevel,
        lessonCount: tables['lessons']!.length,
        cardCount: tables['cards']!.length,
        reviewCount: tables['review_history']!.length,
        sessionCount:
            tables['lesson_sessions']!.length +
            tables['daily_review_sessions']!.length,
      ),
    );
  }

  static String _orderByFor(String table) {
    if (table == 'card_progress' || table == 'learner_settings') {
      return 'learner_id ASC';
    }
    return 'id ASC';
  }
}

class _BackupSnapshot {
  const _BackupSnapshot({required this.tables, required this.preview});

  final Map<String, List<Map<String, Object?>>> tables;
  final BackupPreview preview;
}
