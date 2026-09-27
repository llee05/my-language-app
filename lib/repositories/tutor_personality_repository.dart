import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../local_database.dart';
import '../models/tutor_personality.dart';

abstract interface class TutorPersonalityRepository {
  Future<TutorPersonalityLibrary> load();
  Future<void> save(TutorPersonalityLibrary library);
}

/// Uses the existing local key/value table; full data reset removes profiles.
class SqliteTutorPersonalityRepository implements TutorPersonalityRepository {
  const SqliteTutorPersonalityRepository();

  static const _key = 'tutor_personalities';

  @override
  Future<TutorPersonalityLibrary> load() => LocalDatabase.use((db) async {
    final rows = await db.query(
      'app_data',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_key],
      limit: 1,
    );
    if (rows.isEmpty) return TutorPersonalityLibrary();
    final decoded = jsonDecode(rows.single['value'] as String);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid saved personalities.');
    }
    return TutorPersonalityLibrary.fromJson(decoded);
  });

  @override
  Future<void> save(TutorPersonalityLibrary library) async {
    final validated = TutorPersonalityLibrary.fromJson(library.toJson());
    await LocalDatabase.use((db) async {
      await db.insert('app_data', {
        'key': _key,
        'value': jsonEncode(validated.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
