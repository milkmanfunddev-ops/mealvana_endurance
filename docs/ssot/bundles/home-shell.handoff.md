# Coding-agent handoff — `home-shell@v1`

Standing implementation contract. Checkout the tag; the manifest
(`bundles/home-shell.yaml`) is the index. Authority order: **manifest → this handoff → the
specs**; where anything disagrees with the archived export, **the specs and tokens §Materials
win**.

## 1 · Where the truth lives

- Tag: `home-shell@v1` (qa repo, branch `qa/home-shell`). Point re-tag cut alongside:
  `daily-macros-dashboard@v3.2` (tokens.md §Materials + macro-dashboard.md staged
  recomposition — re-pin your mirror there for the dashboard bundle).
- Specs: `spec/design/components/{tab-bar,date-header,calendar-sheet}.md` (all v1),
  `spec/design/tokens.md` §Materials, `spec/design/surfaces/macro-dashboard.md`
  §home-shell recomposition (STAGED — applies to the NEW screen only).
- Conformance: `conformance/design/home-shell.gestures.yaml` (21 tests, TBD pins to fill) +
  `conformance/design/home-shell.goldens.yaml` (11 goldens, canonical mock month pinned).
- Companion artifact: `spec/design/renderings/home-shell-export-2026-09-06.html` —
  **ILLUSTRATIVE, not a ratified rendering.** Ruled divergences where the export loses:
  compact header row = `glass` recipe (not its blur-14 fade); tab-switch refraction +
  drag-tracking (not drawn in it at all — the property-based spec is the only truth).
- App handback (mirror re-sync + sequencing): `intake/2026-09-06-home-shell-handback.md`.

## 2 · The port prompt (static fidelity — for what the export DOES draw)

This is a port, not a redesign. The archived export above is the visual reference for layout,
hierarchy and content of the three in-scope areas — use its exact values where the ratified
tokens/specs don't override them (they override for: header-row material, scrim, anything the
specs name).

1. Preserve visual hierarchy exactly: element order, which item carries the highlight, text
   alignment.
2. Do not substitute, remove, or "improve" any in-scope content.
3. If real app data conflicts with static content in the export, ask before changing anything.

Verification loop per screen state: implement → simulator screenshot → side-by-side vs the
export → list every discrepancy → fix → re-capture until the list is empty (excepting the ruled
divergences above, which must match the SPEC, not the export).

**SCOPE FENCE:** the export also contains AI elements (companion pill + 4 modes, sparkle
suggestion toggle + dashed cards, Add-to-Dinner sheet, chat sheet, Ride Fuel Plan editor). ALL
deferred/parked — implement none of them, port none of their code, leave no dead affordances.

## 3 · Design-SSOT addendum (what screenshots can't hold)

- Every state/gesture row in the three specs, **including the negatives** (tb7 slot-empty, dh5
  no-horizontal-swipe, cs2 snap-back, cs7 SKIPPED→no-dot, cs8 engine-planned-not-tinted).
- Tokens by MEANING: no `dragonfruit` anywhere on the calendar surface; `electrolyte` dots are
  per-workout, `orange` rings are planned; glass highlights cream-based, never full-opacity #fff.
- Materials from ONE registry: constants land in `lib/theme/kyle_design/` beside
  app_colors/app_spacing — no second token class, no inline alpha values.
- Goldens regenerate only after a spec change; regeneration commits cite it.
- Gesture-manifest TBD pins: the commit that lands each widget REPLACES the TBD with the
  implemented value in `home-shell.gestures.yaml` (qa repo). A surviving TBD fails the audit.

## 4 · Verified conflict watchlist (terrain recon, greps run 2026-09-06)

1. **Update, not greenfield — the tab bar.**
   `lib/shared/widgets/kyle_design/navigation/floating_action_buttons_bar.dart` exists and
   already uses a `BackdropFilter`. Rework it (or supersede it deliberately on the new screen);
   don't build a parallel bar and leave two.
2. **Nothing pins the current bar.** Zero tests/goldens reference it (grep of `test/`
   verified). Nothing breaks when you change it — and nothing guards it: the home-shell
   manifests are its FIRST guard. Don't infer safety from green.
3. **`kyle_tab_pill.dart` is shared** by `log_meal_screen`, `food_screen`,
   `vana_conversations_screen`. If the bar rework touches the pill component, those three
   screens ride along — verify them or fork the component deliberately.
