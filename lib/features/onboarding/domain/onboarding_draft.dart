import '../../auth/domain/user_preferences.dart';

/// Sports selectable on the onboarding sports step.
///
/// Distinct from [ActivityType]: `triathlon` here is a *training focus*
/// (implies run + bike + swim fueling cards), not a calendar entry type.
enum OnboardingSport {
  running,
  cycling,
  swimming,
  triathlon;

  /// Stable string persisted in `onboarding_surveys.sports`.
  String get dbValue => name;

  static OnboardingSport? fromDbValue(String? value) {
    if (value == null) return null;
    for (final sport in OnboardingSport.values) {
      if (sport.name == value) return sport;
    }
    return null;
  }

  String get displayName {
    switch (this) {
      case OnboardingSport.running:
        return 'Running';
      case OnboardingSport.cycling:
        return 'Cycling';
      case OnboardingSport.swimming:
        return 'Swimming';
      case OnboardingSport.triathlon:
        return 'Triathlon';
    }
  }

  /// Whether this selection implies run fueling (long-run card).
  bool get impliesRunning =>
      this == OnboardingSport.running || this == OnboardingSport.triathlon;

  /// Whether this selection implies bike fueling (long-ride card).
  bool get impliesCycling =>
      this == OnboardingSport.cycling || this == OnboardingSport.triathlon;
}

/// Goals selectable on the onboarding goals step ("What's your goal?").
enum OnboardingGoal {
  performance,
  eatHealthier,
  weightManagement,
  understandEating;

  /// Stable string persisted in `onboarding_surveys.goals`.
  String get dbValue {
    switch (this) {
      case OnboardingGoal.performance:
        return 'performance';
      case OnboardingGoal.eatHealthier:
        return 'eat_healthier';
      case OnboardingGoal.weightManagement:
        return 'weight_management';
      case OnboardingGoal.understandEating:
        return 'understand_eating';
    }
  }

  static OnboardingGoal? fromDbValue(String? value) {
    if (value == null) return null;
    for (final goal in OnboardingGoal.values) {
      if (goal.dbValue == value) return goal;
    }
    return null;
  }

  String get displayName {
    switch (this) {
      case OnboardingGoal.performance:
        return 'Dial in performance nutrition and race a PR';
      case OnboardingGoal.eatHealthier:
        return 'Eat healthier day to day';
      case OnboardingGoal.weightManagement:
        return 'Lose or maintain weight';
      case OnboardingGoal.understandEating:
        return "Understand what I'm eating and why";
    }
  }
}

/// Pain points selectable on the pitfalls step ("What's getting in the way?").
enum OnboardingPitfall {
  energyCrash,
  gutIssues,
  hydrationGuesswork,
  dailyEating,
  noTime,
  weightControl,
  conflictingAdvice,
  fuelingCost;

  /// Stable string persisted in `onboarding_surveys.pitfalls`.
  String get dbValue {
    switch (this) {
      case OnboardingPitfall.energyCrash:
        return 'energy_crash';
      case OnboardingPitfall.gutIssues:
        return 'gut_issues';
      case OnboardingPitfall.hydrationGuesswork:
        return 'hydration_guesswork';
      case OnboardingPitfall.dailyEating:
        return 'daily_eating';
      case OnboardingPitfall.noTime:
        return 'no_time';
      case OnboardingPitfall.weightControl:
        return 'weight_control';
      case OnboardingPitfall.conflictingAdvice:
        return 'conflicting_advice';
      case OnboardingPitfall.fuelingCost:
        return 'fueling_cost';
    }
  }

  static OnboardingPitfall? fromDbValue(String? value) {
    if (value == null) return null;
    for (final pitfall in OnboardingPitfall.values) {
      if (pitfall.dbValue == value) return pitfall;
    }
    return null;
  }

  String get displayName {
    switch (this) {
      case OnboardingPitfall.energyCrash:
        return 'Energy crash on long efforts';
      case OnboardingPitfall.gutIssues:
        return 'Gut issues when I fuel';
      case OnboardingPitfall.hydrationGuesswork:
        return 'Cramping, salt and hydration guesswork';
      case OnboardingPitfall.dailyEating:
        return "I don't know how to eat well day to day";
      case OnboardingPitfall.noTime:
        return 'No time to plan meals';
      case OnboardingPitfall.weightControl:
        return 'Struggling with weight control';
      case OnboardingPitfall.conflictingAdvice:
        return 'Conflicting advice everywhere';
      case OnboardingPitfall.fuelingCost:
        return 'Fueling products can be expensive';
    }
  }
}

/// User edits made on the plan-reveal screen. A null field means the user
/// left that target at the algorithm default (and nothing is persisted for
/// it — see NutritionTargetOverrides' "null = algorithm default" contract).
class OnboardingPlanEdits {
  const OnboardingPlanEdits({
    this.longRunCarbGph,
    this.longRideCarbGph,
    this.fluidMlPerHr,
    this.sodiumMgPerHr,
  });

  final double? longRunCarbGph;
  final double? longRideCarbGph;
  final double? fluidMlPerHr;
  final double? sodiumMgPerHr;

  bool get hasAnyEdit =>
      longRunCarbGph != null ||
      longRideCarbGph != null ||
      fluidMlPerHr != null ||
      sodiumMgPerHr != null;

