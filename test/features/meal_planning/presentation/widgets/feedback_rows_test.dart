import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_part_renderer.dart';

import '../../domain/fixture_helpers.dart';
import '../helpers/test_content.dart';

/// Typing into Vana is the feedback system (2026-09-09): the first opener
/// carries a plain-text prompt (no link, nothing to tap) and a `saveFeedback`
/// turn renders a quiet "Saved for the team" row.
void main() {
  Future<void> pump(WidgetTester tester, VanaPart part) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            body: VanaPartRenderer(
              part: part,
              callbacks: VanaPartCallbacks(
                onTapMeal: (_) {},
                onPickMeal: (_, _) {},
                onChipPick: (_) {},
                onSomethingElse: () {},
                onAcceptRule: (_) {},
                onViewShopping: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('feedback_prompt is plain text — no gesture, no link', (
    tester,
  ) async {
    await pump(tester, VanaPart.fromJson(loadFixture('feedback_prompt'))!);
    final row = find.byKey(const ValueKey('meal_planning.feedback_prompt'));
    expect(row, findsOneWidget);
    expect(find.textContaining('Just type it here'), findsOneWidget);
    expect(
      find.ancestor(of: row, matching: find.byType(GestureDetector)),
      findsNothing,
    );
  });

  testWidgets('feedback_saved parses from the fixture and renders the row', (
    tester,
  ) async {
    final part =
        VanaPart.fromJson(loadFixture('feedback_saved'))
            as VanaFeedbackSavedPart;
    expect(part.sentiment, FeedbackSentiment.negative);
    expect(part.about, FeedbackAbout.vana);
    await pump(tester, part);
    expect(
      find.byKey(const ValueKey('meal_planning.feedback_saved_row')),
      findsOneWidget,
    );
    expect(find.text('Saved for the team'), findsOneWidget);
  });
}
