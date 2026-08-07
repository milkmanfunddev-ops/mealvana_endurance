import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/onboarding/application/plan_preview_service.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_draft.dart';
import 'package:mealvana_endurance/features/onboarding/domain/training_insights.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  final now = DateTime(2026, 8, 6);

  OnboardingDraft draft({
    Set<OnboardingSport> sports = const {OnboardingSport.running},
    Gender? gender = Gender.male,
    int? birthYear = 1991,
    double? weightPounds = 154.32, // ≈70 kg
    int? heightFeet = 5,
    int? heightInches = 8, // ≈172.7 cm
    GutTraining gutTraining = GutTraining.moderate,
    SweatRateCat sweatRate = SweatRateCat.medium,
  }) {
    return OnboardingDraft(
      sports: sports,
      gender: gender,
      birthYear: birthYear,
      weightPounds: weightPounds,
      heightFeet: heightFeet,
      heightInches: heightInches,
      gutTraining: gutTraining,
      sweatRate: sweatRate,
    );
  }

  group('fueling targets', () {
    test('run-only selection gets a run card only', () {
      final preview = PlanPreviewService.buildPreview(draft(), now: now);
      expect(preview.longRun, isNotNull);
      expect(preview.longRide, isNull);
      // 150-min run, moderate gut: band [60,90] mid 75, run ceiling 70.
      expect(preview.longRun!.carbGph, 70.0);
    });

    test('triathlon implies both cards', () {
      final preview = PlanPreviewService.buildPreview(
        draft(sports: {OnboardingSport.triathlon}),
        now: now,
      );
      expect(preview.longRun, isNotNull);
      expect(preview.longRide, isNotNull);
      // 180-min ride, moderate gut: mid 75 under the 120 cycling ceiling.
      expect(preview.longRide!.carbGph, 75.0);
    });

    test('gut training flips the g/hr target', () {
      final low = PlanPreviewService.buildPreview(
        draft(gutTraining: GutTraining.low),
        now: now,
      );
      final high = PlanPreviewService.buildPreview(
        draft(gutTraining: GutTraining.high),
        now: now,
      );
      // Low: 75 × 0.7 = 52.5 (under ceiling). High: 75 × 1.2 = 90 → capped 70.
      expect(low.longRun!.carbGph, 52.5);
      expect(high.longRun!.carbGph, 70.0);
      expect(low.longRun!.carbGph, lessThan(high.longRun!.carbGph));
    });

    test('running ceiling engages where cycling does not', () {
      final run = PlanPreviewService.buildPreview(
        draft(gutTraining: GutTraining.high),
        now: now,
      );
      final ride = PlanPreviewService.buildPreview(
        draft(sports: {OnboardingSport.cycling}, gutTraining: GutTraining.high),
        now: now,
      );
      expect(run.longRun!.carbGph, 70.0); // capped
      expect(ride.longRide!.carbGph, 90.0); // 75 × 1.2 uncapped
    });

    test('swim-only selection gets no fueling or hydration cards', () {
      final preview = PlanPreviewService.buildPreview(
        draft(sports: {OnboardingSport.swimming}),
        now: now,
      );
      expect(preview.longRun, isNull);
      expect(preview.longRide, isNull);
      expect(preview.fluidMlPerHr, isNull);
      expect(preview.sodiumMgPerHr, isNull);
    });
  });

  group('hydration', () {
    test('sweat category changes both fluid and sodium', () {
      final light = PlanPreviewService.buildPreview(
        draft(sweatRate: SweatRateCat.light),
        now: now,
      );
      final heavy = PlanPreviewService.buildPreview(
        draft(sweatRate: SweatRateCat.heavy),
        now: now,
      );
      expect(light.fluidMlPerHr, isNotNull);
      expect(heavy.fluidMlPerHr!, greaterThan(light.fluidMlPerHr!));
      expect(heavy.sodiumMgPerHr!, greaterThan(light.sodiumMgPerHr!));
    });
  });

  group('daily tabs', () {
    test('rest day carbs are exactly 4.0 g/kg and carb-load 9.0 g/kg', () {
      final preview = PlanPreviewService.buildPreview(draft(), now: now);
      expect(preview.restDay.carbGPerKg, 4.0);
      expect(preview.carbLoadDay.carbGPerKg, 9.0);
      expect(
        preview.workoutDay.carbGPerKg,
        greaterThan(preview.restDay.carbGPerKg),
      );
    });

    test('calories are 4/4/9-consistent and ordered rest < workout', () {
      final preview = PlanPreviewService.buildPreview(draft(), now: now);
      for (final day in [
        preview.workoutDay,
        preview.restDay,
        preview.carbLoadDay,
      ]) {
        expect(day.calories, day.carbsG * 4 + day.proteinG * 4 + day.fatG * 9);
      }
      expect(
        preview.workoutDay.calories,
        greaterThan(preview.restDay.calories),
      );
      expect(
        preview.carbLoadDay.calories,
        greaterThan(preview.restDay.calories),
      );
    });

    test('gender flip changes calorie targets (RMR offset)', () {
      final male = PlanPreviewService.buildPreview(
        draft(gender: Gender.male),
        now: now,
      );
      final female = PlanPreviewService.buildPreview(
        draft(gender: Gender.female),
        now: now,
      );
      final other = PlanPreviewService.buildPreview(
        draft(gender: Gender.other),
        now: now,
      );
      expect(male.restDay.calories, greaterThan(female.restDay.calories));
      // Non-binary takes the non-male branch, exactly like the server.
      expect(other.restDay.calories, female.restDay.calories);
    });
  });

  group('generic-defaults contract (skip / Runna paths)', () {
    test('all-null biometrics produce a finite sane plan, flagged generic', () {
      final preview = PlanPreviewService.buildPreview(
        const OnboardingDraft(sports: {OnboardingSport.running}),
        now: now,
      );
      expect(preview.isGeneric, isTrue);
      expect(preview.longRun!.carbGph, greaterThan(0));
      expect(preview.fluidMlPerHr, greaterThan(0));
      expect(preview.sodiumMgPerHr, greaterThan(0));
      for (final day in [
        preview.workoutDay,
        preview.restDay,
        preview.carbLoadDay,
      ]) {
        expect(day.carbsG, greaterThan(0));
        expect(day.proteinG, greaterThan(0));
        expect(day.fatG, greaterThan(0));
        expect(day.calories, greaterThan(1000));
        expect(day.calories, lessThan(6000));
      }
    });

    test('full biometrics are not flagged generic', () {
      final preview = PlanPreviewService.buildPreview(draft(), now: now);
      expect(preview.isGeneric, isFalse);
    });

    test('partially missing biometrics still flag generic', () {
      final preview = PlanPreviewService.buildPreview(
        draft(weightPounds: null),
        now: now,
      );
      expect(preview.isGeneric, isTrue);
    });
  });

  group('training insights personalization', () {
    final reliableInsights = TrainingInsights(
      isReliable: true,
      windowDays: 7,
      sessionCount: 5,
      weeklyDurationHours: 9.0,
      longestRun: InsightSession(
        activityType: ActivityType.running,
        durationMinutes: 130,
        distanceMiles: 15,
        scheduledDateTime: DateTime(2026, 7, 26),
      ),
    );

    test('the carb RATE ignores the imported session duration', () {
      // The card prescribes g/hr for a long session — what to take in when
      // the athlete does one. It must not be scaled to whatever happened to
      // be longest in the import: a week whose only ride was 45 minutes
      // once produced a 'long-ride carb target' of 15 g/hr, which is not a
      // long-ride fueling rate. A thin week means we saw no long session,
      // not that this athlete fuels long sessions differently.
      final preview = PlanPreviewService.buildPreview(
        draft(),
        insights: reliableInsights,
        now: now,
      );
      expect(preview.usedTrainingData, isTrue);
      expect(
        preview.longRun!.basedOnMinutes,
        PlanPreviewService.defaultLongRunMinutes,
      );
      // Same rate a generic preview would give — 130 real minutes changed
      // nothing about the prescription.
      expect(
        preview.longRun!.carbGph,
        PlanPreviewService.buildPreview(draft(), now: now).longRun!.carbGph,
      );
      // The real session is still carried, for the daily screen's caption.
      expect(preview.longRun!.insightDescriptor, 'your 15-mile long run');
    });

    test('a short imported ride does not depress the long-ride rate', () {
      // The reported case, in miniature: one 45-minute ride in the window.
      final shortRide = TrainingInsights(
        isReliable: true,
        windowDays: 10,
        sessionCount: 5,
        weeklyDurationHours: 6,
        longestRide: InsightSession(
          activityType: ActivityType.cycling,
          durationMinutes: 45,
          distanceMiles: 10,
          scheduledDateTime: DateTime(2026, 8, 9),
        ),
      );
      final preview = PlanPreviewService.buildPreview(
        draft(sports: {OnboardingSport.cycling}),
        insights: shortRide,
        now: now,
      );

      expect(
        preview.longRide!.basedOnMinutes,
        PlanPreviewService.defaultLongRideMinutes,
      );
      expect(
        preview.longRide!.carbGph,
        PlanPreviewService.buildPreview(
          draft(sports: {OnboardingSport.cycling}),
          now: now,
        ).longRide!.carbGph,
      );
    });

    test('unreliable insights fall back to generic constants', () {
      final unreliable = TrainingInsights(
        isReliable: false,
        windowDays: 3,
        sessionCount: 1,
        weeklyDurationHours: 2,
        longestRun: InsightSession(
          activityType: ActivityType.running,
          durationMinutes: 45,
          scheduledDateTime: DateTime(2026, 7, 26),
        ),
      );
      final preview = PlanPreviewService.buildPreview(
        draft(),
        insights: unreliable,
        now: now,
      );
      expect(preview.usedTrainingData, isFalse);
      expect(
        preview.longRun!.basedOnMinutes,
        PlanPreviewService.defaultLongRunMinutes,
      );
      expect(preview.longRun!.insightDescriptor, isNull);
    });

    test('reliable weekly hours shift the NEAT tier (calorie delta)', () {
      final generic = PlanPreviewService.buildPreview(draft(), now: now);
      final highVolume = PlanPreviewService.buildPreview(
        draft(),
        insights: const TrainingInsights(
          isReliable: true,
          windowDays: 7,
          sessionCount: 6,
          weeklyDurationHours: 14.0,
        ),
        now: now,
      );
      // 14 h/week → base NEAT 0.17 vs default 0.25 → fewer rest-day calories.
      expect(highVolume.restDay.calories, lessThan(generic.restDay.calories));
    });
  });
}
