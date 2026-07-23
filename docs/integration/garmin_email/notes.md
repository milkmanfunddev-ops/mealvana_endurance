# Session Resume Notes — Garmin Response + Iter 5

> Companion to `implementation_plan.md`. Read both before resuming.

## What to prime a new session with

Paste this into the first message of a fresh Claude Code session at `/Users/leemartin/development/mealvana_endurance`:

```
Please resume work on the Garmin production-review response and Daily Macro Calc Iteration 5.

Read these first (in order):
1. /docs/integration/garmin_email/implementation_plan.md (the full plan)
2. /docs/integration/garmin_email/notes.md (this file — context I already gathered)
3. /docs/integration/garmin_email/response.png (Elena's latest email with her asks)

Start with Phase 1: authorize Notion MCP (mcp__notion__authenticate), then pull the root page
"Daily Macro Calculation" (326e3fdb754c80199486c17ecf9947cd) and mirror into /docs/macro_calculations.
Proceed through phases per the plan. Use AskUserQuestion only when something material changes.
```

## Exact text of Elena's email (from /docs/integration/garmin_email/response.png)

> 1. Please use Garmin Connect logo
> [image of "GARMIN Connect" pill badge + "AUTHENTICATING APPLICATIONS" excerpt from brand guidelines]
>
> 2. I see utilization of Activity API. How Training and Health API being used?
>
> Best Regards / Freundliche Grüße / Cordialement
> Elena Kononova
> Garmin Connect Partner Services

She's responding to evaluation-key screenshots Lee sent on Apr 22 (see `/docs/integration/garmin_email/our_screenshots/`). Her prior ask (Apr 8, full text at `Production Review for _Milkman Inc__ Requirements, Ticket_ 206017.eml`) required screenshots of every API we want approved, privacy policy compliance (no third-party AI processing of Garmin data), and brand compliance per `Garmin_Developer_API_Brand_Guidelines.pdf`.

## Current state of play — verified findings

Results from the Explore agent run during planning. Trust these as of 2026-04-24 but re-verify line numbers before editing (files may have moved).

### Garmin ingestion — what we already DO

- **Endpoints implemented:**
  - `supabase/functions/garmin-push/` — direct push handler, handles: activities, activityDetails, manuallyUpdatedActivities, dailies, epochs, sleeps, bodyComps, stressDetails, userMetrics
  - `supabase/functions/garmin-ping/` — ping callback handler, fetches same types via URL
  - `supabase/functions/garmin-deregistration/` — user disconnect
- **Shared Garmin code:** `supabase/functions/_shared/garmin/` (`types.ts`, `auth.ts`, `mappers.ts`)
- **Persistence tables:**
  - `activities` — completed workouts matched to planned TP/FS activities (Match-Only strategy per memory)
  - `garmin_health_data` — JSONB, types: `daily`, `epoch`, `sleep`, `body_composition`, `stress`, `user_metrics`, upserted by `summary_id`
  - `garmin_user_mappings` — Garmin userId → Mealvana userId (`onConflict: garmin_user_id`)
- **Types (`types.ts` lines 139–286)** define all Garmin data structures.

### Garmin consumption — what we DON'T currently do (the gap to close)

- **Nutrition plan service** does NOT query `garmin_health_data`
- **Daily macro service** (`lib/features/daily_macros/application/daily_macro_service.dart` lines 39–89) reads activity sessions + user profile fields (body_fat_pct, lifestyle, typical_weekly_hours) but does NOT read Garmin health data
- **No UI surface** currently displays body composition, sleep, stress, HRV, resting HR, or VO2 max data
- **`garmin-push` handler** reads `garmin_user_mappings` but does NOT feed `garmin_health_data` into any downstream logic

### Macro calculator — current state

