import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/models/vocabulary_example.dart';
import 'package:mylanguageapp/repositories/bundled_vocabulary_example_repository.dart';
import 'package:mylanguageapp/repositories/bundled_vocabulary_repository.dart';
import 'package:mylanguageapp/repositories/lesson_repository.dart';
import 'package:mylanguageapp/repositories/progress_repository.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';
import 'package:mylanguageapp/services/vocabulary_study_service.dart';

const _examples = [
  VocabularyExample(
    chinese: '我喝茶。',
    pinyin: 'Wǒ hē chá.',
    english: 'I drink tea.',
    source: 'Tatoeba',
    chineseId: '123',
    englishId: '456',
    pinyinContributor: 'Test author',
  ),
  VocabularyExample(
    chinese: '你喝茶吗？',
    pinyin: 'Nǐ hē chá ma?',
    english: 'Do you drink tea?',
    source: 'Tatoeba',
    chineseId: '124',
    englishId: '457',
    pinyinContributor: 'Test author',
  ),
  VocabularyExample(
    chinese: '茶很好喝。',
    pinyin: 'Chá hěn hǎohē.',
    english: 'The tea tastes good.',
    source: 'Tatoeba',
    chineseId: '125',
    englishId: '458',
    pinyinContributor: 'Test author',
  ),
];
const _word = {
  'simplified': '茶',
  'pinyin': 'chá',
  'hskLevel': 1,
  'meanings': ['tea'],
  'exampleChinese': '我喝茶。',
  'examplePinyin': 'Wǒ hē chá.',
  'exampleEnglish': 'I drink tea.',
};

