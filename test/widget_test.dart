import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/database/flashcard_seed.dart';
import 'package:mylanguageapp/main.dart';

void main() {
  testWidgets('dashboard renders core learning content', (tester) async {
    await tester.pumpWidget(const HanziPathApp());

    final firstLesson = flashcardLessons.first;

    expect(find.text('早上好，学员'), findsOneWidget);
    expect(find.text(firstLesson['lesson_title'] as String), findsWidgets);
    expect(find.text('WEEKLY XP'), findsOneWidget);
  });

  testWidgets('continue card shows snack bar when resume is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ContinueCard(
            lessonTitle: 'Family & Relationships',
            theme: 'Family & Relationships',
            level: 1,
            duration: '20 cards',
            xpReward: 60,
          ),
        ),
      ),
    );

    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump();

    expect(find.text('Resuming Family & Relationships…'), findsOneWidget);
  });

  testWidgets(
    'app sidebar invokes onSelected callback when an item is tapped',
    (tester) async {
      var selected = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSidebar(
              selectedIndex: 1,
              onSelected: (index) => selected = index,
            ),
          ),
        ),
      );

      expect(find.text('Vocab Rush'), findsOneWidget);
      await tester.tap(find.text('Vocab Rush'));
      await tester.pumpAndSettle();

      expect(selected, 2);
    },
  );

  testWidgets('vocab rush starts a timed vocabulary game', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const HanziPathApp());

    await tester.tap(find.text('Vocab Rush'));
    await tester.pumpAndSettle();
    expect(find.text('词汇冲刺'), findsOneWidget);
    expect(find.text('开始游戏 — Start Game'), findsOneWidget);

    await tester.tap(find.text('开始游戏 — Start Game'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('PICK THE CORRECT MEANING'), findsOneWidget);
    expect(find.text('180s'), findsOneWidget);
  });

  testWidgets('lessons page exposes level and AI topic options', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const HanziPathApp());

    await tester.tap(find.text('Lessons'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lesson Builder'), findsOneWidget);
    expect(find.text('HSK level'), findsOneWidget);
    expect(find.text('Ask AI for a lesson topic'), findsOneWidget);
    expect(find.text('Generate lesson'), findsOneWidget);
    expect(find.text('Daily Life'), findsOneWidget);

    await tester.tap(find.text('HSK 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HSK 2').last);
    await tester.pumpAndSettle();

    expect(find.text('School'), findsOneWidget);
    expect(find.text('Daily Life'), findsNothing);
  });

  testWidgets('ai tutor tab opens the tutor chat page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const HanziPathApp());

    expect(find.text('AI Tutor'), findsOneWidget);
    await tester.tap(find.text('AI Tutor'));
    await tester.pumpAndSettle();

    expect(find.text('龙老师 - Long Laoshi'), findsOneWidget);
    expect(find.text("TODAY'S FOCUS"), findsOneWidget);
    expect(find.text('你好！我是龙老师。你想练习什么中文？'), findsOneWidget);
    expect(find.text('我家里有四个人。爸爸，妈妈，我，和妹妹。'), findsNothing);
    expect(find.text('Ask 龙老师 anything in English or 中文...'), findsOneWidget);
  });

  testWidgets(
    'dashboard header menu button opens the drawer on narrow layouts',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            drawer: Drawer(child: Text('drawer contents')),
            body: DashboardHeader(showMenu: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      expect(find.text('drawer contents'), findsOneWidget);
    },
  );

  testWidgets('locked lesson tile renders with reduced opacity', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonTile(
            title: 'Travel & Directions',
            chinese: '旅行与方向',
            unit: 'Unit 3',
            duration: '22 min',
            xp: '+80 XP',
            state: LessonState.locked,
          ),
        ),
      ),
    );

    final opacityWidget = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.text('Travel & Directions'),
            matching: find.byType(Opacity),
          )
          .first,
    );

    expect(opacityWidget.opacity, 0.48);
    expect(find.text('Travel & Directions'), findsOneWidget);
    expect(find.text('+80 XP'), findsOneWidget);
  });
}
