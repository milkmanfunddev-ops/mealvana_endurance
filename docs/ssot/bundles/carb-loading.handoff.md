# carb-loading@v1 — coding-agent handoff (standing implementation contract)

Authority order: `bundles/carb-loading.yaml` (the frozen manifest, tag `carb-loading@v1` @
`f809f54`) → this handoff → the pinned specs. `done_when` is the manifest's, verbatim: **every
G1–G16 red below is green, both vector slices pass through the runner, and the mirror
byte-identity check passes against the tag's commit.** No deferred ledger exists (first
version — nothing carried).

## Port prompt (design)
This is a PORT of the ratified design, not a redesign. Reference rendering = app
`.scratch/carb-loading/prototype/fuel-timeline-standalone.html` **v22**, app commit `e559dfd7`,
bundle sha256/16 `f1c232d958a98bfe` (verify before porting). Screenshot side-by-side loop for
static fidelity; `spec/design/` for everything screenshots can't hold — read
`surfaces/carb-loading-dashboard.md` (CD-1..6), `surfaces/carb-loading-entryway.md`,
`components/carb-slot-card.md`, `components/energy-card.md` §LOAD-face (Q-D9 form: E1 toggles),
`tokens.md` (glow rules; D7 electrolyte exception; every other carb figure orange).
**Inventory existing components before writing any widget** (glass surfaces, pills, provenance
chips, Add Food shell, Formula Kit, Log-a-Meal path) — the slot page is ruled a COMPOSITION of
shipping surfaces; new pixels are only the slot header + Logged section. Goldens are ratification
artifacts: regenerate only after a spec change, never to green a red.

## Build items → their REDs (done_when covers this WHOLE table)
| Gate | Build item | The red that turns green |
|---|---|---|
| G1 | D-021 mapper fix | DONE (app 30a972fc; keep the unit test green) |
| G2 | Pace-ramp engine (CL-5..11, Option-R anchors + 22:00 clamp) | `carb-loading.json` ramp/band/completion/variants (46) via new runner arm |
| G3 | 1-Day protocol (chooser card + generator @11.0) | `protocol-1day` vectors + chooser L2 |
| G4 | Point-value copy everywhere (CL-12/§2a) | register L2 rows + qa-smoke drawer ⇄ engine check |
| G5 | LOAD face (Q-D9 expanded form) + breakdown page + chips + CE-7 footer | energy-card L1 goldens (collapsed+expanded × today/future/past) + CD-map L2 |
| G6 | Edited-target rederivation incl. clamp | `edited-day-target` vectors |
| G7 | Two-state entry row + plan summary PAGE | L2 `entry-row-two-state`, `summary-opens-plan-surface` |
| G8 | Post-selection → event details, conditional today-CTA snackbar | L2 `post-select-stack-shape` |
| G9 | CE-8 feasibility gate + F5 re-check at selection | `chooser-feasibility` vectors (carb-loading-entryway.json) + L2 |
| G10 | Re-pick migration (CE-4/4a, F3 target-relabel+date, F4 single-notice) | `repick-migration` vectors + dialog L2 rows |
| G11 | Delete UI (dragonfruit, Path-A copy) | L2 `delete-plan-food-survives` |
| G12–G15 | Desk reversals (PAGE-only, dialogs, footer, subtitle) | walked green in v20–v22; pin with L2/goldens at implementation |
| G16 | CE-9 backdrop-abort, both re-pick dialogs (delete confirm keeps its own Cancel — out of scope) | L2 `repick-dialog-backdrop-abort`, `repick-notice-backdrop-abort` (negative: plan unchanged) |
| — | Mirror re-sync `$APP_ROOT/docs/ssot` to the TAG commit + SSOT_SOURCE pin | run_dart.sh byte-identity check (currently red; approval pending Xuan) |

## Verified conflict watchlist (grep/file-checked at ship, 2026-09-25)
1. **GREENFIELD conformance**: zero `carb-loading` references in `qa/conformance/` — the Dart
   harness + runner arms are built red-first WITH the engine (matching-slice precedent).
