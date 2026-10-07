import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/lesson_repository.dart';
import 'package:mylanguageapp/repositories/progress_repository.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';

const _lesson = Lesson(
  summary: LessonSummary(
    id: 7,
    title: 'Everyday words',
    theme: 'Everyday',
    hskLevel: 2,
  ),
  cards: [
    Flashcard(id: 11, chinese: '你', pinyin: 'nǐ', englishMeaning: 'you'),
    Flashcard(id: 12, chinese: '学', pinyin: 'xué', englishMeaning: 'study'),
    Flashcard(id: 13, chinese: '好', pinyin: 'hǎo', englishMeaning: 'good'),
  ],
);
const _nextLesson = Lesson(
  summary: LessonSummary(
    id: 8,
    title: 'Keep learning',
    theme: 'Next',
    hskLevel: 2,
  ),
  cards: [
    Flashcard(id: 21, chinese: '茶', pinyin: 'chá', englishMeaning: 'tea'),
  ],
);
const _higherLesson = Lesson(
  summary: LessonSummary(
    id: 9,
    title: 'Higher level',
    theme: 'Next',
    hskLevel: 3,
  ),
  cards: [
    Flashcard(id: 31, chinese: '水', pinyin: 'shuǐ', englishMeaning: 'water'),
  ],
);

