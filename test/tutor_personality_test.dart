import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/local_database.dart';
import 'package:mylanguageapp/models/tutor_personality.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';
import 'package:mylanguageapp/repositories/tutor_personality_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const custom = TutorPersonality(
    id: 'custom_chef',
    name: 'Chef Lin',
    description: 'Learn through cooking.',
    instructions: 'Be a cheerful chef and teach food vocabulary.',
  );

  test('parses fenced AI profiles and ignores an AI-supplied ID', () {
    final profile = TutorPersonality.fromAiResponse(
      '```json\n${jsonEncode({...custom.toJson(), 'id': 'long_laoshi'})}\n```',
      id: 'custom_local',
    );
    expect(profile.id, 'custom_local');
    expect(profile.name, 'Chef Lin');
  });

  test('rejects malformed, empty, mistyped, or excessive AI fields', () {
    for (final response in [
      'not json',
      '[]',
      '{}',
      jsonEncode({...custom.toJson(), 'name': 4}),
      jsonEncode({...custom.toJson(), 'description': '  '}),
      jsonEncode({...custom.toJson(), 'instructions': 'x' * 1501}),
    ]) {
      expect(
        () => TutorPersonality.fromAiResponse(response, id: 'custom_local'),
        throwsFormatException,
      );
    }
  });

  test('saved library rejects collisions and built-in impersonation', () {
    for (final entries in [
      [custom.toJson(), custom.toJson()],
      [TutorPersonality.builtIns.first.toJson()],
      List.generate(31, (i) => {...custom.toJson(), 'id': 'custom_$i'}),
    ]) {
      expect(
        () => TutorPersonalityLibrary.fromJson({
          'selectedId': 'long_laoshi',
          'custom': entries,
        }),
        throwsFormatException,
      );
    }
    expect(
      TutorPersonalityLibrary(selectedId: 'missing').selected.id,
      'long_laoshi',
    );
  });

  group('local personality storage', () {
    const repository = SqliteTutorPersonalityRepository();
    late Directory directory;

    setUp(() async {
      await LocalDatabase.close();
      directory = await Directory.systemTemp.createTemp('tutor_personalities_');
      LocalDatabase.useDatabasePathForTesting('${directory.path}/test.db');
    });
    tearDown(() async {
      await LocalDatabase.close();
      LocalDatabase.useDatabasePathForTesting(inMemoryDatabasePath);
      await directory.delete(recursive: true);
    });

    test(
      'persists through reopen and onboarding reset; full reset removes it',
      () async {
        expect((await repository.load()).selected.id, 'long_laoshi');
        await repository.save(
          TutorPersonalityLibrary(selectedId: custom.id, custom: [custom]),
        );
        await LocalDatabase.close();
        var restored = await repository.load();
        expect(restored.selected.instructions, custom.instructions);
        await const SqliteLearnerRepository().resetOnboarding();
        restored = await repository.load();
        expect(restored.custom.single.name, 'Chef Lin');
        await LocalDatabase.resetAllData();
        restored = await repository.load();
        expect(restored.custom, isEmpty);
        expect(restored.selected.id, 'long_laoshi');
      },
    );

    test('invalid writes preserve the previous library', () async {
      await repository.save(
        TutorPersonalityLibrary(selectedId: custom.id, custom: [custom]),
      );
      await expectLater(
        repository.save(TutorPersonalityLibrary(custom: [custom, custom])),
        throwsFormatException,
      );
      expect((await repository.load()).custom.length, 1);
    });
  });
}