2. **Tests pinning superseded behavior**: `test/features/carb_loading/carb_loading_service_test.dart`
   and `test/features/calendar/calendar_service_test.dart` + `test/smoke_tests/nutrition_plan_smoke_test.dart`
   reference the delete+recreate `updateCarbLoadingProtocol` / legacy day page — they pin the
   OLD edit path that CE-4/CE-4a retire. Update them to the ruled contract; do not keep both green.
3. **Legacy surfaces needing a deliberate fate**: `carb_loading_day_detail_page.dart` (the
   one-shot pushReplacement target — release-1 routes must stop landing on it),
   `carb_loading_day_card.dart` + `portal_athlete_detail_panel.dart:488` (both read the
   writer-less `logged_carbs_grams`, D-020), the audit's six dead-code widgets. Retire or
   re-point; silence is not a decision.
4. **Call sites the rulings touch**: `event_action_buttons_card.dart:83-93/186-253` (entry row,
   CREATE pushReplacement, EDIT path) — the entryway spec replaces all three behaviors.
5. **Twins/parity**: engine is app-side pure Dart for v1 (no edge twin yet); when a server twin
   appears it joins the D-005 parity discipline — do not fork constants (lb→kg 0.453592 pinned).
6. **Goldens**: 1 existing carb-related golden reference — audit and regenerate only per spec.
7. **Producer/consumer inventory** (fields the new surfaces READ):

| Field | Producers | Shapes actually written | Existing consumers + their rule | New consumer's rule |
|---|---|---|---|---|
| `carb_loading_days.carbTargetGrams` | repo create (round(rate×kg)); Edit Target dialog (athlete value) | int, may diverge from rate×kg after edit | legacy day page (displays); coach portal (denominator) | CL-4a: STORED value drives slots/checkpoints/copy — never re-derive from protocol when edited |
| `carb_loading_days.*_percent` (split) | Drift defaults (fractions); server sync via mapper (D-021-fixed fallback) | fractions 0.25…0.05; server rows carry explicit values | none read them today for display | CL-4 slot targets = round(split × stored target); watch the fraction-vs-percent seam the mapper test now pins |
| `logged_carbs_grams` / `completed` | **NONE** (D-020 — deliberate defect, synced anyway) | always 0 / false | legacy card + coach portal read them (show 0) | **DO NOT READ.** Eaten derives from food-log rows (CL-11); these columns retire with implementation |
| food-log rows (carbs, per day) | Log-a-Meal path (+ new slot tag) | ordinary entries; slot tag NEW and optional | timeline, daily macros (sum all) | CL-11/Q-CL8: eaten = ALL day logs, tagged or not; slot cards sum only tagged — divergence is BY DESIGN |
| `events.carbLoadingStartDate` | service create ONLY (not on event create) | null until a plan exists | notification seam (future) | CE-8 uses raceDate−today, NOT this field — it can't gate a chooser for a plan that doesn't exist yet |
| body weight (lb) | profile | lb; kg = lb × 0.453592 in repo | repo create | same constant; a server twin later must use 0.453592, not 0.45359237 — seam test with producer-shaped stored data required (no hard asserts; tolerance + log) |

## Baseline (Step 4c answers, recorded per the rule)
1. Ruled metric? The pace mechanic is ship-to-learn (S7); its metric is real-athlete logging
   behavior. 2. Measurable without the new code? **No** — no engine exists; nothing to run.
3. Persuasive number pre-code? No. **No baseline captured — by answered decision, not omission.**

## Completion
`done_when` verbatim (manifest). Land is a SEPARATE gated step (land-bundle): green + Xuan's
dev attestation; Xuan is also the explicit checkpoint there. Release train note: the app release
carrying this bundle must also carry the Q-019 `loading-day-macros-coupling` bundle (or ship
with the gap NAMED) — release-coupled, not tag-coupled.
