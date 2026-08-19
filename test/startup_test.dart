import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/repositories/app_dependencies.dart';
import 'package:mylanguageapp/repositories/learner_repository.dart';

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

  testWidgets('learner setup recovers when saving fails', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var saveCalls = 0;
    LearnerProfile? savedProfile;
    await tester.pumpWidget(
      MaterialApp(
        home: LearnerSetupPage(
          onComplete: (profile) async {
            saveCalls++;
            if (saveCalls == 1) throw Exception('database locked');
            savedProfile = profile;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'Mei');
    await tester.tap(find.text('Start learning'));
    await tester.pump();

    expect(find.text('We couldn’t save your profile.'), findsOneWidget);
    expect(find.byKey(const Key('learner-setup-retry')), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.byKey(const Key('learner-setup-retry')));
    await tester.pump();

    expect(saveCalls, 2);
    expect(savedProfile?.name, 'Mei');
    expect(find.text('We couldn’t save your profile.'), findsNothing);
  });

  testWidgets('initial profile load error is friendly and retryable', (
    tester,
  ) async {
    final learners = _FailOnceLearnerRepository();

    await tester.pumpWidget(
      HanziPathApp(dependencies: AppDependencies(learners: learners)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-startup-error')), findsOneWidget);
    expect(find.text('We couldn’t load your profile'), findsOneWidget);
    expect(find.textContaining('sensitive database path'), findsNothing);

    await tester.tap(find.byKey(const Key('app-startup-retry')));
    await tester.pumpAndSettle();

    expect(learners.loadCalls, 2);
    expect(find.byKey(const Key('app-startup-error')), findsNothing);
    expect(find.text('Build your learning path'), findsOneWidget);
  });

  testWidgets('completed onboarding survives a full app reconstruction', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final learnerRepository = _MemoryLearnerRepository();
    final dependencies = AppDependencies(learners: learnerRepository);

    await tester.pumpWidget(HanziPathApp(dependencies: dependencies));
    await tester.pump();
    expect(find.text('Build your learning path'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Persistent Mei');
    await tester.tap(find.text('HSK 3'));
    await tester.ensureVisible(find.text('20 words'));
    await tester.tap(find.text('20 words'));
    await tester.ensureVisible(find.text('Start learning'));
    await tester.tap(find.text('Start learning'));
    await tester.pump();
    await tester.pump();
    expect(find.text('你好，Persistent Mei'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(HanziPathApp(dependencies: dependencies));
    await tester.pump();
    await tester.pump();

    expect(find.text('Build your learning path'), findsNothing);
    expect(find.text('你好，Persistent Mei'), findsOneWidget);
    expect(find.textContaining('HSK 3'), findsWidgets);
    expect(find.textContaining('20 words today'), findsOneWidget);
  });
}

class _MemoryLearnerRepository implements LearnerRepository {
  LearnerProfile? profile;

  @override
  Future<void> clear() async => profile = null;

  @override
  Future<LearnerProfile?> load() async => profile;

  @override
  Future<void> save(LearnerProfile profile) async {
    this.profile = profile;
  }
}

class _FailOnceLearnerRepository implements LearnerRepository {
  int loadCalls = 0;

  @override
  Future<void> clear() async {}

  @override
  Future<LearnerProfile?> load() async {
    loadCalls += 1;
    if (loadCalls == 1) {
      throw StateError('sensitive database path /private/learners.db');
    }
    return null;
  }

  @override
  Future<void> save(LearnerProfile profile) async {}
}
