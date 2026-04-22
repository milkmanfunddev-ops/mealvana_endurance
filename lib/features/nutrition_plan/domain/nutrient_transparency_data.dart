// Data models for the nutrient transparency feature.
//
// These models carry the structured content needed to render the
// TL;DR formula, video section, and Full Story Q&A in the
// PhaseExplanationSheet nutrient cards (Carbs, Fluids, Sodium, Protein).

import 'package:flutter/material.dart';

import '../../../theme/kyle_design/app_colors.dart';

/// Public scenario identifiers for during-workout transparency tabs.
///
/// Used as keys in the [Map<Scenario, NutrientTransparencyData>] returned by
/// [MacroExplanationService.getFluidTransparencyData] and
/// [MacroExplanationService.getSodiumTransparencyData].
enum Scenario {
  /// Standard single-sport workout — the default scenario.
  singleSport,

  /// User has entered a lab-tested sweat rate or sodium concentration.
  /// Shows "TESTED ✓" badge and emphasises that the known rate overrode the
  /// category lookup.
  knownRate,

  /// Short workout (<60 min) in mild conditions (<30°C) — "drink to thirst".
  shortWorkout,

  /// Brick or multi-segment race — total-event duration drives replacement %.
  multiSegment,

  /// Run leg hit the GI ceiling; shortfall redistributed to the bike leg.
  redistribution,

  /// Fixed 300 mL bolus during T1 or T2 transition windows.
  t1t2,
}

/// Visual style for a formula segment — matches the HTML artifact classes.
enum SegmentStyle {
  /// Default green/accent text (e.g. "60 min run", "midpoint", "1.0 gut").
  accent,

  /// Dim operator text (e.g. "×", "→", "=", "·", "<", ">").
  op,

  /// Dim secondary text for intermediate computed values (e.g. "0–30 g/hr").
  dim,

  /// White/bold for the final result value (e.g. "15g", "override").
  result,
}

/// A segment of a formula line with an explicit style.
class FormulaSegment {
  const FormulaSegment(this.text, {this.style = SegmentStyle.accent});

  /// Legacy constructor for backward compatibility.
  const FormulaSegment.highlighted(this.text) : style = SegmentStyle.accent;

  final String text;
  final SegmentStyle style;

  /// Convenience: is this an accent (green) or result (white) value?
  bool get isHighlighted =>
      style == SegmentStyle.accent || style == SegmentStyle.result;
}

/// Shorthand constructors for readability in service code.
FormulaSegment fAccent(String t) => FormulaSegment(t);
FormulaSegment fOp(String t) => FormulaSegment(t, style: SegmentStyle.op);
FormulaSegment fDim(String t) => FormulaSegment(t, style: SegmentStyle.dim);
FormulaSegment fResult(String t) =>
    FormulaSegment(t, style: SegmentStyle.result);

/// One line in the TL;DR formula.
class FormulaLine {
  const FormulaLine(
    this.segments, {
    this.stepNumber,
    this.isResultLine = false,
    this.showDividerBefore = false,
  });

  final List<FormulaSegment> segments;

  /// Circled step number (e.g. '①'). Null = no step number.
  final String? stepNumber;

  /// True for the final result line.
  final bool isResultLine;

  /// Show a thin divider line above this line.
  final bool showDividerBefore;
}

/// One section in the Calculation accordion — a small-caps header plus its
/// numbered formula lines. Matches the Notion/Figma layout:
///   CALCULATE EFFECTIVE SWEAT RATE
///     ① medium sweater → 1.28 L/hr (50th pct)
///     ② 22°C → × 1.0 = 1.28 L/hr
///     …
///   REPLACEMENT STRATEGY
///     ⑤ 90 min → 50% → 1.29 × 1000 × 0.50 = 645 ml/hr
///     …
class CalculationSection {
  const CalculationSection({
    required this.header,
    required this.lines,
  });

  /// Small-caps uppercase header (e.g. "CALCULATE EFFECTIVE SWEAT RATE").
  final String header;

  /// The numbered formula lines that live under this header.
  final List<FormulaLine> lines;
}

