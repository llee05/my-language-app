import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';

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
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VocabularyPage(
            initialEntries: _entries,
            initialProgress: _progress,
            clock: () => _now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

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
          body: VocabularyPage(initialEntries: entries, clock: () => _now),
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
