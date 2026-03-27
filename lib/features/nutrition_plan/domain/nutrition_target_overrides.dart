import 'dart:convert';

import '../../../shared/domain/activity_type.dart';

/// User-configured default nutrition target overrides.
/// Null fields mean "use algorithm defaults."
///
/// During-activity overrides are sport-specific: run, bike, and swim use
/// dedicated [DuringActivityOverrides]. The legacy [during] field is kept for
/// backward compatibility and used as a fallback when sport-specific values
/// are absent.
///
/// Note: [duringBrick] is retained only for backward-compatible reads of older
/// saved data and should not be written by new UI flows.
class NutritionTargetOverrides {
  const NutritionTargetOverrides({
    this.pre,
    this.during,
    this.post,
    this.duringRun,
    this.duringCycling,
    this.duringSwimming,
    this.duringBrick,
  });

  final PreActivityOverrides? pre;
  /// Legacy unified during override. Kept for backward compatibility.
  final DuringActivityOverrides? during;
  final PostActivityOverrides? post;

  /// Sport-specific during overrides.
  final DuringActivityOverrides? duringRun;
  final DuringActivityOverrides? duringCycling;
  final DuringActivityOverrides? duringSwimming;
  final DuringActivityOverrides? duringBrick;

  bool get hasAnyOverride =>
      (pre?.hasAnyOverride ?? false) ||
      (during?.hasAnyOverride ?? false) ||
      (post?.hasAnyOverride ?? false) ||
      (duringRun?.hasAnyOverride ?? false) ||
      (duringCycling?.hasAnyOverride ?? false) ||
      (duringSwimming?.hasAnyOverride ?? false) ||
      (duringBrick?.hasAnyOverride ?? false);

  /// Get the during override for a specific sport, falling back to
  /// the legacy [during] field for backward compatibility.
  DuringActivityOverrides? getDuring(ActivityType sport) {
    switch (sport) {
      case ActivityType.running:
        return duringRun ?? during;
      case ActivityType.cycling:
        return duringCycling ?? during;
      case ActivityType.swimming:
        return duringSwimming ?? during;
      case ActivityType.brick:
        // Brick sessions should derive from segment sports (bike/run/swim).
        // For legacy single-value callers, prefer bike/run/swim before
        // falling back to historical brick/unified values.
        return duringCycling ??
            duringRun ??
            duringSwimming ??
            duringBrick ??
            during;
      default:
        return duringRun ?? during;
    }
  }

  /// Return a new instance with the given sport's during override updated.
  NutritionTargetOverrides setDuring(
    ActivityType sport,
    DuringActivityOverrides? value,
  ) {
    switch (sport) {
      case ActivityType.running:
        return copyWith(duringRun: () => value);
      case ActivityType.cycling:
        return copyWith(duringCycling: () => value);
      case ActivityType.swimming:
        return copyWith(duringSwimming: () => value);
      case ActivityType.brick:
        return copyWith(duringBrick: () => value);
      default:
        return copyWith(duringRun: () => value);
    }
  }

  NutritionTargetOverrides copyWith({
    PreActivityOverrides? Function()? pre,
    DuringActivityOverrides? Function()? during,
    PostActivityOverrides? Function()? post,
    DuringActivityOverrides? Function()? duringRun,
    DuringActivityOverrides? Function()? duringCycling,
    DuringActivityOverrides? Function()? duringSwimming,
    DuringActivityOverrides? Function()? duringBrick,
  }) {
    return NutritionTargetOverrides(
      pre: pre != null ? pre() : this.pre,
      during: during != null ? during() : this.during,
      post: post != null ? post() : this.post,
      duringRun: duringRun != null ? duringRun() : this.duringRun,
      duringCycling: duringCycling != null ? duringCycling() : this.duringCycling,
      duringSwimming: duringSwimming != null ? duringSwimming() : this.duringSwimming,
      duringBrick: duringBrick != null ? duringBrick() : this.duringBrick,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (pre != null) 'pre': pre!.toJson(),
      if (during != null) 'during': during!.toJson(),
      if (post != null) 'post': post!.toJson(),
      if (duringRun != null) 'duringRun': duringRun!.toJson(),
      if (duringCycling != null) 'duringCycling': duringCycling!.toJson(),
      if (duringSwimming != null) 'duringSwimming': duringSwimming!.toJson(),
      if (duringBrick != null) 'duringBrick': duringBrick!.toJson(),
    };
  }

