part of '../widget_test.dart';

void _registerBackNavigationWidgetTests() {
  for (final width in [400.0, 1000.0]) {
    testWidgets(
      'Android Back unwinds dialogs, menu, lesson, section, then exits at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final platformCalls = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            platformCalls.add(call.method);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final pronunciation = _FakePronunciationService();
        final progress = _MemoryProgressRepository();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: DashboardPage(
              vocabularyRepository: const _TestVocabulary(),
              personalityRepository: MemoryTutorPersonalityRepository(),
              appThemeId: AppThemeId.classic,
              onThemeChanged: (_) {},
              profile: testProfile,
              onProfileChanged: (_) async {},
              onResetOnboarding: () async {},
              onResetAllData: () async {},
              lessonRepository: _MemoryLessonRepository(),
              progressRepository: progress,
              settingsRepository: _MemorySettingsRepository(),
              developmentRepository: _MemoryDevelopmentRepository(),
              pronunciationService: pronunciation,
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> openLessons() async {
          if (width < 760) {
            await tester.tap(find.byIcon(Icons.menu_rounded));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text('Flashcards').first);
          await tester.pumpAndSettle();
        }

        await openLessons();
        await tester.ensureVisible(find.text('Resume'));
        await tester.tap(find.text('Resume'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Back to flashcards'), findsOneWidget);
        if (width < 760) {
          await tester.tap(find.byIcon(Icons.menu_rounded));
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(Drawer), findsNothing);
          expect(find.byTooltip('Back to flashcards'), findsOneWidget);
        }
        unawaited(
          showDialog<void>(
            context: tester.element(find.byType(LessonsPage)),
            builder: (_) => const AlertDialog(title: Text('Test dialog')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Test dialog'), findsNothing);
        expect(find.byTooltip('Back to flashcards'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(LessonsPage), findsOneWidget);
        expect(find.byTooltip('Back to flashcards'), findsNothing);
        expect(pronunciation.stopCalls, greaterThan(0));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(LessonsPage), findsNothing);
        expect(platformCalls, isNot(contains('SystemNavigator.pop')));
        // On-screen navigation must remove the same history entries.
        await openLessons();
        await tester.ensureVisible(find.text('Resume'));
        await tester.tap(find.text('Resume'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Back to flashcards'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(LessonsPage), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          platformCalls.where((call) => call == 'SystemNavigator.pop'),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

void _registerResponsivePageWidgetTests() {
  for (final (size, textScale) in [
    (const Size(320, 640), 1.0),
    (const Size(320, 640), 1.5),
    (const Size(320, 640), 2.0),
    (const Size(760, 900), 1.0),
    (const Size(1280, 900), 1.0),
    (const Size(640, 360), 1.0),
  ]) {
    testWidgets(
      'main screens remain usable at ${size.width.toInt()}px with $textScale text',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        rootBundle.evict('assets/data/hsk_vocabulary.json');
        addTearDown(() => rootBundle.evict('assets/data/hsk_vocabulary.json'));
        final pronunciation = _FakePronunciationService();
        addTearDown(pronunciation.dispose);
        await tester.pumpWidget(
          HanziPathApp(
            initialProfile: testProfile,
            dependencies: AppDependencies(
              vocabulary: const _TestVocabulary(),
              lessons: _MemoryLessonRepository(),
              progress: _MemoryProgressRepository(),
              dailyReviews: _MemoryDailyReviewSessionRepository(null),
              settings: _MemorySettingsRepository(),
              development: _MemoryDevelopmentRepository(),
              tutorContext: _EmptyTutorContextRepository(),
              tutorPersonalities: MemoryTutorPersonalityRepository(),
              createPronunciationService: () => pronunciation,
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final label in [
          ...AppSidebar.items.map((item) => item.$2),
          'Settings',
        ]) {
          if (size.width < 760) {
            await tester.tap(find.byIcon(Icons.menu_rounded));
            await tester.pumpAndSettle();
          }
          final navigation = find.descendant(
            of: find.byType(AppSidebar),
            matching: find.text(label),
          );
          if (label == 'Settings') {
            await tester.ensureVisible(navigation);
          } else {
            await tester.scrollUntilVisible(
              navigation,
              100,
              scrollable: find
                  .descendant(
                    of: find.byType(AppSidebar),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
          }
          await tester.pumpAndSettle();
          await tester.tap(navigation);
          if (label == 'Dictionary') {
            await _waitForWidget(
              tester,
              find.byKey(const Key('vocabulary-result-count')),
            );
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
          final pageType = switch (label) {
            'Flashcards' => LessonsPage,
            'Roleplay Missions' => AiRoleplayMissionsPage,
            'Listening Practice' => ListeningPracticePage,
            'Vocab Rush' => VocabRushPage,
            'Dictionary' => VocabularyPage,
            'Doom Scrolling' => DoomScrollingPage,
            'AI Tutor' => AiTutorPage,
            'Exam Mode' => ExamModePage,
            'Settings' => SettingsPage,
            _ => MainDashboard,
          };
          expect(find.byType(pageType), findsOneWidget, reason: label);
          if (label == 'Home') {
            expect(find.byType(WeeklyXp), findsOneWidget);
            expect(
              find.byType(VocabularyPanel),
              size.width < 760 ? findsNothing : findsOneWidget,
            );
            if (size.width < 760) {
              expect(
                tester.getSize(find.byType(WeeklyXp)).width,
                size.width - 40,
              );
            }
          }
          if (label == 'Exam Mode') {
            expect(find.byKey(const Key('exam-start')), findsOneWidget);
          }
        }
        await tester.tap(find.byKey(const Key('open-profile-button')));
        await tester.pumpAndSettle();
        expect(find.byType(ProfilePage), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Profile');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

void _registerMobileNavigationWidgetTests() {
  testWidgets(
    'dashboard header menu button opens the drawer on narrow layouts',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            drawer: Drawer(child: Text('drawer contents')),
            body: DashboardHeader(showMenu: true, profile: testProfile),
          ),
        ),
      );

      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      expect(find.text('drawer contents'), findsOneWidget);
    },
  );

  Future<void> testMobileMenuSwipes(
    WidgetTester tester,
    TargetPlatform platform,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: DashboardPage(
          vocabularyRepository: const _TestVocabulary(),
          personalityRepository: MemoryTutorPersonalityRepository(),
          appThemeId: AppThemeId.classic,
          onThemeChanged: (_) {},
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: () async {},
          onResetAllData: () async {},
          lessonRepository: _MemoryLessonRepository(),
          progressRepository: _MemoryProgressRepository(),
          settingsRepository: _MemorySettingsRepository(),
          developmentRepository: _MemoryDevelopmentRepository(),
          pronunciationService: pronunciation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    await tester.dragFrom(const Offset(200, 600), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(find.byType(Drawer), findsNothing);

    await tester.dragFrom(const Offset(300, 400), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);

    // Inspect the drawer before releasing: it must track the finger, including
    // reversing direction, rather than starting its animation on pointer-up.
    final drag = await tester.startGesture(const Offset(100, 400));
    await drag.moveBy(const Offset(30, 0));
    await tester.pump();
    await drag.moveBy(const Offset(80, 0));
    await tester.pump();
    final partialX = tester.getTopLeft(find.byType(Drawer)).dx;
    expect(partialX, lessThan(0));
    expect(partialX, greaterThan(-tester.getSize(find.byType(Drawer)).width));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(find.byType(Drawer)).dx, partialX);
    await drag.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byType(Drawer)).dx,
      closeTo(partialX + 40, 0.1),
    );
    await drag.moveBy(const Offset(-20, 0));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byType(Drawer)).dx,
      closeTo(partialX + 20, 0.1),
    );
    await drag.moveBy(const Offset(150, 0));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    expect(tester.getTopLeft(find.byType(Drawer)).dx, 0);

    // Tapping the scrim and the system back action both dismiss the drawer.
    await tester.tapAt(const Offset(380, 400));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);

    // A short, slow drag settles closed after release or cancellation.
    for (final cancel in [false, true]) {
      final shortDrag = await tester.startGesture(const Offset(100, 400));
      await shortDrag.moveBy(const Offset(30, 0));
      await tester.pump();
      await shortDrag.moveBy(const Offset(50, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(Drawer), findsOneWidget);
      if (cancel) {
        await shortDrag.cancel();
      } else {
        await shortDrag.up();
      }
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
    }
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    final aitutorNav = find.descendant(
      of: find.byType(AppSidebar),
      matching: find.text('AI Tutor'),
    );
    await tester.scrollUntilVisible(
      aitutorNav,
      120,
      scrollable: find
          .descendant(
            of: find.byType(AppSidebar),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(aitutorNav);
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(AiTutorPage), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.dragFrom(const Offset(100, 400), const Offset(280, 0));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);

    await tester.dragFrom(const Offset(280, 400), const Offset(-260, 0));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('Hello'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    final homeNav = find.descendant(
      of: find.byType(AppSidebar),
      matching: find.text('Home'),
    );
    await tester.scrollUntilVisible(
      homeNav,
      120,
      scrollable: find
          .descendant(
            of: find.byType(AppSidebar),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(homeNav);
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(AiTutorPage), findsNothing);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    final dictionaryNav = find.descendant(
      of: find.byType(AppSidebar),
      matching: find.text('Dictionary'),
    );
    await tester.scrollUntilVisible(
      dictionaryNav,
      120,
      scrollable: find
          .descendant(
            of: find.byType(AppSidebar),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(dictionaryNav);
    await _waitForWidget(
      tester,
      find.byKey(const Key('vocabulary-result-count')),
    );
    await tester.pumpAndSettle();

    final filters = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    final filterScrollable = tester.state<ScrollableState>(
      find.descendant(of: filters.first, matching: find.byType(Scrollable)),
    );
    final filterY = tester.getCenter(filters.first).dy;
    await tester.dragFrom(Offset(280, filterY), const Offset(-160, 0));
    await tester.pumpAndSettle();
    final filterOffset = filterScrollable.position.pixels;
    expect(filterOffset, greaterThan(0));
    await tester.dragFrom(Offset(100, filterY), const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(filterScrollable.position.pixels, lessThan(filterOffset));
    expect(find.byType(Drawer), findsNothing);
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '${platform.name} menu follows swipes across pages and still scrolls',
      (tester) => testMobileMenuSwipes(tester, platform),
    );
  }
}
