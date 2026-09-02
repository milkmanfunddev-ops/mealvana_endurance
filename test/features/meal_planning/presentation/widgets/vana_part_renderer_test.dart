import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_part_renderer.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import '../helpers/test_content.dart';

/// 02 §3 — every part kind renders its widget; `batch` and `brief` render
/// nothing. Drives the renderer with the frozen contract fixtures.
void main() {
  Map<String, dynamic> fixture(String name) => jsonDecode(
    File('test/features/meal_planning/fixtures/$name.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;

  Future<void> pumpPart(
    WidgetTester tester,
    VanaPart part, {
    void Function(String label)? onChipPick,
    void Function(MealRef meal, int servings)? onPickMeal,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VanaPartRenderer(
                part: part,
                callbacks: VanaPartCallbacks(
                  onTapMeal: (_) {},
                  onPickMeal: onPickMeal ?? (_, __) {},
                  onChipPick: onChipPick ?? (_) {},
                  onSomethingElse: () {},
                  onAcceptRule: (_) {},
                  onViewShopping: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('meal_picker renders the carousel title and chip strip', (
    tester,
  ) async {
    final part = VanaMealPickerPart.fromJson(fixture('meal_picker'));
    await pumpPart(tester, part);
    expect(find.text(part.title), findsOneWidget);
    // The chip strip renders under the picker (primary + other + something).
    expect(find.text('I like these'), findsOneWidget);
    expect(find.text('Something else…'), findsOneWidget);
  });

  testWidgets('choices renders the question and options', (tester) async {
    final part = VanaChoicesPart.fromJson(fixture('choices'));
    await pumpPart(tester, part);
    if (part.question != null) expect(find.text(part.question!), findsOneWidget);
    for (final option in part.options) {
      expect(find.text(option), findsOneWidget);
    }
  });

  testWidgets('staples renders the carb line and chips', (tester) async {
    final part = VanaStaplesPart.fromJson(fixture('staples'));
    await pumpPart(tester, part);
    // Title from content keys.
    expect(find.text('Your staples'), findsOneWidget);
  });

  testWidgets('shopping_list renders the confirmed card', (tester) async {
    final part = VanaShoppingListPart.fromJson(fixture('shopping_list'));
    await pumpPart(tester, part);
    expect(
      find.byKey(const ValueKey('meal_planning.confirmed_card')),
      findsOneWidget,
    );
    expect(find.text('View shopping list'), findsOneWidget);
  });

  testWidgets('day_guidance renders the label and note', (tester) async {
    final part = VanaDayGuidancePart.fromJson(fixture('day_guidance'));
    await pumpPart(tester, part);
    expect(find.text(part.label), findsOneWidget);
    if (part.note.isNotEmpty) expect(find.text(part.note), findsOneWidget);
  });

  testWidgets('batch and brief render nothing', (tester) async {
    final batch = VanaPart.fromJson(fixture('batch')['parts'][0]
        as Map<String, dynamic>)!;
    expect(batch, isA<VanaBatchPart>());
    await pumpPart(tester, batch);
    // The batch part itself renders no inline widget — the plan bar owns it.
    expect(find.textContaining('meals picked'), findsNothing);

    final brief = VanaPart.fromJson({
      'kind': 'brief',
      'text': 'legacy',
      'chips': <String>[],
      'cite': <String>[],
    })!;
    await pumpPart(tester, brief);
    expect(find.text('legacy'), findsNothing);
  });

  testWidgets('logged renders the servings-left row', (tester) async {
    const part = VanaLoggedPart(
      planMealId: 'pm-1',
      name: 'Chicken & rice',
      servingsLeft: 3,
    );
    await pumpPart(tester, part);
    expect(find.byKey(const ValueKey('meal_planning.logged_row')), findsOneWidget);
    expect(find.textContaining('Chicken & rice'), findsOneWidget);
  });
}
