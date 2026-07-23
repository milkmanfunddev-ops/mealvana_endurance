# Fuel Timeline — Refactor Plan

**Decisions (Lee, 2026-06-25):**
- New **unified day screen**, **full replacement** of the current Nutrition tab (`DailyMacrosScreen`, tab index 1).
- The **AI "Suggest" feature is deferred** to a later iteration (suggest toggle, suggested-meal cards, and the filter-specific "Today's Fuel" insight box are all out of scope for v1).
- **Timeline = flat chronological feed.** No forced meal categories — log anything, any number of times (two lunches is fine); each entry lands on the timeline by the time eaten. The old breakfast/lunch/dinner/snack **`slot` stays in the data** (so existing logs + sync keep working) but is **auto-filled from time-of-day** and the picker becomes **optional** (user may tag a category if they want; never required).
- **Workout fueling stays separate from food logging.** Recovery/pre/during fuel lives inside the activity's Ride Fuel sheet (the After-ride window), not as a meal category. Logging food = a general timeline entry; no prompt to attach it to a nearby workout.
- **Burned = prorated by time of day** (resting + daily-activity scaled by elapsed day, plus workout once done). Edge cases (my call): **past days = full day** (not prorated); **future days = targets only**, no "burned yet".
- **Tracking on/off = a GLOBAL user preference** (persisted in `PreferencesService`, default ON).
- **Follow the prototype design exactly**, without regard to how the current screens look. Where the prototype differs from today's UI, the prototype wins. The exception is *destinations of actions* (below), which reuse existing infrastructure rather than the prototype's mock sheets.
  - **Add Activity** → routes to our **existing New Activity screen** (the activity-creation flow), not a mock.
  - **Add Food / log a meal** → uses our **existing add-food / meal-logging infrastructure** (`showTabbedLogSheet` + meal_logging service), not the prototype's mock Add Food sheet. Slot picker is optional (auto-derived from time).
- **Refine plan first** — no implementation until the plan/spec are agreed.

Companion docs:
- `FUEL_TIMELINE_SPEC.md` — exact design/behavior reproduction spec (built from clicking through the prototype).
- Prototype: `docs/new_activity/New Activity page v9 - smaller dashboard footprint/`.

---

## 1. The core insight: this is an *assembly* job, not a from-scratch build

Almost every data source the prototype needs already exists. The new screen is a new **presentation layer** over existing controllers/repositories, plus one new day-level aggregator and a couple of new widgets.

