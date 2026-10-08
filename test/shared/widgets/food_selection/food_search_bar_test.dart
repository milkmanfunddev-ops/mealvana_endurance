/// Testing-wave 28-006: the Log search bar's barcode icon and round search
/// button had no accessibility label, so VoiceOver could not find them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
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
}