4. **`features/calendar/` is OUT OF SCOPE.** `calendar_month_view_kyle.dart`,
   `calendar_week_view_kyle.dart`, events, carb-loading protocol screens: untouched. The sheet
   supersedes only the home surface's BY MONTH view. Unifying the two calendars needs a ruling,
   not an initiative.
5. **The current home header** is
   `lib/features/fuel_timeline/presentation/widgets/fuel_timeline_day_header.dart` — replaced
   by DateHeader on the NEW screen only; the shipped screen keeps it until switchover.
6. **Day-key for calendar dots: call the existing resolver.**
   `lib/features/macro_dashboard/domain/dashboard_models.dart:49` — `displayTime` =
   `actual_time ?? planned_time` (two-time model). Do NOT re-derive day assignment. If the
   resolver is too coupled to reuse, EXTRACT it — a copied resolution is the bug class the
   inventory below exists to stop. Note: the engine buckets by `scheduled_date_time` and that
   divergence is an OPEN ruling (`intake/2026-08-20-engine-session-bucketing-day-key.md`) —
   the calendar follows the DISPLAY rule, same as the dashboard.
7. **Dashboard suites must not move.** This bundle adds contracts; the daily-macros vectors
   (172 raw) and design manifests (18 gesture tests, 10 goldens) are untouched. A count change
   after the mirror re-sync is a sync defect, not a spec change.

### Producer/consumer inventory (7) — fields the new surfaces READ

| Field | Producers (who writes it) | Shapes actually written | Existing consumers + how each resolves it | New consumer's rule |
|---|---|---|---|---|
| workout day-of-cell (dot slot) | sync (measured start → `actual_time`), mark-done (`= planned_time`, Q-D7), creation (`planned_time`) | `actual_time` nullable; two-time model tests pin `= planned_time` on mark-done, measured on sync | dashboard: `displayTime` (`actual ?? planned`, dashboard_models.dart:49); engine: `scheduled_date_time` (DIVERGENT — open intake 2026-08-20) | `displayTime` day, via the existing resolver (extract if unreachable). Never `scheduled_date_time` |
| workout state (dot glyph) | Skip/Unskip/mark-done/sync write `status` + `actual_time` per workout-card.md v3 | `status ∈ {planned, skipped, deleted}`; passive SKIPPED is DERIVED (day past ∧ actual null ∧ status ≠ skipped), never written | dashboard cards derive per workout-card.md | same derivation, incl. derived passive SKIPPED → **no dot**. Best-state fold for multi-workout days |
| meal log rows (tint slot) | `meal_logging` service → `MealLog` rows with **typed `MealLogSource` enum** (meal_log.dart) | denormalised totals from DB columns; source always present | intraday eaten_kcal (`daily_macros/intraday_display.dart`) sums them | presence-count per day: **any `MealLog` row counts** (every source is the athlete's). **VERIFY:** no plan-generation path writes meal_log rows — if one does, STOP and file a ruling-request; engine-planned items must NOT tint |
| per-day fueling rollup | **does not exist** — this bundle builds the derivation | n/a | none | client-side derivation over MealLog rows grouped by the daily-macros day boundary. If made server-side instead, that adds a deploy-coupled response field — flag before building |

**Seam tests:** the rollup and dot derivations get tests fed **producer-shaped rows**
(repository fixtures built the way the producers write them — nullable `actual_time`, derived
passive SKIPPED), never rows recomputed by the consumer on both sides. No hard `assert` on
stored data: tolerance + log (the 2026-08-26 BEFORE-card precedent), and one test through the
real controller per write path.

## 5 · Baseline (step 4c) — asked and answered

1. Ruled metric this bundle should move? **No** — pure design/contract; no rate, funnel or
   shortfall is named by these specs. 2. Measurable pre-implementation? n/a. 3. Would a number
   persuade? n/a. **No baseline; recorded here so the skip is deliberate.**

## 6 · Deferred ledger

No `bundles/home-shell.deferred.md` exists — v1 carries no prior ledger. The manifest's
`excludes` list is the complete named-out-of-scope set (AI elements, editor, slot occupant,
tint scaling, light glass, events-calendar feature).

## 7 · Done

`done_when` in `bundles/home-shell.yaml`, verbatim. Then: `/design-sync` on the new screen,
flip the feature-test-plan rows, and run the sim-explore charter
(`.claude/skills/sim-explore/references/charter-home-shell.md`) on the first dev build that
claims green.
