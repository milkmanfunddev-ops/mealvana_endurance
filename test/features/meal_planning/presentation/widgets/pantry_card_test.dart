import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/pantry_card.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_part_renderer.dart';

import '../../domain/fixture_helpers.dart';
import '../helpers/test_content.dart';

/// Plan Phase 7 — the `pantry` part: the grid is seeded from the fixture's
/// ticked items, a custom entry joins (ticked), "Use these" reports the
/// ticked names in grid order and spends the card, and a photo-origin part
/// carries the "from your photo" tag.
void main() {
  final content = loadDefaultContent();
  final part = VanaPart.fromJson(loadFixture('pantry')) as VanaPantryPart;

  Future<void> pump(
    WidgetTester tester,
    Widget child,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
  }

  Finder chip(String label) => find.byKey(ValueKey('selectable_chip_$label'));
  final use = find.byKey(const ValueKey('meal_planning.pantry_use'));

  testWidgets('seeds the grid from the part and uses the wire title', (
    tester,
  ) async {
    await pump(tester, PantryCard(part: part, onUse: (_) {}));
    expect(find.text(part.title!), findsOneWidget);
    for (final item in part.items) {
      expect(chip(item.name), findsOneWidget);
    }
    // Pre-ticked rows carry the check; the unticked one does not.
    expect(
      find.descendant(of: chip('eggs'), matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: chip('spinach'), matching: find.byIcon(Icons.check)),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.pantry_from_photo')),
      findsNothing,
    );
  });

  testWidgets('"Use these" reports the ticked names then spends the card', (
    tester,
  ) async {
    List<String>? used;
    await pump(tester, PantryCard(part: part, onUse: (n) => used = n));

    await tester.tap(chip('spinach')); // tick
    await tester.pump(); // the grid is controlled — one toggle per frame
    await tester.tap(chip('rice')); // untick
    await tester.pump();
    await tester.tap(use);
    await tester.pump();

    expect(used, ['eggs', 'spinach', 'chicken thighs'], reason: 'grid order');
    expect(use, findsNothing);
    expect(
      find.byKey(const ValueKey('meal_planning.pantry_used')),
      findsOneWidget,
    );
    expect(
      find.text(
        content['meal_planning.pantry_used']!.replaceAll('{n}', '3'),
      ),
      findsOneWidget,
    );
    // Spent: the + is gone and a tap changes nothing.
    expect(find.byKey(const ValueKey('selectable_chip_add')), findsNothing);
  });

  testWidgets('a custom entry joins the grid ticked and is reported', (
    tester,
  ) async {
    List<String>? used;
    await pump(tester, PantryCard(part: part, onUse: (n) => used = n));

    await tester.tap(find.byKey(const ValueKey('selectable_chip_add')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('selectable_chip_entry')),
      'tofu',
    );
    await tester.tap(find.byKey(const ValueKey('selectable_chip_submit')));
    await tester.pump();

    expect(chip('tofu'), findsOneWidget);
    await tester.tap(use);
    expect(used, contains('tofu'));
  });

  testWidgets('a duplicate custom entry ticks the existing chip instead', (
    tester,
  ) async {
    await pump(tester, PantryCard(part: part, onUse: (_) {}));
    await tester.tap(find.byKey(const ValueKey('selectable_chip_add')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('selectable_chip_entry')),
      'Spinach',
    );
    await tester.tap(find.byKey(const ValueKey('selectable_chip_submit')));
    await tester.pump();
    expect(chip('spinach'), findsOneWidget);
    expect(chip('Spinach'), findsNothing);
    expect(
      find.descendant(of: chip('spinach'), matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });

  testWidgets('photo origin shows the tag; missing title falls back', (
    tester,
  ) async {
    final photo = VanaPantryPart.fromJson({
      ...loadFixture('pantry'),
      'origin': 'photo',
    }..remove('title'));
    await pump(tester, PantryCard(part: photo, onUse: (_) {}));
    expect(
      find.byKey(const ValueKey('meal_planning.pantry_from_photo')),
      findsOneWidget,
    );
    expect(find.text(content['meal_planning.pantry_title']!), findsOneWidget);
  });

  testWidgets('renders through VanaPartRenderer with onPantryUse wired', (
    tester,
  ) async {
    List<String>? used;
    await pump(
      tester,
      VanaPartRenderer(
        part: part,
        callbacks: VanaPartCallbacks(
          onTapMeal: (_) {},
          onPickMeal: (_, __) {},
          onChipPick: (_) {},
          onSomethingElse: () {},
          onAcceptRule: (_) {},
          onViewShopping: () {},
          onPantryUse: (n) => used = n,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('meal_planning.pantry_card')), findsOneWidget);
    await tester.tap(use);
    expect(used, part.selectedNames);
  });
}
