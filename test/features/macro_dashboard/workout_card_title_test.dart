// Finding 100-002: a FinalSurge-verified card cut "Swim" to "SW…" because
// the chip took the row's width first. The title gets its space first; the
// chip wraps under it when the row is too narrow for both.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/macro_dashboard/domain/dashboard_models.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/widgets/workout_card.dart';

void main() {
  WorkoutCardData verified(String name) => WorkoutCardData(
    activityId: 'a1',
    name: name,
    timeLabel: '7:25 PM',
    metaLabel: '1 mi · 34 min',
    kcal: 300,
    state: WorkoutCardState.doneVerified,
    sport: 'swimming',
    verifiedSourceName: 'Final Surge',
    completionFinal: true,
  );

  Future<void> pump(WidgetTester tester, WorkoutCardData data, double width) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: WorkoutCard(data: data),
            ),
          ),
        ),
      ),
    );
  }

  RenderParagraph titleParagraph(WidgetTester tester, String name) =>
      tester.renderObject<RenderParagraph>(find.text(name));

  testWidgets('a narrow verified card shows "Swim" in full', (tester) async {
    await pump(tester, verified('Swim'), 250);

    expect(find.text('Swim'), findsOneWidget);
    expect(find.text('verified · Final Surge'), findsOneWidget);
    expect(
      titleParagraph(tester, 'Swim').didExceedMaxLines,
      isFalse,
      reason: 'the title is never cut behind the badge',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the badge wraps under a title the row cannot fit beside', (
    tester,
  ) async {
    await pump(tester, verified('Swim'), 250);
    final title = tester.getRect(find.text('Swim'));
    final chip = tester.getRect(find.text('verified · Final Surge'));

    // Either beside (same line) or below, never overlapping the title.
    final beside = chip.left >= title.right;
    final below = chip.top >= title.bottom;
    expect(beside || below, isTrue);
  });

  testWidgets('a long title still ellipsizes inside the card', (tester) async {
    const name = 'Threshold intervals with a very long descriptive title';
    await pump(tester, verified(name), 250);

    expect(tester.takeException(), isNull);
    expect(titleParagraph(tester, name).didExceedMaxLines, isTrue);
    expect(find.text('verified · Final Surge'), findsOneWidget);
  });
}
