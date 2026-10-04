import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';

const _entries = [
  {
    'simplified': '你好',
    'traditional': '你好',
    'pinyin': 'nǐ hǎo',
    'meanings': ['hello', 'hi'],
    'hskLevel': 1,
    'partOfSpeech': ['phrase'],
    'exampleChinese': '你好，很高兴认识你。',
    'examplePinyin': 'nǐ hǎo, hěn gāoxìng rènshì nǐ.',
    'exampleEnglish': 'Hello, nice to meet you.',
  },
  {
    'simplified': '学习',
    'traditional': '學習',
    'pinyin': 'xué xí',
    'meanings': ['to study', 'to learn'],
    'hskLevel': 1,
  },
  {
    'simplified': '图书馆',
    'traditional': '圖書館',
    'pinyin': 'tú shū guǎn',
    'meanings': ['library'],
    'hskLevel': 2,
  },
  {
    'simplified': '罕见词',
    'traditional': '罕見詞',
    'pinyin': 'hǎn jiàn cí',
    'meanings': ['rare word'],
    'hskLevel': 6,
  },
];

final _now = DateTime.utc(2026, 8, 6, 12);
final _progress = [
  VocabularyCardProgress(
    chinese: '你好',
    pinyin: 'nǐ hǎo',
    progress: CardProgress(
      cardId: 1,
      timesSeen: 5,
      correctAnswers: 5,
      mastery: 1,
      dueAt: _now.add(const Duration(days: 2)),
    ),
  ),
  VocabularyCardProgress(
    chinese: '学习',
    pinyin: 'xué xí',
    progress: CardProgress(
      cardId: 2,
      timesSeen: 4,
      correctAnswers: 2,
      incorrectAnswers: 2,
      mastery: .5,
      dueAt: _now.add(const Duration(days: 1)),
    ),
  ),
  VocabularyCardProgress(
    chinese: '图书馆',
    pinyin: 'tú shū guǎn',
    progress: CardProgress(
      cardId: 3,
      timesSeen: 3,
      correctAnswers: 3,
      mastery: 1,
      dueAt: _now.subtract(const Duration(hours: 1)),
    ),
  ),
];

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    LearnerSettings settings = const LearnerSettings(),
    PronunciationService? pronunciationService,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VocabularyPage(
            initialEntries: _entries,
            initialProgress: _progress,
            settingsRepository: _MemorySettingsRepository(settings),
            pronunciationService:
                pronunciationService ?? _FakePronunciationService(),
            clock: () => _now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('clears search, level, and learning filters together', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'HSK 2'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Learning'));
    await tester.enterText(
      find.byKey(const Key('vocabulary-search')),
      'missing',
    );
    await tester.pumpAndSettle();
    expect(find.text('0 words'), findsOneWidget);
    await tester.tap(find.byKey(const Key('vocabulary-clear-filters')));
    await tester.pumpAndSettle();
    expect(find.text('4 words'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('vocabulary-search')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All levels'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All states'))
          .selected,
      isTrue,
    );
    expect(find.byKey(const Key('vocabulary-clear-filters')), findsNothing);
  });

  testWidgets('search results stay reachable with the phone keyboard open', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
      await tester.binding.setSurfaceSize(null);
    });
    await pumpPage(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.enterText(find.byKey(const Key('vocabulary-search')), 'hello');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const Key('vocabulary-scroll')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(find.text('你好').hitTestable(), findsOneWidget);
    await tester.tap(find.text('你好'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, nice to meet you.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('searches vocabulary by Hanzi', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('vocabulary-search')), '學習');
    await tester.pump();

    expect(find.text('学习'), findsOneWidget);
    expect(find.text('你好'), findsNothing);
    expect(find.text('1 word'), findsOneWidget);
  });

  testWidgets('searches pinyin without requiring tone marks or spaces', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(
      find.byKey(const Key('vocabulary-search')),
      'tushuguan',
    );
    await tester.pump();

    expect(find.text('图书馆'), findsOneWidget);
    expect(find.text('tú shū guǎn'), findsOneWidget);
    expect(find.text('你好'), findsNothing);
  });

  for (final query in ['ni3 hao3', 'ni3hao3', 'NI3 HAO3', 'nǐ hǎo']) {
    testWidgets('searches pinyin entered as $query', (tester) async {
      await pumpPage(tester);
      await tester.enterText(find.byKey(const Key('vocabulary-search')), query);
      await tester.pump();
      expect(find.text('你好'), findsOneWidget);
      expect(find.text('1 word'), findsOneWidget);
    });
  }

  for (final query in ['lü4', 'lv4', 'lu:4', 'LU:4', 'lu\u03084']) {
    testWidgets('searches umlaut pinyin entered as $query', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VocabularyPage(
              initialEntries: const [
                {
                  'simplified': '绿',
                  'traditional': '綠',
                  'pinyin': 'lǜ',
                  'meanings': ['green'],
                  'hskLevel': 2,
                },
                {
                  'simplified': '路',
                  'traditional': '路',
                  'pinyin': 'lù',
                  'meanings': ['road'],
                  'hskLevel': 2,
                },
              ],
              settingsRepository: _MemorySettingsRepository(
                const LearnerSettings(),
              ),
              pronunciationService: _FakePronunciationService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('vocabulary-search')), query);
      await tester.pump();
      expect(find.text('绿'), findsOneWidget);
      expect(find.text('路'), findsNothing);
      expect(find.text('1 word'), findsOneWidget);
    });
  }

  testWidgets('a tone number alone does not match every word', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('vocabulary-search')), '3');
    await tester.pump();
    expect(find.text('0 words'), findsOneWidget);
  });

  testWidgets('searches vocabulary by English meaning', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('vocabulary-search')), 'hello');
    await tester.pump();

    expect(find.text('你好'), findsOneWidget);
    expect(find.text('学习'), findsNothing);
  });

  testWidgets('filters vocabulary by HSK level', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'HSK 2'));
    await tester.pump();

    expect(find.text('图书馆'), findsOneWidget);
    expect(find.text('你好'), findsNothing);
    expect(find.text('1 word'), findsOneWidget);
  });

  testWidgets('filters vocabulary by learning state', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Unseen'));
    await tester.pump();
    expect(find.text('罕见词'), findsOneWidget);
    expect(find.text('你好'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Learning'));
    await tester.pump();
    expect(find.text('学习'), findsOneWidget);
    expect(find.text('罕见词'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Learned'));
    await tester.pump();
    expect(find.text('你好'), findsOneWidget);
    expect(find.text('学习'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'To review'));
    await tester.pump();
    expect(find.text('图书馆'), findsOneWidget);
    expect(find.text('你好'), findsNothing);
  });

  testWidgets('load error is friendly and retryable', (tester) async {
    final entries = <Map<String, dynamic>>[
      {'simplified': '损坏的词汇数据'},
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VocabularyPage(
            initialEntries: entries,
            settingsRepository: _MemorySettingsRepository(
              const LearnerSettings(),
            ),
            pronunciationService: _FakePronunciationService(),
            clock: () => _now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vocabulary-error-state')), findsOneWidget);
    expect(find.text('We couldn’t load vocabulary'), findsOneWidget);
    expect(find.textContaining("type 'Null'"), findsNothing);

    entries
      ..clear()
      ..addAll(_entries);
    await tester.tap(find.byKey(const Key('vocabulary-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vocabulary-error-state')), findsNothing);
    expect(find.text('你好'), findsOneWidget);
  });

  testWidgets('opens word details with every meaning and example sentence', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('你好'));
    await tester.pumpAndSettle();

    expect(find.text('Word details'), findsOneWidget);
    expect(find.text('Meanings'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('hi'), findsOneWidget);
    expect(find.text('Example sentence'), findsOneWidget);
    expect(find.text('你好，很高兴认识你。'), findsOneWidget);
    expect(find.text('nǐ hǎo, hěn gāoxìng rènshì nǐ.'), findsOneWidget);
    expect(find.text('Hello, nice to meet you.'), findsOneWidget);
  });

  testWidgets('word details speak the headword and full example sentence', (
    tester,
  ) async {
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);
    await pumpPage(tester, pronunciationService: pronunciation);

    await tester.tap(find.text('你好'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hear word pronunciation'));
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Hear example sentence'));
    await tester.tap(find.byTooltip('Hear example sentence'));
    await tester.pump();

    expect(pronunciation.spoken, ['你好', '你好，很高兴认识你。']);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(pronunciation.stopCalls, greaterThan(0));
    expect(pronunciation.disposeCalls, 0);
  });

  testWidgets('missing Mandarin speech offers the system voice installer', (
    tester,
  ) async {
    final pronunciation = _MissingSystemVoiceService();
    addTearDown(pronunciation.dispose);
    await pumpPage(tester, pronunciationService: pronunciation);
    await tester.tap(find.text('你好'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hear word pronunciation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install voice'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('system-voice-install')));
    await tester.pumpAndSettle();
    expect(pronunciation.openCalls, 1);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('你好，很高兴认识你。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('word details respect the disabled sound preference', (
    tester,
  ) async {
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);
    await pumpPage(
      tester,
      settings: const LearnerSettings(soundEnabled: false),
      pronunciationService: pronunciation,
    );

    await tester.tap(find.text('你好'));
    await tester.pumpAndSettle();

    expect(
      find.byTooltip('Pronunciation audio is disabled in Settings'),
      findsNWidgets(2),
    );
    expect(
      tester
          .widget<PronunciationButton>(
            find.byKey(const Key('vocabulary-word-pronunciation')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<PronunciationButton>(
            find.byKey(const Key('vocabulary-example-pronunciation')),
          )
          .onPressed,
      isNull,
    );
    expect(pronunciation.spoken, isEmpty);
  });

  testWidgets('shows an honest empty state when an example is unavailable', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('vocabulary-search')), '罕见词');
    await tester.pump();
    await tester.tap(find.text('罕见词').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('example-sentence-unavailable')),
      findsOneWidget,
    );
  });
}

class _MemorySettingsRepository implements SettingsRepository {
  _MemorySettingsRepository(this.settings);

  LearnerSettings settings;

  @override
  Future<LearnerSettings> load() async => settings;

  @override
  Future<void> save(LearnerSettings settings) async {
    this.settings = settings;
  }
}

class _FakePronunciationService implements PronunciationService {
  final List<String> spoken = [];
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
  Future<void> speakMandarin(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> dispose() async => disposeCalls++;
}

class _MissingSystemVoiceService extends _FakePronunciationService
    implements SystemVoiceInstaller {
  int openCalls = 0;

  @override
  Future<void> speakMandarin(String text) async =>
      throw const MandarinVoiceUnavailableException();

  @override
  Future<bool> isMandarinVoiceInstalled() async => false;

  @override
  Future<void> openMandarinVoiceInstaller() async => openCalls++;
}
