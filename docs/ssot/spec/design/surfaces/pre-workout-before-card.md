# Design SSOT — Surface: Pre-Workout BEFORE Card

**Status: RATIFIED v1 (Xuan, 2026-08-26).** Extracted 2026-08-26 from the reference rendering; reviewed on the spec-review page (9/9 contracts checked; S-G4 and the M-4/FC-2 rulings folded pre-ratification).
**Surface contract** — owns **composition** of the BEFORE card and the **cross-component**
behaviour (feeding membership, the delivered sum, the hydration-answer propagation, the fine
print). Component internals live in their own specs; this file **pins the component-contract
versions it composes**, the way a bundle manifest pins slices.
**Reference rendering:** [`../renderings/pre-workout@v2.html`](../renderings/pre-workout@v2.html)
(ratified Xuan 2026-08-26; frozen copy of `prototypes/pre-workout/v4.html`; supersedes @v1; all five scenarios ×
three target-states walked 2026-08-26). **Numbers authority:** `spec/fueling/pre-workout-carbs.md`
v2, `pre-workout-hydration.md` v6, `pre-workout-sodium.md` v3, `pre-workout-food-composition.md` v3.
**Reconciliation:**
[`../../../docs/design-reconciliation/pre-workout-v2-vs-pre-workout.md`](../../../docs/design-reconciliation/pre-workout-v2-vs-pre-workout.md).
**Scope:** the **BEFORE** card only — DURING and AFTER are separate surfaces, untouched (brief).

## Composition

| Component | Contract | Pinned version |
|---|---|---|
| Fuel stat (Carbs / Fluids / Sodium) | [`../components/fuel-stat.md`](../components/fuel-stat.md) | v1 (ratified) — three instances form the summary row |
| Feeding card (Meal / Snack / Top-off) | [`../components/feeding-card.md`](../components/feeding-card.md) | v1 (ratified) |
| Hydration check | [`../components/hydration-check.md`](../components/hydration-check.md) | v1 (ratified) — the first row of the SNACK card on ≥ 2 h plans |
| Tokens | [`../tokens.md`](../tokens.md) | v1 — Q-D8 / Q-D9 RULED (2026-08-26) |

The BEFORE card is one summary row (three fuel-stats) above an ordered list of feeding cards.

## Surface contracts

