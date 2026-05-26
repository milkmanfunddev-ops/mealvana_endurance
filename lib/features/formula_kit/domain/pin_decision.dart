/// Reason a pin was supplied but did not fire for a given phase / sub-phase.
///
/// - [noPinForScope] — pinsActive but no in-scope pin matched this workout's
///   activity × duration_bracket × time_window.
/// - [pinnedTemplateUnrenderable] — in-scope pin was selected by the solver
///   but the renderer returned null (e.g. a required component food was
///   missing from the loaded food pool). Option A guard added for After in
///   PR 3 #35 follow-up so the wire never claims `usedPin: true` while the
///   section actually served LP foods.
///
/// Reserved as an enum so future fall-through reasons can be added without
/// breaking parsers.
enum PinFallthroughReason {
  noPinForScope('no_pin_for_scope'),
  pinnedTemplateUnrenderable('pinned_template_unrenderable');

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
  });

  /// True iff the algorithm selected a pinned template for this phase. When
  /// true, all preference / allergen / diet / gut-training / scale-clamp
  /// filters were bypassed (honor-pin policy).
  final bool usedPin;

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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'used_pin': usedPin,
      'pinned_template_id': pinnedTemplateId,
      'pinned_template_name': pinnedTemplateName,
      'fallthrough_reason': fallthroughReason?.wireValue,
      'pin_set_size': pinSetSize,
    };
  }

  @override
  String toString() =>
      'PinDecision(usedPin: $usedPin, id: $pinnedTemplateId, '
      'name: $pinnedTemplateName, fallthrough: $fallthroughReason, '
      'setSize: $pinSetSize)';
}
