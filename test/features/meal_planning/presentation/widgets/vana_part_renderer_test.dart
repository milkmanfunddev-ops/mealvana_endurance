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
  Map<String, dynamic> fixture(String name) =>
      jsonDecode(
            File(
              'test/features/meal_planning/fixtures/$name.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  Future<void> pumpPart(
    WidgetTester tester,
    VanaPart part, {
    void Function(String label)? onChipPick,
    void Function(MealRef meal, int servings)? onPickMeal,
    ValueChanged<VanaHandOffPart>? onHandOff,
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
                  onHandOff: onHandOff,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('hand_off (mp-265, ticket 27)', () {
    test('the frozen fixtures parse: the four targets, the entity id', () {
      final plan = VanaPart.fromJson(fixture('hand_off'));
      expect(plan, isA<VanaHandOffPart>());
      plan as VanaHandOffPart;
      expect(plan.target, VanaHandOffTarget.mealPlan);
      expect(plan.label, 'Open meal planning');
      expect(plan.entityId, isNull);
      expect(plan.toJson(), fixture('hand_off'));

      final activity =
          VanaPart.fromJson(fixture('hand_off_entity')) as VanaHandOffPart;
      expect(activity.target, VanaHandOffTarget.newActivity);
      expect(activity.entityId, '5b0c7a52-3f1e-4d7a-9a51-2d8f0c1e6b44');

      expect(
        [for (final t in VanaHandOffTarget.values) t.wire],
        ['meal_plan', 'new_activity', 'event', 'carb_loading'],
      );
    });

    test('a target this client does not know drops the part', () {
      expect(
        VanaPart.fromJson(const {
          'kind': 'hand_off',
          'target': 'settings',
          'label': 'Open settings',
          'entityId': null,
        }),
        isNull,
      );
    });

    testWidgets('renders a button with the label; a tap hands the part over', (
      tester,
    ) async {
      VanaHandOffPart? tapped;
      final part = VanaPart.fromJson(fixture('hand_off'))!;
      await pumpPart(tester, part, onHandOff: (p) => tapped = p);

      final button = find.byKey(const ValueKey('meal_planning.hand_off'));
      expect(button, findsOneWidget);
      expect(
        find.descendant(of: button, matching: find.text('Open meal planning')),
        findsOneWidget,
      );
      await tester.tap(button);
      expect(tapped?.target, VanaHandOffTarget.mealPlan);
    });
  });

  testWidgets('meal_picker renders the tiles and chip strip, no title', (
    tester,
  ) async {
    final part = VanaMealPickerPart.fromJson(fixture('meal_picker'));
    await pumpPart(tester, part);
    // 2026-09-07 (Lee): the picker draws no title / "tap to add" / why
    // blurb — the tiles are self-explanatory.
    expect(find.text(part.title), findsNothing);
    expect(find.text(part.meals.first.name), findsOneWidget);
    // The chip strip renders under the picker (primary + other + something).
    expect(find.text('I like these'), findsOneWidget);
    expect(find.text('Something else…'), findsOneWidget);
  });

  testWidgets('choices renders the question and options', (tester) async {
    final part = VanaChoicesPart.fromJson(fixture('choices'));
    await pumpPart(tester, part);
    if (part.question != null)
      expect(find.text(part.question!), findsOneWidget);
    for (final option in part.options) {
      expect(find.text(option), findsOneWidget);
    }
  });

  testWidgets('staples renders the carb line and chips', (tester) async {
    final part = VanaStaplesPart.fromJson(fixture('staples'));
    await pumpPart(tester, part);
    // Title from content keys, drawn as an uppercase eyebrow.
    expect(find.text('YOUR STAPLES'), findsOneWidget);
  });

  testWidgets('shopping_list renders the confirmed card', (tester) async {
    final part = VanaShoppingListPart.fromJson(fixture('shopping_list'));
    await pumpPart(tester, part);
    expect(
      find.byKey(const ValueKey('meal_planning.confirmed_card')),
      findsOneWidget,
    );
    expect(find.text('Open shopping list'), findsOneWidget);
  });

  testWidgets('day_guidance renders the label and note', (tester) async {
    final part = VanaDayGuidancePart.fromJson(fixture('day_guidance'));
    await pumpPart(tester, part);
    expect(find.text(part.label), findsOneWidget);
    if (part.note.isNotEmpty) expect(find.text(part.note), findsOneWidget);
  });

  testWidgets('batch and brief render nothing', (tester) async {
    final batch = VanaPart.fromJson(
      fixture('batch')['parts'][0] as Map<String, dynamic>,
    )!;
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
    expect(
      find.byKey(const ValueKey('meal_planning.logged_row')),
      findsOneWidget,
    );
    expect(find.textContaining('Chicken & rice'), findsOneWidget);
  });
}
