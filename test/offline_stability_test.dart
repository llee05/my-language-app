import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/local_database.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/app_dependencies.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';
import 'package:mylanguageapp/services/speech_input_service.dart';
import 'package:mylanguageapp/services/vocabulary_study_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets(
    'fresh offline study and saved progress survive database reopening',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1000));
      final previousHttp = HttpOverrides.current;
      final network = _NoNetwork();
      HttpOverrides.global = network;
      final directory = Directory.systemTemp.createTempSync(
        'tingshuo_offline_',
      );
      await tester.runAsync(LocalDatabase.close);
      LocalDatabase.useDatabasePathForTesting('${directory.path}/study.db');
      addTearDown(() async {
        HttpOverrides.global = previousHttp;
        await LocalDatabase.close();
        LocalDatabase.useDatabasePathForTesting(inMemoryDatabasePath);
        await directory.delete(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      final dependencies = AppDependencies(
        createPronunciationService: _SilentVoice.new,
        createSpeechInputService: _SilentMicrophone.new,
      );
      await tester.pumpWidget(HanziPathApp(dependencies: dependencies));
      await _waitFor(tester, find.text('Build your learning path'));
      await tester.enterText(find.byType(TextFormField), 'Offline Mei');
      await tester.tap(find.text('HSK 3'));
      await tester.ensureVisible(find.text('20 words'));
      await tester.tap(find.text('20 words'));
      await tester.ensureVisible(find.text('Start learning'));
      await tester.tap(find.text('Start learning'));
      await _waitFor(tester, find.text('你好，Offline Mei'));

      for (final page in {
        'Flashcards': 'lesson-library-content',
        'Dictionary': 'vocabulary-result-count',
        'Doom Scrolling': 'doom-scrolling-feed',
        'Listening Practice': 'listening-library-content',
        'Exam Mode': 'exam-start',
      }.entries) {
        final navigation = find.descendant(
          of: find.byType(AppSidebar),
          matching: find.text(page.key),
        );
        await tester.ensureVisible(navigation);
        await tester.tap(navigation);
        await _waitFor(tester, find.byKey(Key(page.value)));
        expect(tester.takeException(), isNull, reason: page.key);
      }

      // Persist an explicit rating with the same service used by the study modes.
      // Reopen the actual file database, rather than retaining a memory fake.
      await tester.runAsync(() async {
        final words = await dependencies.vocabulary.load();
        final study = VocabularyStudyService(
          lessons: dependencies.lessons,
          vocabulary: dependencies.vocabulary,
          progress: dependencies.progress,
        );
        await study.recordWord(
          words.first,
          rating: ReviewRating.easy,
          submissionKey: 'offline-stability-rating',
        );
        final settings = await dependencies.settings.load();
        await dependencies.settings.save(
          settings.copyWith(appThemeId: 'forest'),
        );
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(LocalDatabase.close);
      await tester.pumpWidget(HanziPathApp(dependencies: dependencies));
      await _waitFor(tester, find.text('你好，Offline Mei'));
      expect(find.text('Build your learning path'), findsNothing);
      await tester.runAsync(() async {
        final profile = await dependencies.learners.load();
        expect(profile!.hskLevel, 3);
        expect(profile.dailyWordTarget, 20);
        expect((await dependencies.settings.load()).appThemeId, 'forest');
        final history = await dependencies.progress.reviewHistory();
        expect(history, hasLength(1));
        expect(history.single.submissionKey, 'offline-stability-rating');
      });
      expect(network.attempts, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(LocalDatabase.close);
      await tester.pump();
    },
  );
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
  }
  expect(finder, findsWidgets);
}

class _NoNetwork extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw const SocketException('Offline stability test');
  }
}

class _SilentVoice implements PronunciationService {
  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates => const Stream.empty();
  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async =>
      const OfflineVoiceStatus.unavailable();
  @override
  Future<void> installOfflineVoice() async => throw StateError('No downloads');
  @override
  Future<void> speakMandarin(String text) async => throw StateError('No voice');
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _SilentMicrophone implements SpeechInputService {
  @override
  Future<void> startListening({
    required SpeechInputResult onResult,
    SpeechInputError? onError,
    String? preferredLocaleId,
  }) async => throw const SpeechInputException('Microphone unavailable');
  @override
  Future<void> stopListening() async {}
  @override
  Future<void> cancelListening() async {}
  @override
  Future<void> dispose() async {}
}