void main() {
  late _Examples examples;
  late _Progress progress;
  late _Lessons lessons;
  late _Voice voice;
  VocabularyStudyService study() => VocabularyStudyService(
    lessons: lessons,
    progress: progress,
    vocabulary: const _Words(),
    examples: examples,
  );
  setUp(() {
    examples = _Examples();
    progress = _Progress();
    lessons = _Lessons();
    voice = _Voice();
  });

  Future<void> dictionary(
    WidgetTester tester, {
    bool sound = true,
    _Voice? speech,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VocabularyPage(
            initialEntries: const [_word],
            initialProgress: const [],
            studyService: study(),
            settingsRepository: _Settings(sound),
            pronunciationService: speech ?? voice,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (find.text('茶').evaluate().isEmpty) {
      await tester.drag(
        find.byKey(const Key('vocabulary-scroll')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('茶'));
    await tester.pumpAndSettle();
  }

  Future<void> another(WidgetTester tester) async {
    final button = find
        .byKey(const Key('vocabulary-example-next'))
        .hitTestable();
    if (button.evaluate().isEmpty) {
      await tester.ensureVisible(
        find.byKey(const Key('vocabulary-example-next')).first,
      );
    }
    await tester.tap(
      find.byKey(const Key('vocabulary-example-next')).hitTestable().first,
    );
    await tester.pumpAndSettle();
  }

  for (final (size, scale) in [
    (const Size(320, 640), 2.0),
    (const Size(1000, 1100), 1.0),
  ]) {
    testWidgets(
      'dictionary cycles complete attributed examples at $size with $scale text without saving',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await dictionary(tester);
        expect(find.text(_examples.first.chinese), findsOneWidget);
        await another(tester);
        expect(find.text(_examples[1].chinese), findsOneWidget);
        expect(find.text(_examples[1].pinyin), findsOneWidget);
        expect(find.text(_examples[1].english), findsOneWidget);
        expect(
          find.text('Tatoeba · CC BY 2.0 FR · #124 / #457'),
          findsOneWidget,
        );
        expect(find.text('Pinyin: Test author'), findsOneWidget);
        final speak = find.byKey(const Key('vocabulary-example-pronunciation'));
        await tester.ensureVisible(speak);
        await tester.tap(speak);
        await tester.pumpAndSettle();
        expect(voice.spoken, [_examples[1].chinese]);
        await another(tester);
        await another(tester);
        expect(find.text(_examples.first.chinese), findsOneWidget);
        expect(progress.reviews, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('changing examples cancels a pending pronunciation request', (
    tester,
  ) async {
    final speech = _GatedVoice();
    await dictionary(tester, speech: speech);
    final speaker = find.byKey(const Key('vocabulary-example-pronunciation'));
    await tester.ensureVisible(speaker);
    await tester.tap(speaker);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(speech.gates, hasLength(1));
    await another(tester);
    speech.gates.first.complete();
    await tester.pumpAndSettle();
    expect(speech.spoken, isEmpty);
    await tester.ensureVisible(speaker);
    await tester.tap(speaker);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    speech.gates.last.complete();
    await tester.pumpAndSettle();
    expect(speech.spoken, [_examples[1].chinese]);
    expect(progress.reviews, isEmpty);
  });

  testWidgets(
    'example load failure preserves the current example and allows retry',
    (tester) async {
      examples.fail = true;
      await dictionary(tester);
      expect(find.text(_examples.first.chinese), findsOneWidget);
      expect(find.text('Retry examples'), findsOneWidget);
      expect(find.text('Another sentence'), findsNothing);
      examples.fail = false;
      await tester.ensureVisible(find.text('Retry examples'));
      await tester.tap(find.text('Retry examples'));
      await tester.pumpAndSettle();
      await another(tester);
      expect(find.text(_examples[1].chinese), findsOneWidget);
      expect(progress.reviews, isEmpty);
    },
  );

  testWidgets('sound disabled still allows example browsing', (tester) async {
    await dictionary(tester, sound: false);
    await another(tester);
    expect(
      tester
          .widget<PronunciationButton>(
            find.byKey(const Key('vocabulary-example-pronunciation')),
          )
          .onPressed,
      isNull,
    );
    expect(voice.spoken, isEmpty);
    expect(progress.reviews, isEmpty);
  });

  for (final size in [const Size(320, 640), const Size(1000, 1100)]) {
    testWidgets(
      'Doom Scrolling offers alternate examples at $size without rating the word',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DoomScrollingPage(
                studyService: study(),
                settingsRepository: const _Settings(true),
                pronunciationService: voice,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(voice.spoken, ['茶']);
        if (size.width < 600) {
          await tester.tap(find.byTooltip('Word details').hitTestable().first);
          await tester.pumpAndSettle();
        }
        await another(tester);
        expect(find.text(_examples[1].chinese), findsOneWidget);
        expect(progress.reviews, isEmpty);
        expect(voice.spoken, ['茶']);
        final speaker = find.byKey(
          Key(
            size.width < 600
                ? 'vocabulary-example-pronunciation'
                : 'discovery-example-pronunciation-0',
          ),
        );
        await tester.ensureVisible(speaker);
        await tester.tap(speaker);
        await tester.pumpAndSettle();
        expect(voice.spoken, ['茶', _examples[1].chinese]);
        expect(progress.reviews, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final custom in [false, true]) {
    testWidgets(
      'flashcard example browsing respects custom deck ownership $custom',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        lessons.custom = custom;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LessonsPage(
                repository: lessons,
                progressRepository: progress,
                settingsRepository: const _Settings(true),
                pronunciationService: voice,
                studyService: study(),
                initialLessonId: 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('茶').hitTestable());
        await tester.pumpAndSettle();
        expect(find.text(_examples.first.chinese), findsOneWidget);
        if (custom) {
          expect(find.text('Another sentence'), findsNothing);
          expect(examples.loads, 0);
        } else {
          await another(tester);
          expect(find.text(_examples[1].chinese), findsOneWidget);
          final speaker = find.byKey(const Key('lesson-example-pronunciation'));
          await tester.ensureVisible(speaker);
          await tester.tap(speaker);
          await tester.pumpAndSettle();
          expect(voice.spoken, [_examples[1].chinese]);
        }
        expect(progress.reviews, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Examples extends BundledVocabularyExampleRepository {
  bool fail = false;
  int loads = 0;
  @override
  Future<List<VocabularyExample>> forWord(String chinese, String pinyin) async {
    loads++;
    if (fail) throw StateError('examples unavailable');
    return chinese == '茶' && pinyin == 'chá' ? _examples : const [];
  }
}

class _Words extends BundledVocabularyRepository {
  const _Words();
  @override
  Future<List<Map<String, dynamic>>> load({AssetBundle? bundle}) async => [
    _word,
  ];
}

class _Voice implements PronunciationService {
  final spoken = <String>[];
  @override
  Future<void> speakMandarin(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GatedVoice extends _Voice implements OfflinePronunciationManager {
  final gates = <Completer<void>>[];
  @override
  Future<void> configurePronunciation({
    required PronunciationEngine engine,
    List<String> voiceIds = const [],
  }) {
    final gate = Completer<void>();
    gates.add(gate);
    return gate.future;
  }
}

class _Settings implements SettingsRepository {
  const _Settings(this.sound);
  final bool sound;
  @override
  Future<LearnerSettings> load() async => LearnerSettings(soundEnabled: sound);
  @override
  Future<void> save(LearnerSettings settings) async {}
}

class _Lessons implements LessonRepository {
  bool custom = false;
  Lesson get lesson => Lesson(
    summary: LessonSummary(
      id: 1,
      title: 'Tea',
      theme: 'Tea',
      hskLevel: 1,
      isUserGenerated: custom,
    ),
    cards: const [
      Flashcard(
        id: 1,
        chinese: '茶',
        pinyin: 'chá',
        englishMeaning: 'tea',
        exampleChinese: '我喝茶。',
        examplePinyin: 'Wǒ hē chá.',
        exampleEnglish: 'I drink tea.',
      ),
    ],
  );
  @override
  Future<List<LessonSummary>> topics() async => [lesson.summary];
  @override
  Future<Lesson?> findById(int id) async => lesson;
  @override
  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  }) async => lesson.cards.first;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Progress implements ProgressRepository {
  final reviews = <ReviewRecord>[];
  @override
  Future<List<VocabularyCardProgress>> vocabularyProgress() async => const [];
  @override
  Future<LessonSession?> activeSessionForLesson(int lessonId) async => null;
  @override
  Future<LessonSession> startSession(int lessonId) async => LessonSession(
    id: 1,
    lessonId: lessonId,
    startedAt: DateTime.utc(2026, 10, 12),
  );
  @override
  Future<List<ReviewRecord>> reviewHistory({int? cardId, int? limit}) async =>
      reviews;
  @override
  Future<CardProgress?> progressForCard(int cardId) async => null;
  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async => reviews.add(review);
  @override
  Future<void> updateSessionPosition({
    required int sessionId,
    required int currentCardIndex,
    required int expectedCardsReviewed,
  }) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