  OnboardingPlanEdits copyWith({
    double? Function()? longRunCarbGph,
    double? Function()? longRideCarbGph,
    double? Function()? fluidMlPerHr,
    double? Function()? sodiumMgPerHr,
  }) {
    return OnboardingPlanEdits(
      longRunCarbGph: longRunCarbGph != null
          ? longRunCarbGph()
          : this.longRunCarbGph,
      longRideCarbGph: longRideCarbGph != null
          ? longRideCarbGph()
          : this.longRideCarbGph,
      fluidMlPerHr: fluidMlPerHr != null ? fluidMlPerHr() : this.fluidMlPerHr,
      sodiumMgPerHr: sodiumMgPerHr != null
          ? sodiumMgPerHr()
          : this.sodiumMgPerHr,
    );
  }
}

/// Immutable accumulator for everything the onboarding flow collects.
///
/// Replaces the old OnboardingController per-step caches. Screens call the
/// controller's typed mutators, which rebuild this draft via [copyWith];
/// `saveAllOnboardingData` persists it in one batch after auth.
class OnboardingDraft {
  const OnboardingDraft({
    this.sports = const {},
    this.goals = const {},
    this.pitfalls = const {},
    this.firstName,
    this.lastName,
    this.email,
    this.gender,
    this.birthYear,
    this.useMetricUnits = false,
    this.heightFeet,
    this.heightInches,
    this.weightPounds,
    this.gutTraining = GutTraining.moderate,
    this.sweatRate = SweatRateCat.medium,
    this.planEdits = const OnboardingPlanEdits(),
    this.connectedProvider,
    this.declinedTrainingApps = false,
    this.tridotNotifyRequested = false,
    this.sweatTestInterest = false,
  });

  final Set<OnboardingSport> sports;
  final Set<OnboardingGoal> goals;
  final Set<OnboardingPitfall> pitfalls;
  final String? firstName;
  final String? lastName;
  final String? email;
  final Gender? gender;

  /// Year-only birthday. Persisted as `DateTime(birthYear, 7, 1)` — the
  /// documented mid-year convention (age error ≤ 6 months, ~±2.5 kcal RMR).
  final int? birthYear;

  final bool useMetricUnits;

  /// Height/weight stored canonically imperial, matching UserProfile.
  final int? heightFeet;
  final int? heightInches;
  final double? weightPounds;

  final GutTraining gutTraining;
  final SweatRateCat sweatRate;
  final OnboardingPlanEdits planEdits;

  /// Provider id of the platform connected during onboarding, if any.
  final String? connectedProvider;

  /// User tapped "I don't use training plan apps" (distinct from skip).
  final bool declinedTrainingApps;

  final bool tridotNotifyRequested;

  /// User tapped "Personalize with a sweat test" on the plan reveal.
  final bool sweatTestInterest;

  /// Birthday derived from [birthYear] using the mid-year convention.
  DateTime? get birthday =>
      birthYear == null ? null : DateTime(birthYear!, 7, 1);

  double? get weightKg =>
      weightPounds == null ? null : weightPounds! * 0.45359237;

  double? get heightCm => (heightFeet == null && heightInches == null)
      ? null
      : (((heightFeet ?? 0) * 12) + (heightInches ?? 0)) * 2.54;

  bool get wantsRunFueling => sports.any((s) => s.impliesRunning);
  bool get wantsRideFueling => sports.any((s) => s.impliesCycling);

  OnboardingDraft copyWith({
    Set<OnboardingSport>? sports,
    Set<OnboardingGoal>? goals,
    Set<OnboardingPitfall>? pitfalls,
    String? Function()? firstName,
    String? Function()? lastName,
    String? Function()? email,
    Gender? Function()? gender,
    int? Function()? birthYear,
    bool? useMetricUnits,
    int? Function()? heightFeet,
    int? Function()? heightInches,
    double? Function()? weightPounds,
    GutTraining? gutTraining,
    SweatRateCat? sweatRate,
    OnboardingPlanEdits? planEdits,
    String? Function()? connectedProvider,
    bool? declinedTrainingApps,
    bool? tridotNotifyRequested,
    bool? sweatTestInterest,
  }) {
    return OnboardingDraft(
      sports: sports ?? this.sports,
      goals: goals ?? this.goals,
      pitfalls: pitfalls ?? this.pitfalls,
      firstName: firstName != null ? firstName() : this.firstName,
      lastName: lastName != null ? lastName() : this.lastName,
      email: email != null ? email() : this.email,
      gender: gender != null ? gender() : this.gender,
      birthYear: birthYear != null ? birthYear() : this.birthYear,
      useMetricUnits: useMetricUnits ?? this.useMetricUnits,
      heightFeet: heightFeet != null ? heightFeet() : this.heightFeet,
      heightInches: heightInches != null ? heightInches() : this.heightInches,
      weightPounds: weightPounds != null ? weightPounds() : this.weightPounds,
      gutTraining: gutTraining ?? this.gutTraining,
      sweatRate: sweatRate ?? this.sweatRate,
      planEdits: planEdits ?? this.planEdits,
      connectedProvider: connectedProvider != null
          ? connectedProvider()
          : this.connectedProvider,
      declinedTrainingApps: declinedTrainingApps ?? this.declinedTrainingApps,
      tridotNotifyRequested:
          tridotNotifyRequested ?? this.tridotNotifyRequested,
      sweatTestInterest: sweatTestInterest ?? this.sweatTestInterest,
    );
  }
}
