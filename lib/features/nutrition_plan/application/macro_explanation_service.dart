import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;

import '../../../shared/domain/activity_type.dart';
import '../domain/nutrient_transparency_data.dart';
import '../domain/macro_targets.dart';
import '../domain/resolved_during_target.dart';

part 'macro_explanation_service.explanations.dart';
part 'macro_explanation_service.calculations.dart';
part 'macro_explanation_service.fluid.dart';
part 'macro_explanation_service.sodium.dart';
part 'macro_explanation_service.carb.dart';

/// Structured explanation data for a single macro within a phase
class MacroExplanation {
  const MacroExplanation({
    required this.macroName,
    required this.value,
    required this.unit,
    this.rangeLow,
    this.rangeHigh,
    required this.formulaText,
    required this.rangeRationale,
    this.actualValue,
  });

  final String macroName;
  final String value;
  final String unit;
  final String? rangeLow;
  final String? rangeHigh;
  final String formulaText;
  final String rangeRationale;

  /// The actual food total (e.g. "194") when foods are provided
  final String? actualValue;

  /// Header: "Carbohydrates: 194g" (actual) or "Carbohydrates: 191g" (target)
  String get displayHeader {
    final displayVal = actualValue ?? value;
    return '$macroName: $displayVal$unit';
  }

  /// Sub-header shown when actuals are present: "Target: 191g (range: 167-215g)"
  String? get displaySubHeader {
    if (actualValue == null) return null;
    final rangeStr = (rangeLow != null && rangeHigh != null)
        ? ' (range: $rangeLow-$rangeHigh$unit)'
        : '';
    return 'Target: $value$unit$rangeStr';
  }
}

/// Phase types for explanation context
enum ExplanationPhase { before, during, after, transition1, transition2 }

/// Generates personalized explanation text for each phase/macro combination.
///
/// Pure Dart class - no Riverpod, no async. Takes macro targets and user data
/// and returns structured explanation data derived from algorithm-v4.md.


class MacroExplanationService {
  const MacroExplanationService();
  String getSheetTitle(ExplanationPhase phase, String? sportLabel) {
    final sport = sportLabel ?? 'Run';
    switch (phase) {
      case ExplanationPhase.before:
        return 'How We Calculate Your Before $sport Targets';
      case ExplanationPhase.during:
        return 'How We Calculate Your During $sport Targets';
      case ExplanationPhase.after:
        return 'How We Calculate Your After $sport Targets';
      case ExplanationPhase.transition1:
        return 'How We Calculate Your Transition 1 Targets';
      case ExplanationPhase.transition2:
        return 'How We Calculate Your Transition 2 Targets';
    }
  }

  /// Generate explanations for all macros in a given phase.
  ///
  /// [actuals] - optional map of actual food totals keyed by macro name
  /// (e.g. {'carbs': 194, 'protein': 25, 'sodium': 450, 'fluids': 600})
  List<MacroExplanation> getExplanations({
    required ExplanationPhase phase,
    required MacroTargets macroTargets,
    required double bodyWeightKg,
    bool useImperial = false,
    Map<String, int>? actuals,
    BrickSegmentMacroTarget? brickSegment,
  }) {
    switch (phase) {
      case ExplanationPhase.before:
        return _beforeExplanations(
          macroTargets,
          bodyWeightKg,
          useImperial,
          actuals,
        );
      case ExplanationPhase.during:
        return _duringExplanations(
          macroTargets,
          bodyWeightKg,
          useImperial,
          actuals,
          brickSegment: brickSegment,
        );
      case ExplanationPhase.after:
        return _afterExplanations(
          macroTargets,
          bodyWeightKg,
          useImperial,
          actuals,
        );
      case ExplanationPhase.transition1:
        return _transitionExplanations(1, actuals);
      case ExplanationPhase.transition2:
        return _transitionExplanations(2, actuals);
    }
  }

  /// Sport-specific carb ceiling for during phase (g/hr)
  int _sportCarbCeiling(ActivityType sport) {
    switch (sport) {
      case ActivityType.running:
        return 70;
      case ActivityType.cycling:
        return 120;
      case ActivityType.swimming:
        return 0;
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
      case ActivityType.brick:
        return 70; // brick/multi-sport segments use per-segment sport
    }
  }

  String _sportLabel(ActivityType sport) {
    switch (sport) {
      case ActivityType.running:
        return 'running';
      case ActivityType.cycling:
        return 'cycling';
      case ActivityType.swimming:
        return 'swimming';
      case ActivityType.triathlon:
        return 'triathlon';
      case ActivityType.duathlon:
        return 'duathlon';
      case ActivityType.multisport:
        return 'multisport';
      case ActivityType.brick:
        return 'brick';
    }
  }

  // ── Before Phase ────────────────────────────────────────────────────