| # | Contract |
|---|---|
| B-1 | **Delivered is the surface's sum.** Each fuel-stat's `delivered` figure = Σ of the matching macro over every feeding card's food rows (fuel-stat consumes it; feeding-card FC-G2/FC-G3 emit it). The surface owns the total; no component computes it alone. |
| B-2 | **Feeding membership is set at plan creation by `timeBeforeWorkoutMin`, never by a clock.** ≥ 2 h → Meal · Snack · Top-off; 30 min–2 h → Snack · Top-off; < 30 min → Top-off. **No "live/now" indicator exists** (PW-021 — the planned start time is not accurate enough): every feeding renders the same regardless of wall-clock. A feeding shows when it carries carbohydrate **or** fluid; the start-line Top-off (`0 g`, 6 oz) still renders (carbs †). Authority: carbs inv. 6. |
| B-3 | **A hydration-check answer is a whole-card update.** Consuming the check's emission, the surface re-totals the FLUIDS fuel-stat and — on `dark`/`not-yet`, when not already covered — inserts the tagged water row into the SNACK feeding card, together, in one frame. The fluid **band never moves** (hydration inv. 8b); only the target marker and the delivered figure do. Authority: hydration-check H-4/H-5; PW-021. |
| B-4 | **The `?` opens the fine print** ("About these numbers") — the four `pre-workout.notes.md` §7 paragraphs verbatim. **Below 2 h this fine print is the ONLY hydration cue on the surface** (PW-021 point 3, narrowing hydration v6's "the cue rides with the number" to "one tap away"): the sub-2 h fuel-stats carry no inline cue. **Deferred this iteration — see S-G4.** |
| B-5 | **Every displayed quantity traces to a documented field** (the traceability rule). Plan totals and per-tier carbs → `carbsG`/`tiers[]`; fluid target/band → `fluidMl`/`Low`/`High`; the dark top-up → `TOPUP_ML_KG·BW`; sodium → delivered only. The surface invents no arithmetic; oz is a display unit over ml (R-01, `round(ml/29.5735)`). Per-quantity presentation is fuel-stat's; this row is the surface-wide guarantee. |

## Scope guards (this iteration)

- **S-G1:** BEFORE card only; DURING / AFTER untouched.
- **S-G2:** No live/current-window indicator anywhere (PW-021, B-2) — deliberate, not forgotten.
- **S-G3:** No progress ring, `0/N` counter, completion state or streak on fluid (`fluidLowMl = 0`;
  hydration §4; fuel-stat M-2). Deferred-not-forgotten, like macro-dashboard S-5.
- **S-G4 (Xuan, 2026-08-26, via artifact comment):** **The `?` fine print is deferred this
  iteration** — the app suppresses the control until the fine-print/explanation SSOT is made.
  Deliberate, not forgotten. B-4 states the contract the surface returns to; until then the
  `before_fine_print` golden and the `s_copy_registers` fine-print string check are **deferred**
  in the conformance manifests. The copy itself already has a ratified home
  (`pre-workout.notes.md` §7); what is pending is the dedicated SSOT, not the words. **Note:
  while the `?` is suppressed, PW-021 point 3's "the sub-2 h cue lives in the fine print" has no
  surface at all — accepted for this iteration.**

## Token rulings (were conflicts — now RULED)

Both extraction passes independently flagged two token-meaning conflicts; both are now RULED
(Xuan, 2026-08-26, option a) — the widenings live in `tokens.md`:

- **Q-D8 — RULED:** `electrolyte` widened to the **per-workout fuel side**. The surface's headline
  figures, delivered markers and the hydration-check ring may render teal. Daily intake stays
  `orange` (macro-dashboard Q-D3); the boundary is per-workout-fuel (teal) vs daily-energy (orange).
- **Q-D9 — RULED:** `dragonfruit` widened to **out-of-range caution**. The overshoot marker may
  render magenta.

The teal and overshoot goldens are no longer `blocked_on`.

## Conformance

One gestures manifest + one goldens manifest cover this surface **and its three components** (the
macro-dashboard pattern): `conformance/design/pre-workout-before-card.{gestures,goldens}.yaml`.
Surface-level flows (L2): B-1 (a stepper change re-totals the right fuel-stat); B-3 (a `dark`
answer moves the fluid target + delivered and inserts the tagged water row in one frame, band
unchanged); B-2 three-membership + no-live-clock negative; B-4 fine-print register matches notes §7.
Component flows and goldens are enumerated in the component specs and rolled into the two manifests.

---

**PHASE-CARD VISUAL PARITY — RULED (Xuan, 2026-09-01, post-ratification addition).**
The COMPACT SHARED PHASE STYLE is authoritative for every phase card's visual format on the
plan-detail screen, this surface included. The BEFORE card conforms to what DURING/TRANSITION/
AFTER already use — "the same as the rest of the page": header `sectionTitle` 18 px in the phase
colour; macro figures the shared `MacroSummaryRow` style (`dataNumber` 16 px bold — the sub-choice
in the intake resolves to *exactly the shared size*, not a compromise 18); food-row icons = the
shared per-food colour disc + white glyph.
**AMENDED (Xuan, 2026-09-01, same day): the Add Food button is EXCLUDED from the parity change** —
the BEFORE card keeps its ratified dashed "+ Add Food" pill exactly as FC-7 specifies (which also
means feeding-card v1 needs no erratum; the original (a) button swap would have contradicted FC-7).
Scope of the change is therefore: header + macro figures (font family, size, weight) + food-row
icons. No ratified CONTRACT changes anywhere: fuel-stat v1 (F/M rows) carries no sizes; feeding-card
v1 (FC rows incl. FC-7) is untouched; bands, states, captions, and copy are untouched.
**Rendering supersession:** `renderings/pre-workout@v2.html`'s typography/format (Sansita 22/30 px
hero, dashed pill, orange-disc stroke glyphs) is SUPERSEDED for this surface by this ruling — the
HTML stays as the historical v2 record; the app's regenerated goldens are the reference for
phase-card format from here (the screenshot test owns sizes). No new prototype HTML is
commissioned. Note for the register: Kyle is the external brand source (source-authority rule 2c),
not an approver — the intake's "visible to Kyle" caution is satisfied by this record.
Source: `intake/2026-09-01-before-card-visual-parity-with-during.md`, option (a).
Gates the app-side change + `pre_workout_before_card_goldens_test` regeneration (commit citing
this ruling) + a `/design-sync` run after it lands. Recommend point re-tag
`pre-workout-macros@v2.1` once folded (ship-bundle's act).
