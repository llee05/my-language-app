import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/database/migrations.dart';
import 'package:mylanguageapp/local_database.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/backup_repository.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';
import 'package:mylanguageapp/services/review_scheduler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _lessons = SqliteLessonRepository();
const _progress = SqliteProgressRepository();
const _learners = SqliteLearnerRepository();
const _settings = SqliteSettingsRepository();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    await LocalDatabase.close();
    directory = await Directory.systemTemp.createTemp('sentence_practice_');
    LocalDatabase.useDatabasePathForTesting('${directory.path}/test.db');
    await LocalDatabase.ensureInitialized();
    await _learners.save(
      const LearnerProfile(name: 'Mei', hskLevel: 1, dailyWordTarget: 10),
    );
  });

  tearDown(() async {
    await LocalDatabase.close();
    LocalDatabase.useDatabasePathForTesting(inMemoryDatabasePath);
    await directory.delete(recursive: true);
  });

  test(
    'bundles exactly 100 unique sentences with pinyin and translations',
    () async {
      final decks =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/data/sentence_practice.json',
                ),
              )
              as List<dynamic>;
      expect(decks, hasLength(10));
      final chinese = <String>{};
      for (final deck in decks) {
        expect(deck['topic'], isNotEmpty);
        expect(deck['sentences'], hasLength(10));
        for (final sentence in deck['sentences']) {
          expect(chinese.add(sentence['chinese'] as String), isTrue);
          expect(sentence['chinese'], matches(RegExp(r'[。？！]$')));
          expect(
            sentence['pinyin'],
            matches(RegExp('[āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]')),
          );
          expect(sentence['english'], isNotEmpty);
        }
      }
      expect(chinese, hasLength(100));
      final installed = (await _lessons.topics()).where(
        (s) => s.isSentencePractice,
      );
      expect(installed, hasLength(10));
      for (final summary in installed) {
        final lesson = (await _lessons.findById(summary.id))!;
        expect(lesson.cards, hasLength(10));
        expect(
          lesson.cards.every((c) => c.id > 0 && c.partOfSpeech == 'sentence'),
          isTrue,
        );
        expect(
          await _lessons.findGenerated(theme: summary.theme, hskLevel: 3),
          isNull,
        );
      }
    },
  );

  test(
    'version 13 upgrade and repeated startup preserve sentence progress',
    () async {
      final db = await LocalDatabase.ensureInitialized();
      final original = (await _lessons.topics()).firstWhere(
        (s) => !s.isSentencePractice,
      );
      final originalLesson = await _lessons.findById(original.id);
      // Reconstruct the immediately previous schema in this temporary database.
      await db.delete(
        'cards',
        where:
            'lesson_id IN (SELECT id FROM lessons WHERE is_sentence_practice = 1)',
      );
      await db.delete('lessons', where: 'is_sentence_practice = 1');
      await db.execute('ALTER TABLE lessons DROP COLUMN is_sentence_practice');
      await db.setVersion(13);
      await LocalDatabase.close();
      final upgraded = await LocalDatabase.ensureInitialized();
      expect(await upgraded.getVersion(), databaseSchemaVersion);
      expect(
        (await _lessons.findById(original.id))!.cards.first.id,
        originalLesson!.cards.first.id,
      );
      final summary = (await _lessons.topics()).firstWhere(
        (s) => s.isSentencePractice,
      );
      final lesson = (await _lessons.findById(summary.id))!;
      final session = await _progress.startSession(summary.id);
      final now = DateTime.utc(2026, 9, 20);
      final card = lesson.cards.first;
      await _progress.recordReview(
        review: ReviewRecord(
          id: 0,
          cardId: card.id,
          sessionId: session.id,
          reviewedAt: now,
          rating: ReviewRating.again,
          wasCorrect: false,
        ),
        progress: scheduleCardReview(
          cardId: card.id,
          rating: ReviewRating.again,
          reviewedAt: now,
        ),
      );
      await _progress.updateSession(
        LessonSession(
          id: session.id,
          lessonId: summary.id,
          startedAt: session.startedAt,
          currentCardIndex: 1,
          cardsReviewed: 1,
          correctAnswers: 0,
        ),
      );
      await LocalDatabase.close();
      await LocalDatabase.ensureInitialized();
      expect(
        (await _lessons.topics()).where((s) => s.isSentencePractice),
        hasLength(10),
      );
      expect(
        (await _lessons.findById(summary.id))!.cards.map((c) => c.id),
        lesson.cards.map((c) => c.id),
      );
      expect(
        (await _progress.activeSessionForLesson(summary.id))!.currentCardIndex,
        1,
      );
      expect(await _progress.reviewHistory(cardId: card.id), hasLength(1));
      final queue = await _progress.dailyQueue(
        forDay: now.add(const Duration(days: 1)),
        limit: 1000,
        maxHskLevel: 1,
      );
      expect(
        queue
            .where((q) => q.card.partOfSpeech == 'sentence')
            .map((q) => q.card.id),
        [card.id],
      );
    },
  );

  test(
    'backup preserves sentence decks and accepts the previous lesson format',
    () async {
      const backup = SqliteBackupRepository();
      final bytes = await backup.exportBackup();
      await backup.restoreBackup(bytes);
      expect(
        (await _lessons.topics()).where((s) => s.isSentencePractice),
        hasLength(10),
      );
      final document = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      for (final lesson in document['data']['lessons']) {
        lesson.remove('is_sentence_practice');
      }
      document['databaseSchemaVersion'] = 13;
      final legacy = Uint8List.fromList(utf8.encode(jsonEncode(document)));
      expect(backup.previewBackup(legacy).learnerName, 'Mei');
      await backup.restoreBackup(legacy);
      expect(
        (await _lessons.topics()).every((s) => !s.isSentencePractice),
        isTrue,
      );
    },
  );

  testWidgets(
    'sentence mode reveals answers, rates, resumes and completes a deck',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final voice = _Voice();
      final summary = await tester.runAsync(
        () async => (await _lessons.topics()).firstWhere(
          (s) =>
              s.isSentencePractice && s.theme == 'Greetings and introductions',
        ),
      );
      final lesson = (await tester.runAsync(
        () => _lessons.findById(summary!.id),
      ))!;
      await _pumpLessons(tester, voice);
      await tester.tap(find.byKey(const Key('sentence-practice-mode')));
      await tester.pumpAndSettle();
      expect(find.text('Generate lesson'), findsNothing);
      expect(
        find.byKey(const Key('lesson-library-level-filter')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const Key('lesson-library-search')),
        'Greetings',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await _waitFor(tester, find.text('1 / 10'));
      expect(find.text('Nǐ hǎo!'), findsNothing);
      await tester.tap(find.byTooltip('Hear Mandarin pronunciation').first);
      await tester.pumpAndSettle();
      expect(voice.spoken, ['你好！']);
      await tester.tap(find.text('你好！'));
      await tester.pumpAndSettle();
      expect(find.text('Nǐ hǎo!'), findsOneWidget);
      expect(find.text('Hello!'), findsOneWidget);
      await tester.tap(find.text('Again'));
      await _waitFor(tester, find.text('1 of 10 sentences completed'));
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpLessons(tester, voice, initialLessonId: summary!.id);
      await _waitFor(tester, find.text('Resumed at card 2.'));
      for (var i = 1; i < 10; i++) {
        await tester.tap(find.text(lesson.cards[i].chinese));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Good').hitTestable());
        await _waitFor(tester, find.text('${i + 1} of 10 sentences completed'));
      }
      expect(find.text('Lesson complete!'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
      final history = await tester.runAsync(() => _progress.reviewHistory());
      expect(history, hasLength(10));
      expect(
        await tester.runAsync(
          () => _progress.activeSessionForLesson(summary.id),
        ),
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'sentence ratings can retry a failed save without losing the card',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final summary = await tester.runAsync(
        () async =>
            (await _lessons.topics()).firstWhere((s) => s.isSentencePractice),
      );
      final progress = _FailOnceProgress();
      await _pumpLessons(
        tester,
        _Voice(),
        initialLessonId: summary!.id,
        progress: progress,
      );
      await _waitFor(tester, find.text('1 / 10'));
      await tester.tap(find.text('Tap for answer').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Easy').hitTestable());
      await _waitFor(tester, find.byKey(const Key('lesson-answer-error')));
      expect(find.text('0 of 10 sentences completed'), findsOneWidget);
      expect(await tester.runAsync(() => _progress.reviewHistory()), isEmpty);
      await tester.tap(find.byKey(const Key('lesson-answer-retry')));
      await _waitFor(tester, find.text('1 of 10 sentences completed'));
      final history = await tester.runAsync(() => _progress.reviewHistory());
      expect(history, hasLength(1));
      expect(history!.single.rating, ReviewRating.easy);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('long sentence answers fit a small screen with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final summary = await tester.runAsync(
      () async => (await _lessons.topics()).firstWhere(
        (s) =>
            s.isSentencePractice &&
            s.theme == 'Staying connected and getting help',
      ),
    );
    await _pumpLessons(
      tester,
      _Voice(),
      initialLessonId: summary!.id,
      textScale: 1.5,
    );
    await _waitFor(tester, find.text('你的电话号码是多少？'));
    await tester.ensureVisible(find.text('你的电话号码是多少？'));
    await tester.tap(find.text('你的电话号码是多少？'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Good'));
    await tester.pumpAndSettle();
    expect(find.text('Good').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Good').hitTestable());
    await _waitFor(tester, find.text('1 of 10 sentences completed'));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _pumpLessons(
  WidgetTester tester,
  _Voice voice, {
  int? initialLessonId,
  double textScale = 1,
  SqliteProgressRepository progress = _progress,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: LessonsPage(
          repository: _lessons,
          progressRepository: progress,
          settingsRepository: _settings,
          pronunciationService: voice,
          initialLessonId: initialLessonId,
        ),
      ),
    ),
  );
  if (initialLessonId == null) {
    await _waitFor(tester, find.byKey(const Key('lesson-library-content')));
  }
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  expect(finder, findsWidgets);
}

class _Voice implements PronunciationService {
  final spoken = <String>[];
  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates => const Stream.empty();
  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async =>
      const OfflineVoiceStatus.unavailable();
  @override
  Future<void> installOfflineVoice() async {}
  @override
  Future<void> speakMandarin(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _FailOnceProgress extends SqliteProgressRepository {
  bool fail = true;

  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async {
    if (fail) {
      fail = false;
      throw StateError('Temporary save failure');
    }
    await super.recordReview(review: review, progress: progress);
  }
}
