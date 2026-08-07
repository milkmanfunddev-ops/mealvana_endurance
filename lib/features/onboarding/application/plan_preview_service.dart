import 'dart:math' as math;

import '../../auth/domain/user_preferences.dart';
import '../../nutrition_plan/application/daily_baseline_calculator.dart';
import '../../nutrition_plan/data/offline_macro_calculator.dart';
import '../domain/onboarding_draft.dart';
import '../domain/onboarding_plan_preview.dart';
import '../domain/training_insights.dart';

/// Builds the client-side plan preview shown on the onboarding plan-reveal
/// and daily-plan screens, before any account or network exists.
///
/// Composition, not new math: during-workout carb/fluid/sodium come from
/// [OfflineMacroCalculator] (already parity-pinned against generate-macros-v4)
/// and daily macros from [DailyBaselineCalculator] (parity-pinned against
/// calculate-daily-macros — the SSOT swap point).
///
/// Contract (Lee's failure cases): every biometric input is nullable. Skip
/// and Runna-ICS paths produce a plan from the generic defaults below with
/// `isGeneric: true` — this service never throws for missing data.
class PlanPreviewService {
  PlanPreviewService._();

  // Generic defaults, applied per-field when the draft lacks a biometric.
  // The sex default takes the Mifflin non-male branch, exactly like the
  // server does for any non-'male' sex string.
  static const double defaultWeightKg = 70.0;
  static const double defaultHeightCm = 172.0;
  static const int defaultAge = 35;

  /// Representative long-session durations when no reliable training data
  /// exists. Chosen to sit in the 60–90 g/hr duration band, the typical
  /// "long session" a fueling plan is built around.
  static const int defaultLongRunMinutes = 150;
  static const int defaultLongRideMinutes = 180;

  /// Representative endurance zone distribution for the workout-day session
  /// (mostly conversational with some tempo — IF ≈ 0.74).
  static const double _pctConversational = 0.80;
  static const double _pctTempo = 0.15;
  static const double _pctAllout = 0.05;

  /// Build the preview for [draft], personalized from [insights] when they
  /// pass the reliability gate. [now] injectable for tests.
  static OnboardingPlanPreview buildPreview(
    OnboardingDraft draft, {
    TrainingInsights? insights,
    DateTime? now,
  }) {
    final reliable = insights != null && insights.isReliable;

    // --- Resolve biometrics (generic per-field fallback) ---
    final weightKg = draft.weightKg ?? defaultWeightKg;
    final heightCm = draft.heightCm ?? defaultHeightCm;
    final age = _ageFrom(draft.birthday, now ?? DateTime.now()) ?? defaultAge;
    final isMale = draft.gender == Gender.male;
    final isGeneric =
        draft.weightKg == null ||
        draft.heightCm == null ||
        draft.birthYear == null ||
        draft.gender == null;

    // --- During-workout fueling cards ---
    final wantsRun = draft.wantsRunFueling;
    final wantsRide = draft.wantsRideFueling;

    final runMinutes = reliable && insights.longestRun != null
        ? insights.longestRun!.durationMinutes
        : defaultLongRunMinutes;
    final rideMinutes = reliable && insights.longestRide != null
        ? insights.longestRide!.durationMinutes
        : defaultLongRideMinutes;

    final longRun = wantsRun
        ? _fuelingTarget(
            sport: 'running',
            minutes: runMinutes,
            gutTraining: draft.gutTraining,
            insightDescriptor: reliable && insights.longestRun != null
                ? insights.longestRun!.descriptor
                : null,
          )
        : null;
    final longRide = wantsRide
        ? _fuelingTarget(
            sport: 'cycling',
            minutes: rideMinutes,
            gutTraining: draft.gutTraining,
            insightDescriptor: reliable && insights.longestRide != null
                ? insights.longestRide!.descriptor
                : null,
          )
        : null;

    // Hydration keyed to the primary land sport (swim-only gets no drinking
    // plan — the calculator returns zeros for swimming).
    int? fluidMlPerHr;
    int? sodiumMgPerHr;
    if (wantsRun || wantsRide) {
      final hydration = OfflineMacroCalculator.calculateDuringWorkoutHydration(
        durationMin: (wantsRun ? runMinutes : rideMinutes).toDouble(),
        weightKg: weightKg,
        sweatRateCategory: draft.sweatRate.name,
        sweatSodiumCat: 'average',
        sport: wantsRun ? 'running' : 'cycling',
      );
      fluidMlPerHr = hydration.hydrationRateMlph;
      sodiumMgPerHr = hydration.sodiumRateMgph;
    }

    // --- Daily macro tabs ---
    final rmr = DailyBaselineCalculator.calculateRmr(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      isMale: isMale,
    );
    final baseNeat = DailyBaselineCalculator.baseNeatForWeeklyHours(
      reliable ? insights.weeklyDurationHours : null,
    );
    final baseline = DailyBaselineCalculator.baselineMacros(
      weightKg: weightKg,
      age: age,
    );

    // Workout day: baseline + the representative long session's carb demand.
    final sessionSport = wantsRun || !wantsRide ? 'running' : 'cycling';
    final sessionMinutes = sessionSport == 'running' ? runMinutes : rideMinutes;
    final sessionHr = sessionMinutes / 60.0;
    final intensityFactor = DailyBaselineCalculator.zoneDistributionToIf(
      pctConversational: _pctConversational,
      pctTempo: _pctTempo,
      pctAllout: _pctAllout,
    );
    final sessionKcal = DailyBaselineCalculator.sessionCost(
      sport: sessionSport,
      durationHr: sessionHr,
      intensityFactor: intensityFactor,
      weightKg: weightKg,
    );
    final sessionCarb = DailyBaselineCalculator.carbDemand(
      intensityFactor: intensityFactor,
      durationHr: sessionHr,
      weightKg: weightKg,
    );

    final workoutDay = _dayPreview(
      dayType: PreviewDayType.workout,
      carbG: baseline.carbG + sessionCarb,
      protG: baseline.protG,
      weightKg: weightKg,
      rmr: rmr,
      baseNeat: baseNeat,
      dayModifier: DailyBaselineCalculator.trainingDayModifier,
      sessionKcal: sessionKcal,
    );
    final restDay = _dayPreview(
      dayType: PreviewDayType.rest,
      carbG: baseline.carbG,
      protG: baseline.protG,
      weightKg: weightKg,
      rmr: rmr,
      baseNeat: baseNeat,
      dayModifier: DailyBaselineCalculator.restDayModifier,
      sessionKcal: 0,
    );
    final carbLoadDay = _dayPreview(
      dayType: PreviewDayType.carbLoad,
      carbG: math.max(
        baseline.carbG,
        DailyBaselineCalculator.carbLoadGPerKg * weightKg,
      ),
      protG: baseline.protG,
      weightKg: weightKg,
      rmr: rmr,
      baseNeat: baseNeat,
      dayModifier: DailyBaselineCalculator.restDayModifier,
      sessionKcal: 0,
    );

    return OnboardingPlanPreview(
      longRun: longRun,
      longRide: longRide,
      fluidMlPerHr: fluidMlPerHr,
      sodiumMgPerHr: sodiumMgPerHr,
      workoutDay: workoutDay,
      restDay: restDay,
      carbLoadDay: carbLoadDay,
      isGeneric: isGeneric,
      usedTrainingData: reliable,
    );
  }

