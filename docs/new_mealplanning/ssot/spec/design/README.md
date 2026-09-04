# spec/design/ — meal-planning design SSOT

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.** Same discipline as
`docs/ssot/spec/design/` (the QA repo's design family): the **screenshot test** decides what lives here — only
what a side-by-side screenshot cannot hold (state machines, gestures and their data writes, suppressions, token
*meaning*, cross-component propagation, persistence, copy registers, number traceability). Layout, radius,
type and colour values are **screenshot-held** by the reference renderings and are deliberately absent.

**Reference renderings (candidates, per `source-authority.md` §3 — nothing here is a ratified rendering yet):**
- the prototype itself (`mealplanning-prototype/packages/web`, `styles/{tokens,kyle}.css` = exact Dart values);
- `../../design-screens/previews/*.html` (Kyle-styled screens, 2026-08-27) and `../../design-system/previews/`;
- the canvas https://claude.ai/code/artifact/c776e4cd-1e7f-4f7a-8c71-a6a2d332ec21 (v2, 2026-08-26);
- the app's regenerated goldens (`test/features/meal_planning/presentation/widget_goldens_test.dart`).
When they disagree visually, the prototype wins (update plan §8).

**Tokens:** the app's Kyle registry is authoritative — `docs/ssot/spec/design/tokens.md` (RATIFIED v1) + the
Q-D8/Q-D9 widenings. [`tokens.md`](tokens.md) here adds only the meal-planning **meaning contracts** (slot
colours, the selection accent) on top of it.

## Library

| Component | Contract | Status |
|---|---|---|
| [`components/meal-picker.md`](components/meal-picker.md) | the 3-meal carousel: tap = pick, tick state, "Other options" | RECORDED |
| [`components/meal-card.md`](components/meal-card.md) | default / selected / excluded / in-plan / yours; the why + attribution line; macros behind `show_macros` | RECORDED |
| [`components/plan-bar.md`](components/plan-bar.md) | minimized ↔ expanded, tiles with ×/stepper, Review gate, collapse-on-turn | RECORDED |
| [`components/plan-tile.md`](components/plan-tile.md) | the Plan-tab tile: swipe right = swap, left = remove (undo), tap = sheet, edit mode | RECORDED |
| [`components/choice-chips.md`](components/choice-chips.md) | model chips vs client-drawn picker chips; single-pick spent state; detail rows | RECORDED |
| [`components/staples-card.md`](components/staples-card.md) | ticked = in the draft; log-only rows are inert | RECORDED |
| [`components/shopping-list.md`](components/shopping-list.md) | aisle groups, checked vs have, share | RECORDED |
| [`components/cooking-mode.md`](components/cooking-mode.md) | overview → steps → done; timers; alarm; wake lock; thumb | RECORDED |
| `docs/ssot/spec/design/components/macro-pill-row.md` | kcal · C · P · F fact strip (app-authored, PROPOSED v1, 2026-09-03) | cited, not restated |
| `docs/ssot/spec/design/components/selectable-chip-grid.md` | multi-pick grid + `+` (the pantry card) — PROPOSED v1 | cited, not restated |

| Surface | Composes | Status |
|---|---|---|
| [`surfaces/vana-planning-chat.md`](surfaces/vana-planning-chat.md) | transcript order, picker chips, plan bar, review sheet, confirmed card, status lines, intro card, edit/rewind | RECORDED |
| [`surfaces/vana-general-chat.md`](surfaces/vana-general-chat.md) | empty state, no plan bar, narration suppression | RECORDED |
| [`surfaces/food-plan-tab.md`](surfaces/food-plan-tab.md) | Vana message (day note), the plan list, no-plan state with staples, confirm | RECORDED |
| [`surfaces/food-meals-catalog.md`](surfaces/food-meals-catalog.md) | Mine/Library, chips, semantic search, detail, thumb, save, add ×N | RECORDED |
| [`surfaces/food-shopping.md`](surfaces/food-shopping.md) | the list tab | RECORDED |
| [`surfaces/vana-settings.md`](surfaces/vana-settings.md) | batch cooking, show macros, reminders (dark), the memory drawer | RECORDED |

## Lifecycle

PROPOSED → reconcile against the renderings (`design-spec-reconcile`) → Xuan ratifies → the rendering is
copied to `docs/ssot/spec/design/renderings/<name>@v1.html` → goldens are blessed → `/design-sync`. A golden may
only be regenerated after a spec here changes — never to make a red test pass.

## Conformance

The app's meal-planning suites: goldens (`widget_goldens_test.dart`), widget tests under
`test/features/meal_planning/presentation/widgets/`, two Patrol flows (plan build; chat), all run by
`scripts/run-meal-planning-tests.sh`. No `conformance/design/*.yaml` manifests exist yet for this family — Q-DS1.