  Map<Scenario, NutrientTransparencyData>? getFluidTransparencyData({
    required ExplanationPhase phase,
    required MacroTargets macroTargets,
    required double bodyWeightKg,
    bool useImperial = false,
    BrickSegmentMacroTarget? brickSegment,
    bool isBrick = false,
  }) {
    switch (phase) {
      case ExplanationPhase.before:
        final data = _preWorkoutFluidTransparency(
          macroTargets: macroTargets,
          bodyWeightKg: bodyWeightKg,
          useImperial: useImperial,
        );
        // Pre-workout has no scenario tabs — return a single-entry map so the
        // sheet can still get a NutrientTransparencyData without special-casing.
        return {Scenario.singleSport: data};

      case ExplanationPhase.during:
        final sport = brickSegment?.sport ?? '';
        if (sport.contains('swim')) {
          return null; // Swim: zero-state rendered directly by sheet
        }
        if (isBrick && brickSegment != null) {
          return _brickSegmentFluidMap(
            macroTargets: macroTargets,
            segment: brickSegment,
            bodyWeightKg: bodyWeightKg,
            useImperial: useImperial,
          );
        }
        return _singleSportFluidMap(
          macroTargets: macroTargets,
          bodyWeightKg: bodyWeightKg,
          useImperial: useImperial,
        );

      case ExplanationPhase.transition1:
      case ExplanationPhase.transition2:
        final data = _transitionFluidTransparency(
          phase: phase,
          macroTargets: macroTargets,
          useImperial: useImperial,
        );
        return {Scenario.t1t2: data};

      case ExplanationPhase.after:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // PRE-WORKOUT FLUID
  // ---------------------------------------------------------------------------

  NutrientTransparencyData getSwimFluidTransparency() =>
      _swimFluidTransparency();

  Map<Scenario, NutrientTransparencyData>? getSodiumTransparencyData({
    required ExplanationPhase phase,
    required MacroTargets macroTargets,
    required double bodyWeightKg,
    BrickSegmentMacroTarget? brickSegment,
    bool isBrick = false,
  }) {
    switch (phase) {
      case ExplanationPhase.before:
        return {
          Scenario.singleSport:
              _preWorkoutSodiumTransparency(macroTargets: macroTargets),
        };

      case ExplanationPhase.during:
        final sport = brickSegment?.sport ?? '';
        if (sport.contains('swim')) {
          return null; // Swim: zero-state rendered directly
        }
        if (isBrick && brickSegment != null) {
          return _brickSegmentSodiumMap(
            macroTargets: macroTargets,
            segment: brickSegment,
          );
        }
        return _singleSportSodiumMap(macroTargets: macroTargets);

      case ExplanationPhase.transition1:
      case ExplanationPhase.transition2:
        return {
          Scenario.t1t2: _transitionSodiumTransparency(
            phase: phase,
            macroTargets: macroTargets,
          ),
        };

      case ExplanationPhase.after:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // SODIUM MAP BUILDERS
  // ---------------------------------------------------------------------------

  NutrientTransparencyData getSwimSodiumTransparency() =>
      _swimSodiumTransparency();

  NutrientTransparencyData getCarbTransparencyData({
    required ExplanationPhase phase,
    required MacroTargets macroTargets,
    required double bodyWeightKg,
    required String gutTrainingLabel,
    required double gutMultiplier,
    double? personalCarbTargetGPerH,
    String? personalTargetSport,
    String? sportLabel,
    BrickSegmentMacroTarget? brickSegment,
    bool isBrick = false,
    ResolvedDuringTarget? resolvedDuringTarget,
  }) {
    if (phase == ExplanationPhase.before) {
      return _preWorkoutTransparency(
        macroTargets: macroTargets,
        bodyWeightKg: bodyWeightKg,
      );
    }

    // Swim zero-state
    final sport = brickSegment?.sport ?? sportLabel?.toLowerCase() ?? 'running';
    if (sport.contains('swim')) {
      return _swimTransparency(brickSegment: brickSegment);
    }

    if (isBrick && brickSegment != null) {
      return _brickSegmentTransparency(
        macroTargets: macroTargets,
        segment: brickSegment,
        gutTrainingLabel: gutTrainingLabel,
        gutMultiplier: gutMultiplier,
        personalCarbTargetGPerH: personalCarbTargetGPerH,
        personalTargetSport: personalTargetSport,
        resolvedDuringTarget: resolvedDuringTarget,
      );
    }

    // Brick transition (T1/T2) — no segment-level formula, just context
    if (isBrick &&
        (phase == ExplanationPhase.transition1 ||
            phase == ExplanationPhase.transition2)) {
      return _brickTransitionTransparency(
        phase: phase,
        macroTargets: macroTargets,
      );
    }

    // Brick during segment without detailed segment data — show generic brick message
    if (isBrick && phase == ExplanationPhase.during) {
      return _brickGenericTransparency(
        macroTargets: macroTargets,
        sportLabel: sportLabel ?? 'Brick',
        gutTrainingLabel: gutTrainingLabel,
        gutMultiplier: gutMultiplier,
        personalCarbTargetGPerH: personalCarbTargetGPerH,
        personalTargetSport: personalTargetSport,
      );
    }

    return _duringSingleSportTransparency(
      macroTargets: macroTargets,
      bodyWeightKg: bodyWeightKg,
      sportLabel: sportLabel ?? 'Run',
      gutTrainingLabel: gutTrainingLabel,
      gutMultiplier: gutMultiplier,
      personalCarbTargetGPerH: personalCarbTargetGPerH,
      personalTargetSport: personalTargetSport,
      resolvedDuringTarget: resolvedDuringTarget,
    );
  }

  // ---------------------------------------------------------------------------
  // PRE-WORKOUT
  // ---------------------------------------------------------------------------

  int _defaultSportCeiling(String sportLabel) {
    final s = sportLabel.toLowerCase();
    if (s.contains('run')) return 70;
    if (s.contains('cycl') || s.contains('bike')) return 120;
    if (s.contains('swim')) return 0;
    return 70;
  }

  String _formatDuration(double hours) {
    if (hours == hours.roundToDouble()) return '${hours.round()}.0';
    return (hours * 10).round() / 10 == hours
        ? hours.toStringAsFixed(1)
        : hours.toStringAsFixed(2);
  }
}
