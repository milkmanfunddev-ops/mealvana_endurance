/// Value objects produced by PlanPreviewService for the plan-reveal and
/// daily-plan-preview screens. Copy-free: screens compose user-facing text
/// (via the content system) from this structured data.
library;

/// During-workout fueling target for one sport card on the plan reveal.
class FuelingTargetPreview {
  const FuelingTargetPreview({
    required this.sport,
    required this.carbGph,
    required this.bandLowGph,
    required this.bandHighGph,
    required this.basedOnMinutes,
    this.insightDescriptor,
  });

  /// 'running' or 'cycling' (edge-function sport strings).
  final String sport;

  final double carbGph;
  final int bandLowGph;
  final int bandHighGph;

  /// The representative session duration this target was computed at —
  /// the athlete's actual longest session when insights are reliable,
  /// otherwise the generic constant.
  final int basedOnMinutes;

  /// e.g. "your 15-mile long run" when derived from imported training data;
  /// null when generic.
  final String? insightDescriptor;
}

enum PreviewDayType { workout, rest, carbLoad }

/// One tab of the daily-plan preview (Workout / Rest / Carb load).
class DayPreview {
  const DayPreview({
    required this.dayType,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    required this.calories,
    required this.carbGPerKg,
    required this.proteinGPerKg,
    required this.fatGPerKg,
  });

  final PreviewDayType dayType;
  final int carbsG;
  final int proteinG;
  final int fatG;

  /// Intake calories (4/4/9 arithmetic over the macros shown).
  final int calories;

  final double carbGPerKg;
  final double proteinGPerKg;
  final double fatGPerKg;
}

/// Everything the plan-reveal + daily-preview screens render.
class OnboardingPlanPreview {
  const OnboardingPlanPreview({
    this.longRun,
    this.longRide,
    this.fluidMlPerHr,
    this.sodiumMgPerHr,
    required this.workoutDay,
    required this.restDay,
    required this.carbLoadDay,
    required this.isGeneric,
    required this.usedTrainingData,
  });

  /// Null when the athlete's sports don't imply that card
  /// (e.g. swim-only selections get neither).
  final FuelingTargetPreview? longRun;
  final FuelingTargetPreview? longRide;

  /// Null for swim-only selections (no in-water drinking plan).
  final int? fluidMlPerHr;
  final int? sodiumMgPerHr;

  final DayPreview workoutDay;
  final DayPreview restDay;
  final DayPreview carbLoadDay;

  /// True when biometrics were defaulted (skip / Runna-no-biometrics paths) —
  /// UI shows the "estimates — add your details for accuracy" caption.
  final bool isGeneric;

  /// True when reliable imported training data personalized the targets.
  final bool usedTrainingData;
}