/// What kind of inline edit a Full Story section supports.
enum InlineEditType {
  none,
  gutTraining,
  personalTarget,
  // TODO(phase5): wire up knownSweatRate inline-edit UI.
  knownSweatRate,
  // TODO(phase5): wire up knownSodiumConcentration inline-edit UI.
  knownSodiumConcentration,
}

/// One Q&A section in the Full Story accordion.
class StorySection {
  const StorySection({
    required this.question,
    required this.answer,
    this.citation,
    this.transparencyNote,
    this.inlineEditType = InlineEditType.none,
    this.dataChips = const [],
  });

  final String question;
  final String answer;
  final String? citation;
  final String? transparencyNote;
  final InlineEditType inlineEditType;
  final List<String> dataChips;
}

/// All data needed to render the nutrient transparency UI for one phase
/// and one nutrient (Carbs, Fluids, Sodium, or Protein).
class NutrientTransparencyData {
  const NutrientTransparencyData({
    required this.phase,
    required this.tldrLines,
    required this.storySections,
    this.calculationSections = const [],
    this.calculationWarning,
    this.nutrientLabel = 'Carbs',
    Color? nutrientColor,
    this.primaryUnit = 'g/h',
    this.isTested = false,
    this.tldrBody,
    this.tldrTip,
    this.videoUrl,
    this.videoTitle,
    this.isSwimZero = false,
    this.swimCallout,
    this.targetGrams,
    this.rangeLow,
    this.rangeHigh,
    this.sportLabel,
    this.currentGutTrainingLabel,
    this.currentPersonalTargetGPerH,
    this.personalTargetSport,
    this.isOverrideApplied = false,
  }) : _nutrientColor = nutrientColor;

  /// Sections rendered inside the "Calculation" accordion (below the TL;DR
  /// body, above "Watch" and "The Full Story"). Empty list = don't show
  /// the accordion at all.
  final List<CalculationSection> calculationSections;

  /// Optional warning block rendered below the calculation sections
  /// (e.g. "Even at this intake you may lose ~1.5% body weight…").
  final String? calculationWarning;

  // ---------------------------------------------------------------------------
  // Theming / per-nutrient display fields
  // ---------------------------------------------------------------------------

  /// Human-readable nutrient label used in headers and chip labels.
  ///
  /// Examples: "Carbs", "Fluids", "Sodium", "Protein".
  final String nutrientLabel;

  /// Accent color for borders, formula highlights, and chip accents.
  ///
  /// Defaults to [AppColors.electrolyte] when not provided, preserving
  /// full backward compatibility with the existing carb card.
  final Color? _nutrientColor;

  Color get nutrientColor => _nutrientColor ?? AppColors.electrolyte;

  /// Primary unit label displayed alongside values in the TL;DR formula.
  ///
  /// Examples: "g/h", "ml/h", "mg/h".
  final String primaryUnit;

  /// When true, the Full Story card shows a "TESTED ✓" badge.
  ///
  /// Used for fluid cards where the athlete has lab-tested sweat data.
  final bool isTested;

  // ---------------------------------------------------------------------------
  // Core content fields (unchanged from CarbTransparencyData)
  // ---------------------------------------------------------------------------

  final String phase;

  /// Body paragraph above the formula (supports **bold** markers).
  final String? tldrBody;

  final List<FormulaLine> tldrLines;

  /// Tip line below the formula (supports **bold** markers).
  final String? tldrTip;

  final List<StorySection> storySections;
  final String? videoUrl;
  final String? videoTitle;
  final bool isSwimZero;
  final String? swimCallout;
  final double? targetGrams;
  final double? rangeLow;
  final double? rangeHigh;
  final String? sportLabel;
  final String? currentGutTrainingLabel;
  final double? currentPersonalTargetGPerH;
  final String? personalTargetSport;
  final bool isOverrideApplied;
}

// ---------------------------------------------------------------------------
// Backward-compat alias
// ---------------------------------------------------------------------------

/// Alias kept so that any transient references to [CarbTransparencyData]
/// resolve without churn. Remove when Phase 5 cleans up the old name fully.
typedef CarbTransparencyData = NutrientTransparencyData;
