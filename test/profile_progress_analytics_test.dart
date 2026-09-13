import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';

const _profile = LearnerProfile(name: 'Mei', hskLevel: 3, dailyWordTarget: 20);

void main() {
  testWidgets('the dashboard user icon opens the profile', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardHeader(
            showMenu: false,
            profile: _profile,
            onProfilePressed: () => presses++,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-profile-button')));

    expect(presses, 1);
    expect(find.byTooltip('Open profile'), findsOneWidget);
  });

  testWidgets('profile presents saved progress analytics and actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var editPresses = 0;
    const stats = DashboardLearningStats(
      totalXp: 245,
      weeklyXp: [10, 20, 0, 15, 30, 0, 0],
      streakDays: 4,
      wordsSeen: 40,
      wordsLearning: 10,
      wordsLearned: 30,
      reviewCount: 32,
      correctReviewCount: 24,
      activeStudyDays: 8,
      weeklyReviewCount: 12,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePage(
            profile: _profile,
            stats: stats,
            loading: false,
            loadError: false,
            onRetry: () {},
            onStartReview: () {},
            onEditProfile: () => editPresses++,
          ),
        ),
      ),
    );

    expect(find.text('Mei'), findsOneWidget);
    expect(find.text('HSK 3 learner  ·  20-word daily goal'), findsOneWidget);
    expect(find.text('245'), findsOneWidget);
    expect(find.text('4 days'), findsOneWidget);
    expect(find.text('75%'), findsNWidgets(2));
    expect(find.text('32'), findsOneWidget);
    expect(find.text('Reviews this week'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Words seen'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit-profile-button')));
    expect(editPresses, 1);
  });

  testWidgets('profile offers a starting point with no learning history', (
    tester,
  ) async {
    var reviewPresses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePage(
            profile: _profile,
            stats: const DashboardLearningStats(),
            loading: false,
            loadError: false,
            onRetry: () {},
            onStartReview: () => reviewPresses++,
            onEditProfile: () {},
          ),
        ),
      ),
    );

    expect(find.text('Your progress story starts here'), findsOneWidget);
    final startReview = find.text('Start review');
    await tester.ensureVisible(startReview);
    await tester.pumpAndSettle();
    await tester.tap(startReview);
    expect(reviewPresses, 1);
  });

  testWidgets('profile analytics adapt to a narrow phone layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePage(
            profile: _profile,
            stats: const DashboardLearningStats(
              totalXp: 50,
              weeklyXp: [10, 0, 10, 0, 10, 0, 20],
              streakDays: 2,
              reviewCount: 6,
              correctReviewCount: 5,
            ),
            loading: false,
            loadError: false,
            onRetry: () {},
            onStartReview: () {},
            onEditProfile: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('profile-name')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
