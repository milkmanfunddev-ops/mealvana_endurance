import 'dart:convert';

import '../../../shared/domain/activity_type.dart';
import '../../activities/domain/brick_metadata.dart';

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
    this.preRunSelections,
    this.brickSegments,
    this.brickPhaseTargets,
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
  final List<Map<String, dynamic>>? preRunSelections;

  /// Brick segment data (only populated for brick workouts)
  /// Contains sport type, order, duration, and other segment-specific data
  final List<BrickSegment>? brickSegments;

  /// Exact per-segment/per-transition phase targets from generate-macros-v4.
  /// Used to keep generate-nutrition-plan-v3 aligned to V4 ranges.
  final BrickPhaseTargets? brickPhaseTargets;

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
    List<Map<String, dynamic>>? preRunSelections,
    List<BrickSegment>? brickSegments,
    BrickPhaseTargets? brickPhaseTargets,
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
      preRunSelections: preRunSelections ?? this.preRunSelections,
      brickSegments: brickSegments ?? this.brickSegments,
      brickPhaseTargets: brickPhaseTargets ?? this.brickPhaseTargets,
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
      if (preRunSelections != null) 'preRunSelections': preRunSelections,
      if (brickSegments != null)
        'brickSegments': brickSegments!.map((s) => s.toJson()).toList(),
      if (brickPhaseTargets != null)
        'brickPhaseTargets': brickPhaseTargets!.toJson(),
    };
  }

  factory MacroTargets.fromJson(Map<String, dynamic> json) {
    return MacroTargets(
      id: json['id'] as String,
      activityType: ActivityType.values.byName(
        json['activityType'] as String? ?? 'running',
      ),
      preRun: PreRunMacros.fromJson(json['preRun'] as Map<String, dynamic>),
      duringRun: DuringRunMacros.fromJson(
        json['duringRun'] as Map<String, dynamic>,
      ),
      postRun: PostRunMacros.fromJson(json['postRun'] as Map<String, dynamic>),
      metrics: RunMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
      calculationRule: json['calculationRule'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isUserModified: json['isUserModified'] as bool,
      modifiedFields: List<String>.from(json['modifiedFields'] as List? ?? []),
      preRunSelections: (json['preRunSelections'] as List<dynamic>?)
          ?.map((s) => Map<String, dynamic>.from(s as Map))
          .toList(),
      brickSegments: json['brickSegments'] != null
          ? (json['brickSegments'] as List<dynamic>)
                .map((s) => BrickSegment.fromJson(s as Map<String, dynamic>))
                .toList()
          : null,
      brickPhaseTargets: json['brickPhaseTargets'] != null
          ? BrickPhaseTargets.fromJson(
              json['brickPhaseTargets'] as Map<String, dynamic>,
            )
          : null,
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
        _listEquals(other.modifiedFields, modifiedFields) &&
        _nullableListOfMapEquals(other.preRunSelections, preRunSelections) &&
        _nullableListEquals(other.brickSegments, brickSegments) &&
        other.brickPhaseTargets == brickPhaseTargets;
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
      Object.hashAll((preRunSelections ?? const []).map(jsonEncode)),
      Object.hashAll(brickSegments ?? []),
      brickPhaseTargets,
    );
  }

  @override
  String toString() {
    return 'MacroTargets(id: $id, activityType: $activityType, preRun: $preRun, duringRun: $duringRun, postRun: $postRun, metrics: $metrics, calculationRule: $calculationRule, timestamp: $timestamp, isUserModified: $isUserModified, modifiedFields: $modifiedFields, preRunSelections: ${preRunSelections?.length ?? 0}, brickSegments: ${brickSegments?.length ?? 0}, brickPhaseTargets: ${brickPhaseTargets != null})';
  }
}

/// Brick phase targets produced by generate-macros-v4.
class BrickPhaseTargets {
  const BrickPhaseTargets({
    required this.duringSegments,
    required this.transitions,
  });

  final List<BrickSegmentMacroTarget> duringSegments;
  final List<BrickTransitionMacroTarget> transitions;