Future<void> _pumpLesson(
  WidgetTester tester,
  _CompletionProgress progress, {
  List<Lesson> lessons = const [_lesson, _nextLesson, _higherLesson],
  Size size = const Size(1000, 1100),
  bool reduceMotion = false,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: LessonsPage(
          repository: _CompletionLessons(lessons),
          progressRepository: progress,
          settingsRepository: const _CompletionSettings(),
          pronunciationService: _SilentPronunciation(),
          initialLessonId: lessons.first.summary.id,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _markFamiliar(WidgetTester tester, Flashcard card) async {
  await tester.tap(find.text(card.chinese).hitTestable());
  await tester.pumpAndSettle();
  await tester.tap(find.text('I know this word').hitTestable());
  await tester.pumpAndSettle();
}

ReviewRecord _review(int cardId, int sessionId, ReviewRating rating) =>
    ReviewRecord(
      id: cardId,
      cardId: cardId,
      sessionId: sessionId,
      reviewedAt: DateTime.utc(2026, 10, 3, 8),
      rating: rating,
      wasCorrect: rating != ReviewRating.again,
    );

void main() {
  testWidgets('a mobile answer keeps the example and rating in view', (
    tester,
  ) async {
    const card = Flashcard(
      id: 51,
      chinese: '一',
      pinyin: 'yī',
      englishMeaning: 'one',
      exampleChinese: '一年有十二个月。',
      examplePinyin: 'Yī nián yǒu shí èr gè yuè.',
      exampleEnglish: 'One year has twelve months.',
      exampleSource: 'Tatoeba',
      exampleSourceId: '333474',
    );
    final progress = _CompletionProgress();
    await _pumpLesson(
      tester,
      progress,
      size: const Size(390, 844),
      lessons: [
        Lesson(summary: _lesson.summary, cards: const [card]),
      ],
    );
    await tester.tap(find.text(card.chinese));
    await tester.pumpAndSettle();

    for (final text in [
      card.chinese,
      card.pinyin,
      card.englishMeaning,
      card.exampleChinese,
      card.examplePinyin,
      card.exampleEnglish,
      'Tatoeba · sentence 333474',
      'I know this word',
      'Tap for word',
    ]) {
      expect(find.text(text).hitTestable(), findsOneWidget);
    }
    expect(progress.recordCalls, 0);
    await tester.tap(find.text('Tap for word'));
    await tester.pumpAndSettle();
    expect(find.text(card.pinyin), findsNothing);
    expect(find.text('Tap for answer').hitTestable(), findsOneWidget);
    expect(progress.recordCalls, 0);
    await _markFamiliar(tester, card);
    expect(progress.recordCalls, 1);
    expect(progress.reviews.single.rating, ReviewRating.easy);
    expect(find.text('Deck complete!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (size, textScale) in [
    (const Size(320, 568), 1.0),
    (const Size(360, 640), 1.5),
    (const Size(390, 844), 2.0),
    (const Size(1000, 1100), 1.0),
  ]) {
    testWidgets('long vocabulary answers scroll at $size and scale $textScale', (
      tester,
    ) async {
      const card = Flashcard(
        id: 51,
        chinese: '从而',
        pinyin: 'cóng ér',
        englishMeaning: 'thus; thereby',
        exampleChinese: '他们创作出令人惊叹的艺术作品，从而让人们驻足欣赏宇宙之美。',
        examplePinyin:
            "Tāmen chuàngzuò chū lìngrén jīngtàn de yìshù zuòpǐn, cóng'ér ràng rénmen zhùzú xīnshǎng yǔzhòu zhī měi.",
        exampleEnglish:
            "They're creating stunning works of art to force people to stop and appreciate the beauty of the universe.",
        exampleSource: 'Tatoeba',
        exampleSourceId: '13753100',
      );
      final progress = _CompletionProgress();
      await _pumpLesson(
        tester,
        progress,
        lessons: [
          Lesson(summary: _lesson.summary, cards: const [card]),
        ],
        size: size,
        textScale: textScale,
      );
      await tester.tap(find.text(card.chinese).hitTestable());
      await tester.pumpAndSettle();
      expect(find.text(card.pinyin), findsOneWidget);
      expect(find.text(card.exampleChinese), findsOneWidget);
      expect(find.text(card.examplePinyin), findsOneWidget);
      expect(find.text(card.exampleEnglish), findsOneWidget);
      expect(find.text('Tatoeba · sentence 13753100'), findsOneWidget);
      final rating = find.byKey(const Key('lesson-familiar'));
      await tester.ensureVisible(rating);
      await tester.pumpAndSettle();
      expect(rating.hitTestable(), findsOneWidget);
      expect(tester.getSize(rating).height, greaterThanOrEqualTo(48));
      expect(progress.recordCalls, 0);
      expect(tester.takeException(), isNull);
      await tester.tap(rating);
      await tester.pumpAndSettle();
      expect(progress.recordCalls, 1);
      expect(progress.reviews.single.cardId, card.id);
      expect(progress.reviews.single.rating, ReviewRating.easy);
      expect(find.text('Deck complete!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'completion restores the full recap and awards XP from saved ratings',
    (tester) async {
      final progress = _CompletionProgress(
        reviews: [
          _review(11, 1, ReviewRating.again),
          _review(12, 1, ReviewRating.hard),
          _review(12, 99, ReviewRating.good),
        ],
        sessions: [
          LessonSession(
            id: 1,
            lessonId: 7,
            startedAt: DateTime.utc(2026, 10, 3, 7),
            currentCardIndex: 2,
            cardsReviewed: 2,
            correctAnswers: 1,
          ),
        ],
      );
      await _pumpLesson(tester, progress);
      await _markFamiliar(tester, _lesson.cards[2]);

      expect(find.text('Deck complete!'), findsOneWidget);
      expect(find.text('+25 XP'), findsOneWidget);
      expect(find.text('67%'), findsOneWidget);
      expect(find.text('New words'), findsOneWidget);
      expect(find.text('Words revisited'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(
        progress.reviews.where((review) => review.sessionId == 1),
        hasLength(3),
      );

      final recap = find.byKey(const Key('lesson-revisit-list'));
      await tester.ensureVisible(recap);
      await tester.tap(recap);
      await tester.pumpAndSettle();
      expect(find.text('2 rated Again or Hard'), findsOneWidget);
      expect(find.text('你'), findsOneWidget);
      expect(find.text('学'), findsOneWidget);
      expect(find.text('好'), findsNothing);
      expect(find.text('nǐ'), findsOneWidget);
      expect(find.text('study'), findsOneWidget);
      expect(progress.recordCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('next lesson starts once and clears the previous session recap', (
    tester,
  ) async {
    final progress = _CompletionProgress();
    await _pumpLesson(tester, progress);
    for (final card in _lesson.cards) {
      await _markFamiliar(tester, card);
    }
    final next = find.byKey(const Key('lesson-completion-next'));
    await tester.ensureVisible(next);
    final start = tester.widget<FilledButton>(next).onPressed!;
    start();
    start();
    await tester.pumpAndSettle();
    expect(progress.startedLessons, [7, 8]);
    expect(find.text('茶'), findsOneWidget);
    expect(find.text('Deck complete!'), findsNothing);
    await _markFamiliar(tester, _nextLesson.cards.single);
    expect(find.text('+10 XP'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.byKey(const Key('lesson-completion-next')), findsNothing);
    expect(find.byKey(const Key('lesson-revisit-list')), findsNothing);

    final done = find.byKey(const Key('lesson-completion-done'));
    await tester.ensureVisible(done);
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lesson-completion-summary')), findsNothing);
    expect(find.text('Everyday words'), findsOneWidget);
    expect(progress.recordCalls, 4);
  });

  testWidgets(
    'a failed next-lesson reconciliation preserves the completed recap',
    (tester) async {
      final progress = _CompletionProgress(
        reviews: [_review(21, 2, ReviewRating.good)],
        sessions: [
          LessonSession(
            id: 2,
            lessonId: 8,
            startedAt: DateTime.utc(2026, 10, 3),
          ),
        ],
      );
      await _pumpLesson(tester, progress);
      for (final card in _lesson.cards) {
        await _markFamiliar(tester, card);
      }
      progress.failSessionSaveForLesson = 8;
      final next = find.byKey(const Key('lesson-completion-next'));
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Deck complete!'), findsOneWidget);
      expect(find.text('+30 XP'), findsOneWidget);
      expect(find.text('3'), findsNWidgets(2));
      expect(find.text('0'), findsOneWidget);
      expect(find.text('We couldn’t open this deck.'), findsOneWidget);
      expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
      final retrySave = Completer<void>();
      progress.failSessionSaveForLesson = null;
      progress.sessionSaveGate = retrySave;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('lesson-completion-done')),
            )
            .onPressed,
        isNull,
      );
      retrySave.complete();
      await tester.pumpAndSettle();
      expect(find.text('+10 XP'), findsOneWidget);
      expect(progress.sessions[8]?.isComplete, isTrue);
      expect(progress.recordCalls, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'celebration waits for the final session save and retries without duplicate XP',
    (tester) async {
      final progress = _CompletionProgress();
      await _pumpLesson(tester, progress, lessons: const [_nextLesson]);
      final save = Completer<void>();
      progress.sessionSaveGate = save;
      await tester.tap(find.text('茶'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I know this word').hitTestable());
      await tester.pump();
      await tester.pump();
      expect(progress.recordCalls, 1);
      expect(find.text('Deck complete!'), findsNothing);
      save.completeError(StateError('save failed'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lesson-answer-error')), findsOneWidget);
      expect(find.text('Deck complete!'), findsNothing);
      progress.sessionSaveGate = null;
      await tester.tap(find.byKey(const Key('lesson-answer-retry')));
      await tester.pumpAndSettle();
      expect(find.text('+10 XP'), findsOneWidget);
      expect(progress.reviews, hasLength(1));
      expect(progress.sessions[8]?.isComplete, isTrue);
    },
  );

  for (final (size, textScale) in [
    (const Size(320, 700), 1.0),
    (const Size(390, 800), 2.0),
    (const Size(1000, 1100), 1.0),
  ]) {
    testWidgets(
      'completed sentence deck fits $size at text scale $textScale with reduced motion',
      (tester) async {
        final sentence = Lesson(
          summary: const LessonSummary(
            id: 40,
            title: 'Sentence practice',
            theme: 'Greetings and introductions',
            hskLevel: 1,
            isSentencePractice: true,
          ),
          cards: const [
            Flashcard(
              id: 41,
              chinese: '你好。',
              pinyin: 'Nǐ hǎo.',
              englishMeaning: 'Hello.',
            ),
          ],
        );
        final nextSentence = Lesson(
          summary: const LessonSummary(
            id: 42,
            title: 'Sentence practice',
            theme: 'Ordering food',
            hskLevel: 1,
            isSentencePractice: true,
          ),
          cards: const [
            Flashcard(
              id: 43,
              chinese: '谢谢。',
              pinyin: 'Xièxie.',
              englishMeaning: 'Thank you.',
            ),
          ],
        );
        final progress = _CompletionProgress(
          reviews: [_review(41, 1, ReviewRating.hard)],
          sessions: [
            LessonSession(
              id: 1,
              lessonId: 40,
              startedAt: DateTime.utc(2026, 10, 3),
            ),
          ],
        );
        await _pumpLesson(
          tester,
          progress,
          lessons: [sentence, nextSentence],
          size: size,
          textScale: textScale,
          reduceMotion: true,
        );
        expect(find.text('Deck complete!'), findsOneWidget);
        expect(find.text('+10 XP'), findsOneWidget);
        expect(find.text('New sentences'), findsOneWidget);
        expect(find.text('Sentences revisited'), findsOneWidget);
        expect(
          find.byKey(const Key('lesson-completion-next')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('lesson-completion-done')).hitTestable(),
          findsOneWidget,
        );
        final recap = find.byKey(const Key('lesson-revisit-list'));
        await tester.ensureVisible(recap);
        await tester.tap(recap);
        await tester.pumpAndSettle();
        expect(find.text('Nǐ hǎo.'), findsOneWidget);
        final next = find.byKey(const Key('lesson-completion-next'));
        await tester.ensureVisible(next);
        expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _CompletionLessons implements LessonRepository {
  _CompletionLessons(this.lessons);
  final List<Lesson> lessons;

  @override
  Future<List<LessonSummary>> topics() async => [
    for (final lesson in lessons) lesson.summary,
  ];

  @override
  Future<Lesson?> findById(int id) async =>
      lessons.where((lesson) => lesson.summary.id == id).firstOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CompletionProgress implements ProgressRepository {
  _CompletionProgress({
    List<ReviewRecord> reviews = const [],
    List<LessonSession> sessions = const [],
  }) : reviews = List.of(reviews),
       sessions = {for (final session in sessions) session.lessonId: session};

  final List<ReviewRecord> reviews;
  final Map<int, LessonSession> sessions;
  final _progress = <int, CardProgress>{};
  final startedLessons = <int>[];
  int recordCalls = 0;
  int? failSessionSaveForLesson;
  Completer<void>? sessionSaveGate;

  @override
  Future<LessonSession?> activeSessionForLesson(int lessonId) async {
    final session = sessions[lessonId];
    return session?.isComplete == false ? session : null;
  }

  @override
  Future<LessonSession> startSession(int lessonId) async {
    startedLessons.add(lessonId);
    final session = LessonSession(
      id:
          sessions.values.fold(
            0,
            (maxId, session) => maxId > session.id ? maxId : session.id,
          ) +
          1,
      lessonId: lessonId,
      startedAt: DateTime.utc(2026, 10, 3),
    );
    sessions[lessonId] = session;
    return session;
  }

  @override
  Future<void> updateSession(
    LessonSession session, {
    bool reconcileFromHistory = false,
    int? expectedCardsReviewed,
    int? expectedCorrectAnswers,
  }) async {
    await sessionSaveGate?.future;
    if (session.lessonId == failSessionSaveForLesson) {
      throw StateError('save failed');
    }
    sessions[session.lessonId] = session;
  }

  @override
  Future<void> updateSessionPosition({
    required int sessionId,
    required int currentCardIndex,
    required int expectedCardsReviewed,
  }) async {}

  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async {
    recordCalls++;
    if (reviews.any(
      (saved) =>
          saved.submissionKey == review.submissionKey &&
          saved.submissionKey != null,
    )) {
      return;
    }
    reviews.insert(0, review);
    _progress[review.cardId] = progress;
  }

  @override
  Future<List<ReviewRecord>> reviewHistory({int? cardId, int? limit}) async =>
      reviews
          .where((review) => cardId == null || review.cardId == cardId)
          .take(limit ?? reviews.length)
          .toList();

  @override
  Future<CardProgress?> progressForCard(int cardId) async => _progress[cardId];

  @override
  Future<List<VocabularyCardProgress>> vocabularyProgress() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CompletionSettings implements SettingsRepository {
  const _CompletionSettings();
  @override
  Future<LearnerSettings> load() async =>
      const LearnerSettings(soundEnabled: false);

  @override
  Future<void> save(LearnerSettings settings) async {}
}

class _SilentPronunciation implements PronunciationService {
  @override
  Future<void> speakMandarin(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
