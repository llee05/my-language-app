import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/hsk_exam.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/bundled_vocabulary_repository.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';

const word = ExamWord(
  id: 'word',
  hanzi: '学习',
  traditional: '學習',
  pinyin: 'xué xí',
  meaning: 'study',
  meanings: {'study'},
);
HskExam smallExam() => HskExam(
  level: 1,
  questions: [
    ExamQuestion(
      section: ExamSection.reading,
      word: word,
      options: ['study', 'eat', 'drink', 'sleep'],
    ),
    ExamQuestion(section: ExamSection.writing, word: word, options: []),
    ExamQuestion(
      section: ExamSection.listening,
      word: word,
      options: ['study', 'eat', 'drink', 'sleep'],
    ),
  ],
);

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _session(
  WidgetTester tester, {
  _Audio? audio,
  DateTime Function()? clock,
  bool timed = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ExamSessionPage(
        exam: smallExam(),
        pronunciationService: audio ?? _Audio(),
        timed: timed,
        clock: clock,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final entries =
      (jsonDecode(File('assets/data/hsk_vocabulary.json').readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>();
  for (var level = 1; level <= 6; level++) {
    testWidgets('HSK $level can be selected and started offline', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExamModePage(
              vocabularyRepository: _Vocabulary(entries),
              settingsRepository: _Settings(),
              pronunciationService: _Audio(),
              random: Random(1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'exam-level-$level');
      expect(
        find.text(
          '${HskExam.questionsPerSection(level) * 4} questions · ${HskExam.questionsPerSection(level)} per section',
        ),
        findsOneWidget,
      );
      await tap(tester, 'exam-start');
      expect(find.text('HSK $level practice exam'), findsOneWidget);
      expect(find.byKey(const Key('exam-position')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'answers remain editable and hidden until submitted; written recall accepts traditional',
    (tester) async {
      await _session(tester);
      await tap(tester, 'exam-option-1');
      expect(find.text('Incorrect'), findsNothing);
      await tap(tester, 'exam-next');
      await tester.enterText(
        find.byKey(const Key('exam-written-answer')),
        '學習',
      );
      await tap(tester, 'exam-previous');
      await tap(tester, 'exam-option-0');
      await tap(tester, 'exam-next');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('exam-written-answer')))
            .controller!
            .text,
        '學習',
      );
      await tap(tester, 'exam-submit');
      expect(find.textContaining('1 unanswered questions'), findsOneWidget);
      await tester.tap(find.text('Keep working'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exam-complete')), findsNothing);
      await tap(tester, 'exam-submit');
      await tap(tester, 'exam-confirm-submit');
      expect(find.text('2 / 3 · 67%'), findsOneWidget);
      expect(find.text('Reading: 1 / 1'), findsOneWidget);
      expect(find.text('Written recall: 1 / 1'), findsOneWidget);
      expect(find.text('Listening: 0 / 1'), findsOneWidget);
      expect(find.text('Answer review'), findsOneWidget);
      expect(find.byKey(const Key('exam-option-0')), findsNothing);
    },
  );

  testWidgets(
    'audio prompts hide Hanzi and failures can be excluded from scoring',
    (tester) async {
      final audio = _Audio()..fail = true;
      await _session(tester, audio: audio);
      await tap(tester, 'exam-jump-2');
      expect(find.text(word.hanzi), findsNothing);
      expect(find.text(word.pinyin), findsNothing);
      await tap(tester, 'exam-play');
      expect(audio.requests, [word.hanzi]);
      await tap(tester, 'exam-skip-audio');
      await tap(tester, 'exam-submit');
      await tap(tester, 'exam-confirm-submit');
      expect(find.text('0 / 2 · 0%'), findsOneWidget);
      expect(find.textContaining('partial assessment'), findsOneWidget);
    },
  );

  testWidgets(
    'late audio failure cannot affect a later question or disposed page',
    (tester) async {
      final audio = _Audio()..gate = Completer<void>();
      await _session(tester, audio: audio);
      await tap(tester, 'exam-jump-2');
      await tap(tester, 'exam-play');
      await tap(tester, 'exam-previous');
      audio.gate!.completeError(StateError('late audio failure'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Audio could not'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
      expect(audio.stops, greaterThan(0));
    },
  );

  testWidgets('deadline submits unanswered questions after background time', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 27);
    await _session(tester, timed: true, clock: () => now);
    await tap(tester, 'exam-option-0');
    now = now.add(const Duration(minutes: 26));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Time is up'), findsOneWidget);
    expect(find.text('1 / 3 · 33%'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('deadline closes pending submission dialog and locks answers', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 27);
    await _session(tester, timed: true, clock: () => now);
    await tap(tester, 'exam-submit');
    now = now.add(const Duration(minutes: 26));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Time is up'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('leaving a running exam requires confirmation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExamSessionPage(
                    exam: smallExam(),
                    pronunciationService: _Audio(),
                    timed: false,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Leave this exam?'), findsOneWidget);
    await tester.tap(find.text('Continue exam'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave exam'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets(
    'sound preference disables listening; load errors retry and sparse levels fail gracefully',
    (tester) async {
      final vocabulary = _Vocabulary()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExamModePage(
              vocabularyRepository: vocabulary,
              settingsRepository: _Settings(sound: false),
              pronunciationService: _Audio(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Exam vocabulary could not be loaded'), findsOneWidget);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(640, 200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
      await tester.pumpAndSettle();
      vocabulary.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('exam-listening-toggle')),
            )
            .onChanged,
        isNull,
      );
      expect(find.text('30 questions · 10 per section'), findsOneWidget);
      await tap(tester, 'exam-start');
      expect(find.textContaining('A full exam could not'), findsOneWidget);
    },
  );

  for (final size in [const Size(360, 640), const Size(1200, 900)]) {
    testWidgets('exam and results fit $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _session(tester);
      await tap(tester, 'exam-next');
      await tester.enterText(
        find.byKey(const Key('exam-written-answer')),
        '学习',
      );
      await tap(tester, 'exam-submit');
      await tap(tester, 'exam-confirm-submit');
      expect(find.byKey(const Key('exam-score')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Settings implements SettingsRepository {
  _Settings({this.sound = true});
  final bool sound;
  @override
  Future<LearnerSettings> load() async => LearnerSettings(soundEnabled: sound);
  @override
  Future<void> save(LearnerSettings settings) async {}
}

class _Vocabulary extends BundledVocabularyRepository {
  _Vocabulary([this.entries = const []]);
  final List<Map<String, dynamic>> entries;
  bool fail = false;
  @override
  Future<List<Map<String, dynamic>>> load({AssetBundle? bundle}) async {
    if (fail) throw StateError('unavailable');
    return entries;
  }
}

class _Audio implements PronunciationService {
  bool fail = false;
  Completer<void>? gate;
  int stops = 0;
  final requests = <String>[];
  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates => const Stream.empty();
  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async =>
      const OfflineVoiceStatus.unavailable();
  @override
  Future<void> installOfflineVoice() async {}
  @override
  Future<void> speakMandarin(String text) async {
    requests.add(text);
    if (fail) throw StateError('no voice');
    await gate?.future;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {}
}
