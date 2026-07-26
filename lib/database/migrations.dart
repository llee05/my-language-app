import 'package:sqflite_common_ffi/sqflite_ffi.dart';

typedef MigrationStep = Future<void> Function(Database db);

const int databaseSchemaVersion = 2;

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
