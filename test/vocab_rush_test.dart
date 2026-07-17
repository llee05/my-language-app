import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';

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

  testWidgets('difficulty and duration can be selected independently', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VocabRushPage())),
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
    final correctAnswer = (card['meanings'] as List<dynamic>).first as String;

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
      final correctAnswer = (card['meanings'] as List<dynamic>).first as String;
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
}
