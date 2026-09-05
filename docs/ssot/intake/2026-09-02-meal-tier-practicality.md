> **RESOLVED 2026-09-03 → option 1 (thread-refined a/b/e); folded to food-recommendation.md §6.** Block text as pasted (held for ADJ-1 routing confirmation): "Q1 closed by catalog-conventions A3 — embedded water counts; band discipline moves to the food-recommendation selection contract. Q2 option (b) — the DARK row adds the shortfall ceil'd to 0.5 cup, never a fixed 8 oz, never past the ceiling; fold into hydration-check.md DARK state row."

type: ruling-request
bundle: (food-recommendation ratification)

## Why this matters
The transition slice of practicality was ruled 2026-09-01 (C3/C4) but the meal-tier half — the "3 bananas as a marathon meal", "10 cups of sports drink", portion-cap family — stayed open and vanished from the desk behind the parent file's PARTIAL stamp. Split out here so it can be ruled.

## The question (items (a)(b)(d) of `intake/2026-08-31-recommendation-practicality-constraints.md`)
- **(a) Per-item practical portion caps at recommendation time** — a meal slot filled by one food ×3+ servings (probe F-29 "Banana ×3"; F-33 pinned oatmeal ×3.5). Should the selector cap single-item scaling below the row's max_servings, and/or require the meal tier to prefer composed templates over scaled singles?
- **(b) A volume/carryability budget for during-phase rows** — "10 cups Sports Drink" (2.4L) is in-band but uncarryable on a run (F-37). Cap liquid volume per hour? Prefer concentrated sources past a threshold?
- **(d) Minimum composition for a meal-tier feeding** — the 2026-08-05 drop-migration articulated "a row must be a standalone-sufficient feeding" but no spec holds a composition rule (≥2 components unless explicitly single-food-sufficient?).

## Options
Rule each as a selector-contract line in the food-recommendation spec (H-series pattern), with constants ratified (e.g. max single-item scale 2×; during liquid ≤ 800ml/h carried; meal ≥ 2 components); or explicitly ratify "macro bands only" and close.

## Gates
The food-recommendation spec's selection-quality section; P18-family close-out; F-37/F-51 dispositions.

## Suggested spec home
`spec/fueling/food-recommendation.md` (skeleton drafted 2026-09-02) §Practicality.

> **Producer note 2026-09-02 (dossier thread dc350050):** Xuan's point on (b): dropping the big
> sports-drink volume implies equal water + more gels + electrolytes, and RACES HAVE WATER STOPS —
> carrying is only the constraint in self-supported contexts, and powder-mixing at aid stations is
> the rarer pattern vs capsules/tabs taken with station water. The (b) ruling should therefore
> either scope the carry budget to self-supported sessions, or introduce a supported/self-supported
> context input (race day ⇒ course fluid assumed, carried volume budget applies only to what the
> athlete must bring). High-sodium single-serve mixes are the awkward middle; capsules mostly
> close the gap.

> **Producer note 2026-09-02 (thread, continued):** governance guard for (b) — hourly RATE caps
> belong to the ratified macro SSOTs (hydration v6 / sodium v3 / carbs v2) and must not be
> re-ratified here. The refined (b) shape proposed on the thread: (1) totals stay the SSOTs';
> (2) fluid presented in container-sized rows, never one mega-row; (3) per-sport carry budget
> (run ~1L, bike = bottles) with beyond-budget fluid labeled refill/aid-station-sourced —
> supported vs self-supported context decides the on-course assumption; (4) concentrated sodium
> forms preferred under a tight carry budget (must agree with the Q-FR3 form-preference ruling).

> **Producer note 2026-09-02 (thread, third round):**
> - **(b) carry budget WITHDRAWN** (Xuan: "not a good constraint — amounts come from science").
>   (b) narrows to: container-sized rows (no "10 cups" mega-row — the TOTAL is the hydration
>   SSOT's call; the ROW SHAPE is practicality) + per-sport FORM preference (capsule/gel over
>   mixed drinks for running; mixes suit cycling) which handles carry implicitly.
> - **NEW sub-question (e) — solvent dependency contract** (Xuan: an electrolyte/carb mix needs
>   water to dissolve, and one cup is not enough for a high-sodium stick; post-C1 the mix rows
>   carry zero water so the water must be co-scheduled). Proposed mechanism (thread): per-product
>   `solvent_min_ml` (optionally `solvent_max_ml`) — values from each product's LABEL dilution,
>   not one ratified constant; LP/selection constraint per time window: plain water ≥ Σ solvent
>   minima of concentrated products in the window; solvent water COUNTS toward the hydration
>   total (pairing, not additive demand); gels chase ~150 ml; window granularity open — start
>   same-hour. KEY TIE-IN: this supersedes C2's flat DEFAULT_PAIRING_VOLUME_ML = 250 ml (both
>   twins) — i.e. a catalog-conventions **v1.1 post-ratification addition**, not a new mechanism.

> **Producer note 2026-09-03 (thread, implementation shape for (e)):** confirmed on-thread — a NEW
> `template_foods` column `solvent_min_ml` (+ optional `solvent_max_ml`); pairing pass reads the
> column with the flat 250 ml as fallback for undeclared rows; null/zero for non-concentrated
> products; values backfilled from product-label dilutions. One schema migration + data backfill
> + the pairing/LP constraint change in both twins — rides whichever bundle the (e) ruling lands in.

> **Producer note 2026-09-03 (thread, granularity):** the interface reports session totals only —
> and the engine agrees (`by_hour_data: null`, client buckets are empty). So (e)'s CONTRACT form
> is session-total: plain water across the session ≥ Σ solvent_min_ml of scheduled concentrated
> products; same-window co-scheduling stays a solver-internal preference, promoted to an audited
> constraint only when per-window reporting exists. Vectors assert the session-total form.

> **Producer note 2026-09-03 (thread, pinned-path interaction for (e)):** pinned formulas scale
> UNIFORMLY to the carb target (composition ratio fixed as authored, 2026-06-11 decision); the
> fluid/sodium backfill adds water toward the HYDRATION target only — nothing checks the authored
> ratio against a dissolution requirement, so an under-solvated pinned formula stays under-solvated
> at every scale. The (e) solvent constraint must therefore bind the pinned path too, as a WATER
> TOP-UP (add to meet solvent minima, pin items untouched), never a re-ratio (pin fidelity).

> **Producer note 2026-09-03 (thread, (e) SCOPE NARROWED by Xuan):** keep pin/formula scaling
> exactly as-is — no solvent machinery on the pinned path ("hydration-driven water is usually
> enough to dissolve the mix; don't overcomplicate"). The (e) solvent contract applies to the
> SELECTION/solver paths only. Pins keep uniform scaling + the existing backfill.

## RULING (Xuan, 2026-09-03, RULING-DESK block — option 1, content as refined on thread dc350050)
(a) Meal tier prefers composed templates: single-item scaling capped at 2× before another template
is preferred; a meal-tier feeding has ≥2 components unless flagged single-food-sufficient.
(b) Container-sized rows (no mega-rows); totals owned by the macro SSOTs; per-sport form
preference (capsules/gels for running, mixes acceptable for cycling). Carry budget withdrawn.
(e) Solvent contract on SELECTION paths only (pins unchanged): `solvent_min_ml` column
(label-derived values, 250 ml fallback), session-total constraint (plain water ≥ Σ solvent
minima; solvent water counts toward hydration), gels chase ~150 ml.
NOTE: the block's attached text was the ADJ-1 (Q1/Q2 dark-row) response — quoted in full in the
stamp below and held for routing confirmation; it is NOT folded here.
