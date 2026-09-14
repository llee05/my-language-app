import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mylanguageapp/ai/ai_service.dart';
import 'package:mylanguageapp/ai/gemini_service.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/ai_configuration.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/models/tutor_learner_snapshot.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';
import 'package:mylanguageapp/repositories/tutor_context_repository.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';
import 'package:mylanguageapp/services/speech_input_service.dart';

import 'ai_test_support.dart';

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

class _FakeDialoguePronunciationService extends _FakePronunciationService
    implements OfflinePronunciationManager, DialoguePronunciationService {
  final List<List<PronunciationUtterance>> dialogues = [];

  @override
  Stream<OfflineVoiceStatus> get voicePackUpdates => const Stream.empty();

  @override
  Future<OfflineVoiceStatus> checkVoicePack(PronunciationEngine engine) async =>
      OfflineVoiceStatus.ready(engine: engine);

  @override
  Future<void> installVoicePack(PronunciationEngine engine) async {}

  @override
  List<PronunciationVoice> voicesFor(PronunciationEngine engine) => [
    kokoroMandarinVoices.first,
    kokoroMandarinVoices.firstWhere((voice) => voice.id.startsWith('zm_')),
  ];

  @override
  Future<void> configurePronunciation({
    required PronunciationEngine engine,
    List<String> voiceIds = const [],
  }) async {}

  @override
  Future<void> speakDialogue(List<PronunciationUtterance> utterances) async =>
      dialogues.add(List.unmodifiable(utterances));
}

class _FakeSpeechInputService implements SpeechInputService {
  String transcript = '';
  String? preferredLocaleId;
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int disposeCalls = 0;
  Object? startError;

  @override
  Future<void> startListening({
    required SpeechInputResult onResult,
    SpeechInputError? onError,
    String? preferredLocaleId,
  }) async {
    startCalls++;
    this.preferredLocaleId = preferredLocaleId;
    if (startError != null) throw startError!;
    if (transcript.isNotEmpty) onResult(transcript);
  }

  @override
  Future<void> stopListening() async => stopCalls++;

  @override
  Future<void> cancelListening() async => cancelCalls++;

  @override
  Future<void> dispose() async => disposeCalls++;
}

class _MemoryTutorContextRepository implements TutorContextRepository {
  _MemoryTutorContextRepository({
    TutorLearnerSnapshot? snapshot,
    this.loadError,
  }) : snapshot =
           snapshot ?? TutorLearnerSnapshot(asOf: DateTime.utc(2026, 9, 13));

  final TutorLearnerSnapshot snapshot;
  final Object? loadError;
  final List<DateTime> requestedAt = [];

  @override
  Future<TutorLearnerSnapshot> load({required DateTime asOf}) async {
    requestedAt.add(asOf);
    if (loadError != null) throw loadError!;
    return snapshot;
  }
}

