import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/ai/openai_service.dart';
import 'package:mylanguageapp/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dotenv optional load does not throw when .env is missing', () async {
    dotenv.clean();

    await expectLater(dotenv.load(isOptional: true), completes);
    expect(dotenv.isInitialized, isTrue);
  });

  test('OpenAIService initialization is safe without dotenv env', () async {
    dotenv.clean();

    await expectLater(OpenAIService.instance.ensureInitialized(), completes);
  });

  testWidgets('HanziPathApp builds without crashing', (tester) async {
    await tester.pumpWidget(const HanziPathApp());

    expect(find.byType(HanziPathApp), findsOneWidget);
    expect(find.text('早上好，学员'), findsOneWidget);
  });
}
