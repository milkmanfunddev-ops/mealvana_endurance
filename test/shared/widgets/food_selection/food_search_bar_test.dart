/// Testing-wave 28-006: the Log search bar's barcode icon and round search
/// button had no accessibility label, so VoiceOver could not find them.
///
/// Testing-wave 68-010 (develop-2026-10 ticket 82): Search with an empty
/// field did nothing at all. It now says what to do and does not search.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/shared/widgets/food_selection/food_search_bar.dart';

import '../../../helpers/test_content.dart';

void main() {
  testWidgets('barcode and search are labelled buttons', (tester) async {
    final handle = tester.ensureSemantics();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var scans = 0;
    final searches = <String>[];

    // The labels come from the content system (content_defaults.json).
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            body: FoodSearchBar(
              controller: controller,
              onSearch: searches.add,
              onBarcodeScan: () => scans++,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Scan barcode')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Search')),
      isSemantics(isButton: true, hasTapAction: true),
    );

    // The labelled nodes are the working controls.
    await tester.tap(find.bySemanticsLabel('Scan barcode'));
    controller.text = 'oats';
    await tester.tap(find.bySemanticsLabel('Search'));
    expect(scans, 1);
    expect(searches, ['oats']);
    handle.dispose();
  });

  for (final empty in ['', '   ']) {
    testWidgets('an empty query ("$empty") says what to do and does not '
        'search, from the Search tap and from Return', (tester) async {
      final emptyQuery = loadDefaultContent()[ContentKeys.foodSearchEmptyQuery];
      expect(emptyQuery, 'Type a food or recipe to search.');
      final controller = TextEditingController(text: empty);
      addTearDown(controller.dispose);
      final searches = <String>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [contentServiceProvider.overrideWith(testContentService)],
          child: MaterialApp(
            home: Scaffold(
              body: FoodSearchBar(
                controller: controller,
                onSearch: searches.add,
                onChanged: (_) {},
                onBarcodeScan: () {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel('Search'));
      await tester.pump();
      expect(searches, isEmpty);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(emptyQuery!),
        ),
        findsOneWidget,
      );

      // Return in the empty field: the same, and the bar is replaced rather
      // than stacked.
      await tester.showKeyboard(find.byType(TextField));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(searches, isEmpty);
      expect(find.text(emptyQuery), findsOneWidget);

      // Let the bar's display timer run out inside the test (#110).
      await tester.pumpAndSettle(const Duration(seconds: 10));
    });
  }
}
