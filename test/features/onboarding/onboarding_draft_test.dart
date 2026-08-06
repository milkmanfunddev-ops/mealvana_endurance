import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_draft.dart';

void main() {
  group('enum dbValue round-trips', () {
    test('OnboardingSport', () {
      for (final sport in OnboardingSport.values) {
        expect(OnboardingSport.fromDbValue(sport.dbValue), sport);
      }
      expect(OnboardingSport.fromDbValue('not-a-sport'), isNull);
      expect(OnboardingSport.fromDbValue(null), isNull);
    });

    test('OnboardingGoal', () {
      for (final goal in OnboardingGoal.values) {
        expect(OnboardingGoal.fromDbValue(goal.dbValue), goal);
      }
      expect(OnboardingGoal.fromDbValue('nope'), isNull);
    });

    test('OnboardingPitfall', () {
      for (final pitfall in OnboardingPitfall.values) {
        expect(OnboardingPitfall.fromDbValue(pitfall.dbValue), pitfall);
      }
      expect(OnboardingPitfall.fromDbValue('nope'), isNull);
    });
  });

  group('triathlon implication', () {
    test('triathlon implies both run and ride fueling', () {
      const draft = OnboardingDraft(sports: {OnboardingSport.triathlon});
      expect(draft.wantsRunFueling, isTrue);
      expect(draft.wantsRideFueling, isTrue);
    });

    test('swimming implies neither', () {
      const draft = OnboardingDraft(sports: {OnboardingSport.swimming});
      expect(draft.wantsRunFueling, isFalse);
      expect(draft.wantsRideFueling, isFalse);
    });
  });

  group('unit conversions and conventions', () {
    test('birthday uses the documented mid-year convention', () {
      const draft = OnboardingDraft(birthYear: 1990);
      expect(draft.birthday, DateTime(1990, 7, 1));
      expect(const OnboardingDraft().birthday, isNull);
    });

    test('imperial height/weight convert to metric', () {
      const draft = OnboardingDraft(
        heightFeet: 5,
        heightInches: 8,
        weightPounds: 154.32,
      );
      expect(draft.heightCm, closeTo(172.72, 0.01));
      expect(draft.weightKg, closeTo(70.0, 0.01));
      expect(const OnboardingDraft().heightCm, isNull);
      expect(const OnboardingDraft().weightKg, isNull);
    });
  });

  group('copyWith', () {
    test('nullable setters can clear values', () {
      const draft = OnboardingDraft(firstName: 'Avery', birthYear: 1990);
      final cleared = draft.copyWith(
        firstName: () => null,
        birthYear: () => null,
      );
      expect(cleared.firstName, isNull);
      expect(cleared.birthYear, isNull);
      // Untouched fields survive.
      expect(cleared.gutTraining, GutTraining.moderate);
    });

    test('defaults match the app-wide defaults (moderate/medium)', () {
      const draft = OnboardingDraft();
      expect(draft.gutTraining, GutTraining.moderate);
      expect(draft.sweatRate, SweatRateCat.medium);
      expect(draft.planEdits.hasAnyEdit, isFalse);
    });
  });

  group('plan edits', () {
    test('hasAnyEdit reflects a single edited field', () {
      const edits = OnboardingPlanEdits(longRunCarbGph: 65);
      expect(edits.hasAnyEdit, isTrue);
      final cleared = edits.copyWith(longRunCarbGph: () => null);
      expect(cleared.hasAnyEdit, isFalse);
    });
  });
}
