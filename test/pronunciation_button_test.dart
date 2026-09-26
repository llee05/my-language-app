import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';

void main() {
  Future<void> pumpButton(
    WidgetTester tester, {
    Future<void> Function()? onPressed,
    Object? requestKey,
    bool reduceMotion = false,
    String? label,
    ButtonAnimationStyle animationStyle = ButtonAnimationStyle.combined,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppButtonTheme.apply(ThemeData(), animationStyle: animationStyle),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(
            child: PronunciationButton(
              onPressed: onPressed,
              requestKey: requestKey,
              label: label,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('shows immediate feedback and ignores taps while starting', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await pumpButton(
      tester,
      onPressed: () {
        calls++;
        return pending.future;
      },
    );
    final button = find.byType(IconButton);
    final size = tester.getSize(button);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    expect(calls, 1);
    expect(find.byTooltip('Starting audio…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<IconButton>(button).onPressed, isNull);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('audio errors leave the control ready to retry', (tester) async {
    var calls = 0;
    await pumpButton(
      tester,
      onPressed: () async {
        if (++calls == 1) throw StateError('Audio unavailable');
      },
    );
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(
      find.text('Mandarin audio is unavailable. Try again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('old requests cannot clear a new card loading state', (
    tester,
  ) async {
    final first = Completer<void>();
    final second = Completer<void>();
    await pumpButton(tester, requestKey: 1, onPressed: () => first.future);
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await pumpButton(tester, requestKey: 2, onPressed: () => second.future);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    first.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    second.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('completion after leaving a screen is safe', (tester) async {
    final pending = Completer<void>();
    await pumpButton(tester, onPressed: () => pending.future);
    await tester.tap(find.byType(IconButton));
    await tester.pumpWidget(const SizedBox());
    pending.completeError(StateError('Late failure'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled voice control has no action or busy animation', (
    tester,
  ) async {
    await pumpButton(tester);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(IconButton)),
      matchesSemantics(
        tooltip: 'Hear Mandarin pronunciation',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    semantics.dispose();
  });

  testWidgets('keyboard activation works for labeled controls', (tester) async {
    var calls = 0;
    await pumpButton(
      tester,
      label: 'Replay',
      onPressed: () async {
        calls++;
      },
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('reduced motion stays still while audio is pending', (
    tester,
  ) async {
    final pending = Completer<void>();
    await pumpButton(
      tester,
      reduceMotion: true,
      onPressed: () => pending.future,
    );
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      .75,
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('voice controls honor the selected press animation', (
    tester,
  ) async {
    for (final style in [
      ButtonAnimationStyle.subtleScale,
      ButtonAnimationStyle.ripple,
    ]) {
      await pumpButton(tester, animationStyle: style, onPressed: () async {});
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IconButton)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        style == ButtonAnimationStyle.subtleScale ? .95 : 1,
      );
      await gesture.up();
      await tester.pumpAndSettle();
    }
  });
}
