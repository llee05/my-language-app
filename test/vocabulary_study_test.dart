import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/local_database.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/hsk_exam.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/models/tutor_learner_snapshot.dart';
import 'package:mylanguageapp/repositories/bundled_vocabulary_repository.dart';
import 'package:mylanguageapp/repositories/progress_repository.dart';
import 'package:mylanguageapp/repositories/lesson_repository.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';
import 'package:mylanguageapp/repositories/tutor_context_repository.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';
import 'package:mylanguageapp/services/vocabulary_study_service.dart';
import 'package:mylanguageapp/services/speech_input_service.dart';

import 'tutor_personality_test_support.dart';

const _words = [
  {
    'simplified': '茶',
    'traditional': '茶',
    'pinyin': 'chá',
    'studyMeaning': 'tea',
    'meanings': ['tea'],
    'hskLevel': 1,
  },
  {
    'simplified': '书',
    'traditional': '書',
    'pinyin': 'shū',
    'studyMeaning': 'book',
    'meanings': ['book'],
    'hskLevel': 1,
  },
  {
    'simplified': '学习',
    'traditional': '學習',
    'pinyin': 'xuéxí',
    'studyMeaning': 'to study',
    'meanings': ['to study'],
    'hskLevel': 1,
  },
];

class _Vocabulary extends BundledVocabularyRepository {
  const _Vocabulary();
  @override
  Future<List<Map<String, dynamic>>> load({AssetBundle? bundle}) async =>
      _words;
}

class _Settings implements SettingsRepository {
  const _Settings();
  @override
  Future<LearnerSettings> load() async =>
      const LearnerSettings(soundEnabled: false);
  @override
  Future<void> save(LearnerSettings settings) async {}
}

