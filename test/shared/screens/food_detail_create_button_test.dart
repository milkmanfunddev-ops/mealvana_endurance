/// Testing-wave 68-009 (ticket 74): on Create Custom Food, "Create Food"
/// stayed disabled after the name was typed.
///
/// The field listeners call `setState` only the first time (`_hasChanges`),
/// and a `TextEditingController` also notifies on a selection change: the tap
/// that focuses the empty name field spent that one rebuild with the name
/// still empty, so no keystroke ever re-read the name. The button now
/// listens to the name controller itself.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/screens/food_detail_screen.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/buttons/primary_button.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  const createButton = ValueKey('custom_food.create_button');
  const nameField = ValueKey('custom_food.name_field');

  /// Pumps a host page that opens Create Custom Food the way the swap
  /// picker does (`context.push<FoodDetailResult>`), and records the result.
  Future<List<Object?>> pumpCreateFood(WidgetTester tester) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final results = <Object?>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                results.add(await context.push<Object?>('/create'));
              },
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/create',
          builder: (_, _) => FoodDetailScreen(
            foodData: FoodDetailData(id: 'new-food-id', name: ''),
            mode: FoodDetailMode.createNew,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [mockAppExternalDeps(), mockSharedPreferences()],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (_, _) => MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  bool isEnabled(WidgetTester tester) =>
      tester.widget<KylePrimaryButton>(find.byKey(createButton)).onPressed !=
      null;

  testWidgets('focusing the name field first, then typing, enables Create '
      'Food and one tap returns the food', (tester) async {
    final results = await pumpCreateFood(tester);
    expect(isEnabled(tester), isFalse);

    // The tap that places the caret: run 68's first move.
    await tester.tap(find.byKey(nameField));
    await tester.pump();
    expect(isEnabled(tester), isFalse);

    await tester.enterText(find.byKey(nameField), 'tw68 rice cup');
    await tester.pump();
    expect(isEnabled(tester), isTrue);

    await tester.ensureVisible(find.byKey(createButton));
    await tester.tap(find.byKey(createButton));
    await tester.pumpAndSettle();

    expect(results, hasLength(1));
    final result = results.single;
    expect(result, isA<FoodDetailResult>());
    expect((result! as FoodDetailResult).name, 'tw68 rice cup');
  });

  testWidgets('clearing the name disables Create Food again', (tester) async {
    await pumpCreateFood(tester);

    await tester.tap(find.byKey(nameField));
    await tester.pump();
    await tester.enterText(find.byKey(nameField), 'tw68 rice cup');
    await tester.pump();
    expect(isEnabled(tester), isTrue);

    await tester.enterText(find.byKey(nameField), '   ');
    await tester.pump();
    expect(isEnabled(tester), isFalse);
  });
}
