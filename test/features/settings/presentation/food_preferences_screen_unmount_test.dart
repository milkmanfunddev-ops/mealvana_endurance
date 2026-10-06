// Ticket 23 (Sentry MEALVANA-ENDURANCE-CC): "Null check operator used on a
// null value" from `State.setState` inside `_loadFoods`. The user opened the
// likes/dislikes row and backed out within a second; the catalog fetch landed
// after the screen was disposed and `_loadFoods` called `setState` anyway. In a
// release build that is `_element!` on a null element; in a debug/test build
// the same bug surfaces as "setState() called after dispose()".
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/food_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/food_preferences_screen.dart';
import 'package:mealvana_endurance/features/user_foods/data/user_foods_repository.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fakes/recording_report.dart';
import '../../../helpers/widget_test_harness.dart';

class _MockFoodRepository extends Mock implements FoodRepository {}

class _MockAuthService extends Mock implements AuthService {}

/// Shows the screen while [visible] is true: flipping it false disposes the
/// screen with the ProviderScope still alive, the way a back-pop does.
class _Host extends StatelessWidget {
  const _Host(this.visible);

  final ValueNotifier<bool> visible;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: visible,
    builder: (_, show, __) =>
        show ? const FoodPreferencesScreen() : const SizedBox.shrink(),
  );
}

void main() {
  testWidgets('a food load that lands after the screen closed is dropped quietly', (
    tester,
  ) async {
    final catalog = Completer<List<FoodItem>>();
    final foodRepository = _MockFoodRepository();
    when(
      () => foodRepository.getPrimaryFoodsForPreferences(),
    ).thenAnswer((_) => catalog.future);
    when(
      () => foodRepository.getAdditionalFoodsForPreferences(),
    ).thenAnswer((_) async => <FoodItem>[]);

    final authService = _MockAuthService();
    when(() => authService.getCurrentUser()).thenAnswer((_) async => null);

    final report = RecordingReport();
    final visible = ValueNotifier<bool>(true);
    addTearDown(visible.dispose);

    await pumpSeeded(
      tester,
      _Host(visible),
      overrides: [
        reportProvider.overrideWithValue(report),
        foodRepositoryProvider.overrideWithValue(foodRepository),
        authServiceProvider.overrideWithValue(authService),
        // No remote in a widget test: the sync step degrades and the load
        // carries on with cached data, exactly as on a flaky network.
        userFoodsRepositoryProvider.overrideWith(
          (ref) async => throw StateError('no remote in test'),
        ),
      ],
    );

    // The load is parked on the catalog fetch.
    expect(find.byType(FoodPreferencesScreen), findsOneWidget);

    // User backs out before the catalog answers.
    visible.value = false;
    await tester.pump();
    expect(find.byType(FoodPreferencesScreen), findsNothing);

    // The catalog lands after dispose.
    catalog.complete(<FoodItem>[]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(
      report.faults,
      isEmpty,
      reason: report.faults.map((f) => '${f.message}: ${f.error}').join('\n'),
    );
  });
}
