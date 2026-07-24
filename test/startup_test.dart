import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('learner setup collects first-run preferences', (tester) async {
    LearnerProfile? savedProfile;
    await tester.pumpWidget(
      MaterialApp(
        home: LearnerSetupPage(
          onComplete: (profile) async => savedProfile = profile,
        ),
      ),
    );

    expect(find.text('Build your learning path'), findsOneWidget);
    expect(find.text('HSK 1'), findsOneWidget);
    expect(find.text('10 words'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Mei');
    await tester.tap(find.text('HSK 3'));
    await tester.ensureVisible(find.text('20 words'));
    await tester.tap(find.text('20 words'));
    await tester.ensureVisible(find.text('Start learning'));
    await tester.tap(find.text('Start learning'));
    await tester.pump();

    expect(savedProfile?.name, 'Mei');
    expect(savedProfile?.hskLevel, 3);
    expect(savedProfile?.dailyWordTarget, 20);
  });
}