  factory NutritionTargetOverrides.fromJson(Map<String, dynamic> json) {
    return NutritionTargetOverrides(
      pre: json['pre'] != null
          ? PreActivityOverrides.fromJson(json['pre'] as Map<String, dynamic>)
          : null,
      during: json['during'] != null
          ? DuringActivityOverrides.fromJson(
              json['during'] as Map<String, dynamic>)
          : null,
      post: json['post'] != null
          ? PostActivityOverrides.fromJson(json['post'] as Map<String, dynamic>)
          : null,
      duringRun: json['duringRun'] != null
          ? DuringActivityOverrides.fromJson(
              json['duringRun'] as Map<String, dynamic>)
          : null,
      duringCycling: json['duringCycling'] != null
          ? DuringActivityOverrides.fromJson(
              json['duringCycling'] as Map<String, dynamic>)
          : null,
      duringSwimming: json['duringSwimming'] != null
          ? DuringActivityOverrides.fromJson(
              json['duringSwimming'] as Map<String, dynamic>)
          : null,
      duringBrick: json['duringBrick'] != null
          ? DuringActivityOverrides.fromJson(
              json['duringBrick'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Parse from a JSON string (for Drift TEXT column).
  static NutritionTargetOverrides? fromJsonString(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return NutritionTargetOverrides.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Serialize to a JSON string (for Drift TEXT column).
  String? toJsonString() {
    if (!hasAnyOverride) return null;
    return jsonEncode(toJson());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NutritionTargetOverrides &&
        other.pre == pre &&
        other.during == during &&
        other.post == post &&
        other.duringRun == duringRun &&
        other.duringCycling == duringCycling &&
        other.duringSwimming == duringSwimming &&
        other.duringBrick == duringBrick;
  }

  @override
  int get hashCode => Object.hash(
        pre, during, post, duringRun, duringCycling, duringSwimming, duringBrick,
      );

  /// Convert to flat map matching the edge function's `NutritionOverrides` interface.
  ///
  /// When [sport] is provided, uses the sport-specific during override
  /// (falling back to legacy [during]) for the during-activity keys.
  Map<String, dynamic> toEdgeFunctionPayload({ActivityType? sport}) {
    final effectiveDuring = sport != null ? getDuring(sport) : during;
    return {
      if (pre?.carbsG != null) 'pre_carbs_g': pre!.carbsG,
      if (pre?.proteinG != null) 'pre_protein_g': pre!.proteinG,
      if (pre?.sodiumMg != null) 'pre_sodium_mg': pre!.sodiumMg,
      if (pre?.fluidMl != null) 'pre_water_ml': pre!.fluidMl,
      if (effectiveDuring?.carbRateGPerH != null)
        'during_carb_rate_g_per_h': effectiveDuring!.carbRateGPerH,
      if (effectiveDuring?.sodiumRateMgPerH != null)
        // Legacy key kept for backward compatibility.
        'during_sodium_mg': effectiveDuring!.sodiumRateMgPerH,
      if (effectiveDuring?.sodiumRateMgPerH != null)
        'during_sodium_rate_mg_per_h': effectiveDuring!.sodiumRateMgPerH,
      if (effectiveDuring?.fluidRateMlPerH != null)
        // Legacy key kept for backward compatibility.
        'during_water_ml': effectiveDuring!.fluidRateMlPerH,
      if (effectiveDuring?.fluidRateMlPerH != null)
        'during_water_rate_ml_per_h': effectiveDuring!.fluidRateMlPerH,
      if (post?.carbsG != null) 'post_carbs_g': post!.carbsG,
      if (post?.proteinG != null) 'post_protein_g': post!.proteinG,
      if (post?.sodiumMg != null) 'post_sodium_mg': post!.sodiumMg,
      if (post?.fluidMl != null) 'post_water_ml': post!.fluidMl,
    };
  }

  @override
  String toString() =>
      'NutritionTargetOverrides(pre: $pre, during: $during, post: $post, '
      'duringRun: $duringRun, duringCycling: $duringCycling, '
      'duringSwimming: $duringSwimming, duringBrick: $duringBrick)';
}

/// Pre-activity override targets.
class PreActivityOverrides {
  const PreActivityOverrides({
    this.carbsG,
    this.proteinG,
    this.fatG,
    this.sodiumMg,
    this.fluidMl,
  });

  final double? carbsG;
  final double? proteinG;
  final double? fatG;
  final double? sodiumMg;
  final double? fluidMl;

  bool get hasAnyOverride =>
      carbsG != null ||
      proteinG != null ||
      fatG != null ||
      sodiumMg != null ||
      fluidMl != null;

  PreActivityOverrides copyWith({
    double? Function()? carbsG,
    double? Function()? proteinG,
    double? Function()? fatG,
    double? Function()? sodiumMg,
    double? Function()? fluidMl,
  }) {
    return PreActivityOverrides(
      carbsG: carbsG != null ? carbsG() : this.carbsG,
      proteinG: proteinG != null ? proteinG() : this.proteinG,
      fatG: fatG != null ? fatG() : this.fatG,
      sodiumMg: sodiumMg != null ? sodiumMg() : this.sodiumMg,
      fluidMl: fluidMl != null ? fluidMl() : this.fluidMl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (carbsG != null) 'carbsG': carbsG,
      if (proteinG != null) 'proteinG': proteinG,
      if (fatG != null) 'fatG': fatG,
      if (sodiumMg != null) 'sodiumMg': sodiumMg,
      if (fluidMl != null) 'fluidMl': fluidMl,
    };
  }

  factory PreActivityOverrides.fromJson(Map<String, dynamic> json) {
    return PreActivityOverrides(
      carbsG: (json['carbsG'] as num?)?.toDouble(),
      proteinG: (json['proteinG'] as num?)?.toDouble(),
      fatG: (json['fatG'] as num?)?.toDouble(),
      sodiumMg: (json['sodiumMg'] as num?)?.toDouble(),
      fluidMl: (json['fluidMl'] as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PreActivityOverrides &&
        other.carbsG == carbsG &&
        other.proteinG == proteinG &&
        other.fatG == fatG &&
        other.sodiumMg == sodiumMg &&
        other.fluidMl == fluidMl;
  }

  @override
  int get hashCode => Object.hash(carbsG, proteinG, fatG, sodiumMg, fluidMl);

  @override
  String toString() =>
      'PreActivityOverrides(carbsG: $carbsG, proteinG: $proteinG, fatG: $fatG, sodiumMg: $sodiumMg, fluidMl: $fluidMl)';
}

/// During-activity override targets (per-hour rates).
class DuringActivityOverrides {
  const DuringActivityOverrides({
    this.carbRateGPerH,
    this.sodiumRateMgPerH,
    this.fluidRateMlPerH,
  });

  final double? carbRateGPerH;
  final double? sodiumRateMgPerH;
  final double? fluidRateMlPerH;

  bool get hasAnyOverride =>
      carbRateGPerH != null ||
      sodiumRateMgPerH != null ||
      fluidRateMlPerH != null;

  DuringActivityOverrides copyWith({
    double? Function()? carbRateGPerH,
    double? Function()? sodiumRateMgPerH,
    double? Function()? fluidRateMlPerH,
  }) {
    return DuringActivityOverrides(
      carbRateGPerH:
          carbRateGPerH != null ? carbRateGPerH() : this.carbRateGPerH,
      sodiumRateMgPerH:
          sodiumRateMgPerH != null ? sodiumRateMgPerH() : this.sodiumRateMgPerH,
      fluidRateMlPerH:
          fluidRateMlPerH != null ? fluidRateMlPerH() : this.fluidRateMlPerH,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (carbRateGPerH != null) 'carbRateGPerH': carbRateGPerH,
      if (sodiumRateMgPerH != null) 'sodiumRateMgPerH': sodiumRateMgPerH,
      if (fluidRateMlPerH != null) 'fluidRateMlPerH': fluidRateMlPerH,
    };
  }

  factory DuringActivityOverrides.fromJson(Map<String, dynamic> json) {
    return DuringActivityOverrides(
      carbRateGPerH: (json['carbRateGPerH'] as num?)?.toDouble(),
      sodiumRateMgPerH: (json['sodiumRateMgPerH'] as num?)?.toDouble(),
      fluidRateMlPerH: (json['fluidRateMlPerH'] as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DuringActivityOverrides &&
        other.carbRateGPerH == carbRateGPerH &&
        other.sodiumRateMgPerH == sodiumRateMgPerH &&
        other.fluidRateMlPerH == fluidRateMlPerH;
  }

  @override
  int get hashCode =>
      Object.hash(carbRateGPerH, sodiumRateMgPerH, fluidRateMlPerH);

  @override
  String toString() =>
      'DuringActivityOverrides(carbRateGPerH: $carbRateGPerH, sodiumRateMgPerH: $sodiumRateMgPerH, fluidRateMlPerH: $fluidRateMlPerH)';
}

/// Post-activity override targets.
class PostActivityOverrides {
  const PostActivityOverrides({
    this.carbsG,
    this.proteinG,
    this.sodiumMg,
    this.fluidMl,
  });

  final double? carbsG;
  final double? proteinG;
  final double? sodiumMg;
  final double? fluidMl;

  bool get hasAnyOverride =>
      carbsG != null ||
      proteinG != null ||
      sodiumMg != null ||
      fluidMl != null;

  PostActivityOverrides copyWith({
    double? Function()? carbsG,
    double? Function()? proteinG,
    double? Function()? sodiumMg,
    double? Function()? fluidMl,
  }) {
    return PostActivityOverrides(
      carbsG: carbsG != null ? carbsG() : this.carbsG,
      proteinG: proteinG != null ? proteinG() : this.proteinG,
      sodiumMg: sodiumMg != null ? sodiumMg() : this.sodiumMg,
      fluidMl: fluidMl != null ? fluidMl() : this.fluidMl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (carbsG != null) 'carbsG': carbsG,
      if (proteinG != null) 'proteinG': proteinG,
      if (sodiumMg != null) 'sodiumMg': sodiumMg,
      if (fluidMl != null) 'fluidMl': fluidMl,
    };
  }

  factory PostActivityOverrides.fromJson(Map<String, dynamic> json) {
    return PostActivityOverrides(
      carbsG: (json['carbsG'] as num?)?.toDouble(),
      proteinG: (json['proteinG'] as num?)?.toDouble(),
      sodiumMg: (json['sodiumMg'] as num?)?.toDouble(),
      fluidMl: (json['fluidMl'] as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PostActivityOverrides &&
        other.carbsG == carbsG &&
        other.proteinG == proteinG &&
        other.sodiumMg == sodiumMg &&
        other.fluidMl == fluidMl;
  }

  @override
  int get hashCode => Object.hash(carbsG, proteinG, sodiumMg, fluidMl);

  @override
  String toString() =>
      'PostActivityOverrides(carbsG: $carbsG, proteinG: $proteinG, sodiumMg: $sodiumMg, fluidMl: $fluidMl)';
}

/// Safety guardrails for nutrition target overrides.
class NutritionTargetGuardrails {
  // Pre-activity ranges
  static const double preMinCarbsG = 0;
  static const double preMaxCarbsG = 500;
  static const double preMinProteinG = 0;
  static const double preMaxProteinG = 100;
  static const double preMinFatG = 0;
  static const double preMaxFatG = 100;
  static const double preMinSodiumMg = 0;
  static const double preMaxSodiumMg = 3000;
  static const double preMinFluidMl = 0;
  static const double preMaxFluidMl = 2000;

  // During-activity ranges (per hour) - general
  static const double duringMinCarbRateGPerH = 0;
  static const double duringMaxCarbRateGPerH = 120;
  static const double duringMinSodiumRateMgPerH = 0;
  static const double duringMaxSodiumRateMgPerH = 2000;
  static const double duringMinFluidRateMlPerH = 200;
  static const double duringMaxFluidRateMlPerH = 3000;

  // Sport-specific carb rate ceilings for UI validation
  static const double duringMaxCarbRateRunning = 70;
  static const double duringMaxCarbRateCycling = 120;
  static const double duringMaxCarbRateSwimming = 0; // can't eat while swimming
  static const double duringMaxCarbRateBrick = 120;

  // Post-activity ranges
  static const double postMinCarbsG = 0;
  static const double postMaxCarbsG = 500;
  static const double postMinProteinG = 0;
  static const double postMaxProteinG = 100;
  static const double postMinSodiumMg = 0;
  static const double postMaxSodiumMg = 2000;
  static const double postMinFluidMl = 0;
  static const double postMaxFluidMl = 3000;

  /// Clamp a value to guardrail range. Returns null if input is null.
  static double? clamp(double? value, double min, double max) {
    if (value == null) return null;
    return value.clamp(min, max);
  }

  /// Clamp a single DuringActivityOverrides to guardrail ranges.
  static DuringActivityOverrides? _clampDuring(DuringActivityOverrides? d) {
    if (d == null) return null;
    return DuringActivityOverrides(
      carbRateGPerH: clamp(
          d.carbRateGPerH, duringMinCarbRateGPerH, duringMaxCarbRateGPerH),
      sodiumRateMgPerH: clamp(d.sodiumRateMgPerH, duringMinSodiumRateMgPerH,
          duringMaxSodiumRateMgPerH),
      fluidRateMlPerH: clamp(
          d.fluidRateMlPerH, duringMinFluidRateMlPerH, duringMaxFluidRateMlPerH),
    );
  }

  /// Clamp all overrides to their guardrail ranges.
  static NutritionTargetOverrides clampAll(NutritionTargetOverrides overrides) {
    return NutritionTargetOverrides(
      pre: overrides.pre != null
          ? PreActivityOverrides(
              carbsG: clamp(overrides.pre!.carbsG, preMinCarbsG, preMaxCarbsG),
              proteinG: clamp(
                  overrides.pre!.proteinG, preMinProteinG, preMaxProteinG),
              fatG: clamp(overrides.pre!.fatG, preMinFatG, preMaxFatG),
              sodiumMg: clamp(
                  overrides.pre!.sodiumMg, preMinSodiumMg, preMaxSodiumMg),
              fluidMl: clamp(
                  overrides.pre!.fluidMl, preMinFluidMl, preMaxFluidMl),
            )
          : null,
      during: _clampDuring(overrides.during),
      duringRun: _clampDuring(overrides.duringRun),
      duringCycling: _clampDuring(overrides.duringCycling),
      duringSwimming: _clampDuring(overrides.duringSwimming),
      duringBrick: _clampDuring(overrides.duringBrick),
      post: overrides.post != null
          ? PostActivityOverrides(
              carbsG:
                  clamp(overrides.post!.carbsG, postMinCarbsG, postMaxCarbsG),
              proteinG: clamp(
                  overrides.post!.proteinG, postMinProteinG, postMaxProteinG),
              sodiumMg: clamp(
                  overrides.post!.sodiumMg, postMinSodiumMg, postMaxSodiumMg),
              fluidMl: clamp(
                  overrides.post!.fluidMl, postMinFluidMl, postMaxFluidMl),
            )
          : null,
    );
  }
}
