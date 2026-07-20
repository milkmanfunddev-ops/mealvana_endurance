/// Reason a pin was supplied but did not fire for a given phase / sub-phase.
///
/// - [noPinForScope] — pinsActive but no in-scope pin matched this workout's
///   activity × duration_bracket × time_window.
/// - [pinnedTemplateUnrenderable] — in-scope pin was selected by the solver
///   but the renderer returned null (e.g. a required component food was
///   missing from the loaded food pool). Option A guard added for After in
///   PR 3 #35 follow-up so the wire never claims `usedPin: true` while the
///   section actually served LP foods.
/// - [personalFormulaEmpty] — a pinned PERSONAL formula matched scope but
///   rendered zero components (e.g. an empty/corrupt `components` array),
///   so the section fell through to the normal algorithmic selection. Item
///   12 (personal formulas silently dropped), 2026-07-04.
///
/// Reserved as an enum so future fall-through reasons can be added without
/// breaking parsers.
enum PinFallthroughReason {
  noPinForScope('no_pin_for_scope'),
  pinnedTemplateUnrenderable('pinned_template_unrenderable'),
  personalFormulaEmpty('personal_formula_empty');

  const PinFallthroughReason(this.wireValue);

  /// String emitted by the edge function and stored in the JSON-blob plan.
  final String wireValue;

  static PinFallthroughReason? fromWireValue(String? value) {
    if (value == null) return null;
    for (final reason in PinFallthroughReason.values) {
      if (reason.wireValue == value) return reason;
    }
    // Forward-compat: ignore unknown fall-through reasons rather than throw.
    // A new server-side reason on an old client just renders as "no detail".
    return null;
  }
}

/// Why a pinned personal formula the user authored for this phase was
/// excluded from it.
///
/// - [activityOutOfScope] — the formula's activity list doesn't include this
///   workout's sport.
/// - [durationOutOfScope] — the sport matched, but the workout's duration
///   bracket isn't one the formula targets. The common case: a "90-150 min"
///   cycling formula on a 75-minute ride.
enum SkippedFormulaReason {
  activityOutOfScope('activity_out_of_scope'),
  durationOutOfScope('duration_out_of_scope');

  const SkippedFormulaReason(this.wireValue);

  final String wireValue;

  static SkippedFormulaReason? fromWireValue(String? value) {
    if (value == null) return null;
    for (final reason in SkippedFormulaReason.values) {
      if (reason.wireValue == value) return reason;
    }
    return null;
  }
}

/// One personal formula that was dropped from a phase, with the reason.
///
/// Added 2026-07-18 (see `docs/architecture/formula-not-honored-audit-2026-07-18.md`).
/// Before this existed, a scope-excluded personal formula produced no signal:
/// when an unrelated system pin fired afterwards the wire reported
/// `usedPin: true` naming THAT pin, so the banner showed a green "pinned
/// formula used" state for a formula the user never chose.
class SkippedPersonalFormula {
  const SkippedPersonalFormula({
    required this.id,
    required this.name,
    required this.reason,
    this.formulaDurations = const [],
    this.workoutBracket,
  });

  final String id;
  final String name;
  final SkippedFormulaReason? reason;

  /// Duration brackets the formula targets, e.g. `['90-150 min']`.
  final List<String> formulaDurations;

  /// Bracket this workout resolved to, e.g. `'< 90 min'`. Null when unknown.
  final String? workoutBracket;

