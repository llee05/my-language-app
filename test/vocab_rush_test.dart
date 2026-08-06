import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/lesson_repository.dart';
import 'package:mylanguageapp/repositories/progress_repository.dart';

Future<void> startGame(WidgetTester tester) async {
  final startButton = find.text('开始游戏 — Start Game');
  await tester.ensureVisible(startButton);
  await tester.tap(startButton);
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
  await tester.pumpAndSettle();
  expect(find.text('PICK THE CORRECT MEANING'), findsOneWidget);
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('difficulty and duration can be selected independently', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VocabRushPage())),
    );

    expect(find.text('HSK 1–2'), findsOneWidget);
    expect(find.text('HSK 3–4'), findsOneWidget);
    expect(find.text('HSK 5–6'), findsOneWidget);
    expect(find.text('3 minutes'), findsOneWidget);
    expect(find.text('5 minutes'), findsOneWidget);
    expect(find.text('Survival'), findsOneWidget);

    await tester.tap(find.text('Advanced'));
    await tester.tap(find.text('5 minutes'));
    await tester.pumpAndSettle();
    await startGame(tester);

    expect(find.text('300s'), findsOneWidget);
    expect(find.text('PICK THE CORRECT MEANING'), findsOneWidget);

    final vocabulary =
        (jsonDecode(File('assets/data/hsk_vocabulary.json').readAsStringSync())
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toSet();
    final card = vocabulary.firstWhere(
      (entry) => visibleText.contains(entry['simplified']),
    );
    final correctAnswer = (card['meanings'] as List<dynamic>).first as String;

    await tester.tap(find.widgetWithText(OutlinedButton, correctAnswer));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('×1'), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 500));

    for (var mistake = 1; mistake <= 3; mistake++) {
      final visibleText = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .toSet();
      final card = vocabulary.firstWhere(
        (entry) => visibleText.contains(entry['simplified']),
      );
      final correctAnswer = (card['meanings'] as List<dynamic>).first as String;
      final wrongButton = tester
          .widgetList<OutlinedButton>(find.byType(OutlinedButton))
          .firstWhere(
            (button) => ((button.child as Text).data ?? '') != correctAnswer,
          );

      await tester.tap(find.byWidget(wrongButton));
      await tester.pump();
      expect(find.text('$mistake/3'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.textContaining('Three strikes!'), findsOneWidget);
    expect(find.text('再玩一次 — Play Again'), findsOneWidget);
  });

  testWidgets('incorrect answers are saved for daily review', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lessons = _RushLessonRepository();
    final progress = _RushProgressRepository();
    const vocabulary = [
      {
        'simplified': '错',
        'pinyin': 'cuò',
        'meanings': ['wrong'],
        'partOfSpeech': ['adjective'],
        'hskLevel': 1,
      },
      {
        'simplified': '对',
        'pinyin': 'duì',
        'meanings': ['correct'],
        'partOfSpeech': ['adjective'],
        'hskLevel': 1,
      },
      {
        'simplified': '人',
        'pinyin': 'rén',
        'meanings': ['person'],
        'partOfSpeech': ['noun'],
        'hskLevel': 1,
      },
      {
        'simplified': '书',
        'pinyin': 'shū',
        'meanings': ['book'],
        'partOfSpeech': ['noun'],
        'hskLevel': 1,
      },
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VocabRushPage(
            lessonRepository: lessons,
            progressRepository: progress,
            initialVocabulary: vocabulary,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Survival'));
    await startGame(tester);

    final visibleHanzi = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .firstWhere((text) => const {'错', '对', '人', '书'}.contains(text));
    final visibleCard = vocabulary.firstWhere(
      (card) => card['simplified'] == visibleHanzi,
    );
    final correctMeaning =
        (visibleCard['meanings'] as List<dynamic>).first as String;
    final wrongButton = tester
        .widgetList<OutlinedButton>(find.byType(OutlinedButton))
        .firstWhere((button) => (button.child as Text).data != correctMeaning);

    await tester.tap(find.byWidget(wrongButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(lessons.savedCard?.chinese, visibleHanzi);
    expect(progress.review?.cardId, 42);
    expect(progress.review?.rating, ReviewRating.again);
    expect(progress.review?.wasCorrect, isFalse);
    expect(progress.savedProgress?.lapses, 1);
    expect(progress.savedProgress?.reviewInterval, 1);
    expect(progress.savedProgress?.easeFactor, closeTo(2.3, .0001));
    await tester.pump(const Duration(milliseconds: 500));
  });
}

class _RushLessonRepository implements LessonRepository {
  Flashcard? savedCard;

  @override
  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  }) async {
    savedCard = card;
    return Flashcard(
      id: 42,
      chinese: card.chinese,
      pinyin: card.pinyin,
      englishMeaning: card.englishMeaning,
      partOfSpeech: card.partOfSpeech,
    );
  }

  @override
  Future<Lesson?> findById(int id) async => null;

  @override
  Future<Lesson?> findGenerated({
    required String theme,
    required int hskLevel,
  }) async => null;

  @override
  Future<void> saveGenerated(Lesson lesson) async {}

  @override
  Future<List<LessonSummary>> topics() async => const [];
}

class _RushProgressRepository implements ProgressRepository {
  ReviewRecord? review;
  CardProgress? savedProgress;

  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async {
    this.review = review;
    savedProgress = progress;
  }

  @override
  Future<CardProgress?> progressForCard(int cardId) async => null;

  @override
  Future<List<DailyQueueCard>> dailyQueue({
    required DateTime forDay,
    required int limit,
    double weakThreshold = .7,
    int maxHskLevel = 6,
  }) async => const [];

  @override
  Future<LessonSession?> activeSessionForLesson(int lessonId) async => null;

  @override
  Future<List<CardProgress>> dueCards(DateTime through) async => const [];

  @override
  Future<LessonSession?> latestActiveSession() async => null;

  @override
  Future<List<ReviewRecord>> reviewHistory({int? cardId, int? limit}) async =>
      const [];

  @override
  Future<LessonSession> startSession(int lessonId) =>
      throw UnimplementedError();

  @override
  Future<void> updateSession(LessonSession session) async {}
}