| Prototype element | Existing source to reuse |
|---|---|
| Week strip / BY WEEK·MONTH / month nav | `calendar_week_view_kyle.dart`, `calendar_month_view_kyle.dart`, `calendar_view_toggle.dart`, `calendarSelectedDateProvider` |
| Energy dashboard (intake / burned / targets) | `DailyMacroTargets` (`tdee, rmr, sessionKcal, neatKcal, carbG/protG/fatG`) + `consumedTotalsForDateProvider` |
| Energy Breakdown sheet (Daily TDEE rows) | `EnergySourceBreakdown` widget (RMR + NEAT + Session = TDEE, Garmin badges) |
| Energy Breakdown sheet (Weekly chart) | `DailyMacrosState.weeklyMacros` (7-day cache) — **new chart widget needed** |
| Meal timeline nodes (logged foods) | `mealLogsForDateProvider` (`MealLog`: slot, name, calories, macros, `eatenAt`) |
| Add Food sheet (search + quick add) | `showTabbedLogSheet()` (Recent/Favorites/Search/Describe/Manual) + `SlotChipSelector` |
| Swap / Remove on a meal | `MealLogRepository.softDelete()`, edit flow, `/swap-food` |
| Workout/ride node | `Activity` (type, distance, speed, `scheduledDateTime`) + activities-for-date query |
| Ride Fuel Sheet (Before/During/After) | `NutritionPlan.sections` (PlanSection before/during/after) + `FuelLogData` + `activity_detail_controller` (`saveFuelLogAndComplete` = "Complete Workout") |
| Macro colors | `macro_palette.dart` — already matches the prototype tokens |
| Coach insight entry | Keep existing `JadeCoachBanner` for v1 (prototype's AI insight box is deferred) |

**What's genuinely new:**
1. A **day-level aggregator** that interleaves meals + activities on one time axis and computes the energy-balance summary.
2. The **Fuel Timeline screen** + its widgets (header dashboard, filter row, timeline rail, node cards).
3. **Tracking on/off** mode (no current equivalent).
4. The **Weekly periodization chart** in the Energy Breakdown sheet.
5. **Timeline-restyled** Ride Fuel / Energy / Add Food sheets.

---

## 2. Key reconciliations between prototype and real data

These need a deliberate call during the build (defaults proposed):

1. **No forced slots — chronological feed (DECIDED).** The prototype's 5 groups (incl. "Recovery") are *not* the model. Build the timeline as a **flat chronological list** of entries ordered by time: each `MealLog` by `eatenAt` (fallback `createdAt`), each `Activity` by `scheduledDateTime`, interleaved. The user can log the same thing twice; nothing is bucketed. The `MealLog.slot` field stays (DB CHECK unchanged) but is **auto-derived from `eatenAt` time-of-day** on log; the `SlotChipSelector` in `TabbedLogSheet` becomes **optional** (collapsed by default; user can expand to tag a category). "Recovery" is the ride's After window inside the activity, not a timeline category.

2. **Node ordering / times.** Order the unified list by `eatenAt`/`scheduledDateTime`. Entries with no time fall back to `createdAt`. The left "time rail" shows that time. No empty-slot rows (there are no slots to be empty).

3. **"Burned" number — prorate by time of day (DECIDED).** Burned = (resting `rmr` + daily-activity `neatKcal`) **scaled by fraction of day elapsed**, **plus** `sessionKcal` for workouts already completed (full value once done). **Net intake = eaten − burned.** Pin the exact proration formula + how "elapsed" is defined for past/future days (past days = full day; future days = targets only) in Phase 1 before wiring the dashboard.

4. **Per-item macro line on meal cards** (`574 kcal · 58C · 30P · 25F`). `MealLog` carries denormalized totals → use directly.

5. **Add Food sheet.** Prototype shows a stripped search+quick-add. We already have the richer `TabbedLogSheet` (5 logging methods incl. photo/describe/Jade). → **Reuse `TabbedLogSheet`, restyled** to the timeline look. Make `SlotChipSelector` **optional/collapsed** (slot auto-derived from time-of-day); don't force a category choice.

6. **Tracking on/off.** New concept: when off, hide the energy dashboard and strip macro numbers from cards ("log without numbers"). → Persist as a **global user preference** in `PreferencesService` (default ON). Single source of truth, read by the screen + meal cards.

7. **Web layout.** Tab shell has a web NavigationRail variant + a Coach tab. The new screen must keep working under both (`tabs_screen.dart`). Build responsive from the start (CLAUDE.md responsiveness rule).

---

## 3. Architecture (FOA)

New feature module: `lib/features/fuel_timeline/` (presentation + application + domain). Reuse existing data layers (no new repositories; the meal/activity/macro repos already exist).

```
fuel_timeline/
  domain/
    timeline_node.dart          # sealed: MealNode | WorkoutNode (time, payload)
    day_energy_summary.dart     # eaten/target cals+macros, burned breakdown, net
    fuel_timeline_filter.dart   # enum: all | workout | meals
  application/
    day_timeline_assembler.dart # pure: (meals, activities, macros, consumed) -> nodes + summary
  presentation/
    screens/fuel_timeline_screen.dart      # UI-only: composition, state read, nav
    providers/
      fuel_timeline_controller.dart        # @riverpod AsyncNotifier: aggregates the day
      fuel_timeline_view_state.dart        # filter, dashOpen, trackingOn, timelineOpen
    widgets/
      day_header_bar.dart            # reuse calendar week/month + segmented + gear
      energy_dashboard_card.dart     # collapsible; All/Workout/Meals variants
      fuel_filter_row.dart           # segmented + tracking/timeline toggles (no AI for v1)
      timeline_rail.dart             # left time column + dotted rail
      meal_node_card.dart            # logged meal; expand -> Swap/Remove
      workout_node_card.dart         # ride card -> opens Ride Fuel sheet
    sheets/
      ride_fuel_sheet.dart           # wraps activity_detail (Before/During/After)
      energy_breakdown_sheet.dart    # Daily (EnergySourceBreakdown) + Weekly chart
      weekly_fuel_chart.dart         # new line chart over weeklyMacros
```

**Controller** composes existing providers (don't refetch): `calendarSelectedDateProvider`, `dailyMacrosControllerProvider`, `mealLogsForDateProvider`, `consumedTotalsForDateProvider`, and an activities-for-date provider. The **`day_timeline_assembler` is pure** (easily unit-tested) — feed it the four inputs, get back ordered `TimelineNode`s + a `DayEnergySummary`.

---

## 4. Phased build

**Phase 0 — Scaffolding & decisions (small)**
- Create the `fuel_timeline` module skeleton + domain types.
- Lock the reconciliations in §2 (slots, burned definition, tracking persistence).
- Add `trackingOn` to `PreferencesService` (default true).

**Phase 1 — Day aggregator (domain/application, test-first)**
- `DayEnergySummary` + `TimelineNode` models.
- `DayTimelineAssembler` pure function + unit tests (interleave ordering, empty-slot omission, energy math, tracking-off masking).
- `fuel_timeline_controller` wiring existing providers → assembler output.

**Phase 2 — Screen scaffold, tracking ON, filter = All**
- `fuel_timeline_screen` with: day header (reuse calendar), energy dashboard (collapsed + expanded "Energy Balance"), filter row (All/Workout/Meals + tracking + timeline toggles), Add Food/Add Activity buttons, and the timeline list rendering real meal + workout nodes.
- Wire `Add Food` → `showTabbedLogSheet`, `Add Activity` → existing new-activity route.

**Phase 3 — Node interactions + dashboard variants**
- Meal card expand → Swap (`/swap-food`) / Remove (`softDelete`).
- Workout card → Ride Fuel sheet.
- Dashboard Meals variant (macro bars) + Workout variant (active energy) + collapse/expand chevron.
- Filter gating (All/Workout/Meals hides nodes + Add buttons per spec).

**Phase 4 — Sheets**
- Ride Fuel sheet over `activity_detail_controller` (Before/During/After, Swap/Remove/Add Food per window, "Complete Workout" → `saveFuelLogAndComplete`).
- Energy Breakdown sheet: Daily (reuse `EnergySourceBreakdown`) + Weekly periodization chart (new `weekly_fuel_chart` over `weeklyMacros`).

**Phase 5 — Tracking off mode + timeline rail toggle + polish**
- Tracking off: hide dashboard, strip macro lines from cards.
- Timeline rail show/hide (collapse time column).
- Theming to `macro_palette` / `AppColors`, content strings via ContentService (no hardcoded user-facing copy), responsiveness (mobile pill nav + web rail), `MealvanaSnackbar`.

**Phase 6 — Cut over (full replacement)**
- Swap `DailyMacrosScreen` → `FuelTimelineScreen` in `tabs_screen.dart` (tab 1) + `app_router.dart` (`?tab=nutrition`).
- Migrate/retire `daily_summary_card`, `today_log_section`'s host screen, etc. Keep reused widgets (`EnergySourceBreakdown`, `TabbedLogSheet`, `JadeCoachBanner`).
- Run codegen (riverpod), `/task-checker`, widget + golden tests, then commit on the feature branch.

**Deferred (later iteration) — AI Suggest**
- Suggest toggle, suggested-meal cards (dashed-orange, Add to plan/Dismiss), and filter-specific "Today's Fuel" insight box. Leave seams: the assembler can later emit `suggested` nodes; the filter row has space for the sparkle toggle; the insight box slots above the timeline. Until then keep the existing `JadeCoachBanner` as the coach entry point.

---

## 4b. Build status (2026-06-25)

Phases 1–6 implemented on the feature branch under `lib/features/fuel_timeline/`. Tests: `test/features/fuel_timeline/` (14 unit + 3 widget smoke) all green; analyzer clean.

- **Phase 1** ✅ pure aggregator (`DayTimelineAssembler`, `DayEnergySummary` w/ prorated burn, `TimelineNode`, filter) + unit tests.
- **Phase 2** ✅ screen scaffold wired to real data; swapped into the Nutrition tab (`tabs_screen.dart` index 1). Add Food → `showTabbedLogSheet`; Add Activity → `/distancepacegut`.
- **Phase 3** ✅ Meals + Workout dashboard variants; meal tap → Swap (`/meal-log/edit`) / Remove (soft-delete + undo).
- **Phase 4** ✅ Energy Breakdown sheet (Daily reuses `EnergySourceBreakdown` + Weekly chart `weekly_fuel_chart.dart`); workout tap → existing fuel screen via shared `openActivityFuel()` helper (Lee's choice). Per-activity burn = `sessionKcal` (single-workout common case).
- **Phase 5** ✅ tracking → global `PreferencesService.fuelTrackingEnabled`; widget smoke tests (caught + fixed 2 overflow bugs); ContentService for content strings (`fuel_timeline.*`, `energy_breakdown.*`, `common.retry`) with fallbacks. Look kept **theme-aware** (Lee's call). Leaf micro-labels stay hardcoded (consistent with sibling screens).
- **Phase 6** ✅ functional cut-over verified (no prod imports of `DailyMacrosScreen`; `?tab=nutrition` → Fuel Timeline). Re-added `GarminConnectBanner` + `JadeCoachBanner` (Lee wanted both kept). **File deletion DEFERRED until after on-device validation.**

**Deferred-deletion manifest** (orphaned in prod once validated — KEEP the reused ones):
- DELETE candidates: `daily_macros/presentation/screens/daily_macros_screen.dart`, `widgets/daily_summary_card.dart`, `widgets/today_hero_card.dart`, `widgets/macro_summary_strip.dart` — plus update/remove the 4 referencing tests (`test/smoke_tests/auth_misc_smoke_test.dart`, `test/features/daily_macros/daily_macros_screen_layout_test.dart`, `test/seeded_tests/daily_macros_content_test.dart`, `test/features/daily_macros/macro_card_screenshot_test.dart` + its goldens).
- **KEEP (reused by Fuel Timeline):** `daily_macros_controller`/state/service, `energy_source_breakdown.dart`, `macro_palette.dart`, `garmin_connect_banner.dart`, `jade_coach_banner.dart`, `meal_logging/today_log_section.dart`, all `calendar/*` widgets.

**Still TODO:** on-device/simulator shakedown (can't be assistant-run); then the deletion pass; then the deferred **AI Suggest** feature.

## 5. Risks / watch-items
- **Full replacement** means the Nutrition tab is the new screen from cut-over — keep the branch shippable per phase and don't merge until Phase 6 + `/task-checker` pass. (Memory note: never wholesale-copy `codemagic.yaml`.)
- **Energy-balance semantics** (burned proration, net intake sign) are the most likely thing to "look wrong" — pin exact formulas in Phase 1 with Lee.
- **Slot/time model** — meals without `eatenAt` need a sensible fallback for rail ordering (use `createdAt`).
- **Offline-first** — all writes already go through local-first repos; keep that (no direct Supabase writes from the screen).
- **Web parity** — the Coach tab + NavigationRail must not break.

---

## 6. Open questions for Lee (non-blocking; defaults chosen)
- **Resolved:** timeline = chronological feed w/ optional slot; food/fuel separate; burned = prorated; full replacement; AI deferred.
1. **Tracking on/off:** global preference (recommended) or per-day?
2. **Proration edge cases:** for *past* days show full-day burned (not prorated)? For *future* days show targets only / no "burned yet"? (Proposed: yes to both.)
3. Anything to **preserve** from today's Daily Macros screen that the prototype drops — e.g. the energy-availability `eaStatus` warning, Garmin attribution badges on the energy breakdown? (Proposed: keep both, surfaced in the Energy Breakdown sheet.)
