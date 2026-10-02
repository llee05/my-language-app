import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/lesson_repository.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';

void main() {
  for (final width in [390.0, 1000.0]) {
    testWidgets('default listening decks stay separate at width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final document =
          jsonDecode(
                File('assets/data/vocabulary_lessons.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final vocabulary = {
        for (final word
            in jsonDecode(
                  File('assets/data/hsk_vocabulary.json').readAsStringSync(),
                )
                as List)
          word['id']: word,
      };
      final lessons = <Lesson>[
        for (final (index, row) in (document['lessons'] as List).indexed)
          Lesson(
            summary: LessonSummary(
              id: index + 1,
              title: row['title'] as String,
              theme: 'HSK ${row['hskLevel']} vocabulary',
              hskLevel: row['hskLevel'] as int,
            ),
            cards: [
              for (final card in row['entries'] as List)
                Flashcard(
                  chinese:
                      vocabulary[card['vocabularyId']]['simplified'] as String,
                  pinyin: vocabulary[card['vocabularyId']]['pinyin'] as String,
                  englishMeaning:
                      vocabulary[card['vocabularyId']]['studyMeaning']
                          as String,
                ),
            ],
          ),
      ];
      final pronunciation = _ListeningPronunciationService();
      await tester.pumpWidget(
        MaterialApp(
          home: ListeningPracticePage(
            lessonRepository: _ListeningLessonRepository(lessons: lessons),
            progressRepository: const _ListeningProgressRepository(),
            settingsRepository: const _ListeningSettingsRepository(),
            maxHskLevel: 1,
            pronunciationService: pronunciation,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('8 lessons available'), findsOneWidget);
      expect(find.text('HSK 1 · Lesson 001'), findsOneWidget);
      expect(find.text('7/20'), findsOneWidget);
      expect(find.text('7 of 20 words learned'), findsOneWidget);
      final picker = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(picker.items, hasLength(10));
      expect(picker.items!.map((item) => item.value).toSet(), hasLength(10));

      final start = find.byKey(const Key('listening-start-practice'));
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.text('HSK 1 · Lesson 001 · 1 of 20'), findsOneWidget);
      for (var index = 0; index < 20; index++) {
        expect(
          pronunciation.requests.last.$1,
          lessons.first.cards[index].chinese,
        );
        final reveal = find.byKey(const Key('listening-reveal-answer'));
        await tester.ensureVisible(reveal);
        await tester.tap(reveal);
        await tester.pump();
        final next = find.byKey(const Key('listening-next'));
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(pronunciation.requests, hasLength(20));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final range = find.byKey(const Key('listening-hsk-range'));
      await tester.ensureVisible(range);
      await tester.tap(range);
      await tester.pumpAndSettle();
      await tester.tap(find.text('All levels').last);
      await tester.pumpAndSettle();
      expect(find.text('251 lessons available'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('listening-topic-search')),
        'HSK 6 · Lesson 125',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.text('HSK 6 · Lesson 125 · 1 of 20'), findsOneWidget);
      expect(pronunciation.requests.last.$1, lessons.last.cards.first.chinese);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Android Back stops listening and returns to topic selection', (
    tester,
  ) async {
    final pronunciation = _ListeningPronunciationService();
    await tester.pumpWidget(
      MaterialApp(
        home: ListeningPracticePage(
          lessonRepository: _ListeningLessonRepository(),
          settingsRepository: const _ListeningSettingsRepository(),
          maxHskLevel: 1,
          pronunciationService: pronunciation,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listening-start-practice')));
    await tester.pumpAndSettle();
    final stops = pronunciation.stopCalls;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Choose what to listen for'), findsOneWidget);
    expect(pronunciation.stopCalls, greaterThan(stops));
    expect(tester.takeException(), isNull);
  });

  testWidgets('starting listening freezes topic search until audio stops', (
    tester,
  ) async {
    final pronunciation = _ListeningPronunciationService();
    await tester.pumpWidget(
      MaterialApp(
        home: ListeningPracticePage(
          lessonRepository: _ListeningLessonRepository(),
          settingsRepository: const _ListeningSettingsRepository(),
          maxHskLevel: 3,
          pronunciationService: pronunciation,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final search = find.byKey(const Key('listening-topic-search'));
    await tester.enterText(search, 'Basics');
    final stopGate = Completer<void>();
    pronunciation.stopGate = stopGate.future;
    await tester.tap(find.byKey(const Key('listening-start-practice')));
    await tester.pump();

    expect(tester.widget<TextField>(search).enabled, isFalse);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('listening-topic-search-clear')),
          )
          .onPressed,
      isNull,
    );
    stopGate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Basics · 1 of 3'), findsOneWidget);
    expect(pronunciation.requests, [const ('你', 1.0)]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'listening practice hides Mandarin, auto-plays, replays, and slows speech',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pronunciation = _ListeningPronunciationService();
      addTearDown(pronunciation.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ListeningPracticePage(
            lessonRepository: _ListeningLessonRepository(),
            settingsRepository: const _ListeningSettingsRepository(),
            maxHskLevel: 1,
            pronunciationService: pronunciation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose what to listen for'), findsOneWidget);
      expect(pronunciation.requests, isEmpty);
      await tester.tap(find.byKey(const Key('listening-start-practice')));
      await tester.pumpAndSettle();

      expect(find.text('Listen and choose the meaning'), findsOneWidget);
      expect(pronunciation.requests, [const ('你', 1.0)]);
      expect(find.text('你'), findsNothing);
      expect(find.text('nǐ'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'you'), findsOneWidget);
      expect(find.text('advanced'), findsNothing);

      await tester.tap(find.byKey(const Key('listening-replay')));
      await tester.pump();
      expect(pronunciation.requests.last, const ('你', 1.0));

      await tester.tap(find.byKey(const Key('listening-slower-playback')));
      await tester.pump();
      expect(pronunciation.requests.last, const ('你', .75));

      await tester.tap(find.widgetWithText(OutlinedButton, 'you'));
      await tester.pump();

      expect(find.text('Correct'), findsOneWidget);
      expect(find.byKey(const Key('listening-answer-hanzi')), findsOneWidget);
      expect(find.text('你'), findsOneWidget);
      expect(find.text('nǐ'), findsOneWidget);

      await tester.tap(find.byKey(const Key('listening-next')));
      await tester.pumpAndSettle();

      expect(pronunciation.requests.last, const ('学', 1.0));
      expect(find.text('学'), findsNothing);
      expect(find.text('xué'), findsNothing);

      await tester.tap(find.byKey(const Key('listening-reveal-answer')));
      await tester.pump();

      expect(find.text('Answer revealed'), findsOneWidget);
      expect(find.text('学'), findsOneWidget);
      expect(find.text('study'), findsOneWidget);
    },
  );

  testWidgets('listening practice honors the disabled sound preference', (
    tester,
  ) async {
    final pronunciation = _ListeningPronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ListeningPracticePage(
          lessonRepository: _ListeningLessonRepository(),
          settingsRepository: const _ListeningSettingsRepository(
            LearnerSettings(soundEnabled: false),
          ),
          maxHskLevel: 1,
          pronunciationService: pronunciation,
          sessionSize: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('listening-start-practice')));
    await tester.pumpAndSettle();

    expect(pronunciation.requests, isEmpty);
    expect(find.byKey(const Key('listening-sound-disabled')), findsOneWidget);
    expect(
      tester
          .widget<PronunciationButton>(
            find.byKey(const Key('listening-slower-playback')),
          )
          .onPressed,
      isNull,
    );

    final reveal = find.byKey(const Key('listening-reveal-answer'));
    await tester.ensureVisible(reveal);
    await tester.tap(reveal);
    await tester.pump();
    expect(find.text('你'), findsOneWidget);
    expect(find.text('nǐ'), findsOneWidget);
  });

  testWidgets('listening practice can be limited to a selected topic', (
    tester,
  ) async {
    final pronunciation = _ListeningPronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ListeningPracticePage(
          lessonRepository: _ListeningLessonRepository(),
          settingsRepository: const _ListeningSettingsRepository(),
          maxHskLevel: 3,
          pronunciationService: pronunciation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('listening-topic-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Random mix'), findsOneWidget);
    await tester.tap(find.text('Advanced').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listening-start-practice')));
    await tester.pumpAndSettle();

    expect(find.text('Advanced · 1 of 1'), findsOneWidget);
    expect(pronunciation.requests, [const ('高级', 1.0)]);
    expect(find.text('高级'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'advanced'), findsOneWidget);
  });

  testWidgets('listening topics can be searched by pinyin', (tester) async {
    final pronunciation = _ListeningPronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ListeningPracticePage(
          lessonRepository: _ListeningLessonRepository(),
          settingsRepository: const _ListeningSettingsRepository(),
          maxHskLevel: 3,
          pronunciationService: pronunciation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('listening-topic-search')),
      'gao ji',
    );
    await tester.pumpAndSettle();

    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('Basics'), findsNothing);
    await tester.tap(find.byKey(const Key('listening-start-practice')));
    await tester.pumpAndSettle();

    expect(find.text('Advanced · 1 of 1'), findsOneWidget);
    expect(pronunciation.requests, [const ('高级', 1.0)]);
  });

  testWidgets('listening search explains when no topics match', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ListeningPracticePage(
          lessonRepository: _ListeningLessonRepository(),
          settingsRepository: const _ListeningSettingsRepository(),
          maxHskLevel: 3,
          pronunciationService: _ListeningPronunciationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('listening-topic-search')),
      'not in any lesson',
    );
    await tester.pump();

    expect(
      find.byKey(const Key('listening-topic-search-empty')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('listening-start-practice')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('random listening mode shuffles cards from every topic', (
    tester,
  ) async {
    final pronunciation = _ListeningPronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ListeningPracticePage(
          lessonRepository: _ListeningLessonRepository(),
          settingsRepository: const _ListeningSettingsRepository(),
          maxHskLevel: 3,
          pronunciationService: pronunciation,
          sessionSize: 4,
          random: _ZeroRandom(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('listening-topic-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Random mix').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listening-start-practice')));
    await tester.pumpAndSettle();

    expect(find.text('Random mix · 1 of 4'), findsOneWidget);
    expect(pronunciation.requests.first, const ('学', 1.0));

    for (var position = 0; position < 3; position++) {
      final reveal = find.byKey(const Key('listening-reveal-answer'));
      await tester.ensureVisible(reveal);
      await tester.tap(reveal);
      await tester.pump();
      await tester.tap(find.byKey(const Key('listening-next')));
      await tester.pumpAndSettle();
    }

    expect(pronunciation.requests.map((request) => request.$1).toSet(), {
      '你',
      '学',
      '书',
      '高级',
    });
  });

  testWidgets('random topic mode chooses one focused listening topic', (
    tester,
  ) async {
    final pronunciation = _ListeningPronunciationService();
    addTearDown(pronunciation.dispose);
    final random = _ZeroRandom();

    await tester.pumpWidget(
      MaterialApp(
        home: ListeningPracticePage(
          lessonRepository: _ListeningLessonRepository(),
          settingsRepository: const _ListeningSettingsRepository(),
          maxHskLevel: 3,
          pronunciationService: pronunciation,
          sessionSize: 4,
          random: random,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('listening-topic-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Random topic').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listening-start-practice')));
    await tester.pumpAndSettle();

    expect(find.text('Basics · 1 of 3'), findsOneWidget);
    expect(pronunciation.requests.first, const ('你', 1.0));

    for (var position = 0; position < 2; position++) {
      final reveal = find.byKey(const Key('listening-reveal-answer'));
      await tester.ensureVisible(reveal);
      await tester.tap(reveal);
      await tester.pump();
      await tester.tap(find.byKey(const Key('listening-next')));
      await tester.pumpAndSettle();
    }

    expect(pronunciation.requests.map((request) => request.$1).toSet(), {
      '你',
      '学',
      '书',
    });
  });

  testWidgets('a saved random lesson uses the single random picker mode', (
    tester,
  ) async {
    final pronunciation = _ListeningPronunciationService();
    addTearDown(pronunciation.dispose);
    final repository = _ListeningLessonRepository(
      lessons: const [
        Lesson(
          summary: LessonSummary(
            id: 5,
            title: 'Random mix · HSK 1',
            theme: 'Random mix',
            hskLevel: 1,
          ),
          cards: [
            Flashcard(
              id: 51,
              chinese: '听',
              pinyin: 'tīng',
              englishMeaning: 'listen',
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ListeningPracticePage(
          lessonRepository: repository,
          settingsRepository: const _ListeningSettingsRepository(),
          maxHskLevel: 1,
          pronunciationService: pronunciation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final picker = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(picker.items, hasLength(1));
    expect(find.text('Random mix'), findsOneWidget);

    await tester.tap(find.byKey(const Key('listening-start-practice')));
    await tester.pumpAndSettle();

    expect(find.text('Random mix · 1 of 1'), findsOneWidget);
    expect(pronunciation.requests, [const ('听', 1.0)]);
  });

  testWidgets('listening is available from the app sidebar', (tester) async {
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSidebar(onSelected: (index) => selected = index),
        ),
      ),
    );

    await tester.tap(find.text('Listening Practice'));
    await tester.pump();

    expect(selected, 3);
  });
}

class _ListeningProgressRepository extends SqliteProgressRepository {
  const _ListeningProgressRepository();

  @override
  Future<Map<int, LessonLearningProgress>> lessonLearningProgress() async => {
    for (var id = 1; id <= 251; id++)
      id: LessonLearningProgress(totalCards: 20, learnedCards: id == 1 ? 7 : 0),
  };
}

class _ListeningLessonRepository implements LessonRepository {
  @override
  Future<void> deleteGenerated(int lessonId) async {
    throw UnimplementedError();
  }

  _ListeningLessonRepository({this.lessons = defaultLessons});

  final List<Lesson> lessons;

  static const defaultLessons = [
    Lesson(
      summary: LessonSummary(
        id: 1,
        title: 'Basics',
        theme: 'Basics',
        hskLevel: 1,
      ),
      cards: [
        Flashcard(id: 11, chinese: '你', pinyin: 'nǐ', englishMeaning: 'you'),
        Flashcard(id: 12, chinese: '学', pinyin: 'xué', englishMeaning: 'study'),
        Flashcard(id: 13, chinese: '书', pinyin: 'shū', englishMeaning: 'book'),
      ],
    ),
    Lesson(
      summary: LessonSummary(
        id: 3,
        title: 'Advanced',
        theme: 'Advanced',
        hskLevel: 3,
      ),
      cards: [
        Flashcard(
          id: 31,
          chinese: '高级',
          pinyin: 'gāojí',
          englishMeaning: 'advanced',
        ),
      ],
    ),
  ];

  @override
  Future<List<LessonSummary>> topics() async => [
    for (final lesson in lessons) lesson.summary,
  ];

  @override
  Future<Lesson?> findById(int id) async {
    for (final lesson in lessons) {
      if (lesson.summary.id == id) return lesson;
    }
    return null;
  }

  @override
  Future<Lesson?> findGenerated({
    required String theme,
    required int hskLevel,
  }) async => null;

  @override
  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  }) async => card;

  @override
  Future<void> saveGenerated(Lesson lesson) async {}
}

class _ListeningSettingsRepository implements SettingsRepository {
  const _ListeningSettingsRepository([this.settings = const LearnerSettings()]);

  final LearnerSettings settings;

  @override
  Future<LearnerSettings> load() async => settings;

  @override
  Future<void> save(LearnerSettings settings) async {}
}

class _ListeningPronunciationService
    implements PronunciationService, PlaybackRatePronunciationService {
  final List<(String, double)> requests = [];
  int stopCalls = 0;
  Future<void>? stopGate;

  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates => const Stream.empty();

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async =>
      const OfflineVoiceStatus.unavailable();

  @override
  Future<void> installOfflineVoice() async {}

  @override
  Future<void> speakMandarin(String text) async {
    requests.add((text, 1));
  }

  @override
  Future<void> speakMandarinAtRate(String text, {required double rate}) async {
    requests.add((text, rate));
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    await stopGate;
  }

  @override
  Future<void> dispose() async {}
}

class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}
