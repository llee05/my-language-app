import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

typedef MigrationStep = Future<void> Function(Database db);

const int databaseSchemaVersion = 4;

/// Each entry upgrades the database from `version - 1` to `version`.
final Map<int, MigrationStep> databaseMigrations = {
  2: (db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lessons_theme_hsk '
      'ON lessons(theme COLLATE NOCASE, hsk_level)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cards_lesson_id ON cards(lesson_id)',
    );
  },
  3: (db) async {
    await db.execute('''
      CREATE TABLE learner_profiles (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        name TEXT NOT NULL,
        hsk_level INTEGER NOT NULL CHECK (hsk_level BETWEEN 1 AND 6),
        daily_word_target INTEGER NOT NULL CHECK (daily_word_target > 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE learner_settings (
        learner_id INTEGER PRIMARY KEY,
        show_pinyin INTEGER NOT NULL DEFAULT 1,
        sound_enabled INTEGER NOT NULL DEFAULT 1,
        reminder_enabled INTEGER NOT NULL DEFAULT 0,
        reminder_hour INTEGER NOT NULL DEFAULT 18,
        FOREIGN KEY (learner_id) REFERENCES learner_profiles (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE lesson_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        learner_id INTEGER NOT NULL,
        lesson_id INTEGER NOT NULL,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        current_card_index INTEGER NOT NULL DEFAULT 0,
        cards_reviewed INTEGER NOT NULL DEFAULT 0,
        correct_answers INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (learner_id) REFERENCES learner_profiles (id) ON DELETE CASCADE,
        FOREIGN KEY (lesson_id) REFERENCES lessons (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE review_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        learner_id INTEGER NOT NULL,
        card_id INTEGER NOT NULL,
        session_id INTEGER,
        reviewed_at TEXT NOT NULL,
        rating INTEGER NOT NULL CHECK (rating BETWEEN 0 AND 3),
        was_correct INTEGER NOT NULL,
        response_time_ms INTEGER,
        FOREIGN KEY (learner_id) REFERENCES learner_profiles (id) ON DELETE CASCADE,
        FOREIGN KEY (card_id) REFERENCES cards (id) ON DELETE CASCADE,
        FOREIGN KEY (session_id) REFERENCES lesson_sessions (id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE card_progress (
        learner_id INTEGER NOT NULL,
        card_id INTEGER NOT NULL,
        repetitions INTEGER NOT NULL DEFAULT 0,
        lapses INTEGER NOT NULL DEFAULT 0,
        interval_days INTEGER NOT NULL DEFAULT 0,
        ease_factor REAL NOT NULL DEFAULT 2.5,
        due_at TEXT NOT NULL,
        last_reviewed_at TEXT,
        PRIMARY KEY (learner_id, card_id),
        FOREIGN KEY (learner_id) REFERENCES learner_profiles (id) ON DELETE CASCADE,
        FOREIGN KEY (card_id) REFERENCES cards (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_sessions_learner_started '
      'ON lesson_sessions(learner_id, started_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_reviews_card_date '
      'ON review_history(card_id, reviewed_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_progress_due ON card_progress(learner_id, due_at)',
    );

    final legacyRows = await db.query(
      'app_data',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['learner_profile'],
      limit: 1,
    );
    if (legacyRows.isNotEmpty && legacyRows.single['value'] != null) {
      try {
        final profile =
            jsonDecode(legacyRows.single['value'] as String)
                as Map<String, dynamic>;
        final name = profile['name'];
        final hskLevel = profile['hskLevel'];
        final dailyTarget = profile['dailyWordTarget'];
        if (name is String &&
            name.trim().isNotEmpty &&
            hskLevel is int &&
            hskLevel >= 1 &&
            hskLevel <= 6 &&
            dailyTarget is int &&
            dailyTarget > 0) {
          final now = DateTime.now().toUtc().toIso8601String();
          await db.insert('learner_profiles', {
            'id': 1,
            'name': name.trim(),
            'hsk_level': hskLevel,
            'daily_word_target': dailyTarget,
            'created_at': now,
            'updated_at': now,
          });
        }
      } on FormatException {
        // Invalid legacy data is treated as incomplete onboarding.
      } on TypeError {
        // Invalid legacy data is treated as incomplete onboarding.
      }
    }
  },
  4: (db) async {
    await db.execute(
      'ALTER TABLE card_progress '
      'ADD COLUMN times_seen INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE card_progress '
      'ADD COLUMN correct_answers INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE card_progress '
      'ADD COLUMN incorrect_answers INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE card_progress '
      'ADD COLUMN mastery REAL NOT NULL DEFAULT 0',
    );

    // Existing installations already have the source-of-truth review events.
    // Backfill the new summary columns rather than losing that history.
    await db.execute('''
      UPDATE card_progress
      SET times_seen = (
            SELECT COUNT(*)
            FROM review_history
            WHERE review_history.learner_id = card_progress.learner_id
              AND review_history.card_id = card_progress.card_id
          ),
          correct_answers = (
            SELECT COUNT(*)
            FROM review_history
            WHERE review_history.learner_id = card_progress.learner_id
              AND review_history.card_id = card_progress.card_id
              AND review_history.was_correct = 1
          ),
          incorrect_answers = (
            SELECT COUNT(*)
            FROM review_history
            WHERE review_history.learner_id = card_progress.learner_id
              AND review_history.card_id = card_progress.card_id
              AND review_history.was_correct = 0
          ),
          mastery = CASE
            WHEN (
              SELECT COUNT(*)
              FROM review_history
              WHERE review_history.learner_id = card_progress.learner_id
                AND review_history.card_id = card_progress.card_id
            ) = 0 THEN 0
            ELSE CAST((
              SELECT COUNT(*)
              FROM review_history
              WHERE review_history.learner_id = card_progress.learner_id
                AND review_history.card_id = card_progress.card_id
                AND review_history.was_correct = 1
            ) AS REAL) / (
              SELECT COUNT(*)
              FROM review_history
              WHERE review_history.learner_id = card_progress.learner_id
                AND review_history.card_id = card_progress.card_id
            )
          END
    ''');
  },
};

Future<void> migrateDatabase(
  Database db, {
  required int fromVersion,
  required int toVersion,
}) async {
  if (fromVersion > toVersion) {
    throw StateError(
      'Database downgrade is not supported: $fromVersion → $toVersion.',
    );
  }

  for (var version = fromVersion + 1; version <= toVersion; version++) {
    final migration = databaseMigrations[version];
    if (migration == null) {
      throw StateError(
        'Missing database migration for schema version $version.',
      );
    }
    await migration(db);
  }
}
