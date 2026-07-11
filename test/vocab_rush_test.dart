import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';

Future<void> startGame(WidgetTester tester) async {
  await tester.tap(find.text('开始游戏 — Start Game'));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 250)),
  );
  await tester.pumpAndSettle();
  expect(find.text('PICK THE CORRECT MEANING'), findsOneWidget);
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('difficulty selection changes the game timer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VocabRushPage())),
    );

    expect(find.text('◷ 90s   HSK 1'), findsOneWidget);
    expect(find.text('◷ 60s   HSK 3'), findsOneWidget);
    expect(find.text('◷ 45s   HSK 6'), findsOneWidget);

    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await startGame(tester);

    expect(find.text('45s'), findsOneWidget);
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
    final correctAnswer = (card['meanings'] as List<dynamic>).first as String;

    await tester.tap(find.widgetWithText(OutlinedButton, correctAnswer));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('×1'), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 500));
  });
}
