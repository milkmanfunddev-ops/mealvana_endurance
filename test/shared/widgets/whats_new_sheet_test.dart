import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/shared/widgets/whats_new_sheet.dart';

import '../../features/meal_planning/presentation/helpers/test_content.dart';

void main() {
  testWidgets('renders the announcement copy and dismisses on the CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showWhatsNewSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('whats_new.title')), findsOneWidget);
    expect(find.text("Shake to tell us what's wrong"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('whats_new.cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('whats_new.title')), findsNothing);
  });
}
