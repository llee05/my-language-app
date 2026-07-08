import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';

void main() {
  testWidgets('dashboard renders core learning content', (tester) async {
    await tester.pumpWidget(const HanziPathApp());

    expect(find.text('早上好，学员'), findsOneWidget);
    expect(find.text('Family & Relationships'), findsNWidgets(2));
    expect(find.text('WEEKLY XP'), findsOneWidget);
  });

  testWidgets('continue card shows snack bar when resume is tapped', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ContinueCard()),
      ),
    );

    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.text('Resuming Family & Relationships…'), findsOneWidget);
  });

  testWidgets('app sidebar invokes onSelected callback when an item is tapped', (tester) async {
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

    expect(find.text('Lessons'), findsOneWidget);
    await tester.tap(find.text('Lessons'));
    await tester.pumpAndSettle();

    expect(selected, 1);
  });

  testWidgets('dashboard header menu button opens the drawer on narrow layouts', (tester) async {
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
  });

  testWidgets('locked lesson tile renders with reduced opacity', (tester) async {
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
      find.ancestor(
        of: find.text('Travel & Directions'),
        matching: find.byType(Opacity),
      ).first,
    );

    expect(opacityWidget.opacity, 0.48);
    expect(find.text('Travel & Directions'), findsOneWidget);
    expect(find.text('+80 XP'), findsOneWidget);
  });
}
