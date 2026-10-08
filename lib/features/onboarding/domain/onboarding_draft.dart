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

  /// Stored with a pending signup (ticket 42) so a relaunch on Verify your
  /// email keeps the edits.
  Map<String, dynamic> toJson() => {
    'long_run_carb_gph': longRunCarbGph,
    'long_ride_carb_gph': longRideCarbGph,
    'fluid_ml_per_hr': fluidMlPerHr,
    'sodium_mg_per_hr': sodiumMgPerHr,
  };

  /// The edits [json] holds; a missing or non-numeric field is left at the
  /// algorithm default. Never throws.
  factory OnboardingPlanEdits.fromJson(Object? json) {
    if (json is! Map) return const OnboardingPlanEdits();
    double? number(String key) {
      final value = json[key];
      return value is num ? value.toDouble() : null;
    }

    return OnboardingPlanEdits(
      longRunCarbGph: number('long_run_carb_gph'),
      longRideCarbGph: number('long_ride_carb_gph'),
      fluidMlPerHr: number('fluid_ml_per_hr'),
      sodiumMgPerHr: number('sodium_mg_per_hr'),
    );
  }

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

  /// Stored with a pending signup (testing-wave develop-2026-10 ticket 42,
  /// 30-007), so a relaunch on Verify your email restores the answers. Sets
  /// are `dbValue` lists, as the onboarding snapshot stores them; enums by
  /// `name`.
  Map<String, dynamic> toJson() => {
    'version': 1,
    'sports': [for (final s in sports) s.dbValue],
    'goals': [for (final g in goals) g.dbValue],
    'pitfalls': [for (final p in pitfalls) p.dbValue],
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'gender': gender?.name,
    'birth_year': birthYear,
    'use_metric_units': useMetricUnits,
    'height_feet': heightFeet,
    'height_inches': heightInches,
    'weight_pounds': weightPounds,
    'gut_training': gutTraining.name,
    'sweat_rate': sweatRate.name,
    'plan_edits': planEdits.toJson(),
    'connected_provider': connectedProvider,
    'declined_training_apps': declinedTrainingApps,
    'tridot_notify_requested': tridotNotifyRequested,
    'sweat_test_interest': sweatTestInterest,
  };

  /// The draft [json] holds. Never throws: an unknown enum value or a
  /// wrongly typed field is dropped and the field keeps its default, so a
  /// record written by another build still restores what it can.
  factory OnboardingDraft.fromJson(Object? json) {
    if (json is! Map) return const OnboardingDraft();
    String? text(String key) {
      final value = json[key];
      return value is String ? value : null;
    }

    int? whole(String key) {
      final value = json[key];
      return value is num ? value.toInt() : null;
    }

    bool flag(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    Set<T> setOf<T>(String key, T? Function(String?) parse) {
      final value = json[key];
      if (value is! List) return const {};
      return Set.unmodifiable({
        for (final item in value)
          if (item is String && parse(item) != null) parse(item) as T,
      });
    }

    T? byName<T extends Enum>(List<T> values, String key) {
      final name = text(key);
      for (final value in values) {
        if (value.name == name) return value;
      }
      return null;
    }

    final weight = json['weight_pounds'];
    return OnboardingDraft(
      sports: setOf('sports', OnboardingSport.fromDbValue),
      goals: setOf('goals', OnboardingGoal.fromDbValue),
      pitfalls: setOf('pitfalls', OnboardingPitfall.fromDbValue),
      firstName: text('first_name'),
      lastName: text('last_name'),
      email: text('email'),
      gender: byName(Gender.values, 'gender'),
      birthYear: whole('birth_year'),
      useMetricUnits: flag('use_metric_units', false),
      heightFeet: whole('height_feet'),
      heightInches: whole('height_inches'),
      weightPounds: weight is num ? weight.toDouble() : null,
      gutTraining:
          byName(GutTraining.values, 'gut_training') ?? GutTraining.moderate,
      sweatRate:
          byName(SweatRateCat.values, 'sweat_rate') ?? SweatRateCat.medium,
      planEdits: OnboardingPlanEdits.fromJson(json['plan_edits']),
      connectedProvider: text('connected_provider'),
      declinedTrainingApps: flag('declined_training_apps', false),
      tridotNotifyRequested: flag('tridot_notify_requested', false),
      sweatTestInterest: flag('sweat_test_interest', false),
    );
  }

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
      // Defensive copies: the selection screens pass their live _selected
      // sets and keep mutating them in place, which would otherwise alias
      // every "immutable" draft snapshot to the screen's mutable state.
      sports: sports != null ? Set.unmodifiable(sports) : this.sports,
      goals: goals != null ? Set.unmodifiable(goals) : this.goals,
      pitfalls: pitfalls != null ? Set.unmodifiable(pitfalls) : this.pitfalls,
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
