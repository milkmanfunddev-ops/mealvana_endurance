import '../../../shared/domain/activity_type.dart';

/// Complete macro targets for a running session
class MacroTargets {
  const MacroTargets({
    required this.id,
    required this.activityType,
    required this.preRun,
    required this.duringRun,
    required this.postRun,
    required this.metrics,
    required this.calculationRule,
    required this.timestamp,
    required this.isUserModified,
    this.modifiedFields = const [],
  });

  final String id;
  final ActivityType activityType;
  final PreRunMacros preRun;
  final DuringRunMacros duringRun;
  final PostRunMacros postRun;
  final RunMetrics metrics;
  final String calculationRule;
  final DateTime timestamp;
  final bool isUserModified;
  final List<String> modifiedFields;

  MacroTargets copyWith({
    String? id,
    ActivityType? activityType,
    PreRunMacros? preRun,
    DuringRunMacros? duringRun,
    PostRunMacros? postRun,
    RunMetrics? metrics,
    String? calculationRule,
    DateTime? timestamp,
    bool? isUserModified,
    List<String>? modifiedFields,
  }) {
    return MacroTargets(
      id: id ?? this.id,
      activityType: activityType ?? this.activityType,
      preRun: preRun ?? this.preRun,
      duringRun: duringRun ?? this.duringRun,
      postRun: postRun ?? this.postRun,
      metrics: metrics ?? this.metrics,
      calculationRule: calculationRule ?? this.calculationRule,
      timestamp: timestamp ?? this.timestamp,
      isUserModified: isUserModified ?? this.isUserModified,
      modifiedFields: modifiedFields ?? this.modifiedFields,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activityType': activityType.name,
      'preRun': preRun.toJson(),
      'duringRun': duringRun.toJson(),
      'postRun': postRun.toJson(),
      'metrics': metrics.toJson(),
      'calculationRule': calculationRule,
      'timestamp': timestamp.toIso8601String(),
      'isUserModified': isUserModified,
      'modifiedFields': modifiedFields,
    };
  }

  factory MacroTargets.fromJson(Map<String, dynamic> json) {
    return MacroTargets(
      id: json['id'] as String,
      activityType: ActivityType.values.byName(json['activityType'] as String? ?? 'running'),
      preRun: PreRunMacros.fromJson(json['preRun'] as Map<String, dynamic>),
      duringRun: DuringRunMacros.fromJson(json['duringRun'] as Map<String, dynamic>),
      postRun: PostRunMacros.fromJson(json['postRun'] as Map<String, dynamic>),
      metrics: RunMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
      calculationRule: json['calculationRule'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isUserModified: json['isUserModified'] as bool,
      modifiedFields: List<String>.from(json['modifiedFields'] as List? ?? []),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MacroTargets &&
        other.id == id &&
        other.activityType == activityType &&
        other.preRun == preRun &&
        other.duringRun == duringRun &&
        other.postRun == postRun &&
        other.metrics == metrics &&
        other.calculationRule == calculationRule &&
        other.timestamp == timestamp &&
        other.isUserModified == isUserModified &&
        _listEquals(other.modifiedFields, modifiedFields);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      activityType,
      preRun,
      duringRun,
      postRun,
      metrics,
      calculationRule,
      timestamp,
      isUserModified,
      Object.hashAll(modifiedFields),
    );
  }

  @override
  String toString() {
    return 'MacroTargets(id: $id, activityType: $activityType, preRun: $preRun, duringRun: $duringRun, postRun: $postRun, metrics: $metrics, calculationRule: $calculationRule, timestamp: $timestamp, isUserModified: $isUserModified, modifiedFields: $modifiedFields)';
  }
}

/// Pre-run nutrition targets (1-4 hours before)
class PreRunMacros {
  const PreRunMacros({
    required this.carbsG,
    required this.proteinG,
    required this.fatCapG,
    required this.fluidsMl,
    required this.sodiumMg,
  });

  final double carbsG;
  final double proteinG;
  final double fatCapG;
  final double fluidsMl;
  final double sodiumMg;

  /// Convert fluids to US units (fl oz)
  double get fluidsFlOz => fluidsMl * 0.033814;

