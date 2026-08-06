import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';

const _entries = [
  {
    'simplified': '你好',
    'traditional': '你好',
    'pinyin': 'nǐ hǎo',
    'meanings': ['hello', 'hi'],
    'hskLevel': 1,
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
];

void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VocabularyPage(initialEntries: _entries)),
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
}
