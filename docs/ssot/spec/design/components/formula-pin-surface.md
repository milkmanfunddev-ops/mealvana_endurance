# Design SSOT — Formula-pin surface (plan-detail banner + rows)

**Status: RATIFIED (Xuan, 2026-09-03).** Contracts FP-1..FP-9 including the conflict-label system (FP-4a pre-pin, FP-4b post-pin, FP-7 detail disclosure with the emphasis rule, FP-8 authoring save-time). Reference rendering: `prototypes/formula-kit/v4.html` (candidate; promotion to `spec/design/renderings/` is a separate act). Reconciliation: `docs/design-reconciliation/formula-kit-v3-vs-formula-pin-surface.md` (v3 + v4 passes). Evidence:
`runs/2026-09-03-design-recording/pin-banner-ref.png` (expanded banner, probe film 2026-08-31).
Wire authority: `pin_decision` (used_pin / fallthrough_reason / skipped_personal_formulas —
audit-hardened 2026-07-18). Policy authority: `food-recommendation.md` §1/§1a (labeled override,
RULED). Prototype lineage: `prototypes/formula-kit/formula-kit-v2.html` (candidate only, per
source-authority §3).

## Contracts
| # | Contract |
|---|---|
| FP-1 | Plan-detail pin banner, collapsed states: **"Some pins honored, some skipped · N honored · M skipped"** (mixed) · **"Pin didn't apply to this workout · No in-scope pin for this activity"** (none applied) · **"Pin formulas you love"** (no pins exist — invitation). Pin glyph leads; chevron expands. |
| FP-2 | Expanded: one row per scope (Meal · Snack · Top-Off · During · After): ✓ + formula name when honored; ⓘ + "No pin found" otherwise. CTA **"Pin your favorite formula →"**. Rows derive strictly from the `pin_decision` wire — never invented client-side; an ephemeral default-formula decision renders as NO pin row (it is not the user's pin). |
| FP-3 | **[copy defect, recorded]** "M skipped" counts scopes with no pin at all — "skipped" implies pins existed and were passed over. See Q-FP1. |
| FP-4a | **PRE-PIN warning (RULED Xuan, 2026-09-03; design: formula-kit v3):** pinning a formula that conflicts with the athlete's profile shows an INLINE in-card warning at the decision moment — never a modal. **Allergy conflict:** full warning naming the allergen ("This formula contains gluten, which you've listed as an allergy. Pinning it means Mealvana will always include it.") with two actions. **Diet conflict (RULED R-02 option 1):** a SOFTER one-line note, no interrupting action pair — e.g. "Doesn't match your keto preference." **Emphasis (RULED R-01 option 1): "Choose another" is the filled primary; "Pin anyway" is the outline** — the safer default carries the visual weight; the pin stays one tap away. |
| FP-4b | **POST-PIN label (RULED Xuan, 2026-09-03):** an honored conflicting pin carries a persistent, COLLAPSIBLE label in `dragonfruit` (Q-D9-conformant): collapsed = one line ("Pinned despite your gluten allergy"); expanded = the policy sentence ("Pins always win: this formula stays in your plans even though it conflicts with the profile you added later.") + **Keep pin / Unpin**. The pin glyph carries a conflict dot. Answers the allergies-changed-after-pin case: the pin persists, labeled, never auto-unpinned. |

| FP-5 | **Formula Library screen** (reached via the banner CTA / pin glyph): title "Formula Library"; phase tabs Before · During · After; timing chips Meal · Snack · Top-up; **"Your Formulas · + New"** — the personal-formula authoring entry; Library cards = name + time-window chip + composition line + macro chips (C · P · F · Na) + per-card pin toggle. Renders the LIVE catalog, never mock rows. Evidence: `runs/2026-09-03-design-recording/11-formula-kit-app.png`. |
| FP-6 | **Prototype caution (verified in-browser 2026-09-03):** `prototypes/formula-kit/formula-kit-v2.html` does NOT match as-built — "Formula Kit" title, no After tab, no Your Formulas section, chevron cards, mock template data. The conflict-label iteration must reconstruct from the current screenshots, not iterate that file. |

| FP-7 | **Formula detail view** (card tap-in): title + "Make this mine" (fork to personal) + pin glyph; chips (window · digest speed · tier); macro grid CAL/CARBS/PROTEIN/FAT/SODIUM/FLUID (fluid shows embedded water per A3); COMPONENTS list; OPTIONAL ADD-ONS; NOTES; **DIETARY section — UPGRADED (design v4, 2026-09-03):** allergen chips + diet chips in human copy (no machine strings). **Emphasis rule (S-04): an allergen the athlete HAS renders personalized and emphasized ("Contains gluten — your allergy", dragonfruit); an allergen they do NOT have renders neutral ("Contains peanut"); diet exclusions render neutral ("Not Keto").** Evidence: as-built `13-oatmeal-detail.png` (pre-upgrade) → `prototypes/formula-kit/v4.html` (target). |
| FP-8 | **New-formula authoring** ("Your Formulas · + New"): Name · Phase · Timing (required) · live macro tally · Add Food · Notes · Save formula. **Save-time conflict disclosure (design v4, 2026-09-03):** a component conflicting with the athlete's profile renders above Save — allergy: full note naming the food and allergen, ending "You can still save — Mealvana will always include your own formulas."; diet: the softer one-liner. **Save is never disabled** (disclose-never-block, §1a). Evidence: `prototypes/formula-kit/v4.html`. |
| FP-9 | **Coach insight — OUT OF THIS BUNDLE (Xuan, 2026-09-03).** The authoring screen's "Coach insight" expander belongs to the AI-coach feature, not the pin surface: this spec neither owns nor asserts it, conformance never checks it, and the implementation must not build it as part of this bundle. It ships in a LATER version (its own bundle) or not at all — that call is deferred. Its presence in `prototypes/formula-kit/v4.html` is prototype chrome, not a contract (S-05). |

## Open questions
| Q | Question | Blocks |
|---|---|---|
| Q-FP1 | STILL OPEN (copy only, non-blocking): replace "M skipped" with honest counts ("N honored · M scopes without a pin") | banner copy |
| Q-FP2 | RULED by the v3 design (Xuan, 2026-09-03): **BOTH** — pre-pin warning (FP-4a) AND persistent post-pin label (FP-4b). Save-time for personal formulas (FP-8) remains to be drawn | — |
| Q-FP3 | PARTLY delivered by v3 (chips now read "Not Keto", not "Not keto"/"Not gluten_free"); still open: allergen chips with personalization on the detail screen | FP-7 copy |

## Conformance
Goldens: three collapsed states + expanded row set. Widget: FP-2 wire-derivation (ephemeral
decisions render no pin row — the F-31 guard); FP-4 label presence on a conflicting honored pin
(post-design). Copy register per FP-1.
