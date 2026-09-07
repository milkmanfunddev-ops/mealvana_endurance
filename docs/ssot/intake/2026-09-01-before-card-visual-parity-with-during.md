> **RESOLVED 2026-09-01 → RULED option (a) AS AMENDED same day: compact shared style wins for the header + macro figures (shared 16 px exactly) + food-row icons; the Add Food button is EXCLUDED — the dashed FC-7 pill stays (no feeding-card erratum needed). Fold: spec/design/surfaces/pre-workout-before-card.md ruling block; re-tag pre-workout-macros@v2.1 recommended**

---
type: ruling-request
bundle: pre-workout-macros@v2 (design SSOT: surfaces/pre-workout-before-card v1, components/fuel-stat v1, components/feeding-card v1)
raised-by: Xuan, 2026-09-01, during the brick-transition@v1 dev smoke test
status: open
---

# The BEFORE card looks like a different app from the DURING / TRANSITION cards — unify?

## Why this matters

On the plan-detail screen the BEFORE (pre-workout) card was ported faithfully from Kyle's
`renderings/pre-workout@v2.html` (app commit `8ecb23f5`, 2026-08-26). Every other phase card on the
same screen — DURING, TRANSITION, AFTER — still uses the older shared phase-section style. Seen
together on one screen (screenshot taken 2026-09-01 on the dev build, a RUN→BIKE brick), the BEFORE
card reads as a hero and the rest read as compact, and the difference is not a meaning-bearing one:
none of the contracts in fuel-stat v1 (states, bands, markers, captions F-1/F-2, M-1…M-3) or
feeding-card v1 (FC-1…FC-7) depend on the sizes, the button shape, or the icon family.

Xuan's wish (verbal, 2026-09-01): the BEFORE card should take the same visual format as the other
phases — header, figures, Add Food button, icons. Because the BEFORE look is *Kyle's* ratified
rendering, this cannot be an app-side edit: it is either a spec change (rendering + surface spec)
or a ruling that the rendering is a one-off and the app-wide phase style wins.

## What is different today (measured in the app, not in the rendering)

| Element | BEFORE card (kyle_design, ratified) | DURING / TRANSITION / AFTER (shared phase section) |
|---|---|---|
| Section header | `pre_workout_before_card.dart` — Sansita 700 **22 px**, orange, "BEFORE BRICK" | `during_phase_section_widget.dart:270` — `AppTextStyles.sectionTitle` at **18 px** in the phase colour |
| Macro figures | `FuelStat` (`fuel_stat.dart:64`) — Sansita 700 **30 px** figures, Apercu 11 labels (80g / 12oz / 263mg) | `MacroSummaryRow._valueStyle` non-prominent — `dataNumber` **16 px bold**; the legacy `prominent` path (Lee, `e357b821`, 2026-08-05) was `pageTitle` 24 px |
| Add Food | `feeding_card.dart` `_AddFoodButton` — **dashed** orange pill, 44 px, text "+ Add Food", Sansita 700 14 (FC-7) | `KyleAddFoodButton` (`kyle_design/buttons/add_food_button.dart`) — **solid** 2 px orange outline, `AppRadius.buttonRadius`, FontAwesome plus + "ADD FOOD" in `buttonPrimary` bold |
| Food-row icon | 36 px **orange** disc with a **blackberry stroke** `FuelingGlyph` (drop / bowl / bar / chew paths, `fueling_glyphs.dart`) | `expandable_food_item_widget.dart:242` — `AppIconSizes.foodIcon` disc **coloured per food** (`getFoodIconColor`) with a **white Material/FontAwesome** icon (`getFoodIcon`) |
| Collapsed feeding row | orange ">" chevron, no icon | n/a (DURING rows are not tiered) |

Provenance: the BEFORE hero sizes are from `8ecb23f5` (Xuan + Claude, the pre-workout-macros@v2
port), reproducing the rendering with the Compadre→Sansita fallback ruled in
`2026-08-26-compadre-demo-cut-cannot-render-design-lowercase.md`. Nothing on the
brick-transition@v1 branch touched these; the TRANSITION card was deliberately built on the
*shared* phase style (transition-card v1 TC-1…TC-5), which is why the gap is now visible on a
brick plan.

## The question

Which side of the seam is authoritative for the *visual format* of a phase card on the plan-detail
screen?

- **(a) DURING style wins — the BEFORE card conforms.** Header → `sectionTitle` 18 px in orange;
  figures → the shared `MacroSummaryRow` figure style (bold `dataNumber`; proposal: 18 px so BEFORE
  is neither hero nor smaller than DURING's 16 — or exactly 16, Kyle's call); Add Food →
  `KyleAddFoodButton` ("ADD FOOD", solid outline); row icons → the DURING chip (per-food colour
  disc + white glyph), keeping the FuelingGlyph paths only if Kyle wants them as the glyph set
  app-wide. The rendering `pre-workout@v2.html` and the surface spec's typography then get a v2
  note; fuel-stat v1 / feeding-card v1 contracts are untouched (they carry no sizes).
  **Recommended by Xuan.**
- **(b) BEFORE style wins — the other phases lift to it.** Sansita headers/figures, dashed pill,
  orange-disc stroke glyphs across DURING/TRANSITION/AFTER. Larger blast radius (touches the
  transition-card v1 goldens just ratified in brick-transition@v1 and every existing phase golden).
- **(c) Keep as is** — the rendering is the contract and the BEFORE card is intentionally a hero.
- **(d) Split ruling** — e.g. typography per (a) but keep the FuelingGlyph icon set and promote it
  to the DURING rows as well, so the icon family unifies on Kyle's glyphs while the sizes unify on
  the shared style.

Whichever way it goes, this needs to be visible to **Kyle**, because (a) and (d) depart from his
ratified rendering.

## What it gates

- The app-side change (a separate branch off `develop`, not the brick-transition branch): FuelStat
  + BEFORE header + `MacroSummaryRow` prominent path + `_AddFoodButton` + feeding-row icon —
  all in `lib/shared/widgets/kyle_design/` and the BEFORE surface widget, with their header
  citations bumped to the new spec version.
- Golden regeneration for `pre_workout_before_card_goldens_test` (and, under (b)/(d), the
  transition-card and macro-dashboard goldens) — goldens regenerate only with a commit message citing
  this ruling.
- A `/design-sync` run (Xuan-invoked) after the library change lands.
- Not gated: brick-transition@v1 attestation / land-bundle — this is orthogonal to the transition
  numbers and can land before or after.
