/// Unit tests for the redesigned OnboardingController: draft mutators, the
/// incomplete-draft guard, the legacy-cache bridge (transition safety), and
/// the pure plan-edit → NutritionTargetOverrides merge.
///
/// The full saveAllOnboardingData pipeline (profile create → migrate →
/// upload → defaults → survey → overrides) requires a live Supabase session
/// and is covered by the Patrol e2e flows instead.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_target_overrides.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_draft.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';

void main() {
  late ProviderContainer container;
  late OnboardingController controller;

  setUp(() {
    container = ProviderContainer();
    controller = container.read(onboardingControllerProvider.notifier);
  });

  tearDown(() => container.dispose());

  group('draft mutators', () {
    test('updates accumulate into one draft', () {
      controller.updateSports({OnboardingSport.triathlon});
      controller.updateGoals({OnboardingGoal.performance});
      controller.updatePitfalls({
        OnboardingPitfall.gutIssues,
        OnboardingPitfall.energyCrash,
      });
      controller.updatePersonalInfo(
        firstName: 'Avery',
        gender: Gender.other,
        birthYear: 1994,
      );
      controller.updateBodyComposition(
        heightFeet: 5,
        heightInches: 9,
        weightPounds: 140,
      );
      controller.updateNutritionSettings(
        gutTraining: GutTraining.high,
        sweatRate: SweatRateCat.heavy,
      );

      final draft = controller.draft;
      expect(draft.sports, {OnboardingSport.triathlon});
      expect(draft.goals, {OnboardingGoal.performance});
      expect(draft.pitfalls, hasLength(2));
      expect(draft.firstName, 'Avery');
      expect(draft.gender, Gender.other);
      expect(draft.birthYear, 1994);
      expect(draft.weightPounds, 140);
      expect(draft.gutTraining, GutTraining.high);
      expect(draft.sweatRate, SweatRateCat.heavy);
    });

    test('blank strings do not clobber earlier personal info', () {
      controller.updatePersonalInfo(firstName: 'Avery', email: 'a@b.c');
      controller.updatePersonalInfo(firstName: '  ', email: '');
      expect(controller.draft.firstName, 'Avery');
      expect(controller.draft.email, 'a@b.c');
    });

    test('hasCompletedProfileDraft requires gender, birth year and weight', () {
      expect(controller.hasCompletedProfileDraft, isFalse);
      controller.updatePersonalInfo(gender: Gender.female, birthYear: 1990);
      expect(controller.hasCompletedProfileDraft, isFalse);
      controller.updateBodyComposition(weightPounds: 150);
      expect(controller.hasCompletedProfileDraft, isTrue);
    });

    test('connect-step flags land in the draft', () {
      controller.recordConnectedProvider('garmin');
      controller.recordTridotNotifyRequested();
      controller.recordSweatTestInterest();
      expect(controller.draft.connectedProvider, 'garmin');
      expect(controller.draft.tridotNotifyRequested, isTrue);
      expect(controller.draft.sweatTestInterest, isTrue);
    });
  });

  group('incomplete-draft guard', () {
    test('saveAllOnboardingData returns false cleanly with no draft', () async {
      final ok = await controller.saveAllOnboardingData();
      expect(ok, isFalse);
      // MEALVANA-ENDURANCE-DEV-4M regression: must not surface an AsyncError.
      expect(container.read(onboardingControllerProvider).hasError, isFalse);
    });
  });

  group('mergedOverridesForEdits (pure)', () {
    test('writes only edited fields; untouched stay null', () {
      final merged = OnboardingController.mergedOverridesForEdits(
        null,
        const OnboardingPlanEdits(longRunCarbGph: 65),
      );
      expect(merged.duringRun?.carbRateGPerH, 65);
      expect(merged.duringRun?.fluidRateMlPerH, isNull);
      expect(merged.duringCycling?.carbRateGPerH, isNull);
    });

    test('fluid/sodium edits apply to both run and ride', () {
      final merged = OnboardingController.mergedOverridesForEdits(
        null,
        const OnboardingPlanEdits(fluidMlPerHr: 600, sodiumMgPerHr: 800),
      );
      expect(merged.duringRun?.fluidRateMlPerH, 600);
      expect(merged.duringCycling?.fluidRateMlPerH, 600);
      expect(merged.duringRun?.sodiumRateMgPerH, 800);
      expect(merged.duringCycling?.sodiumRateMgPerH, 800);
    });

    test('existing overrides survive a partial edit', () {
      const existing = NutritionTargetOverrides(
        duringRun: DuringActivityOverrides(fluidRateMlPerH: 500),
      );
      final merged = OnboardingController.mergedOverridesForEdits(
        existing,
        const OnboardingPlanEdits(longRunCarbGph: 60),
      );
      expect(merged.duringRun?.carbRateGPerH, 60);
      expect(merged.duringRun?.fluidRateMlPerH, 500);
    });

    test('guardrails clamp out-of-range edits', () {
      final merged = OnboardingController.mergedOverridesForEdits(
        null,
        const OnboardingPlanEdits(
          longRunCarbGph: 500, // way past the 120 g/hr ceiling
          fluidMlPerHr: 50, // below the 200 mL/hr floor
        ),
      );
      expect(
        merged.duringRun!.carbRateGPerH,
        lessThanOrEqualTo(NutritionTargetGuardrails.duringMaxCarbRateGPerH),
      );
      expect(
        merged.duringRun!.fluidRateMlPerH,
        greaterThanOrEqualTo(
          NutritionTargetGuardrails.duringMinFluidRateMlPerH,
        ),
      );
    });
  });
}
