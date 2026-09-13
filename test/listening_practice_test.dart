import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/lesson_repository.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';

void main() {
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

    expect(pronunciation.requests, isEmpty);
    expect(find.byKey(const Key('listening-sound-disabled')), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
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

  testWidgets('listening is available from the app sidebar', (tester) async {
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSidebar(onSelected: (index) => selected = index),
        ),
      ),
    );

    await tester.tap(find.text('Listening'));
    await tester.pump();

    expect(selected, 6);
  });
}

class _ListeningLessonRepository implements LessonRepository {
  static const lessons = [
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
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> dispose() async {}
}