  static int? _ageFrom(DateTime? birthday, DateTime now) {
    if (birthday == null) return null;
    var age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age;
  }

  static FuelingTargetPreview _fuelingTarget({
    required String sport,
    required int minutes,
    required GutTraining gutTraining,
    String? insightDescriptor,
  }) {
    final result = OfflineMacroCalculator.calculateDuringWorkoutCarbRate(
      durationMin: minutes.toDouble(),
      activityType: sport,
      gutTraining: gutTraining.name,
    );
    return FuelingTargetPreview(
      sport: sport,
      carbGph: result['rate_gph'] as double,
      bandLowGph: result['band_low'] as int,
      bandHighGph: result['band_high'] as int,
      basedOnMinutes: minutes,
      insightDescriptor: insightDescriptor,
    );
  }

  static DayPreview _dayPreview({
    required PreviewDayType dayType,
    required double carbG,
    required double protG,
    required double weightKg,
    required double rmr,
    required double baseNeat,
    required double dayModifier,
    required double sessionKcal,
  }) {
    final clamped = DailyBaselineCalculator.clampMacros(
      carbG: carbG,
      protG: protG,
      weightKg: weightKg,
    );
    final neat = DailyBaselineCalculator.calculateNeat(
      rmr: rmr,
      baseNeat: baseNeat,
      dayModifier: dayModifier,
    );
    final tdee = DailyBaselineCalculator.calculateTdee(
      rmr: rmr,
      neat: neat,
      sessionKcal: sessionKcal,
      carbG: clamped.carbG,
      protG: clamped.protG,
      weightKg: weightKg,
    );

    final carbsG = clamped.carbG.round();
    final proteinG = clamped.protG.round();
    final fatG = tdee.fatG;
    final calories = carbsG * 4 + proteinG * 4 + fatG * 9;

    return DayPreview(
      dayType: dayType,
      carbsG: carbsG,
      proteinG: proteinG,
      fatG: fatG,
      calories: calories,
      carbGPerKg: _round1(clamped.carbG / weightKg),
      proteinGPerKg: _round1(clamped.protG / weightKg),
      fatGPerKg: _round1(fatG / weightKg),
    );
  }

  static double _round1(double v) => (v * 10).round() / 10.0;
}
