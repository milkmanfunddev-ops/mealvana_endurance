> **RULED 2026-09-03 (late, Xuan): option (a) is REPLACED by parity — personal formulas follow the library-card contract exactly (FP-4d).** Rationale, verified in code: the engine honors a personal formula only when PINNED (`pins.ts` resolvePersonalFormulaPins), so the "standing auto-include" premise behind FP-4c was false. Pre-pin warning + post-pin collapsible label with Unpin, same as library cards; no persistent label while unpinned. The plan-card surface (option b) remains OPEN.

# Intake — persistent conflict labeling on saved personal formulas

- **Raised:** Xuan, on-device 2026-09-03 (evening, formula-pin-surface bundle testing)
- **Status:** PARTIALLY RULED (Xuan on-device, 2026-09-03 evening): library-card label + glyph dot = YES, not gated on pinning (now FP-4c); FP-8 disclosure placement amended to top-of-screen. STILL OPEN: the plan-card surface when a conflicting personal formula is served in a generated plan.
- **Spec family:** design (formula-pin-surface.md FP-7/FP-8/Q-FP2 tail) × policy
  (food-recommendation.md §1a labeled override)

## The find (and the defect it exposed — already fixed)
"Make this mine" on Cottage Cheese + Applesauce, athlete has a dairy allergy → the
forked personal formula showed NO conflict anywhere. Root cause was an app defect
against the RULED FP-8 contract, not a spec gap: `componentsForFork` built component
maps without the kAllergens/kExcludedDiets metadata (only the +Add Food path stamped
it), so the save-time disclosure's detection saw nothing. **Fixed 2026-09-03** on
`feature/food-recommendation-v1`: forks stamp the metadata at source AND the editor
backfills it on load for formulas persisted without it (rescues old forks);
regression test `test/features/formula_kit/fork_conflict_metadata_test.dart`. The
FP-8 conformance test passed throughout because it exercised the +Add Food
component shape only — fork-shaped components were never under test.

## The ruling actually needed (the part FP-8 does not cover)
FP-8 rules the SAVE-MOMENT disclosure. Personal formulas are standing
auto-includes ("Mealvana will always include your own formulas") — the closest
thing to a permanent pin — yet once saved they carry **no persistent label** on
any surface: not on the Your Formulas library card, not in the editor outside the
save moment (the disclosure does render there while editing — is that enough?),
and no FP-4b-style label on plan cards that render a conflicting personal formula.
Q-FP2's tail ("save-time for personal formulas remains to be drawn") was answered
by v4 for the save moment only; the persistent-label question was never drawn.

Xuan's stated instinct (2026-09-03): the label **should still show** on the saved
formula. Options to rule:
  a) FP-4b analog on the personal formula's library card + editor header
     (dragonfruit collapsed one-liner, "Contains dairy — your allergy").
  b) Also on plan-detail cards whenever a personal formula with a conflict is
     served (§1a "the card must label any conflict visibly" read broadly).
  c) Save-moment + in-editor disclosure is sufficient (status quo post-fix).
Xuan's instinct excludes (c); the a-vs-a+b scope and the exact surfaces/copy need
the design pass + ruling.

## Interim app behavior (until ruled)
The RULED FP-8 disclosure now fires correctly (fork + editor paths), including
every time the formula is reopened for editing. No persistent card label ships
ahead of the ruling — surfaces and copy are undrawn.
