part of '../widget_test.dart';

void _registerThemeWidgetTests() {
  for (final palette in AppThemes.all) {
    testWidgets('primary buttons have readable contrast in ${palette.label}', (
      tester,
    ) async {
      await tester.pumpWidget(
        HanziPathApp(
          initialProfile: testProfile,
          dependencies: AppDependencies(
            vocabulary: const _TestVocabulary(),
            lessons: _MemoryLessonRepository(),
            progress: _MemoryProgressRepository(),
            dailyReviews: _MemoryDailyReviewSessionRepository(null),
            settings: _MemorySettingsRepository(
              LearnerSettings(appThemeId: palette.id.name),
            ),
            createPronunciationService: () => _FakePronunciationService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scheme = Theme.of(
        tester.element(find.byType(DashboardPage)),
      ).colorScheme;
      final luminances = [
        scheme.primary.computeLuminance(),
        scheme.onPrimary.computeLuminance(),
      ]..sort();
      expect(
        (luminances.last + .05) / (luminances.first + .05),
        greaterThanOrEqualTo(4.5),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      AppColors.apply(AppThemes.classic);
    });
  }
}