  Map<String, dynamic> toJson() {
    return {
      'duringSegments': duringSegments.map((s) => s.toJson()).toList(),
      'transitions': transitions.map((t) => t.toJson()).toList(),
    };
  }

  factory BrickPhaseTargets.fromJson(Map<String, dynamic> json) {
    return BrickPhaseTargets(
      duringSegments: (json['duringSegments'] as List<dynamic>? ?? const [])
          .map(
            (s) => BrickSegmentMacroTarget.fromJson(s as Map<String, dynamic>),
          )
          .toList(),
      transitions: (json['transitions'] as List<dynamic>? ?? const [])
          .map(
            (t) =>
                BrickTransitionMacroTarget.fromJson(t as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BrickPhaseTargets &&
        _listEquals(other.duringSegments, duringSegments) &&
        _listEquals(other.transitions, transitions);
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(duringSegments), Object.hashAll(transitions));
}

/// Per-segment during targets for brick workouts.
class BrickSegmentMacroTarget {
  const BrickSegmentMacroTarget({
    required this.segmentOrder,
    required this.sport,
    required this.durationMinutes,
    required this.carbsG,
    this.carbsLowG,
    this.carbsHighG,
    required this.sodiumMg,
    this.sodiumLowMg,
    this.sodiumHighMg,
    required this.waterMl,
    this.waterLowMl,
    this.waterHighMl,
    this.carbsRateGPerH,
    this.rawBandLowGPerH,
    this.rawBandHighGPerH,
    this.scaledBandLowGPerH,
    this.scaledBandHighGPerH,
    this.gutMultiplier,
    this.sportCeilingGPerH,
    this.brickPenalty,
    this.cumulativeDurationMin,
  });

  final int segmentOrder;
  final String sport;
  final int durationMinutes;
  final double carbsG;
  final double? carbsLowG;
  final double? carbsHighG;
  final double sodiumMg;
  final double? sodiumLowMg;
  final double? sodiumHighMg;
  final double waterMl;
  final double? waterLowMl;
  final double? waterHighMl;
  final double? carbsRateGPerH;
  final double? rawBandLowGPerH;
  final double? rawBandHighGPerH;
  final double? scaledBandLowGPerH;
  final double? scaledBandHighGPerH;
  final double? gutMultiplier;
  final double? sportCeilingGPerH;
  final double? brickPenalty;
  final double? cumulativeDurationMin;

  Map<String, dynamic> toJson() {
    return {
      'segmentOrder': segmentOrder,
      'sport': sport,
      'durationMinutes': durationMinutes,
      'carbsG': carbsG,
      if (carbsLowG != null) 'carbsLowG': carbsLowG,
      if (carbsHighG != null) 'carbsHighG': carbsHighG,
      'sodiumMg': sodiumMg,
      if (sodiumLowMg != null) 'sodiumLowMg': sodiumLowMg,
      if (sodiumHighMg != null) 'sodiumHighMg': sodiumHighMg,
      'waterMl': waterMl,
      if (waterLowMl != null) 'waterLowMl': waterLowMl,
      if (waterHighMl != null) 'waterHighMl': waterHighMl,
      if (carbsRateGPerH != null) 'carbsRateGPerH': carbsRateGPerH,
      if (rawBandLowGPerH != null) 'rawBandLowGPerH': rawBandLowGPerH,
      if (rawBandHighGPerH != null) 'rawBandHighGPerH': rawBandHighGPerH,
      if (scaledBandLowGPerH != null)
        'scaledBandLowGPerH': scaledBandLowGPerH,
      if (scaledBandHighGPerH != null)
        'scaledBandHighGPerH': scaledBandHighGPerH,
      if (gutMultiplier != null) 'gutMultiplier': gutMultiplier,
      if (sportCeilingGPerH != null) 'sportCeilingGPerH': sportCeilingGPerH,
      if (brickPenalty != null) 'brickPenalty': brickPenalty,
      if (cumulativeDurationMin != null)
        'cumulativeDurationMin': cumulativeDurationMin,
    };
  }

  factory BrickSegmentMacroTarget.fromJson(Map<String, dynamic> json) {
    return BrickSegmentMacroTarget(
      segmentOrder: (json['segmentOrder'] as num).toInt(),
      sport: json['sport'] as String,
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      carbsG: (json['carbsG'] as num).toDouble(),
      carbsLowG: (json['carbsLowG'] as num?)?.toDouble(),
      carbsHighG: (json['carbsHighG'] as num?)?.toDouble(),
      sodiumMg: (json['sodiumMg'] as num).toDouble(),
      sodiumLowMg: (json['sodiumLowMg'] as num?)?.toDouble(),
      sodiumHighMg: (json['sodiumHighMg'] as num?)?.toDouble(),
      waterMl: (json['waterMl'] as num).toDouble(),
      waterLowMl: (json['waterLowMl'] as num?)?.toDouble(),
      waterHighMl: (json['waterHighMl'] as num?)?.toDouble(),
      carbsRateGPerH: (json['carbsRateGPerH'] as num?)?.toDouble(),
      rawBandLowGPerH: (json['rawBandLowGPerH'] as num?)?.toDouble(),
      rawBandHighGPerH: (json['rawBandHighGPerH'] as num?)?.toDouble(),
      scaledBandLowGPerH: (json['scaledBandLowGPerH'] as num?)?.toDouble(),
      scaledBandHighGPerH: (json['scaledBandHighGPerH'] as num?)?.toDouble(),
      gutMultiplier: (json['gutMultiplier'] as num?)?.toDouble(),
      sportCeilingGPerH: (json['sportCeilingGPerH'] as num?)?.toDouble(),
      brickPenalty: (json['brickPenalty'] as num?)?.toDouble(),
      cumulativeDurationMin:
          (json['cumulativeDurationMin'] as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BrickSegmentMacroTarget &&
        other.segmentOrder == segmentOrder &&
        other.sport == sport &&
        other.durationMinutes == durationMinutes &&
        other.carbsG == carbsG &&
        other.carbsLowG == carbsLowG &&
        other.carbsHighG == carbsHighG &&
        other.sodiumMg == sodiumMg &&
        other.sodiumLowMg == sodiumLowMg &&
        other.sodiumHighMg == sodiumHighMg &&
        other.waterMl == waterMl &&
        other.waterLowMl == waterLowMl &&
        other.waterHighMl == waterHighMl &&
        other.carbsRateGPerH == carbsRateGPerH &&
        other.rawBandLowGPerH == rawBandLowGPerH &&
        other.rawBandHighGPerH == rawBandHighGPerH &&
        other.scaledBandLowGPerH == scaledBandLowGPerH &&
        other.scaledBandHighGPerH == scaledBandHighGPerH &&
        other.gutMultiplier == gutMultiplier &&
        other.sportCeilingGPerH == sportCeilingGPerH &&
        other.brickPenalty == brickPenalty &&
        other.cumulativeDurationMin == cumulativeDurationMin;
  }

  @override
  int get hashCode => Object.hash(
    segmentOrder,
    sport,
    durationMinutes,
    carbsG,
    carbsLowG,
    carbsHighG,
    sodiumMg,
    sodiumLowMg,
    sodiumHighMg,
    waterMl,
    waterLowMl,
    waterHighMl,
    carbsRateGPerH,
    rawBandLowGPerH,
    rawBandHighGPerH,
    scaledBandLowGPerH,
    scaledBandHighGPerH,
    Object.hash(gutMultiplier, sportCeilingGPerH, brickPenalty, cumulativeDurationMin),
  );
}

/// Per-transition targets for brick workouts.
class BrickTransitionMacroTarget {
  const BrickTransitionMacroTarget({
    required this.transitionName,
    required this.carbsG,
    this.carbsLowG,
    this.carbsHighG,
    required this.sodiumMg,
    this.sodiumLowMg,
    this.sodiumHighMg,
    required this.waterMl,
    this.waterLowMl,
    this.waterHighMl,
  });

  final String transitionName;
  final double carbsG;
  final double? carbsLowG;
  final double? carbsHighG;
  final double sodiumMg;
  final double? sodiumLowMg;
  final double? sodiumHighMg;
  final double waterMl;
  final double? waterLowMl;
  final double? waterHighMl;

  Map<String, dynamic> toJson() {
    return {
      'transitionName': transitionName,
      'carbsG': carbsG,
      if (carbsLowG != null) 'carbsLowG': carbsLowG,
      if (carbsHighG != null) 'carbsHighG': carbsHighG,
      'sodiumMg': sodiumMg,
      if (sodiumLowMg != null) 'sodiumLowMg': sodiumLowMg,
      if (sodiumHighMg != null) 'sodiumHighMg': sodiumHighMg,
      'waterMl': waterMl,
      if (waterLowMl != null) 'waterLowMl': waterLowMl,
      if (waterHighMl != null) 'waterHighMl': waterHighMl,
    };
  }

  factory BrickTransitionMacroTarget.fromJson(Map<String, dynamic> json) {
    return BrickTransitionMacroTarget(
      transitionName: json['transitionName'] as String,
      carbsG: (json['carbsG'] as num).toDouble(),
      carbsLowG: (json['carbsLowG'] as num?)?.toDouble(),
      carbsHighG: (json['carbsHighG'] as num?)?.toDouble(),
      sodiumMg: (json['sodiumMg'] as num).toDouble(),
      sodiumLowMg: (json['sodiumLowMg'] as num?)?.toDouble(),
      sodiumHighMg: (json['sodiumHighMg'] as num?)?.toDouble(),
      waterMl: (json['waterMl'] as num).toDouble(),
      waterLowMl: (json['waterLowMl'] as num?)?.toDouble(),
      waterHighMl: (json['waterHighMl'] as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BrickTransitionMacroTarget &&
        other.transitionName == transitionName &&
        other.carbsG == carbsG &&
        other.carbsLowG == carbsLowG &&
        other.carbsHighG == carbsHighG &&
        other.sodiumMg == sodiumMg &&
        other.sodiumLowMg == sodiumLowMg &&
        other.sodiumHighMg == sodiumHighMg &&
        other.waterMl == waterMl &&
        other.waterLowMl == waterLowMl &&
        other.waterHighMl == waterHighMl;
  }

  @override
  int get hashCode => Object.hash(
    transitionName,
    carbsG,
    carbsLowG,
    carbsHighG,
    sodiumMg,
    sodiumLowMg,
    sodiumHighMg,
    waterMl,
    waterLowMl,
    waterHighMl,
  );
}

/// Pre-run nutrition targets (1-4 hours before)
class PreRunMacros {
  const PreRunMacros({
    required this.carbsG,
    required this.proteinG,
    required this.fatCapG,
    required this.fluidsMl,
    required this.sodiumMg,
    this.carbsLowG,
    this.carbsHighG,
    this.proteinLowG,
    this.proteinHighG,
    this.sodiumLowMg,
    this.sodiumHighMg,
    this.fluidsLowMl,
    this.fluidsHighMl,
  });

  final double carbsG;
  final double proteinG;
  final double fatCapG;
  final double fluidsMl;
  final double sodiumMg;
  final double? carbsLowG;
  final double? carbsHighG;
  final double? proteinLowG;
  final double? proteinHighG;
  final double? sodiumLowMg;
  final double? sodiumHighMg;
  final double? fluidsLowMl;
  final double? fluidsHighMl;

  /// Convert fluids to US units (fl oz)
  double get fluidsFlOz => fluidsMl * 0.033814;

  PreRunMacros copyWith({
    double? carbsG,
    double? proteinG,
    double? fatCapG,
    double? fluidsMl,
    double? sodiumMg,
    double? carbsLowG,
    double? carbsHighG,
    double? proteinLowG,
    double? proteinHighG,
    double? sodiumLowMg,
    double? sodiumHighMg,
    double? fluidsLowMl,
    double? fluidsHighMl,
  }) {
    return PreRunMacros(
      carbsG: carbsG ?? this.carbsG,
      proteinG: proteinG ?? this.proteinG,
      fatCapG: fatCapG ?? this.fatCapG,
      fluidsMl: fluidsMl ?? this.fluidsMl,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      carbsLowG: carbsLowG ?? this.carbsLowG,
      carbsHighG: carbsHighG ?? this.carbsHighG,
      proteinLowG: proteinLowG ?? this.proteinLowG,
      proteinHighG: proteinHighG ?? this.proteinHighG,
      sodiumLowMg: sodiumLowMg ?? this.sodiumLowMg,
      sodiumHighMg: sodiumHighMg ?? this.sodiumHighMg,
      fluidsLowMl: fluidsLowMl ?? this.fluidsLowMl,
      fluidsHighMl: fluidsHighMl ?? this.fluidsHighMl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'carbsG': carbsG,
      'proteinG': proteinG,
      'fatCapG': fatCapG,
      'fluidsMl': fluidsMl,
      'sodiumMg': sodiumMg,
      if (carbsLowG != null) 'carbsLowG': carbsLowG,
      if (carbsHighG != null) 'carbsHighG': carbsHighG,
      if (proteinLowG != null) 'proteinLowG': proteinLowG,
      if (proteinHighG != null) 'proteinHighG': proteinHighG,
      if (sodiumLowMg != null) 'sodiumLowMg': sodiumLowMg,
      if (sodiumHighMg != null) 'sodiumHighMg': sodiumHighMg,
      if (fluidsLowMl != null) 'fluidsLowMl': fluidsLowMl,
      if (fluidsHighMl != null) 'fluidsHighMl': fluidsHighMl,
    };
  }

  factory PreRunMacros.fromJson(Map<String, dynamic> json) {
    return PreRunMacros(
      carbsG: (json['carbsG'] as num).toDouble(),
      proteinG: (json['proteinG'] as num).toDouble(),
      fatCapG: (json['fatCapG'] as num).toDouble(),
      fluidsMl: (json['fluidsMl'] as num).toDouble(),
      sodiumMg: (json['sodiumMg'] as num).toDouble(),
      carbsLowG: (json['carbsLowG'] as num?)?.toDouble(),
      carbsHighG: (json['carbsHighG'] as num?)?.toDouble(),
      proteinLowG: (json['proteinLowG'] as num?)?.toDouble(),
      proteinHighG: (json['proteinHighG'] as num?)?.toDouble(),
      sodiumLowMg: (json['sodiumLowMg'] as num?)?.toDouble(),
      sodiumHighMg: (json['sodiumHighMg'] as num?)?.toDouble(),
      fluidsLowMl: (json['fluidsLowMl'] as num?)?.toDouble(),
      fluidsHighMl: (json['fluidsHighMl'] as num?)?.toDouble(),
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
        other.sodiumMg == sodiumMg &&
        other.carbsLowG == carbsLowG &&
        other.carbsHighG == carbsHighG &&
        other.proteinLowG == proteinLowG &&
        other.proteinHighG == proteinHighG &&
        other.sodiumLowMg == sodiumLowMg &&
        other.sodiumHighMg == sodiumHighMg &&
        other.fluidsLowMl == fluidsLowMl &&
        other.fluidsHighMl == fluidsHighMl;
  }

  @override
  int get hashCode {
    return Object.hash(
      carbsG,
      proteinG,
      fatCapG,
      fluidsMl,
      sodiumMg,
      carbsLowG,
      carbsHighG,
      proteinLowG,
      proteinHighG,
      sodiumLowMg,
      sodiumHighMg,
      fluidsLowMl,
      fluidsHighMl,
    );
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
    this.carbsLowG,
    this.carbsHighG,
    this.sodiumLowMg,
    this.sodiumHighMg,
    this.fluidsLowMl,
    this.fluidsHighMl,
    this.gutMultiplier,
    this.sportCeilingGPerH,
    this.rawBandLowGPerH,
    this.rawBandHighGPerH,
  });

  final double carbRateGPerH;
  final double carbTotalG;
  final double fluidRateMlPerH;
  final double fluidTotalMl;
  final double sodiumRateMgPerH;
  final double sodiumTotalMg;
  final double massNormRateGPerH;
  final List<double> absClampRangeGPerH;
  final double? carbsLowG;
  final double? carbsHighG;
  final double? sodiumLowMg;
  final double? sodiumHighMg;
  final double? fluidsLowMl;
  final double? fluidsHighMl;
  final double? gutMultiplier;
  final double? sportCeilingGPerH;
  final double? rawBandLowGPerH;
  final double? rawBandHighGPerH;

  /// Convert fluids to US units (fl oz)
  double get fluidRateFlOzPerH => fluidRateMlPerH * 0.033814;
  double get fluidTotalFlOz => fluidTotalMl * 0.033814;

  /// Create updated instance with new total carbs, recalculating rate
  DuringRunMacros withUpdatedTotalCarbs(double newTotalG, double durationH) {
    final newRate = durationH > 0 ? newTotalG / durationH : carbRateGPerH;
    return copyWith(carbTotalG: newTotalG, carbRateGPerH: newRate);
  }

  /// Create updated instance with new carb rate, recalculating total
  DuringRunMacros withUpdatedRateCarbs(double newRateGPerH, double durationH) {
    final newTotal = newRateGPerH * durationH;
    return copyWith(carbRateGPerH: newRateGPerH, carbTotalG: newTotal);
  }

  /// Create updated instance with new total fluids, recalculating rate
  DuringRunMacros withUpdatedTotalFluids(double newTotalMl, double durationH) {
    final newRate = durationH > 0 ? newTotalMl / durationH : fluidRateMlPerH;
    return copyWith(fluidTotalMl: newTotalMl, fluidRateMlPerH: newRate);
  }

  /// Create updated instance with new total sodium, recalculating rate
  DuringRunMacros withUpdatedTotalSodium(double newTotalMg, double durationH) {
    final newRate = durationH > 0 ? newTotalMg / durationH : sodiumRateMgPerH;
    return copyWith(sodiumTotalMg: newTotalMg, sodiumRateMgPerH: newRate);
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
    double? carbsLowG,
    double? carbsHighG,
    double? sodiumLowMg,
    double? sodiumHighMg,
    double? fluidsLowMl,
    double? fluidsHighMl,
    double? gutMultiplier,
    double? sportCeilingGPerH,
    double? rawBandLowGPerH,
    double? rawBandHighGPerH,
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
      carbsLowG: carbsLowG ?? this.carbsLowG,
      carbsHighG: carbsHighG ?? this.carbsHighG,
      sodiumLowMg: sodiumLowMg ?? this.sodiumLowMg,
      sodiumHighMg: sodiumHighMg ?? this.sodiumHighMg,
      fluidsLowMl: fluidsLowMl ?? this.fluidsLowMl,
      fluidsHighMl: fluidsHighMl ?? this.fluidsHighMl,
      gutMultiplier: gutMultiplier ?? this.gutMultiplier,
      sportCeilingGPerH: sportCeilingGPerH ?? this.sportCeilingGPerH,
      rawBandLowGPerH: rawBandLowGPerH ?? this.rawBandLowGPerH,
      rawBandHighGPerH: rawBandHighGPerH ?? this.rawBandHighGPerH,
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
      if (carbsLowG != null) 'carbsLowG': carbsLowG,
      if (carbsHighG != null) 'carbsHighG': carbsHighG,
      if (sodiumLowMg != null) 'sodiumLowMg': sodiumLowMg,
      if (sodiumHighMg != null) 'sodiumHighMg': sodiumHighMg,
      if (fluidsLowMl != null) 'fluidsLowMl': fluidsLowMl,
      if (fluidsHighMl != null) 'fluidsHighMl': fluidsHighMl,
      if (gutMultiplier != null) 'gutMultiplier': gutMultiplier,
      if (sportCeilingGPerH != null) 'sportCeilingGPerH': sportCeilingGPerH,
      if (rawBandLowGPerH != null) 'rawBandLowGPerH': rawBandLowGPerH,
      if (rawBandHighGPerH != null) 'rawBandHighGPerH': rawBandHighGPerH,
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
      absClampRangeGPerH: List<double>.from(
        json['absClampRangeGPerH'] as List? ?? [30, 60],
      ),
      carbsLowG: (json['carbsLowG'] as num?)?.toDouble(),
      carbsHighG: (json['carbsHighG'] as num?)?.toDouble(),
      sodiumLowMg: (json['sodiumLowMg'] as num?)?.toDouble(),
      sodiumHighMg: (json['sodiumHighMg'] as num?)?.toDouble(),
      fluidsLowMl: (json['fluidsLowMl'] as num?)?.toDouble(),
      fluidsHighMl: (json['fluidsHighMl'] as num?)?.toDouble(),
      gutMultiplier: (json['gutMultiplier'] as num?)?.toDouble(),
      sportCeilingGPerH: (json['sportCeilingGPerH'] as num?)?.toDouble(),
      rawBandLowGPerH: (json['rawBandLowGPerH'] as num?)?.toDouble(),
      rawBandHighGPerH: (json['rawBandHighGPerH'] as num?)?.toDouble(),
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
        _listEquals(other.absClampRangeGPerH, absClampRangeGPerH) &&
        other.carbsLowG == carbsLowG &&
        other.carbsHighG == carbsHighG &&
        other.sodiumLowMg == sodiumLowMg &&
        other.sodiumHighMg == sodiumHighMg &&
        other.fluidsLowMl == fluidsLowMl &&
        other.fluidsHighMl == fluidsHighMl &&
        other.gutMultiplier == gutMultiplier &&
        other.sportCeilingGPerH == sportCeilingGPerH &&
        other.rawBandLowGPerH == rawBandLowGPerH &&
        other.rawBandHighGPerH == rawBandHighGPerH;
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
      carbsLowG,
      carbsHighG,
      sodiumLowMg,
      sodiumHighMg,
      fluidsLowMl,
      fluidsHighMl,
      gutMultiplier,
      sportCeilingGPerH,
      rawBandLowGPerH,
      rawBandHighGPerH,
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
    this.carbsLowG,
    this.carbsHighG,
    this.proteinLowG,
    this.proteinHighG,
    this.sodiumLowMg,
    this.sodiumHighMg,
    this.fluidsLowMl,
    this.fluidsHighMl,
  });

  final double carbsG;
  final double proteinG;
  final double fluidsMl;
  final double sodiumMg;
  final double? carbsLowG;
  final double? carbsHighG;
  final double? proteinLowG;
  final double? proteinHighG;
  final double? sodiumLowMg;
  final double? sodiumHighMg;
  final double? fluidsLowMl;
  final double? fluidsHighMl;

  /// Convert fluids to US units (fl oz)
  double get fluidsFlOz => fluidsMl * 0.033814;

  PostRunMacros copyWith({
    double? carbsG,
    double? proteinG,
    double? fluidsMl,
    double? sodiumMg,
    double? carbsLowG,
    double? carbsHighG,
    double? proteinLowG,
    double? proteinHighG,
    double? sodiumLowMg,
    double? sodiumHighMg,
    double? fluidsLowMl,
    double? fluidsHighMl,
  }) {
    return PostRunMacros(
      carbsG: carbsG ?? this.carbsG,
      proteinG: proteinG ?? this.proteinG,
      fluidsMl: fluidsMl ?? this.fluidsMl,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      carbsLowG: carbsLowG ?? this.carbsLowG,
      carbsHighG: carbsHighG ?? this.carbsHighG,
      proteinLowG: proteinLowG ?? this.proteinLowG,
      proteinHighG: proteinHighG ?? this.proteinHighG,
      sodiumLowMg: sodiumLowMg ?? this.sodiumLowMg,
      sodiumHighMg: sodiumHighMg ?? this.sodiumHighMg,
      fluidsLowMl: fluidsLowMl ?? this.fluidsLowMl,
      fluidsHighMl: fluidsHighMl ?? this.fluidsHighMl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'carbsG': carbsG,
      'proteinG': proteinG,
      'fluidsMl': fluidsMl,
      'sodiumMg': sodiumMg,
      if (carbsLowG != null) 'carbsLowG': carbsLowG,
      if (carbsHighG != null) 'carbsHighG': carbsHighG,
      if (proteinLowG != null) 'proteinLowG': proteinLowG,
      if (proteinHighG != null) 'proteinHighG': proteinHighG,
      if (sodiumLowMg != null) 'sodiumLowMg': sodiumLowMg,
      if (sodiumHighMg != null) 'sodiumHighMg': sodiumHighMg,
      if (fluidsLowMl != null) 'fluidsLowMl': fluidsLowMl,
      if (fluidsHighMl != null) 'fluidsHighMl': fluidsHighMl,
    };
  }

  factory PostRunMacros.fromJson(Map<String, dynamic> json) {
    return PostRunMacros(
      carbsG: (json['carbsG'] as num).toDouble(),
      proteinG: (json['proteinG'] as num).toDouble(),
      fluidsMl: (json['fluidsMl'] as num).toDouble(),
      sodiumMg: (json['sodiumMg'] as num).toDouble(),
      carbsLowG: (json['carbsLowG'] as num?)?.toDouble(),
      carbsHighG: (json['carbsHighG'] as num?)?.toDouble(),
      proteinLowG: (json['proteinLowG'] as num?)?.toDouble(),
      proteinHighG: (json['proteinHighG'] as num?)?.toDouble(),
      sodiumLowMg: (json['sodiumLowMg'] as num?)?.toDouble(),
      sodiumHighMg: (json['sodiumHighMg'] as num?)?.toDouble(),
      fluidsLowMl: (json['fluidsLowMl'] as num?)?.toDouble(),
      fluidsHighMl: (json['fluidsHighMl'] as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PostRunMacros &&
        other.carbsG == carbsG &&
        other.proteinG == proteinG &&
        other.fluidsMl == fluidsMl &&
        other.sodiumMg == sodiumMg &&
        other.carbsLowG == carbsLowG &&
        other.carbsHighG == carbsHighG &&
        other.proteinLowG == proteinLowG &&
        other.proteinHighG == proteinHighG &&
        other.sodiumLowMg == sodiumLowMg &&
        other.sodiumHighMg == sodiumHighMg &&
        other.fluidsLowMl == fluidsLowMl &&
        other.fluidsHighMl == fluidsHighMl;
  }

  @override
  int get hashCode {
    return Object.hash(
      carbsG,
      proteinG,
      fluidsMl,
      sodiumMg,
      carbsLowG,
      carbsHighG,
      proteinLowG,
      proteinHighG,
      sodiumLowMg,
      sodiumHighMg,
      fluidsLowMl,
      fluidsHighMl,
    );
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
      paceMinPerMile: json['paceMinPerMile'] != null
          ? (json['paceMinPerMile'] as num).toDouble()
          : null,
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
enum MacroSection { preRun, duringRun, postRun }

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

/// Helper function to compare nullable lists for equality
bool _nullableListEquals<T>(List<T>? a, List<T>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return _listEquals(a, b);
}

bool _nullableListOfMapEquals(
  List<Map<String, dynamic>>? a,
  List<Map<String, dynamic>>? b,
) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;

  for (int i = 0; i < a.length; i++) {
    if (!_deepEquals(a[i], b[i])) return false;
  }
  return true;
}

bool _deepEquals(dynamic a, dynamic b) {
  if (identical(a, b)) return true;

  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!_deepEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }

  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }

  return a == b;
}