- **Version:** v4.0.0 (all 4 iterations live, 58 unit tests passing)
- **Location:** `supabase/functions/calculate-daily-macros/`
- **Files:**
  - `index.ts` — HTTP handler + orchestration
  - `pipeline.ts` — `calculateDailyMacros()` + `calculateWeekMacros()` (inspected during planning; 402 lines)
  - `types.ts` — `DailyMacroInput`, `DailyMacroOutput`, `WeekMacroInput`
  - `formulas/rmr.ts` — Cunningham (if BF%) + Mifflin-St Jeor fallback
  - `formulas/session.ts` — `zoneDistributionToIF`, `sessionCost`, `carbDemand`, `processSession`
  - `formulas/baseline.ts` — `baselineMacros`, `calculateProteinBump`, `clampMacros`
  - `formulas/multi-day.ts` — `recoveryDebt`, `preLoadOverride`, `weeklyLoadAdjust`, `phaseModifier`
  - `formulas/neat-tef.ts` — `inferVolumeTier`, `getDayModifier`, `calculateNEAT`, `calculateTDEE` (iterative convergence)
  - `formulas/safety.ts` — `deriveFFM`, `checkEnergyAvailability`, `eaOverride`, `multiSessionCarbCompound`, `carbCycleAdjust`
- **Tests:** `index.test.ts`, `index.integration.test.ts` — Deno-based
- **Response currently contains:** `{ carb_g, prot_g, fat_g, tdee, rmr, session_kcal, neat_kcal, tef_kcal, mode, ea, ea_status, algorithm_version }`
- **Mode parameter:** accepts `prospective|retrospective`, both branches identical today (noted "infrastructure for Iter 5 Garmin integration" in iteration3_spec.txt)

### Brand compliance — current assets

- **Available in repo (docs-only, not in app bundle):** `/docs/integration/GCDP Branding Assets_v2/`
  - `Garmin_connect_badge_digital_RESOURCE_FILE-01.png` ← this is the pill badge Elena wants
  - `Garmin_connect_badge_print_RESOURCE_FILE-01.png`
  - `GarminConnect-Digital_ICN_1000.eps`
  - `GarminConnect_ICN_512.ai`
  - `GarminConnect_ICN_1024.1.ai`
  - `Garmin_Connect_app_1024x1024-02.png` (app icon, for reference)
  - `Garmin Tag/` folder (the tag logo we currently use)
- **Currently in app bundle (`assets/images/integrations/`):**
  - `garmin_tag_black.png`, `garmin_tag_white.png` ← the old tag, needs to be supplemented/replaced
  - Also: strava + training_peaks + final_surge logos for reference
- **Attribution widget:** `lib/features/integrations/presentation/widgets/garmin_attribution.dart` (read in planning)
  - Uses `garmin_tag_white.png` / `garmin_tag_black.png`
  - Has `deviceName` fallback logic: "Garmin Forerunner 955" / "Garmin Connect" / never bare "Garmin"
  - Two styles: `compact` (10pt logo/font) and `standard` (14pt/12pt)
- **14 Dart files reference "garmin"** (see grep output from planning run) — callsites to audit for the badge swap

### Existing `/docs/macro_calculations/` contents (pre-Notion sync)

```
iteration1_spec.txt     # Spec (covers RMR, baseline macros, IF, session cost, carb demand, clamping, TDEE, fat)
iteration1_tests.txt    # Tests
iteration2_spec.txt     # Spec (duplicate-looking to iter2_tests? verify during sync)
iteration2_tests.txt    # Tests (recovery debt, pre-load, weekly, phase)
iteration3_spec.txt     # Spec (NEAT + iterative TEF + mode parameter)
iteration3_tests.txt    # Tests
iteration4_spec.txt     # Spec (EA, multi-session, carb cycling, masters)
iteration4_tests.txt    # Tests
v1_readme.txt           # Covers iterations 1-2
v2_readme.txt           # Covers iterations 3-4
screenshots/            # 3 PNGs from 2026-03-25
```

**Note:** `iteration2_spec.txt` is suspiciously the same size as `iteration2_tests.txt` — the README says "spec corrupted, formulas in v1_readme.txt". Re-sync from Notion will likely fix this.

## Key decisions (recap from planning)