class _SilentVoice implements PronunciationService {
  @override
  Future<void> speakMandarin(String text) async {}
  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SilentSpeech implements SpeechInputService {
  @override
  Future<void> cancelListening() async {}
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Context implements TutorContextRepository {
  @override
  Future<TutorLearnerSnapshot> load({required DateTime asOf}) async =>
      TutorLearnerSnapshot(
        asOf: asOf,
        hskLevel: 1,
        knownWords: [
          for (final (chinese, pinyin, meaning) in [
            ('茶', 'chá', 'tea'),
            ('书', 'shū', 'book'),
            ('你', 'nǐ', 'you'),
            ('我', 'wǒ', 'I'),
            ('要', 'yào', 'want'),
          ])
            TutorWordSnapshot(
              chinese: chinese,
              pinyin: pinyin,
              englishMeaning: meaning,
              mastery: 1,
              incorrectAnswers: 0,
            ),
        ],
      );
}

class _FailAfterSave extends SqliteProgressRepository {
  bool fail = true;
  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async {
    await super.recordReview(review: review, progress: progress);
    if (fail) {
      fail = false;
      throw StateError('lost save response');
    }
  }
}

class _GatedProgress extends _MemoryProgress {
  _GatedProgress(super.cards);
  var gate = Completer<void>();
  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async {
    await gate.future;
    await super.recordReview(review: review, progress: progress);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const lessons = SqliteLessonRepository();
  const progress = SqliteProgressRepository();
  late _MemoryProgress memory;
  late _MemoryLessons widgetLessons;
  VocabularyStudyService widgetStudy([ProgressRepository? store]) =>
      VocabularyStudyService(
        lessons: widgetLessons,
        progress: store ?? memory,
        vocabulary: const _Vocabulary(),
      );
  final now = DateTime.utc(2026, 10, 3, 12);
  VocabularyStudyService service([ProgressRepository store = progress]) =>
      VocabularyStudyService(
        lessons: lessons,
        progress: store,
        vocabulary: const _Vocabulary(),
        clock: () => now,
      );
  setUp(() async {
    widgetLessons = _MemoryLessons();
    memory = _MemoryProgress(widgetLessons.cards);
    await LocalDatabase.resetForTesting();
    await const SqliteLearnerRepository().save(
      const LearnerProfile(name: 'Test', hskLevel: 1, dailyWordTarget: 10),
    );
  });
  tearDown(LocalDatabase.close);

  test('study modes share vocabulary progress and retry identities', () async {
    final study = service();
    final cardIds = <int>{};
    for (final mode in [
      'dictionary',
      'discovery',
      'listening',
      'rush',
      'exam',
      'chat',
      'dialogue',
      'roleplay',
      'sentence',
    ]) {
      final card = await study.recordWord(
        _words.first,
        rating: mode == 'rush' ? ReviewRating.again : ReviewRating.good,
        submissionKey: '$mode:run:1',
      );
      cardIds.add(card.id);
    }
    expect(cardIds, hasLength(1));
    final memberships = await LocalDatabase.use(
      (db) => db.query(
        'lesson_cards',
        where: 'card_id = ?',
        whereArgs: [cardIds.single],
        limit: 1,
      ),
    );
    expect(
      memberships,
      isNotEmpty,
      reason: 'Other study modes must reuse the bundled lesson card.',
    );
    final stats = await progress.loadLearningStats(now);
    expect(stats.wordsSeen, 1);
    expect(stats.wordsLearned, 1);
    expect(stats.reviewCount, 9);
    expect(stats.totalXp, 85);
    expect(
      (await progress.progressForCard(cardIds.single))!.mastery,
      closeTo(8 / 9, .001),
    );
    expect(
      unlearnedVocabulary(_words, await progress.vocabularyProgress()),
      hasLength(2),
    );
  });

  test('failed save responses retry without counting the word twice', () async {
    final study = service(_FailAfterSave());
    await expectLater(
      study.recordWord(
        _words.first,
        rating: ReviewRating.good,
        submissionKey: 'retry:1',
      ),
      throwsStateError,
    );
    await study.recordWord(
      _words.first,
      rating: ReviewRating.good,
      submissionKey: 'retry:1',
    );
    final stats = await progress.loadLearningStats(now);
    expect(stats.reviewCount, 1);
    expect(stats.totalXp, 10);
  });

  test(
    'text practice resolves longest bundled words with canonical readings',
    () async {
      final words = await service().wordsInText('学习，学习。书和茶。');
      expect(words.map((word) => word['simplified']), ['学习', '书', '茶']);
      expect(words.first['pinyin'], 'xuéxí');
      expect(await progress.reviewHistory(), isEmpty);
    },
  );

  test(
    'sentence ratings retain XP without counting a sentence as an HSK word',
    () async {
      final topics = await lessons.topics();
      final sentence = (await lessons.findById(
        topics.firstWhere((topic) => topic.isSentencePractice).id,
      ))!;
      await service().recordCard(
        sentence.cards.first,
        hskLevel: sentence.summary.hskLevel,
        rating: ReviewRating.good,
        submissionKey: 'sentence:1',
      );
      final stats = await progress.loadLearningStats(now);
      expect(stats.reviewCount, 1);
      expect(stats.totalXp, 10);
      expect(stats.wordsSeen, 0);
    },
  );

  for (final mode in ['chat', 'dialogue', 'roleplay']) {
    testWidgets('$mode vocabulary practice saves only explicit word ratings', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late Widget page;
      if (mode == 'roleplay') {
        page = AiRoleplayMissionsPage(
          studyService: widgetStudy(),
          settingsRepository: const _Settings(),
          tutorContextRepository: _Context(),
          pronunciationService: _SilentVoice(),
          speechInputService: _SilentSpeech(),
          request: (_) async => jsonEncode({
            'npc_reply': {
              'chinese': '你要茶。',
              'tokens': ['你', '要', '茶'],
              'pinyin': 'Nǐ yào chá.',
              'english': 'You want tea.',
            },
            'hint': {
              'chinese': '我要茶。',
              'tokens': ['我', '要', '茶'],
              'pinyin': 'Wǒ yào chá.',
              'english': 'I want tea.',
            },
            'progress': 'Order a drink.',
            'mission_complete': false,
            'feedback': '',
            'review_words': [],
          }),
        );
      } else {
        page = AiTutorPage(
          studyService: widgetStudy(),
          settingsRepository: const _Settings(),
          tutorContextRepository: _Context(),
          personalityRepository: MemoryTutorPersonalityRepository(),
          pronunciationService: _SilentVoice(),
          speechInputService: _SilentSpeech(),
          request: (_) async => mode == 'chat'
              ? jsonEncode({
                  'chinese': '茶。',
                  'pinyin': 'Chá.',
                  'english': 'Tea.',
                })
              : jsonEncode({
                  'title': 'Study together',
                  'setting': 'Two friends talk about study.',
                  'lines': [
                    {
                      'speaker': 'A',
                      'chinese': '我学习。',
                      'tokens': ['我', '学习'],
                      'pinyin': 'Wǒ xuéxí.',
                      'english': 'I study.',
                    },
                    {
                      'speaker': 'B',
                      'chinese': '我要书。',
                      'tokens': ['我', '要', '书'],
                      'pinyin': 'Wǒ yào shū.',
                      'english': 'I want a book.',
                    },
                  ],
                  'new_words': [
                    {'chinese': '学习', 'pinyin': 'xuéxí', 'english': 'to study'},
                  ],
                  'questions': [
                    {
                      'prompt': 'What does A do?',
                      'options': ['Study', 'Drink'],
                      'correct_index': 0,
                      'explanation': 'A studies.',
                    },
                    {
                      'prompt': 'What does B want?',
                      'options': ['Book', 'Tea'],
                      'correct_index': 0,
                      'explanation': 'B wants a book.',
                    },
                  ],
                }),
        );
      }
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
      await tester.pumpAndSettle();
      if (mode == 'chat') {
        await tester.enterText(find.byType(TextField), 'Teach me tea');
        await tester.tap(find.byTooltip('Send'));
      } else if (mode == 'dialogue') {
        await tester.tap(find.text('Listening dialogue'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('generate-dialogue')));
      } else {
        final start = find.byKey(const Key('start-roleplay-food-spicy'));
        await tester.ensureVisible(start);
        await tester.tap(start);
      }
      await tester.pumpAndSettle();
      expect(await memory.reviewHistory(), isEmpty);
      final practice = find.text('Practise these words');
      await tester.ensureVisible(practice);
      await tester.tap(practice);
      await tester.pumpAndSettle();
      final gotIt = find.text('Got it').first;
      await tester.ensureVisible(gotIt);
      await tester.tap(gotIt);
      await tester.pumpAndSettle();
      expect(await memory.reviewHistory(), hasLength(1));
      expect((await memory.loadLearningStats(now)).wordsLearned, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Vocab Rush saves correct answers as vocabulary practice', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VocabRushPage(
            studyService: widgetStudy(),
            lessonRepository: widgetLessons,
            progressRepository: memory,
            settingsRepository: const _Settings(),
            pronunciationService: _SilentVoice(),
            initialVocabulary: _words,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Survival'));
    await tester.tap(find.text('开始游戏 — Start Game'));
    await tester.pumpAndSettle();
    final visibleWord = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .firstWhere((text) => _words.any((word) => word['simplified'] == text));
    final meaning =
        _words.singleWhere(
              (word) => word['simplified'] == visibleWord,
            )['studyMeaning']
            as String;
    await tester.tap(find.text(meaning));
    await tester.pumpAndSettle();
    expect(memory.reviews.single.wasCorrect, isTrue);
    expect((await memory.loadLearningStats(now)).wordsLearned, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [const Size(320, 640), const Size(1000, 900)]) {
    testWidgets('word feed skips mastered words and saves ratings at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final study = widgetStudy();
      await study.recordWord(
        _words.first,
        rating: ReviewRating.good,
        submissionKey: 'known:tea',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoomScrollingPage(
              studyService: study,
              settingsRepository: const _Settings(),
              pronunciationService: _SilentVoice(),
              random: Random(7),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 practised · 2 unlearned words'), findsOneWidget);
      expect(find.text('茶'), findsNothing);
      expect((await memory.reviewHistory()), hasLength(1));
      await tester.tap(find.text('Got it').hitTestable().first);
      await tester.pumpAndSettle();
      expect(find.text('1 practised · 2 unlearned words'), findsOneWidget);
      expect((await memory.reviewHistory()), hasLength(2));
      await tester.tap(find.text('Still learning').hitTestable().first);
      await tester.pumpAndSettle();
      expect((await memory.reviewHistory()).first.rating, ReviewRating.again);
      expect(find.text('You’ve reached the end of this mix.'), findsOneWidget);
      await tester.tap(find.text('Refresh word feed'));
      await tester.pumpAndSettle();
      expect(find.text('0 practised · 1 unlearned words'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keyboard skips do not award vocabulary mastery', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DoomScrollingPage(
            studyService: widgetStudy(),
            settingsRepository: const _Settings(),
            pronunciationService: _SilentVoice(),
            random: Random(7),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PageView>(find.byKey(const Key('doom-scrolling-feed')))
          .controller!
          .page,
      1,
    );
    expect(await memory.reviewHistory(), isEmpty);
  });

  testWidgets(
    'vertical swipes and the mouse wheel advance the feed without saving',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoomScrollingPage(
              studyService: widgetStudy(),
              settingsRepository: const _Settings(),
              pronunciationService: _SilentVoice(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final feed = find.byKey(const Key('doom-scrolling-feed'));
      await tester.drag(feed, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(feed).controller!.page, 1);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(tester.getCenter(feed)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 150)));
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(feed).controller!.page, 2);
      expect(await memory.reviewHistory(), isEmpty);
    },
  );

  testWidgets('reduced motion uses immediate feed navigation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: DoomScrollingPage(
            studyService: widgetStudy(),
            settingsRepository: const _Settings(),
            pronunciationService: _SilentVoice(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(
      tester
          .widget<PageView>(find.byKey(const Key('doom-scrolling-feed')))
          .controller!
          .page,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('feed waits for persistence and allows an idempotent retry', (
    tester,
  ) async {
    final store = _GatedProgress(widgetLessons.cards);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DoomScrollingPage(
            studyService: widgetStudy(store),
            settingsRepository: const _Settings(),
            pronunciationService: _SilentVoice(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it').hitTestable().first);
    await tester.pump();
    expect(find.text('Saving…').hitTestable(), findsOneWidget);
    expect(
      tester
          .widget<PageView>(find.byKey(const Key('doom-scrolling-feed')))
          .controller!
          .page,
      0,
    );
    store.gate.completeError(StateError('save failed'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('discovery-save-retry')), findsOneWidget);
    expect(await store.reviewHistory(), isEmpty);
    store.gate = Completer<void>()..complete();
    await tester.tap(find.byKey(const Key('discovery-save-retry')));
    await tester.pumpAndSettle();
    expect(await store.reviewHistory(), hasLength(1));
    expect(store.reviews.single.rating, ReviewRating.good);
    expect(
      tester
          .widget<PageView>(find.byKey(const Key('doom-scrolling-feed')))
          .controller!
          .page,
      1,
    );
  });

  testWidgets('dictionary ratings update the shared word statistics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VocabularyPage(
            initialEntries: _words,
            studyService: widgetStudy(),
            settingsRepository: const _Settings(),
            pronunciationService: _SilentVoice(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dictionary'), findsOneWidget);
    await tester.tap(find.text('茶'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Practise these words'));
    await tester.tap(find.text('Practise these words'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Got it'));
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Progress saved'), findsOneWidget);
    expect(memory.reviews.single.submissionKey, isNot(contains('\u0000')));
    expect((await memory.loadLearningStats(now)).wordsLearned, 1);
  });

  testWidgets('listening answers persist correct and revealed responses', (
    tester,
  ) async {
    final tea = await widgetLessons.findOrCreateVocabularyCard(
      card: const Flashcard(chinese: '茶', pinyin: 'chá', englishMeaning: 'tea'),
      hskLevel: 1,
    );
    final book = await widgetLessons.findOrCreateVocabularyCard(
      card: const Flashcard(
        chinese: '书',
        pinyin: 'shū',
        englishMeaning: 'book',
      ),
      hskLevel: 1,
    );
    await widgetLessons.saveGenerated(
      Lesson(
        summary: const LessonSummary(
          id: 0,
          title: 'Stats practice',
          theme: 'Stats',
          hskLevel: 1,
        ),
        cards: [tea, book],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListeningPracticePage(
            lessonRepository: widgetLessons,
            progressRepository: memory,
            studyService: widgetStudy(),
            settingsRepository: const _Settings(),
            maxHskLevel: 1,
            pronunciationService: _SilentVoice(),
            sessionSize: 1,
            random: Random(2),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('listening-start-practice')),
    );
    await tester.tap(find.byKey(const Key('listening-start-practice')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('listening-reveal-answer')),
    );
    await tester.tap(find.byKey(const Key('listening-reveal-answer')));
    await tester.pumpAndSettle();
    expect((await memory.reviewHistory()).single.rating, ReviewRating.again);
    expect((await memory.loadLearningStats(now)).wordsLearning, 1);
  });

  testWidgets('submitted exam answers contribute; unattempted words do not', (
    tester,
  ) async {
    final exam = HskExam(
      level: 1,
      questions: [
        for (final word in _words.take(2))
          ExamQuestion(
            section: ExamSection.reading,
            word: ExamWord(
              id: word['simplified'] as String,
              hanzi: word['simplified'] as String,
              traditional: word['traditional'] as String,
              pinyin: word['pinyin'] as String,
              meaning: word['studyMeaning'] as String,
              meanings: {word['studyMeaning'] as String},
            ),
            options: ['tea', 'book'],
          ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ExamSessionPage(
          exam: exam,
          pronunciationService: _SilentVoice(),
          studyService: widgetStudy(),
          timed: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('tea'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('exam-submit')));
    await tester.tap(find.byKey(const Key('exam-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exam-confirm-submit')));
    await tester.pumpAndSettle();
    expect((await memory.reviewHistory()).single.rating, ReviewRating.good);
    expect((await memory.loadLearningStats(now)).wordsLearned, 1);
    expect(
      find.text('Vocabulary progress saved for your answered questions.'),
      findsOneWidget,
    );
  });
}

class _MemoryLessons implements LessonRepository {
  final cards = <String, Flashcard>{};
  List<Flashcard>? deck;
  @override
  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  }) async => cards.putIfAbsent(
    card.chinese,
    () => Flashcard(
      id: cards.length + 1,
      chinese: card.chinese,
      pinyin: card.pinyin,
      englishMeaning: card.englishMeaning,
    ),
  );
  @override
  Future<List<LessonSummary>> topics() async => const [
    LessonSummary(id: 1, title: 'Practice', theme: 'Practice', hskLevel: 1),
  ];
  @override
  Future<Lesson?> findById(int id) async => Lesson(
    summary: (await topics()).first,
    cards: deck ?? cards.values.toList(),
  );
  @override
  Future<void> saveGenerated(Lesson lesson) async {
    deck = lesson.cards;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryProgress implements ProgressRepository {
  _MemoryProgress(this.cards);
  final Map<String, Flashcard> cards;
  final reviews = <ReviewRecord>[];
  final states = <int, CardProgress>{};
  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async {
    if (reviews.any((saved) => saved.submissionKey == review.submissionKey)) {
      return;
    }
    reviews.insert(0, review);
    final history = reviews
        .where((item) => item.cardId == review.cardId)
        .toList();
    final correct = history.where((item) => item.wasCorrect).length;
    states[review.cardId] = CardProgress(
      cardId: review.cardId,
      timesSeen: history.length,
      correctAnswers: correct,
      incorrectAnswers: history.length - correct,
      mastery: correct / history.length,
      nextReview: progress.nextReview,
      lastReview: progress.lastReview,
      repetitions: progress.repetitions,
      reviewInterval: progress.reviewInterval,
    );
  }

  @override
  Future<CardProgress?> progressForCard(int cardId) async => states[cardId];
  @override
  Future<List<ReviewRecord>> reviewHistory({int? cardId, int? limit}) async =>
      reviews
          .where((review) => cardId == null || review.cardId == cardId)
          .take(limit ?? reviews.length)
          .toList();
  @override
  Future<List<VocabularyCardProgress>> vocabularyProgress() async => [
    for (final state in states.values)
      VocabularyCardProgress(
        chinese: cards.values
            .singleWhere((card) => card.id == state.cardId)
            .chinese,
        pinyin: cards.values
            .singleWhere((card) => card.id == state.cardId)
            .pinyin,
        progress: state,
      ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
