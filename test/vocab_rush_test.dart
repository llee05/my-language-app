import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/database/vocabulary_content.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/daily_review_session_repository.dart';
import 'package:mylanguageapp/repositories/lesson_repository.dart';
import 'package:mylanguageapp/repositories/progress_repository.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';
import 'package:mylanguageapp/repositories/app_dependencies.dart';
import 'package:mylanguageapp/repositories/bundled_vocabulary_repository.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';

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

  testWidgets('survival has no deadline and stopping has an accurate summary', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var now = DateTime(2026, 10, 4, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VocabRushPage(
            settingsRepository: const _RushSettingsRepository(),
            initialVocabulary: _smallVocabulary,
            clock: () => now,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Survival'));
    await startGame(tester);
    now = now.add(const Duration(days: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('∞'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Game ended. You scored 0 words.'), findsOneWidget);
    expect(find.textContaining('Time!'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Vocab Rush respects the hidden pinyin preference', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VocabRushPage(
            settingsRepository: _RushSettingsRepository(showPinyin: false),
            initialVocabulary: _smallVocabulary,
          ),
        ),
      ),
    );
    await startGame(tester);
    for (final entry in _smallVocabulary) {
      expect(find.text(entry['pinyin']! as String), findsNothing);
      expect(find.text(entry['studyMeaning']! as String), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final elapsed in [
    const Duration(seconds: 37),
    const Duration(minutes: 4),
  ]) {
    testWidgets('timed rush accounts for $elapsed in the background', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var now = DateTime(2026, 10, 4, 12);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VocabRushPage(
              settingsRepository: const _RushSettingsRepository(),
              initialVocabulary: _smallVocabulary,
              clock: () => now,
            ),
          ),
        ),
      );
      await startGame(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(elapsed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      if (elapsed < const Duration(minutes: 3)) {
        expect(find.text('143s'), findsOneWidget);
      } else {
        expect(find.text('PICK THE CORRECT MEANING'), findsNothing);
        expect(find.textContaining('Time!'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('an expired game rejects answers before the next timer tick', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final progress = _RushProgressRepository();
    var now = DateTime(2026, 10, 4, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VocabRushPage(
            lessonRepository: _RushLessonRepository(),
            progressRepository: progress,
            settingsRepository: const _RushSettingsRepository(),
            initialVocabulary: _smallVocabulary,
            clock: () => now,
          ),
        ),
      ),
    );
    await startGame(tester);
    now = now.add(const Duration(minutes: 3));
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pumpAndSettle();
    expect(progress.reviewAttempts, isEmpty);
    expect(find.textContaining('You scored 0 words.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'an earlier game cannot advance a new game during answer feedback',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VocabRushPage(
              lessonRepository: _RushLessonRepository(),
              progressRepository: _RushProgressRepository(),
              settingsRepository: const _RushSettingsRepository(),
              initialVocabulary: _smallVocabulary,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Survival'));
      await startGame(tester);
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.binding.handlePopRoute();
      await tester.pump();
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '再玩一次 — Play Again'),
          )
          .onPressed!();
      await tester.pump();
      final currentWord = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .firstWhere((text) => text == '你' || text == '书')!;
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump(const Duration(milliseconds: 410));
      expect(find.text(currentWord), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets('Android Back ends Vocab Rush and cancels its timer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VocabRushPage(
            settingsRepository: _RushSettingsRepository(),
            initialVocabulary: _smallVocabulary,
          ),
        ),
      ),
    );
    await startGame(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('PICK THE CORRECT MEANING'), findsNothing);
    await tester.pump(const Duration(minutes: 5));
    expect(find.text('PICK THE CORRECT MEANING'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final finish in ['advance', 'Back', 'timeout', 'desktop exit']) {
    testWidgets('slow saves retain the submitted card before $finish', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gate = Completer<void>();
      final progress = _ControlledRushProgressRepository()..gate = gate.future;
      final blocked = <bool>[];
      var now = DateTime(2026, 10, 13, 12);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VocabRushPage(
              lessonRepository: _RushLessonRepository(),
              progressRepository: progress,
              settingsRepository: const _RushSettingsRepository(),
              initialVocabulary: _smallVocabulary,
              clock: () => now,
              onNavigationBlocked: blocked.add,
            ),
          ),
        ),
      );
      await startGame(tester);
      final original = _visibleSmallWord(tester);
      await tester.tap(
        find.widgetWithText(OutlinedButton, _smallMeaning(original)),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(_visibleSmallWord(tester), original);
      expect(progress.reviewAttempts, hasLength(1));
      expect(progress.review, isNull);
      expect(blocked, [true]);
      expect(find.byKey(const Key('vocab-rush-saving')), findsOneWidget);
      expect(
        tester
            .widgetList<OutlinedButton>(find.byType(OutlinedButton))
            .every((b) => b.onPressed == null),
        isTrue,
      );
      if (finish == 'Back') {
        await tester.binding.handlePopRoute();
      } else if (finish == 'timeout') {
        now = now.add(const Duration(minutes: 3));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      } else if (finish == 'desktop exit') {
        expect(
          await tester.binding.handleRequestAppExit(),
          AppExitResponse.cancel,
        );
      }
      await tester.pump();
      expect(find.text('再玩一次 — Play Again'), findsNothing);
      expect(_visibleSmallWord(tester), original);
      gate.complete();
      await tester.pumpAndSettle();
      expect(progress.review?.wasCorrect, isTrue);
      expect(progress.reviewAttempts, hasLength(1));
      expect(blocked, [true, false]);
      if (finish == 'advance') {
        expect(_visibleSmallWord(tester), isNot(original));
      } else {
        expect(find.text('再玩一次 — Play Again'), findsOneWidget);
        expect(
          find.text(
            '${finish == 'timeout' ? 'Time!' : 'Game ended.'} You scored 1 word.',
          ),
          findsOneWidget,
        );
      }
      expect(await tester.binding.handleRequestAppExit(), AppExitResponse.exit);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'a persistent save error retains its word and retries once without rescoring',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final progress = _ControlledRushProgressRepository()
        ..failuresRemaining = 1;
      final gate = Completer<void>();
      var refreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VocabRushPage(
              lessonRepository: _RushLessonRepository(),
              progressRepository: progress,
              settingsRepository: const _RushSettingsRepository(),
              initialVocabulary: _smallVocabulary,
              onProgressChanged: () => refreshed++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Survival'));
      await startGame(tester);
      final original = _visibleSmallWord(tester);
      await tester.tap(
        find.widgetWithText(OutlinedButton, _smallMeaning(original)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(find.byKey(const Key('vocab-rush-save-error')), findsOneWidget);
      expect(_visibleSmallWord(tester), original);
      expect(find.textContaining('private'), findsNothing);
      expect(refreshed, 0);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('再玩一次 — Play Again'), findsNothing);
      progress.gate = gate.future;
      final retry = tester
          .widget<OutlinedButton>(
            find.descendant(
              of: find.byKey(const Key('vocab-rush-retry-save')),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed!;
      retry();
      retry();
      await tester.pump();
      expect(progress.reviewAttempts, hasLength(2));
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        progress.reviewAttempts.map((r) => r.submissionKey).toSet(),
        hasLength(1),
      );
      expect(progress.review?.wasCorrect, isTrue);
      expect(refreshed, 1);
      expect(find.text('Game ended. You scored 1 word.'), findsOneWidget);
      expect(find.byKey(const Key('vocab-rush-save-error')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a failed save stays recoverable on a narrow screen with large text',
    (tester) async {
      const size = Size(320, 640);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final progress = _ControlledRushProgressRepository()
        ..failuresRemaining = 1;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: VocabRushPage(
              lessonRepository: _RushLessonRepository(),
              progressRepository: progress,
              settingsRepository: const _RushSettingsRepository(),
              initialVocabulary: _smallVocabulary,
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Survival'));
      await tester.tap(find.text('Survival'));
      await startGame(tester);
      final answer = find.widgetWithText(
        OutlinedButton,
        _smallMeaning(_visibleSmallWord(tester)),
      );
      await tester.ensureVisible(answer);
      await tester.tap(answer);
      await tester.pumpAndSettle();
      final retry = find.byKey(const Key('vocab-rush-retry-save'));
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      expect(tester.getRect(retry).bottom, lessThanOrEqualTo(size.height));
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(progress.review?.wasCorrect, isTrue);
      expect(find.byKey(const Key('vocab-rush-save-error')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'disposal during a save allows persistence to finish without late UI updates',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gate = Completer<void>();
      final progress = _ControlledRushProgressRepository()..gate = gate.future;
      var refreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VocabRushPage(
              lessonRepository: _RushLessonRepository(),
              progressRepository: progress,
              settingsRepository: const _RushSettingsRepository(),
              initialVocabulary: _smallVocabulary,
              onProgressChanged: () => refreshed++,
            ),
          ),
        ),
      );
      await startGame(tester);
      await tester.tap(
        find.widgetWithText(
          OutlinedButton,
          _smallMeaning(_visibleSmallWord(tester)),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      gate.complete();
      await tester.pump(const Duration(seconds: 1));
      expect(progress.review?.wasCorrect, isTrue);
      expect(progress.reviewAttempts, hasLength(1));
      expect(refreshed, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the third strike waits for its save before showing results', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final progress = _ControlledRushProgressRepository();
    final gate = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VocabRushPage(
            lessonRepository: _RushLessonRepository(),
            progressRepository: progress,
            settingsRepository: const _RushSettingsRepository(),
            initialVocabulary: _smallVocabulary,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Survival'));
    await startGame(tester);
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt == 2) progress.gate = gate.future;
      final correct = _smallMeaning(_visibleSmallWord(tester));
      final wrong = tester
          .widgetList<OutlinedButton>(find.byType(OutlinedButton))
          .firstWhere((b) => (b.child as Text).data != correct);
      await tester.tap(find.byWidget(wrong));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('再玩一次 — Play Again'), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Three strikes! You scored 0 words.'), findsOneWidget);
    expect(progress.reviewAttempts, hasLength(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'sidebar and profile navigation retain pending and failed Rush saves',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gate = Completer<void>();
      final progress = _ControlledRushProgressRepository()
        ..gate = gate.future
        ..failuresRemaining = 1;
      await tester.pumpWidget(
        HanziPathApp(
          initialProfile: const LearnerProfile(
            name: 'Mei',
            hskLevel: 1,
            dailyWordTarget: 10,
          ),
          dependencies: AppDependencies(
            lessons: _RushLessonRepository(),
            progress: progress,
            settings: const _RushSettingsRepository(),
            vocabulary: const _RushVocabulary(),
            createPronunciationService: _RushPronunciationService.new,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vocab Rush'));
      await tester.pumpAndSettle();
      await startGame(tester);
      final original = _visibleSmallWord(tester);
      await tester.tap(
        find.widgetWithText(OutlinedButton, _smallMeaning(original)),
      );
      await tester.pump(const Duration(seconds: 1));
      final home = find.descendant(
        of: find.byType(AppSidebar),
        matching: find.text('Home'),
      );
      await tester.tap(home);
      await tester.pump();
      expect(find.byType(VocabRushPage), findsOneWidget);
      await tester.tap(find.byKey(const Key('open-profile-button')));
      await tester.pump();
      expect(find.byType(VocabRushPage), findsOneWidget);
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('vocab-rush-save-error')), findsOneWidget);
      await tester.tap(home);
      await tester.pump();
      expect(find.byType(VocabRushPage), findsOneWidget);
      progress.gate = null;
      await tester.ensureVisible(
        find.byKey(const Key('vocab-rush-retry-save')),
      );
      await tester.tap(find.byKey(const Key('vocab-rush-retry-save')));
      await tester.pumpAndSettle();
      await tester.tap(home);
      await tester.pumpAndSettle();
      expect(find.byType(VocabRushPage), findsNothing);
      expect(progress.review?.wasCorrect, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('an empty difficulty can recover by choosing available words', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VocabRushPage(
            settingsRepository: _RushSettingsRepository(),
            initialVocabulary: _smallVocabulary,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Advanced'));
    await tester.tap(find.text('开始游戏 — Start Game'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'No words are available for this difficulty. Choose another difficulty.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Beginner'));
    await startGame(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'vocabulary loading blocks repeated starts and recovers after failure',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gate = Completer<void>();
      final bundle = _RushVocabularyBundle()..gate = gate.future;
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: bundle,
            child: const Scaffold(
              body: VocabRushPage(
                settingsRepository: _RushSettingsRepository(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final start = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '开始游戏 — Start Game'),
      );
      start.onPressed!();
      start.onPressed!();
      await tester.pump();
      expect(bundle.loads, 1);
      expect(find.text('Loading words…'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Words could not be loaded. Please try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await startGame(tester);
      expect(bundle.loads, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'long answers stay readable and tappable on a narrow screen with large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VocabRushPage(
              settingsRepository: _RushSettingsRepository(),
              initialVocabulary: _smallVocabulary,
            ),
          ),
        ),
      );
      await startGame(tester);
      expect(tester.takeException(), isNull);
      for (final entry in _smallVocabulary) {
        final answer = entry['studyMeaning']! as String;
        final text = find.text(answer);
        final button = find.widgetWithText(OutlinedButton, answer);
        await tester.ensureVisible(button);
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(
          paragraph.size.height,
          greaterThanOrEqualTo(
            paragraph.getMaxIntrinsicHeight(paragraph.size.width) - .1,
          ),
          reason: answer,
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('difficulty and duration can be selected independently', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VocabRushPage(
            lessonRepository: _RushLessonRepository(),
            progressRepository: _RushProgressRepository(),
            settingsRepository: const _RushSettingsRepository(),
          ),
        ),
      ),
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
    final correctAnswer = vocabularyStudyMeaning(card);

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
      final correctAnswer = vocabularyStudyMeaning(card);
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

  testWidgets('uses curated study meanings instead of raw surname senses', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const vocabulary = [
      {
        'simplified': '三',
        'pinyin': 'sān',
        'studyMeaning': 'three',
        'meanings': ['surname San'],
        'partOfSpeech': ['numeral'],
        'hskLevel': 1,
      },
      {
        'simplified': '冷',
        'pinyin': 'lěng',
        'studyMeaning': 'cold',
        'meanings': ['surname Leng'],
        'partOfSpeech': ['adjective'],
        'hskLevel': 1,
      },
      {
        'simplified': '坐',
        'pinyin': 'zuò',
        'studyMeaning': 'to sit',
        'meanings': ['surname Zuo'],
        'partOfSpeech': ['verb'],
        'hskLevel': 1,
      },
      {
        'simplified': '钱',
        'pinyin': 'qián',
        'studyMeaning': 'money',
        'meanings': ['surname Qian'],
        'partOfSpeech': ['noun'],
        'hskLevel': 2,
      },
    ];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VocabRushPage(
            settingsRepository: _RushSettingsRepository(),
            initialVocabulary: vocabulary,
          ),
        ),
      ),
    );

    await startGame(tester);

    for (final meaning in ['three', 'cold', 'to sit', 'money']) {
      expect(find.widgetWithText(OutlinedButton, meaning), findsOneWidget);
    }
    expect(find.textContaining('surname'), findsNothing);
  });

  testWidgets('incorrect answers are saved for daily review', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lessons = _RushLessonRepository();
    final progress = _RushProgressRepository();
    final dailyReviews = _RushDailyReviewSessionRepository();
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
            dailyReviewSessionRepository: dailyReviews,
            settingsRepository: const _RushSettingsRepository(),
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
    final correctMeaning = vocabularyStudyMeaning(visibleCard);
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
    expect(dailyReviews.enqueuedCardId, 42);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets(
    'failed mistake persistence retries the original word with one logical submission',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final lessons = _RushLessonRepository();
      final progress = _RushProgressRepository();
      final dailyReviews = _FailOnceRushDailyReviewSessionRepository();
      final answeredAt = DateTime(2026, 10, 13, 23, 59);
      var now = answeredAt;
      var refreshed = 0;
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
              dailyReviewSessionRepository: dailyReviews,
              settingsRepository: const _RushSettingsRepository(),
              initialVocabulary: vocabulary,
              clock: () => now,
              onProgressChanged: () => refreshed++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Survival'));
      await startGame(tester);

      final originalHanzi = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .firstWhere((text) => const {'错', '对', '人', '书'}.contains(text));
      final originalCard = vocabulary.firstWhere(
        (card) => card['simplified'] == originalHanzi,
      );
      final correctMeaning = vocabularyStudyMeaning(originalCard);
      final wrongButton = tester
          .widgetList<OutlinedButton>(find.byType(OutlinedButton))
          .firstWhere(
            (button) => (button.child as Text).data != correctMeaning,
          );

      await tester.tap(find.byWidget(wrongButton));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('We couldn’t add this word to your review queue.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('vocab-rush-retry-save')), findsOneWidget);
      expect(dailyReviews.enqueueAttempts, 1);
      expect(refreshed, 1);

      await tester.pump(const Duration(milliseconds: 500));
      final laterHanzi = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .firstWhere((text) => const {'错', '对', '人', '书'}.contains(text));
      expect(laterHanzi, originalHanzi);
      now = now.add(const Duration(minutes: 2));

      await tester.tap(find.byKey(const Key('vocab-rush-retry-save')));
      await tester.pumpAndSettle();

      expect(lessons.attemptedCards.map((card) => card.chinese), [
        originalHanzi,
      ]);
      expect(dailyReviews.enqueueAttempts, 2);
      expect(dailyReviews.attemptDates, [answeredAt, answeredAt]);
      expect(refreshed, 1);
      expect(dailyReviews.enqueuedCardId, 42);
      expect(progress.reviewAttempts, hasLength(1));
      expect(progress.reviewAttempts.first.submissionKey, isNotNull);
      expect(
        progress.reviewAttempts.map((review) => review.submissionKey).toSet(),
        hasLength(1),
      );
    },
  );

  testWidgets('Vocab Rush speaks the visible Mandarin word', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _RushPronunciationService();
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
            settingsRepository: const _RushSettingsRepository(),
            pronunciationService: pronunciation,
            initialVocabulary: vocabulary,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Survival'));
    await startGame(tester);

    final visibleHanzi = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .firstWhere((text) => const {'错', '对', '人', '书'}.contains(text));
    await tester.tap(find.byKey(const Key('vocab-rush-pronunciation')));
    await tester.pump();

    expect(pronunciation.spoken, [visibleHanzi]);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(pronunciation.stopCalls, 1);
    expect(pronunciation.disposeCalls, 0);
  });

  testWidgets('Vocab Rush honors the disabled sound preference', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _RushPronunciationService();
    const vocabulary = [
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
            settingsRepository: const _RushSettingsRepository(
              soundEnabled: false,
            ),
            pronunciationService: pronunciation,
            initialVocabulary: vocabulary,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Survival'));
    await startGame(tester);

    final button = tester.widget<PronunciationButton>(
      find.byKey(const Key('vocab-rush-pronunciation')),
    );
    expect(button.onPressed, isNull);
    expect(
      find.byTooltip('Pronunciation audio is disabled in Settings'),
      findsOneWidget,
    );
    expect(pronunciation.spoken, isEmpty);
  });
}

const _smallVocabulary = [
  {
    'simplified': '你',
    'pinyin': 'nǐ',
    'studyMeaning': 'you (singular, used when addressing another person)',
    'hskLevel': 1,
  },
  {
    'simplified': '书',
    'pinyin': 'shū',
    'studyMeaning': 'a book or other bound collection of written pages',
    'hskLevel': 1,
  },
];

String _visibleSmallWord(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .firstWhere((t) => t == '你' || t == '书')!;

String _smallMeaning(String chinese) =>
    _smallVocabulary.singleWhere(
          (w) => w['simplified'] == chinese,
        )['studyMeaning']
        as String;

class _RushVocabulary extends BundledVocabularyRepository {
  const _RushVocabulary();
  @override
  Future<List<Map<String, dynamic>>> load({AssetBundle? bundle}) async =>
      _smallVocabulary;
}

class _RushVocabularyBundle extends CachingAssetBundle {
  Future<void>? gate;
  int loads = 0;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loads++;
    await gate;
    if (loads == 1) throw StateError('fixture unavailable');
    return jsonEncode(_smallVocabulary);
  }

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

class _RushSettingsRepository implements SettingsRepository {
  const _RushSettingsRepository({
    this.soundEnabled = true,
    this.showPinyin = true,
  });

  final bool soundEnabled;
  final bool showPinyin;

  @override
  Future<LearnerSettings> load() async =>
      LearnerSettings(soundEnabled: soundEnabled, showPinyin: showPinyin);

  @override
  Future<void> save(LearnerSettings settings) async {}
}

class _RushPronunciationService implements PronunciationService {
  final List<String> spoken = [];
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates => const Stream.empty();

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async =>
      const OfflineVoiceStatus.unavailable();

  @override
  Future<void> installOfflineVoice() async {}

  @override
  Future<void> speakMandarin(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> dispose() async => disposeCalls++;
}

class _RushLessonRepository implements LessonRepository {
  @override
  Future<void> deleteGenerated(int lessonId) async {
    throw UnimplementedError();
  }

  Flashcard? savedCard;
  final List<Flashcard> attemptedCards = [];

  @override
  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  }) async {
    attemptedCards.add(card);
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
  final List<ReviewRecord> reviewAttempts = [];

  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async {
    reviewAttempts.add(review);
    this.review = review;
    savedProgress = progress;
  }

  @override
  Future<CardProgress?> progressForCard(int cardId) async => null;

  @override
  Future<List<VocabularyCardProgress>> vocabularyProgress() async => const [];

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
  Future<void> updateSessionPosition({
    required int sessionId,
    required int currentCardIndex,
    required int expectedCardsReviewed,
  }) async {}

  @override
  Future<void> updateSession(
    LessonSession session, {
    bool reconcileFromHistory = false,
    int? expectedCardsReviewed,
    int? expectedCorrectAnswers,
  }) async {}
}

class _RushDailyReviewSessionRepository
    implements DailyReviewSessionRepository {
  int? enqueuedCardId;

  @override
  Future<void> enqueueCard({
    required DateTime date,
    required int cardId,
  }) async {
    enqueuedCardId = cardId;
  }

  @override
  Future<DailyReviewSession> create({
    required DateTime date,
    required List<int> queuedCardIds,
  }) => throw UnimplementedError();

  @override
  Future<DailyReviewSession?> load(DateTime date) async => null;

  @override
  Future<void> update(DailyReviewSession session) async {}

  @override
  Future<bool> complete({
    required int sessionId,
    required DateTime completedAt,
    required int expectedCardCount,
  }) async => true;
}

class _ControlledRushProgressRepository extends _RushProgressRepository {
  Future<void>? gate;
  int failuresRemaining = 0;

  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async {
    reviewAttempts.add(review);
    await gate;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('private database path');
    }
    this.review = review;
    savedProgress = progress;
  }
}

class _FailOnceRushDailyReviewSessionRepository
    extends _RushDailyReviewSessionRepository {
  int enqueueAttempts = 0;
  final attemptDates = <DateTime>[];

  @override
  Future<void> enqueueCard({
    required DateTime date,
    required int cardId,
  }) async {
    enqueueAttempts++;
    attemptDates.add(date);
    if (enqueueAttempts == 1) {
      throw StateError('sensitive database path');
    }
    await super.enqueueCard(date: date, cardId: cardId);
  }
}
