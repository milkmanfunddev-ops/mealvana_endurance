/**
 * Formula-decision telemetry — the single vocabulary for "where did this
 * phase's formula come from?".
 *
 * Context (2026-07-29): the client no longer pre-computes auto-pins at
 * onboarding / in settings. Every phase now resolves its formula at plan
 * generation time on the edge path, which makes the NO-PIN case the common
 * path rather than a rare branch. Three outcomes must be distinguishable:
 *
 *   - `user_pin`         — a real `formula_pins` row (system template) fired.
 *   - `personal_formula` — a real pinned user-authored personal formula fired.
 *   - `default_formula`  — no pin was in scope, so the phase's own ranked
 *                          system-template tier picked a best-fit formula.
 *                          This is the "default formula" tier and it is what
 *                          most users get.
 *   - `solver`           — no formula was renderable at all, so the rule / LP /
 *                          greedy solver produced the foods.
 *
 * Before this existed, a computed default was reported on the wire as
 * `used_pin: true, ephemeral: true` with `fallthrough_reason: null`, which
 * conflated "the user pinned this" with "we picked this for the user" and
 * threw away the reason no pin fired. `used_pin` / `ephemeral` are kept
 * exactly as they were for wire compatibility (the Dart `PinDecision` model
 * and `pin_banner_rows_builder` both read them); the honest signal rides
 * alongside in `decision_source` + `default_fallthrough_reason`, which older
 * parsers ignore.
 *
 * There is deliberately NO ranking logic in this file. Each phase owns its own
 * ranking (during: `selection_priority` + preference score; after: travel /
 * prep; before: Algorithm C's `pickBestFormula`) and those rankings are what
 * actually render. A second, parallel "default formula ranking" used to live in
 * `_shared/nutrition/default-formula.ts`; it was orphaned, had already drifted
 * from the after-phase's shipped travel/prep order, and was deleted on
 * 2026-07-29 so exactly one ranking implementation exists per phase.
 */

/** Where a phase's rendered formula came from. */
export type FormulaDecisionSource =
  | "user_pin"
  | "personal_formula"
  | "default_formula"
  | "solver";

/** Minimal structural shape shared by every phase's `pin_decision` literal. */
export interface FormulaDecisionLike {
  used_pin: boolean;
  ephemeral?: boolean;
  pinned_template_id: string | null;
  pinned_template_name: string | null;
  fallthrough_reason: string | null;
  pin_set_size: number;
}

/** Fields this module adds on top of the legacy `pin_decision` shape. */
export interface FormulaDecisionAnnotations {
  /** Honest provenance. Additive — old clients ignore it. */
  decision_source: FormulaDecisionSource;
  /**
   * Why no real pin fired, preserved for `default_formula` / `solver`
   * outcomes. The legacy `fallthrough_reason` must stay `null` whenever
   * `used_pin` is true (the Dart model documents that invariant and the
   * banner's copy rule depends on it), so the reason rides here instead of
   * being discarded.
   */
  default_fallthrough_reason?: string | null;
}

/**
 * Tag an existing `pin_decision` literal with its provenance without changing
 * any legacy field. Returns a new object; never mutates the input.
 */
export function withDecisionSource<T extends FormulaDecisionLike>(
  decision: T,
  source: FormulaDecisionSource,
  defaultFallthroughReason?: string | null,
): T & FormulaDecisionAnnotations {
  return {
    ...decision,
    decision_source: source,
    ...(defaultFallthroughReason != null && {
      default_fallthrough_reason: defaultFallthroughReason,
    }),
  };
}

/**
 * Classify a decision that came from a REAL pin. System-template pins and
 * personal-formula pins are both "the user asked for this", but the banner and
 * analytics want them apart.
 */
export function realPinSource(isPersonalFormula: boolean): FormulaDecisionSource {
  return isPersonalFormula ? "personal_formula" : "user_pin";
}

/**
 * Build the `pin_decision` for a COMPUTED DEFAULT formula (no pin in scope,
 * but the phase's ranked system-template tier produced a formula).
 *
 * `used_pin: true` + `ephemeral: true` are retained verbatim from the
 * pre-2026-07-29 shape so no client behavior changes: the Dart banner already
 * treats `ephemeral` decisions as invisible, and analytics already skip them.
 * The truthful provenance is in `decision_source`.
 */
export function defaultFormulaDecision<S = never>(args: {
  templateId: string;
  templateName: string;
  pinSetSize: number;
  /** Reason a real pin didn't fire; preserved rather than discarded. */
  fallthroughReason?: string | null;
  /** Personal formulas dropped by scope, carried through untouched. The
   * element type is generic so each phase keeps its own typed shape — this
   * helper never needs to know it. */
  skippedPersonalFormulas?: S[];
}): {
  used_pin: true;
  ephemeral: true;
  decision_source: "default_formula";
  pinned_template_id: string;
  pinned_template_name: string;
  /** Always null: the legacy field must stay null while `used_pin` is true. */
  fallthrough_reason: null;
  default_fallthrough_reason: string;
  pin_set_size: number;
  skipped_personal_formulas?: S[];
} {
  return {
    used_pin: true,
    ephemeral: true,
    decision_source: "default_formula",
    pinned_template_id: args.templateId,
    pinned_template_name: args.templateName,
    fallthrough_reason: null,
    default_fallthrough_reason: args.fallthroughReason ?? "no_pin_for_scope",
    pin_set_size: args.pinSetSize,
    ...(args.skippedPersonalFormulas &&
      args.skippedPersonalFormulas.length > 0 &&
      { skipped_personal_formulas: args.skippedPersonalFormulas }),
  };
}

/**
 * Always-on cascade log — emitted regardless of `emit_ephemeral_default_formula`
 * and regardless of whether a `pin_decision` reaches the wire.
 *
 * This is the regression tripwire for Lee's requirement that the no-pin path
 * must never silently degrade into the solver: every phase exit logs exactly
 * one `[FORMULA-CASCADE]` line naming its source, so a plan that fell to the
 * solver is greppable in the edge logs even for a client that opted out of
 * ephemeral telemetry.
 */
export function logFormulaCascade(args: {
  /** "before:meal" | "during" | "during:segment-2" | "after" | "transition:T1" */
  phase: string;
  source: FormulaDecisionSource;
  templateId?: string | null;
  templateName?: string | null;
  /** Why no real pin fired (for default_formula / solver). */
  reason?: string | null;
  pinSetSize?: number;
}): void {
  const parts = [
    `phase=${args.phase}`,
    `source=${args.source}`,
    `pins_in_scope=${args.pinSetSize ?? 0}`,
  ];
  if (args.templateName || args.templateId) {
    parts.push(`formula=${args.templateName ?? "?"}(${args.templateId ?? "?"})`);
  }
  if (args.reason) parts.push(`reason=${args.reason}`);
  const line = `[FORMULA-CASCADE] ${parts.join(" ")}`;
  // Solver means NO formula rendered for this phase — that is the outcome we
  // never want to happen silently, so it is a warning, not an info log.
  if (args.source === "solver") console.warn(line);
  else console.log(line);
}
