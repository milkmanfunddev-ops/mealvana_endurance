import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_attach_sheet.dart';

import '../helpers/test_content.dart';

/// Plan §5 Phases 6.5 / 7.3 — the composer `+` sheet: "Browse meals",
/// "Snap my fridge", "Choose a photo", "Use what I have". The photo rows
/// hand off to `image_picker` (not exercised here); "Browse meals" and
/// "Use what I have" resolve to their choices and dismissing resolves to
/// null.
void main() {
  Future<Future<VanaAttachChoice?>> open(WidgetTester tester) async {
    late Future<VanaAttachChoice?> result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => result = showVanaAttachSheet(context: context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('lists the four rows (mobile) with real copy', (tester) async {
    await open(tester);
    expect(find.text('Browse meals'), findsOneWidget);
    expect(find.text('Snap my fridge'), findsOneWidget);
    expect(find.text('Choose a photo'), findsOneWidget);
    expect(find.text('Use what I have'), findsOneWidget);
  });

  testWidgets('"Browse meals" leads the sheet and resolves to its choice', (
    tester,
  ) async {
    final result = await open(tester);
    final browseY = tester.getTopLeft(find.text('Browse meals')).dy;
    final fridgeY = tester.getTopLeft(find.text('Snap my fridge')).dy;
    expect(browseY, lessThan(fridgeY));

    await tester.tap(find.text('Browse meals'));
    await tester.pumpAndSettle();
    expect(await result, isA<VanaAttachBrowseMeals>());
  });

  testWidgets('"Use what I have" resolves to its choice', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Use what I have'));
    await tester.pumpAndSettle();
    expect(await result, isA<VanaAttachUseWhatIHave>());
  });

  testWidgets('dismissing resolves to null', (tester) async {
    final result = await open(tester);
    // Tap the barrier above the sheet.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });
}