| Question | Decision |
|---|---|
| Scope | Full: ship Iter 5 + reply to Elena |
| Tone of email | Honest — describe current code state |
| Notion shape | Root page with child pages for iterations 1–5 + tests → mirror into `/docs/macro_calculations/` |
| BF% precedence | User-entered wins; Garmin is fallback only |
| Rollout | No feature flag; ship Iter 5 to all users at merge |
| Email delivery | Assistant drafts full markdown + zipped screenshots → user pastes into Zendesk |

## Relevant memory entries (persisted across sessions)

From `~/.claude/projects/-Users-leemartin-development-mealvana-endurance/memory/MEMORY.md`:

- **Garmin architecture:** Server-to-server push only. Cannot pull on demand. See "Garmin Connect Integration (Added 2026-03-25)" section for user IDs, secrets, deployed edge functions.
- **Match-only strategy (2026-04-01):** Garmin pushes only update existing planned activities from TP/FS. Unplanned activities are skipped.
- **Garmin matching tz bug (fixed 2026-04-17):** `scheduled_date_time` is tz-naive; must use naive local-day bounds. Skip match when `sportType='other'`.
- **PostgREST + partial unique index gotcha:** never use `onConflict` with partial unique index columns — always use `onConflict: 'id'`.
- **Dr. Rachel Mitchell:** Nutrition advisor, PhD nutrition science, provided post-workout recovery formulas to Xuan on 2026-04-07. Check Notion for her latest formulas — possibly part of the iter5 spec.
- **Lee's dev Mealvana user ID:** `607f9dd5-6fa7-48ee-a628-720d4a0506a1` — use this account for testing Garmin data flows.
- **Lee's Garmin User ID:** `af701316-e43f-4a8c-be41-a3fde89a8e96` (portal User ID, NOT the JWT garmin_guid).

## Files examined during planning (to speed up re-verification)

The fresh session doesn't need to re-read these unless it wants to confirm specifics — the Explore agent already surveyed them:

- `lib/features/integrations/presentation/widgets/garmin_attribution.dart` (full read, 95 lines)
- `supabase/functions/calculate-daily-macros/README.md` (full read)
- `supabase/functions/calculate-daily-macros/pipeline.ts` (full read, 402 lines)
- `docs/macro_calculations/iteration1_spec.txt`, `iteration3_spec.txt`, `iteration4_spec.txt`, `v1_readme.txt`, `v2_readme.txt`
- `docs/integration/garmin_email/response.png` (Elena's latest)
- `docs/integration/garmin_email/Production Review for _Milkman Inc__ Requirements, Ticket_ 206017.eml` (prior Apr 8 requirements email)

## Git state at plan time

- Branch: `develop`
- Main branch for PRs: `main`
- Last 5 commits: hydration-themed (G5 redistribution, G5 T1/T2 calc alignment, G4 watch placeholder, G4 tab bar removal, G4 confidence pills) — unrelated to this work
- Uncommitted: `ios/build/` + `tmp/` (untracked, not ours)

The Iter 5 implementation should go on a new feature branch, not develop. Suggested: `feat/macro-iter5-garmin`.

## Sequence cheatsheet for the resume session

```
Phase 1 (docs from Notion):
  - mcp__notion__authenticate → OAuth URL
  - User authorizes
  - Fetch root page + all children
  - Mirror into /docs/macro_calculations/
  - Add README.md + iteration5_spec.md + iteration5_tests.md + garmin_data_usage.md

Phase 2 (edge function, parallelizable with P3):
  - Create formulas/garmin.ts (5 new functions)
  - Extend types.ts (GarminContext, expanded input/output)
  - Update pipeline.ts (Step 8 takes Garmin modifiers, EA uses Garmin FFM, retrospective reads activities table)
  - Add iteration5.test.ts
  - Deploy to dev: supabase functions deploy calculate-daily-macros

Phase 3 (UI + brand, parallelizable with P2):
  - Copy Garmin_connect_badge_digital_RESOURCE_FILE-01.png to assets/images/integrations/garmin_connect_badge.png
  - Update pubspec.yaml asset list if needed
  - Update garmin_attribution.dart to use pill badge by default
  - Add garmin_inputs_sheet.dart + wire into daily_macros_screen.dart
  - Add body composition card to nutrition_profile_screen.dart
  - Add health data summary row to connected_apps_screen.dart
  - Add retrospective banner to activity_detail_screen.dart
  - Update ea_warning_banner.dart to cite Garmin FFM when applicable
  - Run: flutter pub run build_runner build --delete-conflicting-outputs (if @riverpod annotations added)
  - Run: flutter analyze && flutter test

Phase 4 (email):
  - Launch on simulator with Lee's dev account (607f9dd5-6fa7-48ee-a628-720d4a0506a1) — should have Garmin data
  - Capture 6 screenshots (listed in implementation_plan.md Phase 4 step 1)
  - Save to /docs/integration/garmin_email/response_screenshots/
  - zip -r response_bundle.zip response_screenshots/
  - Draft response_draft.md (honest, structured by API)
  - User reviews + sends via Zendesk
```

## Gotchas the resume session should watch for

1. **Don't assume Notion content matches repo.** Diff each iteration1–4 doc after Notion sync. If Rachel's 2026-04-07 recovery formulas are in Notion but not in the repo, that's a formula gap that needs to be propagated to the edge function (potentially a separate commit/PR before Iter 5).
2. **`iteration2_spec.txt` may be corrupted.** README says "spec corrupted, formulas in v1_readme.txt". Notion sync should restore this.
3. **Garmin edge function auth.** The `calculate-daily-macros` function needs service-role key to query `garmin_health_data` (if using direct DB access). Check if `supabase/functions/_shared/supabase.ts` already exports an admin client.
4. **Drift codegen.** If any Dart schema changes land (e.g., cached Garmin context on user), remember: `flutter pub run build_runner build --delete-conflicting-outputs`. Per CLAUDE.md, codegen after Riverpod/Drift annotation changes.
5. **Retrospective mode ambiguity.** The `mode` parameter should be driven by whether a Garmin-sourced completed activity exists for that date. Don't add new UI to toggle it — keep auto.
6. **`MealvanaSnackbar` only.** Per CLAUDE.md: do NOT use raw Flutter `SnackBar`.
7. **FOA layers.** UI code must not call Supabase directly — go through application/data layer. See `/docs/technical/foa-architecture.md`.
8. **Brand guidelines page 2/4.** Elena's Apr 8 email specifically pointed to pages 2 (Activities) and 4 (Health) of `Garmin_Developer_API_Brand_Guidelines.pdf`. Read those pages before touching attribution.
9. **Privacy policy.** Elena's Apr 8 email required an anchor link to a section of our privacy policy stating Garmin data is not processed by external AI providers. If we haven't added that yet, it's part of Phase 4 (email response). Check `docs/legal/` or the marketing site.

## Validation commands (quick reference)

```bash
# Edge function tests
cd supabase/functions/calculate-daily-macros && deno test --allow-all

# Flutter static + unit
flutter analyze
flutter test

# Specific macro calc test file
cd supabase/functions/calculate-daily-macros && deno test --allow-all index.test.ts

# Deploy dev edge function (user must have run `supabase login` already)
supabase functions deploy calculate-daily-macros

# Simulator launch with dev flavor (confirm name with user; check main_web.dart / main.dart)
flutter run --flavor dev
```

## Open questions for the resume session to confirm

If any of these are ambiguous when Notion content arrives, use AskUserQuestion:

- Does the Notion doc include iteration 5 content already, or is Iter 5 purely the assistant's design? If the Notion version of Iter 5 differs from the plan's sketch, the Notion version wins.
- Sleep quality score source — Garmin uses `overall_sleep_score` (0–100) in their sleep object, and also individual stage quality. Pick one consistently in `garmin.ts`.
- Stress level source — `stressDetails` has per-minute timeline; need to pick aggregation window (yesterday 24h vs last 4h, etc.). Ask the user if unclear.
- Retrospective mode trigger — auto-detect based on activity data availability, or require an explicit flag? Plan assumes auto; confirm.