  PreRunMacros copyWith({
    double? carbsG,
    double? proteinG,
    double? fatCapG,
    double? fluidsMl,
    double? sodiumMg,
  }) {
    return PreRunMacros(
      carbsG: carbsG ?? this.carbsG,
      proteinG: proteinG ?? this.proteinG,
      fatCapG: fatCapG ?? this.fatCapG,
      fluidsMl: fluidsMl ?? this.fluidsMl,
      sodiumMg: sodiumMg ?? this.sodiumMg,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'carbsG': carbsG,
      'proteinG': proteinG,
      'fatCapG': fatCapG,
      'fluidsMl': fluidsMl,
      'sodiumMg': sodiumMg,
    };
  }

  factory PreRunMacros.fromJson(Map<String, dynamic> json) {
    return PreRunMacros(
      carbsG: (json['carbsG'] as num).toDouble(),
      proteinG: (json['proteinG'] as num).toDouble(),
      fatCapG: (json['fatCapG'] as num).toDouble(),
      fluidsMl: (json['fluidsMl'] as num).toDouble(),
      sodiumMg: (json['sodiumMg'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PreRunMacros &&
        other.carbsG == carbsG &&
        other.proteinG == proteinG &&
        other.fatCapG == fatCapG &&
        other.fluidsMl == fluidsMl &&
        other.sodiumMg == sodiumMg;
  }

  @override
  int get hashCode {
    return Object.hash(carbsG, proteinG, fatCapG, fluidsMl, sodiumMg);
  }

  @override
  String toString() {
    return 'PreRunMacros(carbsG: $carbsG, proteinG: $proteinG, fatCapG: $fatCapG, fluidsMl: $fluidsMl, sodiumMg: $sodiumMg)';
  }
}

/// During-run nutrition targets
class DuringRunMacros {
  const DuringRunMacros({
    required this.carbRateGPerH,
    required this.carbTotalG,
    required this.fluidRateMlPerH,
    required this.fluidTotalMl,
    required this.sodiumRateMgPerH,
    required this.sodiumTotalMg,
    required this.massNormRateGPerH,
    this.absClampRangeGPerH = const [30, 60],
  });

  final double carbRateGPerH;
  final double carbTotalG;
  final double fluidRateMlPerH;
  final double fluidTotalMl;
  final double sodiumRateMgPerH;
  final double sodiumTotalMg;
  final double massNormRateGPerH;
  final List<double> absClampRangeGPerH;

  /// Convert fluids to US units (fl oz)
  double get fluidRateFlOzPerH => fluidRateMlPerH * 0.033814;
  double get fluidTotalFlOz => fluidTotalMl * 0.033814;

  /// Create updated instance with new total carbs, recalculating rate
  DuringRunMacros withUpdatedTotalCarbs(double newTotalG, double durationH) {
    final newRate = durationH > 0 ? newTotalG / durationH : carbRateGPerH;
    return copyWith(
      carbTotalG: newTotalG,
      carbRateGPerH: newRate,
    );
  }

  /// Create updated instance with new carb rate, recalculating total
  DuringRunMacros withUpdatedRateCarbs(double newRateGPerH, double durationH) {
    final newTotal = newRateGPerH * durationH;
    return copyWith(
      carbRateGPerH: newRateGPerH,
      carbTotalG: newTotal,
    );
  }

  /// Create updated instance with new total fluids, recalculating rate
  DuringRunMacros withUpdatedTotalFluids(double newTotalMl, double durationH) {
    final newRate = durationH > 0 ? newTotalMl / durationH : fluidRateMlPerH;
    return copyWith(
      fluidTotalMl: newTotalMl,
      fluidRateMlPerH: newRate,
    );
  }

  /// Create updated instance with new total sodium, recalculating rate
  DuringRunMacros withUpdatedTotalSodium(double newTotalMg, double durationH) {
    final newRate = durationH > 0 ? newTotalMg / durationH : sodiumRateMgPerH;
    return copyWith(
      sodiumTotalMg: newTotalMg,
      sodiumRateMgPerH: newRate,
    );
  }

  DuringRunMacros copyWith({
    double? carbRateGPerH,
    double? carbTotalG,
    double? fluidRateMlPerH,
    double? fluidTotalMl,
    double? sodiumRateMgPerH,
    double? sodiumTotalMg,
    double? massNormRateGPerH,
    List<double>? absClampRangeGPerH,
  }) {
    return DuringRunMacros(
      carbRateGPerH: carbRateGPerH ?? this.carbRateGPerH,
      carbTotalG: carbTotalG ?? this.carbTotalG,
      fluidRateMlPerH: fluidRateMlPerH ?? this.fluidRateMlPerH,
      fluidTotalMl: fluidTotalMl ?? this.fluidTotalMl,
      sodiumRateMgPerH: sodiumRateMgPerH ?? this.sodiumRateMgPerH,
      sodiumTotalMg: sodiumTotalMg ?? this.sodiumTotalMg,
      massNormRateGPerH: massNormRateGPerH ?? this.massNormRateGPerH,
      absClampRangeGPerH: absClampRangeGPerH ?? this.absClampRangeGPerH,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'carbRateGPerH': carbRateGPerH,
      'carbTotalG': carbTotalG,
      'fluidRateMlPerH': fluidRateMlPerH,
      'fluidTotalMl': fluidTotalMl,
      'sodiumRateMgPerH': sodiumRateMgPerH,
      'sodiumTotalMg': sodiumTotalMg,
      'massNormRateGPerH': massNormRateGPerH,
      'absClampRangeGPerH': absClampRangeGPerH,
    };
  }

  factory DuringRunMacros.fromJson(Map<String, dynamic> json) {
    return DuringRunMacros(
      carbRateGPerH: (json['carbRateGPerH'] as num).toDouble(),
      carbTotalG: (json['carbTotalG'] as num).toDouble(),
      fluidRateMlPerH: (json['fluidRateMlPerH'] as num).toDouble(),
      fluidTotalMl: (json['fluidTotalMl'] as num).toDouble(),
      sodiumRateMgPerH: (json['sodiumRateMgPerH'] as num).toDouble(),
      sodiumTotalMg: (json['sodiumTotalMg'] as num).toDouble(),
      massNormRateGPerH: (json['massNormRateGPerH'] as num).toDouble(),
      absClampRangeGPerH: List<double>.from(json['absClampRangeGPerH'] as List? ?? [30, 60]),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DuringRunMacros &&
        other.carbRateGPerH == carbRateGPerH &&
        other.carbTotalG == carbTotalG &&
        other.fluidRateMlPerH == fluidRateMlPerH &&
        other.fluidTotalMl == fluidTotalMl &&
        other.sodiumRateMgPerH == sodiumRateMgPerH &&
        other.sodiumTotalMg == sodiumTotalMg &&
        other.massNormRateGPerH == massNormRateGPerH &&
        _listEquals(other.absClampRangeGPerH, absClampRangeGPerH);
  }

  @override
  int get hashCode {
    return Object.hash(
      carbRateGPerH,
      carbTotalG,
      fluidRateMlPerH,
      fluidTotalMl,
      sodiumRateMgPerH,
      sodiumTotalMg,
      massNormRateGPerH,
      Object.hashAll(absClampRangeGPerH),
    );
  }

  @override
  String toString() {
    return 'DuringRunMacros(carbRateGPerH: $carbRateGPerH, carbTotalG: $carbTotalG, fluidRateMlPerH: $fluidRateMlPerH, fluidTotalMl: $fluidTotalMl, sodiumRateMgPerH: $sodiumRateMgPerH, sodiumTotalMg: $sodiumTotalMg, massNormRateGPerH: $massNormRateGPerH, absClampRangeGPerH: $absClampRangeGPerH)';
  }
}

/// Post-run nutrition targets (within 30 minutes)
class PostRunMacros {
  const PostRunMacros({
    required this.carbsG,
    required this.proteinG,
    required this.fluidsMl,
    required this.sodiumMg,
  });

  final double carbsG;
  final double proteinG;
  final double fluidsMl;
  final double sodiumMg;

  /// Convert fluids to US units (fl oz)
  double get fluidsFlOz => fluidsMl * 0.033814;

  PostRunMacros copyWith({
    double? carbsG,
    double? proteinG,
    double? fluidsMl,
    double? sodiumMg,
  }) {
    return PostRunMacros(
      carbsG: carbsG ?? this.carbsG,
      proteinG: proteinG ?? this.proteinG,
      fluidsMl: fluidsMl ?? this.fluidsMl,
      sodiumMg: sodiumMg ?? this.sodiumMg,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'carbsG': carbsG,
      'proteinG': proteinG,
      'fluidsMl': fluidsMl,
      'sodiumMg': sodiumMg,
    };
  }

  factory PostRunMacros.fromJson(Map<String, dynamic> json) {
    return PostRunMacros(
      carbsG: (json['carbsG'] as num).toDouble(),
      proteinG: (json['proteinG'] as num).toDouble(),
      fluidsMl: (json['fluidsMl'] as num).toDouble(),
      sodiumMg: (json['sodiumMg'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PostRunMacros &&
        other.carbsG == carbsG &&
        other.proteinG == proteinG &&
        other.fluidsMl == fluidsMl &&
        other.sodiumMg == sodiumMg;
  }

  @override
  int get hashCode {
    return Object.hash(carbsG, proteinG, fluidsMl, sodiumMg);
  }

  @override
  String toString() {
    return 'PostRunMacros(carbsG: $carbsG, proteinG: $proteinG, fluidsMl: $fluidsMl, sodiumMg: $sodiumMg)';
  }
}

/// Run performance metrics and calculations
class RunMetrics {
  const RunMetrics({
    required this.distanceMi,
    required this.distanceKm,
    required this.durationH,
    required this.durationMin,
    this.paceMinPerMile,
    required this.speedMph,
    required this.caloriesGrossKcal,
    required this.caloriesNetKcal,
    required this.met,
  });

  final double distanceMi;
  final double distanceKm;
  final double durationH;
  final double durationMin;
  final double? paceMinPerMile;
  final double speedMph;
  final double caloriesGrossKcal;
  final double caloriesNetKcal;
  final double met;

  /// Format duration as HH:MM
  String get formattedDuration {
    final hours = durationH.floor();
    final minutes = ((durationH - hours) * 60).round();
    return '$hours:${minutes.toString().padLeft(2, '0')}';
  }

  /// Format pace as MM:SS per mile
  String get formattedPace {
    if (paceMinPerMile == null) return 'N/A';
    final minutes = paceMinPerMile!.floor();
    final seconds = ((paceMinPerMile! - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  RunMetrics copyWith({
    double? distanceMi,
    double? distanceKm,
    double? durationH,
    double? durationMin,
    double? paceMinPerMile,
    double? speedMph,
    double? caloriesGrossKcal,
    double? caloriesNetKcal,
    double? met,
  }) {
    return RunMetrics(
      distanceMi: distanceMi ?? this.distanceMi,
      distanceKm: distanceKm ?? this.distanceKm,
      durationH: durationH ?? this.durationH,
      durationMin: durationMin ?? this.durationMin,
      paceMinPerMile: paceMinPerMile ?? this.paceMinPerMile,
      speedMph: speedMph ?? this.speedMph,
      caloriesGrossKcal: caloriesGrossKcal ?? this.caloriesGrossKcal,
      caloriesNetKcal: caloriesNetKcal ?? this.caloriesNetKcal,
      met: met ?? this.met,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distanceMi': distanceMi,
      'distanceKm': distanceKm,
      'durationH': durationH,
      'durationMin': durationMin,
      'paceMinPerMile': paceMinPerMile,
      'speedMph': speedMph,
      'caloriesGrossKcal': caloriesGrossKcal,
      'caloriesNetKcal': caloriesNetKcal,
      'met': met,
    };
  }

  factory RunMetrics.fromJson(Map<String, dynamic> json) {
    return RunMetrics(
      distanceMi: (json['distanceMi'] as num).toDouble(),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      durationH: (json['durationH'] as num).toDouble(),
      durationMin: (json['durationMin'] as num).toDouble(),
      paceMinPerMile: json['paceMinPerMile'] != null ? (json['paceMinPerMile'] as num).toDouble() : null,
      speedMph: (json['speedMph'] as num).toDouble(),
      caloriesGrossKcal: (json['caloriesGrossKcal'] as num).toDouble(),
      caloriesNetKcal: (json['caloriesNetKcal'] as num).toDouble(),
      met: (json['met'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RunMetrics &&
        other.distanceMi == distanceMi &&
        other.distanceKm == distanceKm &&
        other.durationH == durationH &&
        other.durationMin == durationMin &&
        other.paceMinPerMile == paceMinPerMile &&
        other.speedMph == speedMph &&
        other.caloriesGrossKcal == caloriesGrossKcal &&
        other.caloriesNetKcal == caloriesNetKcal &&
        other.met == met;
  }

  @override
  int get hashCode {
    return Object.hash(
      distanceMi,
      distanceKm,
      durationH,
      durationMin,
      paceMinPerMile,
      speedMph,
      caloriesGrossKcal,
      caloriesNetKcal,
      met,
    );
  }

  @override
  String toString() {
    return 'RunMetrics(distanceMi: $distanceMi, distanceKm: $distanceKm, durationH: $durationH, durationMin: $durationMin, paceMinPerMile: $paceMinPerMile, speedMph: $speedMph, caloriesGrossKcal: $caloriesGrossKcal, caloriesNetKcal: $caloriesNetKcal, met: $met)';
  }
}

/// Enumeration for macro sections
enum MacroSection {
  preRun,
  duringRun,
  postRun,
}

/// Enumeration for macro fields within each section
enum MacroField {
  // Pre-run fields
  preRunCarbs,
  preRunProtein,
  preRunFatCap,
  preRunFluids,
  preRunSodium,
  
  // During-run fields
  duringRunCarbTotal,
  duringRunCarbRate,
  duringRunFluidTotal,
  duringRunFluidRate,
  duringRunSodiumTotal,
  duringRunSodiumRate,
  
  // Post-run fields
  postRunCarbs,
  postRunProtein,
  postRunFluids,
  postRunSodium,
}

/// Extension to get field display names
extension MacroFieldExtension on MacroField {
  String get displayName {
    switch (this) {
      case MacroField.preRunCarbs:
        return 'Carbohydrates';
      case MacroField.preRunProtein:
        return 'Protein';
      case MacroField.preRunFatCap:
        return 'Fat cap';
      case MacroField.preRunFluids:
        return 'Fluids';
      case MacroField.preRunSodium:
        return 'Sodium';
      case MacroField.duringRunCarbTotal:
        return 'Total Carbohydrates';
      case MacroField.duringRunCarbRate:
        return 'Carbohydrate rate';
      case MacroField.duringRunFluidTotal:
        return 'Total Fluids';
      case MacroField.duringRunFluidRate:
        return 'Fluid rate';
      case MacroField.duringRunSodiumTotal:
        return 'Total Sodium';
      case MacroField.duringRunSodiumRate:
        return 'Sodium rate';
      case MacroField.postRunCarbs:
        return 'Carbohydrates';
      case MacroField.postRunProtein:
        return 'Protein';
      case MacroField.postRunFluids:
        return 'Fluids';
      case MacroField.postRunSodium:
        return 'Sodium';
    }
  }

  String get unit {
    switch (this) {
      case MacroField.preRunCarbs:
      case MacroField.preRunProtein:
      case MacroField.preRunFatCap:
      case MacroField.duringRunCarbTotal:
      case MacroField.duringRunCarbRate:
      case MacroField.postRunCarbs:
      case MacroField.postRunProtein:
        return 'g';
      case MacroField.preRunFluids:
      case MacroField.duringRunFluidTotal:
      case MacroField.duringRunFluidRate:
      case MacroField.postRunFluids:
        return 'fl oz';
      case MacroField.preRunSodium:
      case MacroField.duringRunSodiumTotal:
      case MacroField.duringRunSodiumRate:
      case MacroField.postRunSodium:
        return 'mg';
    }
  }
}

/// Helper function to compare lists for equality
bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}