import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/ai/ollama_service.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';

class _MemorySettingsRepository implements SettingsRepository {
  _MemorySettingsRepository([this.initial = const LearnerSettings()]);

  LearnerSettings initial;
  LearnerSettings? saved;
  Object? loadError;

  @override
  Future<LearnerSettings> load() async {
    if (loadError != null) throw loadError!;
    return initial;
  }

  @override
  Future<void> save(LearnerSettings settings) async {
    saved = settings;
    initial = settings;
  }
}

class _FakePronunciationService implements PronunciationService {
  final List<String> spokenTexts = [];
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates => const Stream.empty();

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async =>
      const OfflineVoiceStatus.notInstalled();

  @override
  Future<void> installOfflineVoice() async {}

  @override
  Future<void> speakMandarin(String text) async => spokenTexts.add(text);

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> dispose() async => disposeCalls++;
}

Future<void> _pumpTutor(
  WidgetTester tester, {
  required AiTutorRequest request,
  SettingsRepository? settingsRepository,
  PronunciationService? pronunciationService,
}) async {
  await tester.binding.setSurfaceSize(const Size(1100, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AiTutorPage(
          request: request,
          settingsRepository: settingsRepository ?? _MemorySettingsRepository(),
          pronunciationService: pronunciationService,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the tutor greeting, prompt chips, and composer', (
    tester,
  ) async {
    await _pumpTutor(
      tester,
      request: (_) async => fail('No request is expected before user input.'),
    );

    expect(find.text('龙老师 - Long Laoshi'), findsOneWidget);
    expect(find.text('Optional AI tutor · powered by Ollama'), findsOneWidget);
    expect(find.textContaining('你想练习什么中文'), findsOneWidget);
    expect(find.text('How do I use 的 correctly?'), findsOneWidget);
    expect(find.text('What are the four tones?'), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);
  });

  testWidgets('sends a typed prompt and renders a parsed JSON reply', (
    tester,
  ) async {
    final requests = <List<Map<String, String>>>[];
    await _pumpTutor(
      tester,
      request: (messages) async {
        requests.add(messages);
        return '{"chinese":"我的书","pinyin":"wǒ de shū",'
            '"english":"my book","tip":"的 links a modifier to a noun."}';
      },
    );

    await tester.enterText(find.byType(TextField), 'How do I say my book?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.first['role'], 'system');
    expect(requests.single.last, {
      'role': 'user',
      'content': 'How do I say my book?',
    });
    expect(find.text('How do I say my book?'), findsOneWidget);
    expect(find.text('我的书'), findsOneWidget);
    expect(find.text('wǒ de shū'), findsOneWidget);
    expect(find.text('my book'), findsOneWidget);
    expect(find.text('Tip: 的 links a modifier to a noun.'), findsOneWidget);
    expect(find.text('龙老师 is thinking...'), findsNothing);
  });

  testWidgets('prompt chips send their preset question', (tester) async {
    final prompts = <String>[];
    await _pumpTutor(
      tester,
      request: (messages) async {
        prompts.add(messages.last['content'] ?? '');
        return '{"chinese":"好的","pinyin":"hǎo de","english":"OK"}';
      },
    );

    await tester.tap(find.text('What are the four tones?'));
    await tester.pumpAndSettle();

    expect(prompts, ['What are the four tones?']);
    expect(find.text('What are the four tones?'), findsNWidgets(2));
    expect(find.text('好的'), findsOneWidget);
  });

  testWidgets('shows a plain reply when the model response is not JSON', (
    tester,
  ) async {
    await _pumpTutor(tester, request: (_) async => 'Sure! Let us practice.');

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Sure! Let us practice.'), findsOneWidget);
  });

  testWidgets('strips markdown fences before parsing a JSON reply', (
    tester,
  ) async {
    await _pumpTutor(
      tester,
      request: (_) async =>
          '```json\n{"chinese":"你好","pinyin":"nǐ hǎo","english":"hello"}\n```',
    );

    await tester.enterText(find.byType(TextField), 'Hi');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('你好'), findsOneWidget);
    expect(find.text('nǐ hǎo'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('connection errors are retryable and retry resends the prompt', (
    tester,
  ) async {
    var attempts = 0;
    await _pumpTutor(
      tester,
      request: (messages) async {
        attempts++;
        if (attempts == 1) {
          throw StateError('Connection refused');
        }
        return '{"chinese":"再见","pinyin":"zài jiàn","english":"goodbye"}';
      },
    );

    await tester.enterText(find.byType(TextField), 'One more time');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-tutor-error')), findsOneWidget);
    expect(
      find.text('We couldn’t connect to Ollama. Start Ollama before retrying.'),
      findsOneWidget,
    );
    expect(find.text('One more time'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-tutor-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('再见'), findsOneWidget);
    expect(find.byKey(const Key('ai-tutor-error')), findsNothing);
    expect(find.text('One more time'), findsOneWidget);
  });

  testWidgets('configuration errors are shown without a retry option', (
    tester,
  ) async {
    await _pumpTutor(
      tester,
      request: (_) async => throw const OllamaConfigurationException(
        'Long Laoshi needs a mobile Ollama endpoint. Configure OLLAMA_URL '
        'for this build, or use the tutor on desktop.',
      ),
    );

    await tester.enterText(find.byType(TextField), '你好');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('needs a mobile Ollama endpoint'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-tutor-retry')), findsNothing);
  });

  testWidgets('empty prompts and repeated sends are ignored', (tester) async {
    var requests = 0;
    await _pumpTutor(
      tester,
      request: (messages) async {
        requests++;
        return '{"chinese":"好"}';
      },
    );

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(requests, 0);

    await tester.enterText(find.byType(TextField), 'Count once');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.text('Count once'), findsOneWidget);
  });

  testWidgets('reset restores the initial conversation', (tester) async {
    await _pumpTutor(
      tester,
      request: (_) async => '{"chinese":"谢谢","pinyin":"xiè xie"}',
    );

    await tester.enterText(find.byType(TextField), 'Thanks');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('谢谢'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(find.text('谢谢'), findsNothing);
    expect(find.text('Thanks'), findsNothing);
    expect(find.textContaining('你想练习什么中文'), findsOneWidget);
  });

  testWidgets('disables reply audio when the sound preference is off', (
    tester,
  ) async {
    final pronunciation = _FakePronunciationService();
    await _pumpTutor(
      tester,
      request: (_) async =>
          '{"chinese":"你好","pinyin":"nǐ hǎo","english":"hello"}',
      settingsRepository: _MemorySettingsRepository(
        const LearnerSettings(soundEnabled: false),
      ),
      pronunciationService: pronunciation,
    );

    final button = tester.widget<IconButton>(
      find.byKey(const Key('ai-tutor-pronunciation')),
    );
    expect(button.onPressed, isNull);
    expect(
      find.byTooltip('Pronunciation audio is disabled in Settings'),
      findsOneWidget,
    );
  });

  testWidgets('speaks a reply through the shared pronunciation service', (
    tester,
  ) async {
    final pronunciation = _FakePronunciationService();
    await _pumpTutor(
      tester,
      request: (_) async =>
          '{"chinese":"你好","pinyin":"nǐ hǎo","english":"hello"}',
      pronunciationService: pronunciation,
    );

    await tester.enterText(find.byType(TextField), 'Hi');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-tutor-pronunciation')).last);
    await tester.pumpAndSettle();

    expect(pronunciation.spokenTexts, ['你好']);
    expect(pronunciation.disposeCalls, 0);
  });
}