  factory SkippedPersonalFormula.fromJson(Map<String, dynamic> json) {
    return SkippedPersonalFormula(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Your formula',
      reason: SkippedFormulaReason.fromWireValue(json['reason'] as String?),
      formulaDurations:
          (json['formula_durations'] as List<dynamic>?)?.cast<String>() ??
              const [],
      workoutBracket: json['workout_bracket'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'reason': reason?.wireValue,
        'formula_durations': formulaDurations,
        'workout_bracket': workoutBracket,
      };
}

/// Pin honoring telemetry for one phase / sub-phase of a generated plan.
///
/// Mirrors the edge function `pin_decision` wire shape (see PLAN.md PR 2
/// substep 5b / 9). Populated by the algorithm only when the user had pins
/// supplied at plan generation; otherwise the field is absent.
///
/// Stored inline on [BeforeSubPhase] (one per sub-phase) and [PlanSection]
/// (the During section gets one) — persisted as part of the JSON blob on
/// `activities.nutrition_plan_data`, so no Drift schema migration is needed.
class PinDecision {
  const PinDecision({
    required this.usedPin,
    required this.pinnedTemplateId,
    required this.pinnedTemplateName,
    required this.fallthroughReason,
    this.pinSetSize = 0,
    this.ephemeral = false,
    this.skippedPersonalFormulas = const [],
  });

  /// True iff the algorithm selected a pinned template for this phase. When
  /// true, all preference / allergen / diet / gut-training / scale-clamp
  /// filters were bypassed (honor-pin policy).
  final bool usedPin;

  /// True when [usedPin] was satisfied by the EPHEMERAL default-formula
  /// safety net (a best-fit system formula chosen at generation time)
  /// rather than a real `formula_pins` row. Lets the UI distinguish "we
  /// picked a formula for you" from "you pinned this" and, if desired, nudge
  /// the user to pin it. False for real pins and for legacy plans. Formula-
  /// first flip, 2026-07-03.
  final bool ephemeral;

  /// ID of the template that was honored, when [usedPin] is true.
  /// Null when [usedPin] is false.
  final String? pinnedTemplateId;

  /// Display name of the honored template (e.g. "Bagel + Jam"). Lets the
  /// activity-detail banner render the pinned formula's label without an
  /// extra lookup. Null when [usedPin] is false.
  final String? pinnedTemplateName;

  /// Why a pin did not fire. Null when [usedPin] is true.
  final PinFallthroughReason? fallthroughReason;

  /// Count of in-scope pinned candidates the algorithm saw for this phase.
  /// 0 when pins were supplied but none matched scope. Drives the
  /// `plan_used_pin` / `plan_pin_fallthrough` analytics payload. Defaults to
  /// 0 for plans persisted before substep 7 (legacy `pin_decision` shape).
  final int pinSetSize;

  /// Personal formulas the user authored for this phase that were excluded by
  /// activity or duration scope.
  ///
  /// Independent of [usedPin]: a system pin can legitimately fire ([usedPin]
  /// true) while the user's own formula was still dropped. Both facts must be
  /// shown, which is what the banner's info affordance is for. Empty on legacy
  /// plans and whenever nothing was skipped.
  final List<SkippedPersonalFormula> skippedPersonalFormulas;

  /// True when the user authored a formula for this phase that didn't apply.
  bool get hasSkippedFormulas => skippedPersonalFormulas.isNotEmpty;

  factory PinDecision.fromJson(Map<String, dynamic> json) {
    return PinDecision(
      usedPin: json['used_pin'] as bool? ?? json['usedPin'] as bool? ?? false,
      pinnedTemplateId: json['pinned_template_id'] as String? ??
          json['pinnedTemplateId'] as String?,
      pinnedTemplateName: json['pinned_template_name'] as String? ??
          json['pinnedTemplateName'] as String?,
      fallthroughReason: PinFallthroughReason.fromWireValue(
        json['fallthrough_reason'] as String? ??
            json['fallthroughReason'] as String?,
      ),
      pinSetSize: (json['pin_set_size'] as num?)?.toInt() ??
          (json['pinSetSize'] as num?)?.toInt() ??
          0,
      ephemeral: json['ephemeral'] as bool? ?? false,
      skippedPersonalFormulas: ((json['skipped_personal_formulas'] ??
                  json['skippedPersonalFormulas'])
              as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(SkippedPersonalFormula.fromJson)
          .toList(growable: false) ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'used_pin': usedPin,
      'pinned_template_id': pinnedTemplateId,
      'pinned_template_name': pinnedTemplateName,
      'fallthrough_reason': fallthroughReason?.wireValue,
      'pin_set_size': pinSetSize,
      'ephemeral': ephemeral,
      if (skippedPersonalFormulas.isNotEmpty)
        'skipped_personal_formulas':
            skippedPersonalFormulas.map((f) => f.toJson()).toList(),
    };
  }

  @override
  String toString() =>
      'PinDecision(usedPin: $usedPin, ephemeral: $ephemeral, '
      'id: $pinnedTemplateId, name: $pinnedTemplateName, '
      'fallthrough: $fallthroughReason, setSize: $pinSetSize)';
}
