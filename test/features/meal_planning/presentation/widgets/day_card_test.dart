import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/day_card.dart';

import '../helpers/test_content.dart';

/// Ticket 55 (Finding 09-002): the `day_guidance` card says its carb line
/// once and ends with one full stop, whether or not Vana's note already
/// carries the carb target.
void main() {
  Future<String> guidance(WidgetTester tester, String note) async {
    final part = VanaDayGuidancePart(
      date: '2026-09-24',
      label: 'Rest day',
      minCarbsG: 272,
      note: note,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            body: DayCard(part: part, onTapMeal: (_) {}),
          ),
        ),
      ),
    );
    final rich = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .firstWhere((t) => t.contains('272g') || t.contains(note.trim()));
    return rich;
  }

  testWidgets('a note that carries the carb line is shown once, one stop', (
    tester,
  ) async {
    final text = await guidance(
      tester,
      'At least 272g carbs, protein at every meal. No need to top up around training.',
    );
    expect(
      text,
      'At least 272g carbs, protein at every meal. No need to top up around training.',
    );
  });

  testWidgets('a note without the carb line gets it once and one full stop', (
    tester,
  ) async {
    final text = await guidance(
      tester,
      'Race-morning breakfast from your pre-race formula; eat familiar food only.',
    );
    expect('272g carbs'.allMatches(text).length, 1);
    expect(text.endsWith('only.'), isTrue, reason: text);
    expect(text.endsWith('..'), isFalse, reason: text);
  });
}
