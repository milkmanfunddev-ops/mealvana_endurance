/// CookingSessionController: the overview → cooking → done machine, step
/// navigation, parsed timers counting down under fakeAsync, and the
/// wake-lock intent.
library;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/cooking_session_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_detail_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/directions_origin.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_detail.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';

import '../helpers/container.dart';

class _FixedDetail extends MealDetailController {
  _FixedDetail(this.detail);
  final MealDetail detail;

  @override
  Future<MealDetail> build(String id) async => detail;
}

const _detail = MealDetail(
  meal: MealRef(
    source: MealSource.library,
    id: 'D-1',
    name: 'Pasta',
    mealType: MealType.dinner,
  ),
  methodSteps: [
    'Boil the pasta for 10-12 minutes.',
    'Stir the sauce, simmer 5 minutes, then add 90 seconds of high heat.',
    'Plate it.',
  ],
  ingredients: [
    MealIngredient(name: 'Pasta', qty: '200 g'),
    MealIngredient(name: 'Sauce', qty: '1 jar'),
  ],
  directions: MealDirections(
    origin: DirectionsOrigin.aiGenerated,
    verbatim: false,
  ),
  servings: 2,
);

void main() {
  CookingSessionController make(MealDetail detail) {
    final container = testContainer([
      ...baseOverrides(),
      mealDetailControllerProvider(
        'D-1',
      ).overrideWith(() => _FixedDetail(detail)),
    ]);
    container.listen(cookingSessionControllerProvider('D-1'), (_, __) {});
    return container.read(cookingSessionControllerProvider('D-1').notifier);
  }

  test(
    'parses timers per step and starts in overview without the wake lock',
    () async {
      final c = make(_detail);
      final s = await c.future;
      expect(s.phase, CookingPhase.overview);
      expect(s.wakeLockWanted, isFalse);
      expect(s.stepCount, 3);
      expect(
        s.timers[0]!.single.timer.seconds,
        12 * 60,
        reason: 'range → upper bound',
      );
      expect(s.timers[1]!.map((t) => t.timer.seconds), [5 * 60, 90]);
      expect(s.timers[2], isEmpty);
    },
  );

  test(
    'start → next → next → done; back at the first step is a no-op',
    () async {
      final c = make(_detail);
      await c.future;

      c.start();
      expect(c.state.value!.phase, CookingPhase.cooking);
      expect(c.state.value!.wakeLockWanted, isTrue);
      expect(c.state.value!.currentStep, startsWith('Boil'));

      c.back();
      expect(c.state.value!.stepIndex, 0);
      c.next();
      expect(c.state.value!.stepIndex, 1);
      c.goToStep(2);
      expect(c.state.value!.isLastStep, isTrue);
      c.next();
      expect(c.state.value!.phase, CookingPhase.done);
      expect(c.state.value!.wakeLockWanted, isFalse);

      c.startOver();
      expect(c.state.value!.phase, CookingPhase.overview);
      expect(c.state.value!.stepIndex, 0);
    },
  );

  test('no steps → start is a no-op', () async {
    final c = make(_detail.copyWith(methodSteps: const []));
    final s = await c.future;
    expect(s.hasSteps, isFalse);
    c.start();
    expect(c.state.value!.phase, CookingPhase.overview);
  });

  test('ingredients drawer toggles strike-through', () async {
    final c = make(_detail);
    await c.future;
    c.toggleIngredient(1);
    expect(c.state.value!.checkedIngredients, {1});
    c.toggleIngredient(1);
    expect(c.state.value!.checkedIngredients, isEmpty);
  });

  test(
    'timers count down, pause, reset, ring at zero and are acknowledged',
    () {
      fakeAsync((async) {
        final c = make(_detail);
        async.flushMicrotasks();
        expect(c.state.hasValue, isTrue);
        c.start();
        c.next(); // step 1: 5 min + 90 s

        c.startTimer(1, 1); // the 90 s one
        async.elapse(const Duration(seconds: 3));
        var t = c.state.value!.timers[1]![1];
        expect(t.running, isTrue);
        expect(t.remainingSeconds, 87);

        c.pauseTimer(1, 1);
        async.elapse(const Duration(seconds: 5));
        t = c.state.value!.timers[1]![1];
        expect(t.running, isFalse);
        expect(t.remainingSeconds, 87, reason: 'paused timers do not tick');

        c.startTimer(1, 1);
        async.elapse(const Duration(seconds: 87));
        t = c.state.value!.timers[1]![1];
        expect(t.remainingSeconds, 0);
        expect(t.running, isFalse);
        expect(t.rang, isTrue);
        expect(c.state.value!.ringing, hasLength(1));
        expect(c.state.value!.anyRunning, isFalse);

        c.acknowledgeTimer(1, 1);
        expect(c.state.value!.ringing, isEmpty);

        // A finished timer must be reset before it can run again.
        c.startTimer(1, 1);
        expect(c.state.value!.timers[1]![1].running, isFalse);
        c.resetTimer(1, 1);
        expect(c.state.value!.timers[1]![1].remainingSeconds, 90);

        // Two timers at once, finishing the session stops them.
        c.startTimer(1, 0);
        c.startTimer(1, 1);
        async.elapse(const Duration(seconds: 2));
        expect(c.state.value!.timers[1]!.every((x) => x.running), isTrue);
        c.finish();
        expect(c.state.value!.anyRunning, isFalse);
        async.elapse(const Duration(seconds: 2));
        expect(c.state.value!.timers[1]![1].remainingSeconds, 88);
      });
    },
  );
}
