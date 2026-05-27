import '../../../formula_kit/domain/pin_decision.dart';
import '../../../formula_kit/presentation/widgets/pin_status_banner.dart';
import '../../domain/plan_section.dart';

/// What the activity-detail screen should render for the pin status banner.
///
/// Three possible states, derived from the plan's pin decisions:
///   - **Hidden** — `rows.isEmpty && !isOnboarding`. No pinnable phases in
///     the plan (e.g. a short walk with no Before/During section). Banner
///     stays off-screen.
///   - **Onboarding** — `rows.isEmpty && isOnboarding`. The plan has at
///     least one pinnable phase but the user has zero pins. Banner renders
///     a discovery prompt with a CTA into the Formula Library.
///   - **Status** — `rows.isNotEmpty`. The user has pins; banner renders
///     per-phase rows and the CTA. `isOnboarding` is always false here.
///
/// See `docs/features/formula-kit/PLAN.md` (PinStatusBanner V1 polish,
/// substep 11) for the rationale behind each state.
class PinBannerData {
  const PinBannerData({
    required this.rows,
    required this.isOnboarding,
  });

  /// Per-phase rows for the Status mode. Empty in Hidden and Onboarding modes.
  final List<PinStatusBannerRow> rows;

  /// True iff the plan has pinnable phases but the user has zero pins.
  /// Drives the discovery-prompt UI in [PinStatusBanner].
  final bool isOnboarding;

  /// Convenience: should the banner render at all? False for Hidden state.
  bool get shouldRender => rows.isNotEmpty || isOnboarding;

  static const hidden = PinBannerData(rows: [], isOnboarding: false);
  static const onboarding = PinBannerData(rows: [], isOnboarding: true);
}

/// Walk a plan and decide what the pin status banner should render.
/// Extracted from `activity_detail_screen.dart` so the synthesis rule is
/// unit-testable without mounting the full screen.
///
/// Algorithm:
/// 1. Scan all sections / sub-phases to find pinnable phases (Before
///    sub-phases ∈ {meal, snack, top_up} or the During section) AND
///    detect whether any carry a real [PinDecision].
/// 2. If no pinnable phases exist (short walks, etc.) → return
///    [PinBannerData.hidden].
/// 3. If pinnable phases exist but no real decisions → return
///    [PinBannerData.onboarding]. The user has zero pins; banner becomes
///    a discovery prompt.
/// 4. Otherwise emit one row per pinnable phase present in the plan:
///    real decisions render as-is; missing ones get a synthesized
///    `PinDecision(usedPin: false, pinSetSize: 0, fallthroughReason:
///    noPinForScope)` so the banner is honest about every place a pin
///    could have applied.
///
/// Pinnable phases: Before sub_phases ∈ {meal, snack, top_up}, the During
/// section, and the After section. Order matches user-facing flow.
PinBannerData collectPinBannerRows(List<PlanSection> sections) {
  bool isPinnableSubPhase(String type) =>
      type == 'meal' || type == 'snack' || type == 'top_up';

  bool isDuringSection(String id) => id == 'during_run' || id == 'during';

  // Formula Kit PR 3 substep 9 — After is pinnable now that post-workout
  // recovery templates support pins (post_system kind).
  bool isAfterSection(String id) => id == 'after_run' || id == 'after';

  bool hasAnyRealDecision = false;
  bool hasAnyPinnablePhase = false;
  for (final section in sections) {
    if (section.subPhases != null) {
      for (final sub in section.subPhases!) {
        if (isPinnableSubPhase(sub.subPhaseType)) {
          hasAnyPinnablePhase = true;
        }
        if (sub.pinDecision != null) hasAnyRealDecision = true;
      }
    }
    if (isDuringSection(section.id) || isAfterSection(section.id)) {
      hasAnyPinnablePhase = true;
    }
    if (section.pinDecision != null) hasAnyRealDecision = true;
  }

  if (!hasAnyPinnablePhase) return PinBannerData.hidden;
  if (!hasAnyRealDecision) return PinBannerData.onboarding;

  // Synthesized decision for phases the edge function didn't emit one for.
  // pin_set_size == 0 + fallthrough no_pin_for_scope → renders as
  // "No pin found" via the banner's two-state copy rule.
  const syntheticNoPin = PinDecision(
    usedPin: false,
    pinnedTemplateId: null,
    pinnedTemplateName: null,
    fallthroughReason: PinFallthroughReason.noPinForScope,
    pinSetSize: 0,
  );

  final rows = <PinStatusBannerRow>[];
  for (final section in sections) {
    // Before-phase sub-phases each carry their own decision.
    if (section.subPhases != null) {
      for (final sub in section.subPhases!) {
        final decision = sub.pinDecision;
        if (decision != null) {
          rows.add(
            PinStatusBannerRow(
              label: subPhaseLabel(sub.subPhaseType),
              decision: decision,
            ),
          );
        } else if (isPinnableSubPhase(sub.subPhaseType)) {
          rows.add(
            PinStatusBannerRow(
              label: subPhaseLabel(sub.subPhaseType),
              decision: syntheticNoPin,
            ),
          );
        }
      }
    }
    // During / After sections carry their decision at the section level.
    if (section.pinDecision != null) {
      rows.add(
        PinStatusBannerRow(
          label: sectionLabel(section.id),
          decision: section.pinDecision!,
        ),
      );
    } else if (isDuringSection(section.id) || isAfterSection(section.id)) {
      rows.add(
        PinStatusBannerRow(
          label: sectionLabel(section.id),
          decision: syntheticNoPin,
        ),
      );
    }
  }
  return PinBannerData(rows: rows, isOnboarding: false);
}

/// User-facing label for a Before sub-phase: "Meal" / "Snack" / "Top-Off".
/// Falls back to the raw `subPhaseType` for unknown values so a future
/// sub-phase doesn't render blank.
String subPhaseLabel(String subPhaseType) {
  switch (subPhaseType) {
    case 'meal':
      return 'Meal';
    case 'snack':
      return 'Snack';
    case 'top_up':
      return 'Top-Off';
    default:
      return subPhaseType;
  }
}

/// User-facing label for a section id: "Before" / "During" / "After".
/// Falls back to the raw `sectionId` for unknown ids.
String sectionLabel(String sectionId) {
  switch (sectionId) {
    case 'during_run':
    case 'during':
      return 'During';
    case 'before_run':
    case 'before':
      return 'Before';
    case 'after_run':
    case 'after':
      return 'After';
    default:
      return sectionId;
  }
}
