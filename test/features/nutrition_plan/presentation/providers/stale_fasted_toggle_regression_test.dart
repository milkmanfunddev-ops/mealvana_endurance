// Regression tests for the "Adjust your macros shows 0g BEFORE carbs" prod
// bug (fasted-state leak between activities).
//
// Root cause: RunningInputController / CyclingInputController /
// BrickInputController are `@Riverpod(keepAlive: true)`, so their form state
// survives navigation for the whole app session. Every other per-activity
// field is re-seeded when NewActivityScreen initializes (distance, pace,
// duration, timeBefore, title — see _initializeRunningController), but
// `isFasted` had no seed source (Activity doesn't persist a fasted flag) and
// was never reset. A fasted toggle left ON by a previous workout was then
// silently sent as `is_fasted: true` for the NEXT activity's generation —
// generate-macros-v4 correctly answers a fasted request with meal_type
// 'fasted' and ALL pre-workout targets zeroed, so the Adjust Macros screen
// showed 0g BEFORE carbs even though the user had set a pre-workout fueling
// window.
//
// Fix: each input controller exposes `resetFasted()`, and
// NewActivityScreen's per-entry initializers call it, mirroring the existing
// stale-keepAlive title reset in the same initializers and the brick
// controller's `isFasted: false` re-initialization paths.
//
// Mutation check: reverting the `controller.resetFasted()` call in
// NewActivityScreen._initializeRunningController makes the widget test below
// fail with `isFasted` still true after screen entry.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/running_input_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/cycling_input_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/brick_input_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/screens/new_activity_screen.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart'
    show currentUserProvider;
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../../../helpers/widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resetFasted clears a stale per-activity fasted toggle', () {
    ProviderContainer makeContainer() {
      final container = ProviderContainer(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          mockSharedPreferences(),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('RunningInputController', () {
      final container = makeContainer();
      final notifier = container.read(runningInputControllerProvider.notifier);

      notifier.updateFasted(true);
      expect(container.read(runningInputControllerProvider).isFasted, isTrue);

      notifier.resetFasted();
      expect(container.read(runningInputControllerProvider).isFasted, isFalse);
    });

    test('CyclingInputController', () {
      final container = makeContainer();
      final notifier = container.read(cyclingInputControllerProvider.notifier);

      notifier.updateFasted(true);
      expect(container.read(cyclingInputControllerProvider).isFasted, isTrue);

      notifier.resetFasted();
      expect(container.read(cyclingInputControllerProvider).isFasted, isFalse);
    });

    test('BrickInputController', () {
      final container = makeContainer();
      final notifier = container.read(brickInputControllerProvider.notifier);

      notifier.updateFasted(true);
      expect(container.read(brickInputControllerProvider).isFasted, isTrue);

      notifier.resetFasted();
      expect(container.read(brickInputControllerProvider).isFasted, isFalse);
    });

    test('resetFasted is a no-op when the toggle is already off', () {
      final container = makeContainer();
      final notifier = container.read(runningInputControllerProvider.notifier);
      final before = container.read(runningInputControllerProvider);

      notifier.resetFasted();

      // identical() proves no state emission happened (guarded reset).
      expect(
        identical(container.read(runningInputControllerProvider), before),
        isTrue,
      );
    });
  });

  group('NewActivityScreen entry clears leftover fasted state', () {
    // Pumps a shell inside ONE ProviderScope (so keepAlive controller state
    // survives, exactly like a real app session), sets the fasted toggle as a
    // previous workout would have left it, then mounts NewActivityScreen and
    // asserts its per-entry initialization cleared the leftover.
    Future<ProviderContainer> pumpShell(
      WidgetTester tester,
      ValueNotifier<bool> showScreen,
    ) async {
      const shellKey = ValueKey('fasted_regression.shell');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockAppExternalDeps(),
            appConfigProvider.overrideWithValue(AppConfig.forTesting()),
            mockSharedPreferences(),
            inMemoryDatabaseOverride(),
            currentUserProvider.overrideWith((ref) async => null),
          ],
          child: wrapForTest(
            KeyedSubtree(
              key: shellKey,
              child: ValueListenableBuilder<bool>(
                valueListenable: showScreen,
                builder: (_, show, __) =>
                    show ? const NewActivityScreen() : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return ProviderScope.containerOf(tester.element(find.byKey(shellKey)));
    }

    testWidgets(
      'stale running fasted toggle does not leak into the next activity',
      (tester) async {
        final showScreen = ValueNotifier<bool>(false);
        addTearDown(showScreen.dispose);
        final container = await pumpShell(tester, showScreen);

        // A previous workout in this session left the fasted toggle ON.
        container
            .read(runningInputControllerProvider.notifier)
            .updateFasted(true);
        expect(container.read(runningInputControllerProvider).isFasted, isTrue);

        // User opens the New Activity screen again (create or adjust flow).
        showScreen.value = true;
        await tester.pump();
        // Flush the initState microtask that runs _initializeFromEventData.
        await tester.pump(const Duration(milliseconds: 100));

        // Pre-fix this stayed true and the next generation sent
        // is_fasted: true → 0g pre-workout carbs on Adjust Macros.
        expect(
          container.read(runningInputControllerProvider).isFasted,
          isFalse,
        );
      },
    );

    testWidgets(
      'a fasted choice made on the open screen is preserved (reset is '
      'entry-time only)',
      (tester) async {
        final showScreen = ValueNotifier<bool>(true);
        addTearDown(showScreen.dispose);
        final container = await pumpShell(tester, showScreen);
        await tester.pump(const Duration(milliseconds: 100));

        // The user explicitly marks THIS workout as fasted after the screen
        // is up — that choice must stick until they leave the screen.
        container
            .read(runningInputControllerProvider.notifier)
            .updateFasted(true);
        await tester.pump(const Duration(milliseconds: 100));

        expect(container.read(runningInputControllerProvider).isFasted, isTrue);
      },
    );
  });
}
