// Data models for the carb transparency feature.
//
// These models carry the structured content needed to render the
// TL;DR formula, video section, and Full Story Q&A in the
// PhaseExplanationSheet carb card.

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

/// What kind of inline edit a Full Story section supports.
enum InlineEditType { none, gutTraining, personalTarget }

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

/// All data needed to render the carb transparency UI for one phase.
class CarbTransparencyData {
  const CarbTransparencyData({
    required this.phase,
    required this.tldrLines,
    required this.storySections,
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
  });

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
