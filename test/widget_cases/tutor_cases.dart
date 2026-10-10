part of '../widget_test.dart';

void _registerTutorWidgetTests() {
  testWidgets('ai tutor tab opens the tutor chat page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiTutorPage(
            personalityRepository: MemoryTutorPersonalityRepository(),
            settingsRepository: _MemorySettingsRepository(),
            tutorContextRepository: _EmptyTutorContextRepository(),
            pronunciationService: pronunciation,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('龙老师 - Long Laoshi'), findsOneWidget);
    expect(find.text("TODAY'S FOCUS"), findsNothing);
    expect(find.text('GPT-4o'), findsNothing);
    expect(find.text('你好！我是龙老师。你想练习什么中文？'), findsOneWidget);
    expect(find.text('我家里有四个人。爸爸，妈妈，我，和妹妹。'), findsNothing);
    expect(find.text('Ask 龙老师 anything in English or 中文...'), findsOneWidget);
  });

  testWidgets('ai tutor retry reuses the failed prompt without exposing it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var calls = 0;
    final requests = <List<Map<String, String>>>[];
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiTutorPage(
            personalityRepository: MemoryTutorPersonalityRepository(),
            settingsRepository: _MemorySettingsRepository(),
            tutorContextRepository: _EmptyTutorContextRepository(),
            pronunciationService: pronunciation,
            request: (messages) async {
              calls++;
              requests.add([for (final message in messages) Map.of(message)]);
              if (calls == 1) {
                throw StateError(
                  'sensitive model path /private/models/teacher.gguf',
                );
              }
              return '{"chinese":"你好，梅！","pinyin":"nǐ hǎo, Méi!",'
                  '"english":"Hello, Mei!","tip":""}';
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Practise this sentence');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-tutor-error')), findsOneWidget);
    expect(
      find.text('We couldn’t reach Long Laoshi right now.'),
      findsOneWidget,
    );
    expect(find.textContaining('sensitive model path'), findsNothing);
    expect(find.text('Practise this sentence'), findsOneWidget);
    expect(calls, 1);

    await tester.tap(find.byKey(const Key('ai-tutor-retry')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(
      requests.last
          .where((message) => message['role'] == 'user')
          .map((message) => message['content']),
      ['Practise this sentence'],
    );
    expect(find.text('Practise this sentence'), findsOneWidget);
    expect(find.text('你好，梅！'), findsOneWidget);
    expect(find.byKey(const Key('ai-tutor-error')), findsNothing);
  });

  testWidgets('ai tutor configuration errors do not offer a futile retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiTutorPage(
            personalityRepository: MemoryTutorPersonalityRepository(),
            settingsRepository: _MemorySettingsRepository(),
            tutorContextRepository: _EmptyTutorContextRepository(),
            pronunciationService: pronunciation,
            request: (_) async => throw const GeminiConfigurationException(
              'Gemini is not configured for this build.',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Help me practise');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(
      find.text('Gemini is not configured for this build.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-tutor-retry')), findsNothing);
  });

  testWidgets('ai tutor speaks assistant Chinese replies only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiTutorPage(
            personalityRepository: MemoryTutorPersonalityRepository(),
            settingsRepository: _MemorySettingsRepository(),
            tutorContextRepository: _EmptyTutorContextRepository(),
            pronunciationService: pronunciation,
            request: (_) async =>
                '{"chinese":"你好，梅！","pinyin":"nǐ hǎo, Méi!",'
                '"english":"Hello, Mei!","tip":""}',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hear Mandarin reply'));
    await tester.pump();
    expect(pronunciation.spoken, ['你好！我是龙老师。你想练习什么中文？']);

    await tester.enterText(find.byType(TextField), 'Say hello to Mei');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-tutor-pronunciation')), findsNWidgets(2));
    await tester.tap(find.byTooltip('Hear Mandarin reply').last);
    await tester.pump();
    expect(pronunciation.spoken, ['你好！我是龙老师。你想练习什么中文？', '你好，梅！']);

    final stopsBeforeReset = pronunciation.stopCalls;
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(pronunciation.stopCalls, greaterThan(stopsBeforeReset));

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(pronunciation.disposeCalls, 0);
  });

  testWidgets('ai tutor disables reply audio when sound is turned off', (
    tester,
  ) async {
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiTutorPage(
            personalityRepository: MemoryTutorPersonalityRepository(),
            settingsRepository: _MemorySettingsRepository(
              const LearnerSettings(soundEnabled: false),
            ),
            tutorContextRepository: _EmptyTutorContextRepository(),
            pronunciationService: pronunciation,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byTooltip('Pronunciation audio is disabled in Settings'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<PronunciationButton>(
            find.byKey(const Key('ai-tutor-pronunciation')),
          )
          .onPressed,
      isNull,
    );
    expect(pronunciation.spoken, isEmpty);
  });
}
