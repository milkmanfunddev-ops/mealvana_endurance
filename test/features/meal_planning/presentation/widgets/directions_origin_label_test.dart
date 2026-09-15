import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/directions_origin.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_detail.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/directions_origin_label.dart';

import '../helpers/test_content.dart';

/// mp-146 / ticket 32: every recipe says where its steps came from. Four
/// origins, four labels; verbatim names the publisher and links to the
/// original; AI-generated keeps the sparkle badge and its tooltip.
void main() {
  final content = loadDefaultContent();

  final opened = <Uri>[];

  Future<void> pump(WidgetTester tester, MealDirections directions) async {
    opened.clear();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            body: DirectionsOriginLabel(
              directions: directions,
              onOpen: (uri) async {
                opened.add(uri);
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('verbatim: "as published by X", tap opens the original', (
    tester,
  ) async {
    await pump(
      tester,
      const MealDirections(
        origin: DirectionsOrigin.source,
        sourceName: 'Jennifer Sygo',
        sourceUrl: 'https://www.runningmagazine.ca/recipes/salmon-quinoa',
        verbatim: true,
      ),
    );

    final label = ContentKeys.format(
      content['meal_planning.origin_verbatim']!,
      {'name': 'Jennifer Sygo'},
    );
    expect(find.text(label), findsOneWidget);
    expect(find.text('runningmagazine.ca'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('meal_planning.detail_origin_link')),
    );
    expect(opened, [
      Uri.parse('https://www.runningmagazine.ca/recipes/salmon-quinoa'),
    ]);
  });

  testWidgets('verbatim without a publisher name falls back to the host', (
    tester,
  ) async {
    await pump(
      tester,
      const MealDirections(
        origin: DirectionsOrigin.source,
        sourceUrl: 'https://greenletes.com/overnight-oats',
        verbatim: true,
      ),
    );

    final label = ContentKeys.format(
      content['meal_planning.origin_verbatim']!,
      {'name': 'greenletes.com'},
    );
    expect(find.text(label), findsOneWidget);
  });

  testWidgets('alternate source names it and links when it has a url', (
    tester,
  ) async {
    await pump(
      tester,
      const MealDirections(
        origin: DirectionsOrigin.altSource,
        sourceName: 'BBC Good Food',
        sourceUrl: 'https://www.bbcgoodfood.com/recipes/x',
      ),
    );

    final label = ContentKeys.format(
      content['meal_planning.origin_alt_source']!,
      {'name': 'BBC Good Food'},
    );
    expect(find.text(label), findsOneWidget);
    expect(find.text('bbcgoodfood.com'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('meal_planning.detail_origin_link')),
    );
    expect(opened, [Uri.parse('https://www.bbcgoodfood.com/recipes/x')]);
  });

  testWidgets('alternate source without a url is plain text', (tester) async {
    await pump(
      tester,
      const MealDirections(
        origin: DirectionsOrigin.altSource,
        sourceName: 'BBC Good Food',
      ),
    );

    final label = ContentKeys.format(
      content['meal_planning.origin_alt_source']!,
      {'name': 'BBC Good Food'},
    );
    expect(find.text(label), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meal_planning.detail_origin_link')),
      findsNothing,
    );
  });

  testWidgets('a simple assembly says so', (tester) async {
    await pump(
      tester,
      const MealDirections(origin: DirectionsOrigin.assemblySimple),
    );

    expect(
      find.text(content['meal_planning.origin_assembly']!),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.detail_origin_link')),
      findsNothing,
    );
  });

  testWidgets('AI-generated keeps the sparkle badge and its tooltip', (
    tester,
  ) async {
    await pump(
      tester,
      const MealDirections(origin: DirectionsOrigin.aiGenerated),
    );

    expect(
      find.text(content['meal_planning.badge_ai_generated']!),
      findsOneWidget,
    );
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, content['meal_planning.cook_ai_disclaimer']);
    expect(
      find.byKey(const ValueKey('meal_planning.detail_origin_link')),
      findsNothing,
    );
  });

  testWidgets('no recorded origin renders nothing', (tester) async {
    await pump(tester, const MealDirections());

    expect(find.byType(Text), findsNothing);
    expect(find.byType(Tooltip), findsNothing);
  });
}