Future<void> _pumpTutor(
  WidgetTester tester, {
  AiTutorRequest? request,
  AiService aiService = const AiService(),
  SettingsRepository? settingsRepository,
  TutorContextRepository? tutorContextRepository,
  PronunciationService? pronunciationService,
  SpeechInputService? speechInputService,
  DateTime Function()? clock,
}) async {
  await tester.binding.setSurfaceSize(const Size(1100, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AiTutorPage(
          request: request,
          aiService: aiService,
          settingsRepository: settingsRepository ?? _MemorySettingsRepository(),
          tutorContextRepository:
              tutorContextRepository ?? _MemoryTutorContextRepository(),
          pronunciationService: pronunciationService,
          speechInputService: speechInputService,
          clock: clock,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _dialogueResponse() => jsonEncode({
  'title': 'At the café',
  'setting': 'Two friends order a drink.',
  'lines': [
    {
      'speaker': 'A',
      'chinese': '你好！',
      'tokens': ['你', '好'],
      'pinyin': 'Nǐ hǎo!',
      'english': 'Hello!',
    },
    {
      'speaker': 'B',
      'chinese': '你好！',
      'tokens': ['你', '好'],
      'pinyin': 'Nǐ hǎo!',
      'english': 'Hello!',
    },
    {
      'speaker': 'A',
      'chinese': '我要咖啡。',
      'tokens': ['我', '要', '咖啡'],
      'pinyin': 'Wǒ yào kāfēi.',
      'english': 'I want coffee.',
    },
    {
      'speaker': 'B',
      'chinese': '好，谢谢。',
      'tokens': ['好', '谢谢'],
      'pinyin': 'Hǎo, xièxie.',
      'english': 'Okay, thank you.',
    },
  ],
  'new_words': [
    {'chinese': '咖啡', 'pinyin': 'kāfēi', 'english': 'coffee'},
  ],
  'questions': [
    {
      'prompt': 'What does Speaker A want?',
      'options': ['Coffee', 'Tea'],
      'correct_index': 0,
      'explanation': 'Speaker A says they want coffee.',
    },
    {
      'prompt': 'What does Speaker B say at the end?',
      'options': ['Goodbye', 'Okay, thank you'],
      'correct_index': 1,
      'explanation': 'Speaker B agrees and says thank you.',
    },
  ],
});

String _roleplayResponse({bool complete = false}) => jsonEncode({
  'npc_reply': {
    'chinese': complete ? '好，这个菜不辣。' : '你好！你想点菜吗？',
    'tokens': complete
        ? ['好', '这个', '菜', '不', '辣']
        : ['你', '好', '你', '想', '点', '菜', '吗'],
    'pinyin': complete
        ? 'Hǎo, zhège cài bù là.'
        : 'Nǐ hǎo! Nǐ xiǎng diǎn cài ma?',
    'english': complete
        ? 'Okay, this dish is not spicy.'
        : 'Hello! Would you like to order?',
  },
  'hint': {
    'chinese': '我想点这个菜。',
    'tokens': ['我', '想', '点', '这个', '菜'],
    'pinyin': 'Wǒ xiǎng diǎn zhège cài.',
    'english': 'I would like to order this dish.',
  },
  'progress': complete
      ? 'You ordered and checked the spice level.'
      : 'Order a dish and ask whether it is spicy.',
  'mission_complete': complete,
  'feedback': complete
      ? 'You ordered politely and clearly asked about the spice level.'
      : '',
  'review_words': complete ? ['菜', '辣'] : <String>[],
});

TutorLearnerSnapshot _roleplaySnapshot() => TutorLearnerSnapshot(
  asOf: DateTime.utc(2026, 9, 14),
  knownWords: const [
    TutorWordSnapshot(
      chinese: '你',
      pinyin: 'nǐ',
      englishMeaning: 'you',
      mastery: .8,
      incorrectAnswers: 0,
    ),
    TutorWordSnapshot(
      chinese: '好',
      pinyin: 'hǎo',
      englishMeaning: 'good',
      mastery: .8,
      incorrectAnswers: 0,
    ),
    TutorWordSnapshot(
      chinese: '我',
      pinyin: 'wǒ',
      englishMeaning: 'I',
      mastery: .8,
      incorrectAnswers: 0,
    ),
    TutorWordSnapshot(
      chinese: '想',
      pinyin: 'xiǎng',
      englishMeaning: 'want',
      mastery: .8,
      incorrectAnswers: 0,
    ),
    TutorWordSnapshot(
      chinese: '这个',
      pinyin: 'zhège',
      englishMeaning: 'this',
      mastery: .8,
      incorrectAnswers: 0,
    ),
    TutorWordSnapshot(
      chinese: '不',
      pinyin: 'bù',
      englishMeaning: 'not',
      mastery: .8,
      incorrectAnswers: 0,
    ),
    TutorWordSnapshot(
      chinese: '吗',
      pinyin: 'ma',
      englishMeaning: 'question particle',
      mastery: .8,
      incorrectAnswers: 0,
    ),
  ],
);

void main() {
  testWidgets('tutor uses the saved provider and removal stops later sends', (
    tester,
  ) async {
    final repository = MemoryAiConfigurationRepository(
      const AiConfiguration(
        provider: AiProvider.openai,
        apiKey: 'personal-key',
        model: 'gpt-4.1-mini',
      ),
    );
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      expect(request.url.host, 'api.openai.com');
      expect(request.headers['authorization'], 'Bearer personal-key');
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {
                  'content': jsonEncode({
                    'chinese': '我的书',
                    'pinyin': 'wǒ de shū',
                    'english': 'my book',
                  }),
                },
              },
            ],
          }),
        ),
        200,
      );
    });
    addTearDown(client.close);
    await _pumpTutor(
      tester,
      aiService: AiService(configurationRepository: repository, client: client),
    );
    expect(requests, 0);
    await tester.enterText(find.byType(TextField), 'How do I say my book?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('我的书'), findsOneWidget);
    expect(find.text('wǒ de shū'), findsOneWidget);
    expect(find.text('my book'), findsOneWidget);
    await repository.clear();
    await tester.enterText(find.byType(TextField), 'Explain more');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.textContaining('add your API key in Settings'), findsOneWidget);
  });

  testWidgets('renders the tutor greeting, prompt chips, and composer', (
    tester,
  ) async {
    await _pumpTutor(
      tester,
      request: (_) async => fail('No request is expected before user input.'),
    );

    expect(find.text('龙老师 - Long Laoshi'), findsOneWidget);
    expect(
      find.text('Optional AI tutor · your chosen provider'),
      findsOneWidget,
    );
    expect(find.textContaining('你想练习什么中文'), findsOneWidget);
    expect(find.text('How do I use 的 correctly?'), findsOneWidget);
    expect(find.text('What are the four tones?'), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);
    expect(find.byKey(const Key('ai-tutor-push-to-talk')), findsOneWidget);
  });

  testWidgets(
    'holding the tutor microphone dictates Mandarin into the prompt',
    (tester) async {
      final speechInput = _FakeSpeechInputService()..transcript = '我想练习中文';
      final pronunciation = _FakePronunciationService();
      await _pumpTutor(
        tester,
        speechInputService: speechInput,
        pronunciationService: pronunciation,
        request: (_) async => fail('Dictation should not send automatically.'),
      );

      await tester.enterText(find.byType(TextField), '龙老师，');
      await tester.longPress(find.byKey(const Key('ai-tutor-push-to-talk')));
      await tester.pumpAndSettle();

      expect(speechInput.startCalls, 1);
      expect(speechInput.stopCalls, 1);
      expect(pronunciation.stopCalls, 1);
      expect(speechInput.preferredLocaleId, 'zh_CN');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '龙老师， 我想练习中文',
      );
    },
  );

  testWidgets('push-to-talk failures leave typed prompts intact', (
    tester,
  ) async {
    final speechInput = _FakeSpeechInputService()
      ..startError = const SpeechInputException(
        'Microphone access was denied.',
      );
    await _pumpTutor(
      tester,
      speechInputService: speechInput,
      pronunciationService: _FakePronunciationService(),
    );

    await tester.enterText(find.byType(TextField), 'Keep this text');
    await tester.longPress(find.byKey(const Key('ai-tutor-push-to-talk')));
    await tester.pumpAndSettle();

    expect(find.text('Microphone access was denied.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Keep this text',
    );
  });

  testWidgets('listening-dialogue topics support push-to-talk', (tester) async {
    final speechInput = _FakeSpeechInputService()
      ..transcript = 'Ordering breakfast';
    await _pumpTutor(
      tester,
      speechInputService: speechInput,
      pronunciationService: _FakePronunciationService(),
    );

    await tester.tap(find.text('Listening dialogue'));
    await tester.pumpAndSettle();
    await tester.longPress(
      find.byKey(const Key('dialogue-topic-push-to-talk')),
    );
    await tester.pumpAndSettle();

    expect(speechInput.preferredLocaleId, isNull);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('dialogue-topic')))
          .controller!
          .text,
      'Ordering breakfast',
    );
  });

  testWidgets(
    'generates a validated two-voice dialogue with tappable new words and questions',
    (tester) async {
      final pronunciation = _FakeDialoguePronunciationService();
      final contextRepository = _MemoryTutorContextRepository(
        snapshot: TutorLearnerSnapshot(
          asOf: DateTime.utc(2026, 9, 14),
          knownWords: const [
            TutorWordSnapshot(
              chinese: '你',
              pinyin: 'nǐ',
              englishMeaning: 'you',
              mastery: .8,
              incorrectAnswers: 0,
            ),
            TutorWordSnapshot(
              chinese: '好',
              pinyin: 'hǎo',
              englishMeaning: 'good',
              mastery: .9,
              incorrectAnswers: 0,
            ),
            TutorWordSnapshot(
              chinese: '我',
              pinyin: 'wǒ',
              englishMeaning: 'I',
              mastery: .8,
              incorrectAnswers: 0,
            ),
            TutorWordSnapshot(
              chinese: '要',
              pinyin: 'yào',
              englishMeaning: 'want',
              mastery: .7,
              incorrectAnswers: 1,
            ),
            TutorWordSnapshot(
              chinese: '谢谢',
              pinyin: 'xièxie',
              englishMeaning: 'thank you',
              mastery: .8,
              incorrectAnswers: 0,
            ),
          ],
        ),
      );
      List<Map<String, String>>? requestMessages;
      await _pumpTutor(
        tester,
        pronunciationService: pronunciation,
        tutorContextRepository: contextRepository,
        request: (messages) async {
          requestMessages = messages;
          return _dialogueResponse();
        },
      );

      await tester.tap(find.text('Listening dialogue'));
      await tester.pumpAndSettle();
      expect(find.text('AI listening dialogue'), findsOneWidget);
      expect(find.textContaining('5 studied words'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('dialogue-topic')),
        'At a café',
      );
      await tester.tap(find.byKey(const Key('generate-dialogue')));
      await tester.pumpAndSettle();

      expect(requestMessages, isNotNull);
      expect(requestMessages!.first['content'], contains('known_words='));
      expect(requestMessages!.first['content'], contains('"chinese":"你"'));
      expect(requestMessages!.last['content'], contains('At a café'));
      expect(find.text('At the café'), findsOneWidget);
      expect(find.textContaining('What does Speaker A want?'), findsOneWidget);
      expect(find.byKey(const Key('dialogue-transcript')), findsNothing);
      expect(pronunciation.dialogues, hasLength(1));
      expect(
        pronunciation.dialogues.single.map((line) => line.voice.id).toSet(),
        hasLength(2),
      );

      await tester.tap(find.byKey(const Key('dialogue-new-word-咖啡')));
      await tester.pumpAndSettle();
      expect(find.text('kāfēi'), findsOneWidget);
      expect(find.text('coffee'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('dialogue-answer-0-0')));
      await tester.tap(find.byKey(const Key('dialogue-answer-0-0')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('dialogue-answer-1-1')));
      await tester.tap(find.byKey(const Key('dialogue-answer-1-1')));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('submit-dialogue-answers')),
      );
      await tester.tap(find.byKey(const Key('submit-dialogue-answers')));
      await tester.pumpAndSettle();

      expect(find.text('Score: 2 / 2'), findsOneWidget);
      expect(find.byKey(const Key('dialogue-transcript')), findsOneWidget);
      expect(find.text('Wǒ yào kāfēi.'), findsOneWidget);
    },
  );

  testWidgets('offers five goal-oriented roleplay missions', (tester) async {
    await _pumpTutor(
      tester,
      tutorContextRepository: _MemoryTutorContextRepository(
        snapshot: _roleplaySnapshot(),
      ),
      request: (_) async => fail('A mission should not start automatically.'),
    );

    await tester.tap(find.text('Roleplay missions'));
    await tester.pumpAndSettle();

    expect(find.text('AI roleplay missions'), findsOneWidget);
    expect(find.text('Order food'), findsOneWidget);
    expect(find.text('Visit a pharmacist'), findsOneWidget);
    expect(find.text('Language exchange'), findsOneWidget);
    expect(find.text('Return an order'), findsOneWidget);
    expect(find.text('Survive a station announcement'), findsOneWidget);
    expect(find.textContaining('7 studied words'), findsOneWidget);
  });

  testWidgets('roleplay waits for a small studied vocabulary base', (
    tester,
  ) async {
    await _pumpTutor(
      tester,
      request: (_) async => fail('A disabled mission must not make a request.'),
    );

    await tester.tap(find.text('Roleplay missions'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Study at least five'), findsOneWidget);
    final startButton = tester.widget<FilledButton>(
      find.byKey(const Key('start-roleplay-food-spicy')),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets(
    'runs a roleplay with optional hints, feedback, and review words',
    (tester) async {
      final requests = <List<Map<String, String>>>[];
      var turn = 0;
      await _pumpTutor(
        tester,
        tutorContextRepository: _MemoryTutorContextRepository(
          snapshot: _roleplaySnapshot(),
        ),
        request: (messages) async {
          requests.add(messages);
          return _roleplayResponse(complete: turn++ > 0);
        },
      );

      await tester.tap(find.text('Roleplay missions'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('start-roleplay-food-spicy')),
      );
      await tester.tap(find.byKey(const Key('start-roleplay-food-spicy')));
      await tester.pumpAndSettle();

      expect(requests, hasLength(1));
      expect(requests.first.first['content'], contains('known_words='));
      expect(requests.first.first['content'], contains('"chinese":"你"'));
      expect(requests.first.first['content'], contains('"chinese":"辣"'));
      expect(find.text('你好！你想点菜吗？'), findsOneWidget);
      expect(find.byKey(const Key('roleplay-hint')), findsNothing);

      await tester.tap(find.byKey(const Key('reveal-roleplay-hint')));
      await tester.pumpAndSettle();
      expect(find.text('Try: 我想点这个菜。'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('roleplay-reply')),
        '我要这个菜。辣吗？',
      );
      await tester.tap(find.byKey(const Key('send-roleplay-reply')));
      await tester.pumpAndSettle();

      expect(requests, hasLength(2));
      expect(requests.last.last, {'role': 'user', 'content': '我要这个菜。辣吗？'});
      expect(find.byKey(const Key('roleplay-completion')), findsOneWidget);
      expect(find.text('Mission complete'), findsOneWidget);
      expect(find.textContaining('ordered politely'), findsOneWidget);
      expect(find.text('Words to review'), findsOneWidget);
      expect(find.byKey(const Key('roleplay-review-菜')), findsOneWidget);
      expect(find.byKey(const Key('roleplay-review-辣')), findsOneWidget);
      expect(find.byKey(const Key('roleplay-reply')), findsNothing);
    },
  );

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
    expect(requests.single, hasLength(2));
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

  testWidgets('sends a bounded learner snapshot with the tutor prompt', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 9, 13, 10, 30);
    final contextRepository = _MemoryTutorContextRepository(
      snapshot: TutorLearnerSnapshot(
        asOf: now,
        hskLevel: 3,
        weakWords: [
          TutorWordSnapshot(
            chinese: '觉得',
            pinyin: 'juéde',
            englishMeaning: 'to feel; to think',
            mastery: .4,
            incorrectAnswers: 3,
            dueAt: DateTime.utc(2026, 9, 12),
          ),
        ],
        dueCards: [
          TutorWordSnapshot(
            chinese: '认为',
            pinyin: 'rènwéi',
            englishMeaning: 'to believe',
            mastery: .5,
            incorrectAnswers: 2,
            dueAt: DateTime.utc(2026, 9, 13, 9),
          ),
        ],
        recentMistakes: [
          TutorMistakeSnapshot(
            chinese: '认为',
            pinyin: 'rènwéi',
            englishMeaning: 'to believe',
            mistakeCount: 2,
            lastMistakeAt: DateTime.utc(2026, 9, 13, 9),
          ),
        ],
        lessonHistory: [
          TutorLessonSnapshot(
            title: 'Opinions and feelings',
            theme: 'Conversation',
            hskLevel: 3,
            startedAt: DateTime.utc(2026, 9, 12, 8),
            completedAt: DateTime.utc(2026, 9, 12, 8, 15),
            cardsReviewed: 8,
            correctAnswers: 5,
          ),
        ],
      ),
    );
    List<Map<String, String>>? sentMessages;
    await _pumpTutor(
      tester,
      tutorContextRepository: contextRepository,
      clock: () => now,
      request: (messages) async {
        sentMessages = messages;
        return '{"chinese":"我们来练习觉得和认为。"}';
      },
    );

    expect(contextRepository.requestedAt, isEmpty);
    await tester.enterText(find.byType(TextField), 'What should I practise?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(contextRepository.requestedAt, [now]);
    final systemPrompt = sentMessages!.first['content']!;
    expect(systemPrompt, contains('bounded snapshot'));
    expect(systemPrompt, contains('"hsk_level":3'));
    expect(systemPrompt, contains('"chinese":"觉得"'));
    expect(systemPrompt, contains('"chinese":"认为"'));
    expect(systemPrompt, contains('"mistake_count":2'));
    expect(systemPrompt, contains('"title":"Opinions and feelings"'));
    expect(systemPrompt, isNot(contains('learner name')));
  });

  testWidgets('snapshot failures do not prevent a tutor reply', (tester) async {
    List<Map<String, String>>? sentMessages;
    await _pumpTutor(
      tester,
      tutorContextRepository: _MemoryTutorContextRepository(
        loadError: StateError('local database unavailable'),
      ),
      request: (messages) async {
        sentMessages = messages;
        return '{"chinese":"好的","english":"OK"}';
      },
    );

    await tester.enterText(find.byType(TextField), 'Help me practise');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(sentMessages!.first['content'], isNot(contains('bounded snapshot')));
    expect(find.text('好的'), findsOneWidget);
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
          throw const GeminiRequestException(
            'We couldn’t connect to Gemini. Check your internet connection and try again.',
          );
        }
        return '{"chinese":"再见","pinyin":"zài jiàn","english":"goodbye"}';
      },
    );

    await tester.enterText(find.byType(TextField), 'One more time');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-tutor-error')), findsOneWidget);
    expect(
      find.text(
        'We couldn’t connect to Gemini. Check your internet connection and try again.',
      ),
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
      request: (_) async => throw const GeminiConfigurationException(
        'Gemini is not configured for this build.',
      ),
    );

    await tester.enterText(find.byType(TextField), '你好');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Gemini is not configured for this build.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-tutor-retry')), findsNothing);
  });

  testWidgets('Gemini refusals invite a new prompt without retrying', (
    tester,
  ) async {
    await _pumpTutor(
      tester,
      request: (_) async => throw const GeminiRequestException(
        'Gemini couldn’t answer that prompt. Try rephrasing it.',
        isRetryable: false,
      ),
    );
    await tester.enterText(find.byType(TextField), 'Help me practise');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(
      find.text('Gemini couldn’t answer that prompt. Try rephrasing it.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-tutor-retry')), findsNothing);
    expect(find.byTooltip('Send'), findsOneWidget);
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
