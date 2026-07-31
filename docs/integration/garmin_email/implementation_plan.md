# Garmin Production Review Response + Daily Macro Calc Iteration 5

> **Session resume note (2026-04-24):**
> This plan was drafted in a Claude Code session that required Notion MCP authorization to proceed with Phase 1. Authorization couldn't be completed without closing the session. To continue:
>
> 1. Open a new Claude Code session in this repo.
> 2. Prime with: "Read `/docs/integration/garmin_email/implementation_plan.md` and resume from Phase 1. Authorize Notion MCP when prompted."
> 3. The assistant will re-trigger Notion OAuth. Complete the OAuth flow in the browser; the session will detect auth and proceed.
> 4. Target Notion page: `Daily Macro Calculation` — https://www.notion.so/Daily-Macro-Calculation-326e3fdb754c80199486c17ecf9947cd
> 5. Elena's latest email screenshot: `/docs/integration/garmin_email/response.png` — she asked for (a) Garmin Connect pill badge use and (b) how Training + Health API are used.
> 6. Prior screenshots we sent: `/docs/integration/garmin_email/our_screenshots/`.
>
> User decisions captured during planning:
> - **Scope:** Full — ship Iteration 5 (real Garmin consumption) + reply to Elena.
> - **Tone:** Honest — describe what's actually in code when we send.
> - **Notion shape:** Root page with child pages for iterations 1–5 + tests; mirror hierarchy into `/docs/features/macro_calculations/`.
> - **BF% precedence:** User-entered body fat % always wins; Garmin body comp is fallback only.
> - **Rollout:** No feature flag; ship Iteration 5 to all users at merge.
> - **Email delivery:** Assistant drafts full markdown reply + zipped screenshots; user pastes into Zendesk.

---

## Context

**Why this is happening:** We're in Garmin's production approval queue. Elena Kononova (Garmin Connect Partner Services) reviewed our evaluation-key screenshots and replied on Apr 23 with two asks:

1. **Brand compliance** — use the "Garmin Connect" pill badge (not just the Garmin tag) wherever the app authenticates users or displays Garmin data.
2. **API usage clarity** — she sees we use the Activity API but wants to know how we use Training API + Health API.

**What we actually have in code today (verified via Explore survey):**
- Activity API: ingested via `garmin-push`/`garmin-ping`; matched to planned activities from TrainingPeaks/FinalSurge. **Currently surfaced in the UI** (activity cards + detail screens with Garmin attribution).
- Training API endpoints configured in portal, but "Training" in Garmin's taxonomy covers planned workout push-to-device (Courses/Workouts). We ingest completed workouts, not yet pushing planned workouts to devices.
- Health API: all wellness types (`dailies`, `epochs`, `sleeps`, `bodyComps`, `stress`, `userMetrics`) are **ingested and persisted** in `garmin_health_data` but **zero consumption** by any downstream logic — not by the macro calculator, not in any UI surface.

**Macro calculator status:** Iterations 1–4 are fully live in `supabase/functions/calculate-daily-macros/` (v4.0.0). The pipeline accepts a `mode: prospective | retrospective` parameter documented in iteration3_spec.txt as "infrastructure for Iter 5 Garmin integration" — but both modes currently run identical math. **Iteration 5 has not been started.**

**The honesty risk:** If we respond to Elena describing how Health API data feeds nutrition calculations when the code doesn't actually read that table, Garmin's production review will catch the gap (they ask for screenshots per API). We must either (a) ship real consumption + UI surfaces before replying, or (b) reply honestly about the current state and roadmap.

**User decision (confirmed):** Ship Iteration 5 (real Garmin Training/Health consumption + UI surfaces), organize the macro calc docs from Notion as source of truth, then reply to Elena honestly with the newly built surfaces documented.

---

## Approach

The plan is a sequence of four phases. Each phase produces output we need for the next. Phase 4 (email) depends on Phases 1–3 being merged so the screenshots are truthful.

### Phase 1 — Docs sync from Notion (blocked on Notion auth)

**Goal:** Make Notion the authoritative spec source and mirror it cleanly into `/docs/features/macro_calculations/` so the team (Rachel the nutrition advisor, Xuan, engineering) works off one version.

**Steps:**
1. User authorizes Notion MCP (OAuth URL delivered earlier in conversation).
2. Pull root page `Daily-Macro-Calculation-326e3fdb754c80199486c17ecf9947cd` and all child pages recursively via Notion tools.
3. Replace/supersede the current `/docs/features/macro_calculations/` contents:
   - Keep file names stable (`iteration1_spec.txt`, etc.) so links in `supabase/functions/calculate-daily-macros/README.md` (lines 305–310) don't break.
   - Convert `.txt` → `.md` and update README references.
   - Add: `iteration5_spec.md`, `iteration5_tests.md` (the Garmin integration iteration).
   - Add: `garmin_data_usage.md` — single-page reference mapping each Garmin endpoint to what the app does with it (for Elena's review AND future team onboarding).
   - Add: `README.md` (new, at folder root) listing all iterations in order with status (implemented/planned) + one-line description + Notion link.
4. Diff Notion-sourced content against what's currently in-repo for iterations 1–4. If Notion has more recent updates (e.g., Rachel's Apr 7 post-workout recovery formulas per memory), surface them and flag for Xuan.

**Critical files touched:**
- `/docs/features/macro_calculations/README.md` (new)
- `/docs/features/macro_calculations/iteration{1,2,3,4,5}_spec.md` (rewrite/new)
- `/docs/features/macro_calculations/iteration{1,2,3,4,5}_tests.md` (rewrite/new)
- `/docs/features/macro_calculations/garmin_data_usage.md` (new)
- `/supabase/functions/calculate-daily-macros/README.md` (update doc links)

---

### Phase 2 — Iteration 5: Garmin Training + Health consumption

**Goal:** Macro calculator reads Garmin data from `garmin_health_data` and `activities` tables instead of trusting only onboarding-form values, AND the UI shows where Garmin data is influencing the numbers. This is what makes screenshots truthful for Elena.

**Architecture decision:** Edge function queries `garmin_health_data` directly for the user's most recent records. Dart only passes `user_id` + `date`. This keeps sync state out of the client and gives us one place to validate data recency/thresholds.

**Data mappings (Iter 5 formulas, added to pipeline):**

| Garmin source | Macro calc consumer | Effect |
| --- | --- | --- |
| `bodyComps.percent_fat` (most recent within 30 days) | `body_fat_pct` **fallback** (only when user left onboarding field blank) → RMR (Cunningham) + FFM (EA check) | Fills a gap; user-entered value always wins |
| `userMetrics.vo2_max` | Cross-check `typical_weekly_hours` → volume tier inference | Flags tier mismatch; does not override user input (yet) |
| `dailies.resting_heart_rate` (7-day avg) | NEAT baseline modifier (new `getRestingHRModifier`) | Lower RHR + high weekly load = reduce NEAT floor (athlete is efficient); elevated RHR after hard day = already handled by REST_AFTER_HARD but this refines it |
| `sleeps.sleep_quality_score` (last night) | Recovery debt amplifier | Score < 60 after hard session extends recovery window 18h→24h threshold |
| `stress.average_stress_level` (yesterday + today) | Day modifier refinement | High stress on a REST day shifts modifier toward REST_AFTER_HARD (1.00→0.95) |
| `activities` (completed, retrospective mode) | Session array source | Replaces planned sessions with actual when `mode=retrospective` AND activity is in `activities` table with `source='garmin'` |

**Body-fat % precedence (user decision):** User-entered `body_fat_pct` from onboarding/profile ALWAYS wins. Garmin `bodyComps.percent_fat` is only consulted when the user value is null/missing. The "Why these numbers?" sheet still surfaces the latest Garmin body comp reading so the user can see what Garmin measured and manually reconcile if they want — this keeps the Health API data visible in the UI (satisfying Elena's review) without silently overriding user input.

**Rollout (user decision):** No feature flag. Iteration 5 ships to all users at merge. Users without Garmin connected see zero UI change (Garmin inputs simply aren't present → all code paths fall back to existing behavior). Users with Garmin connected see the new "Why these numbers?" sheet and body-composition card automatically.

**New formulas to add (in `supabase/functions/calculate-daily-macros/formulas/garmin.ts`):**
- `resolveGarminContext(user_id, date, supabase)` — fetches all relevant rows, returns a typed `GarminContext` object
- `getRestingHRModifier(rhr_7d_avg, weekly_hours)` — returns NEAT modifier adjustment
- `getSleepRecoveryModifier(sleep_score, yesterday_tss)` — returns extended recovery window or decay shift
- `getStressDayModifier(avg_stress, base_modifier)` — returns refined day modifier
- `resolveRetrospectiveSessions(user_id, date, supabase)` — fetches `activities` table rows for the date

**Pipeline changes (`pipeline.ts`):**
- Accept new optional input: `garmin_context?: GarminContext` OR `resolve_garmin?: boolean` flag that triggers the edge function to fetch it
- In `calculateDailyMacros`: when `garmin_context` present, prefer `garmin_context.body_fat_pct` over input `body_fat_pct`, apply resting-HR and sleep modifiers to Step 8 (NEAT/TDEE), extend EA check with FFM from Garmin body comp
- Response gains: `garmin_inputs_used: { body_fat_pct_source, rhr_7d_avg, sleep_score, stress_level, vo2_max }` — explicit audit trail so the UI can show "these numbers came from your Garmin Connect data"

**Dart changes:**
- `lib/features/daily_macros/application/daily_macro_service.dart` — add `includeGarmin: true` to edge function payload
- No new controller work; existing `DailyMacrosController` just re-fetches

**Sanity-check guardrails:**
- Body comp staler than 30 days → ignore
- Sleep score from >36h ago → ignore
- If Garmin data exists but conflicts with user-entered profile by >25%, log a flag and prefer the user value (per user-decision above); surface the flag in the "Why these numbers?" sheet so they can reconcile manually.

**Test strategy:**
- Add `iteration5_tests.ts` (13–15 cases): "rest day with good sleep vs. poor sleep", "training day with Garmin body comp override", "retrospective mode pulls actual activity", "missing Garmin data → falls back to form inputs cleanly", "stale body comp ignored"
- All iteration 1–4 tests must continue to pass with `includeGarmin: false`

**Critical files:**
- `/supabase/functions/calculate-daily-macros/formulas/garmin.ts` (new)
- `/supabase/functions/calculate-daily-macros/types.ts` (extend `DailyMacroInput`, `DailyMacroOutput`)
- `/supabase/functions/calculate-daily-macros/pipeline.ts` (integrate garmin context in Step 8 + retrospective session source)
- `/supabase/functions/calculate-daily-macros/iteration5.test.ts` (new)
- `/lib/features/daily_macros/application/daily_macro_service.dart` (pass `includeGarmin` flag)

---

### Phase 3 — UI surfaces for Garmin Health data

**Goal:** Screenshots of four or five screens each showing Health API data, with proper attribution, so Elena can tick the "Health API used where?" box.

**Surfaces to add or extend:**

1. **Daily macros screen — "Why these numbers?" sheet**
   - File: `lib/features/daily_macros/presentation/screens/daily_macros_screen.dart` + new `presentation/widgets/garmin_inputs_sheet.dart`
   - Tappable "i" on the total kcal row → bottom sheet lists: body fat % from Garmin Connect (bodyComps) + date, 7-day avg resting HR from Garmin (dailies), last night's sleep score (sleeps), today's stress level (stress)
   - Each row shows Garmin Connect badge attribution per brand guidelines
   - This is the main screenshot for Elena re: Health API consumption

2. **Nutrition profile screen — body composition card**
   - File: `lib/features/settings/presentation/screens/nutrition_profile_screen.dart`
   - Add "Body composition (from Garmin Connect)" card: weight, body fat %, muscle mass from latest `bodyComps` entry. Fallback text if none.
   - Shows that Health API data flows into the nutrition profile

3. **Activity detail — retrospective correction banner**
   - File: `lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart`
   - When a Garmin-completed activity differs from the planned session (duration, TSS, HR zones), show a "Nutrition adjusted based on actual effort" banner with numbers before/after
   - Demonstrates Training/Activity API feeding retrospective mode

4. **Connected apps screen — health data summary**
   - File: `lib/features/settings/presentation/screens/connected_apps_screen.dart`
   - Under the Garmin row: "Latest received: daily summary 2h ago · sleep 11h ago · body comp 3d ago · activity 1h ago"
   - Proves we handle all the endpoint types

5. **EA warning banner — cite Garmin FFM**
   - File: `lib/features/daily_macros/presentation/widgets/ea_warning_banner.dart`
   - When EA warning is active and Garmin body comp is available, note: "Energy availability calculated against FFM from Garmin Connect body composition (date)"

**Brand compliance fixes (parallel):**
- Add `Garmin_connect_badge_digital_RESOURCE_FILE-01.png` (from `/docs/integration/GCDP Branding Assets_v2/`) to `assets/images/integrations/` as `garmin_connect_badge.png` (+ dark variant if needed)
- Update `pubspec.yaml` asset declarations if applicable
- Update `lib/features/integrations/presentation/widgets/garmin_attribution.dart`:
  - Default style switches to the Connect pill badge
  - Keep the tag logo only for contexts the guidelines permit (verify against `Garmin_Developer_API_Brand_Guidelines.pdf` page 2/4)
  - Preserve `deviceName` fallback logic ("Garmin Forerunner 955" etc.)
- Sweep all callsites (14 known Dart files reference Garmin) to make sure the pill badge renders, not just "Garmin" text.

**Critical files:**
- `assets/images/integrations/garmin_connect_badge.png` (new)
- `lib/features/integrations/presentation/widgets/garmin_attribution.dart` (update)
- `lib/features/daily_macros/presentation/widgets/garmin_inputs_sheet.dart` (new)
- `lib/features/daily_macros/presentation/screens/daily_macros_screen.dart` (wire sheet)
- `lib/features/settings/presentation/screens/nutrition_profile_screen.dart` (add body comp card)
- `lib/features/settings/presentation/screens/connected_apps_screen.dart` (add health data summary)
- `lib/features/daily_macros/presentation/widgets/ea_warning_banner.dart` (cite Garmin FFM)
- `lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart` (retrospective banner)

---

### Phase 4 — Email response + screenshot bundle

**Goal:** Reply to Elena in a tone that's factual, polite, and ships with the screenshots she needs. **Delivery:** Assistant drafts the full markdown reply + produces a zipped screenshot bundle; user pastes into Zendesk reply + attaches the zip.

**Steps:**
1. Capture screenshots (simulator + physical Garmin-connected account):
   - Daily macros → "Why these numbers?" with Garmin Connect badge
   - Nutrition profile → body composition card with Garmin data
   - Activity detail → retrospective banner with Garmin-sourced activity
   - Connected apps → Garmin row with health-data summary
   - Workout match: planned TP activity + Garmin completion merged (Activity API, already shown previously — reshoot with new badge)
   - EA warning banner with Garmin FFM citation (force into warning state for the screenshot)
2. Save to `/docs/integration/garmin_email/response_screenshots/` + `zip -r response_bundle.zip response_screenshots/` at `/docs/integration/garmin_email/response_bundle.zip`.
3. Draft reply email in full prose markdown at `/docs/integration/garmin_email/response_draft.md`:
   - Open by acknowledging the logo update + inline reference to the new badge screenshot
   - Section per API, each referencing specific screenshot filenames:
     - **Activity API** — workout matching (existing use, reshoot with new badge)
     - **Training API** — planned session ingestion + retrospective correction flow
     - **Health API** — body composition → RMR/FFM fallback, sleep → recovery, stress → NEAT, resting HR → NEAT baseline, user metrics → volume tier cross-check
   - Reference the attached zip by filename
   - Confirm privacy policy status (no external AI processing of Garmin data per prior email)
   - Sign-off in Lee's voice (first-person, concise, no marketing speak)
4. User reviews the draft + bundle, pastes into the Zendesk ticket, attaches zip, sends.

**Honesty guardrails:**
- Do not claim consumption that isn't in code at the time of sending. If Phase 2 slips for any Health data type (e.g., stress modifier), drop that line from the email.
- Match claims to screenshots 1:1 — every API section has a pointer to a specific screenshot filename.

---

## Sequencing & dependencies

- Phase 1 (docs) is **blocked on Notion auth** but does not block Phase 2/3 coding. Start Phase 2 in parallel once the user authorizes, since the Notion content is specs/tests we already partially have.
- Phase 2 (edge function) and Phase 3 (UI + brand) can proceed in parallel after Phase 1 spec confirmation. They merge at Phase 3.1 (the "Why these numbers?" sheet needs the new edge-function response field `garmin_inputs_used`).
- Phase 4 (email) is **last** — screenshots must reflect shipped behavior.

## Verification

Per phase:

- **Phase 1**: Folder structure diff review; every iteration file links back to its Notion source URL; `README.md` lists all iterations with implemented/planned status.
- **Phase 2**:
  - `deno test --allow-all supabase/functions/calculate-daily-macros/*.test.ts` — all 58 existing + new iteration-5 tests pass
  - Run edge function locally with a test user who has Garmin body comp + sleep data → response includes `garmin_inputs_used` block with the right fields
  - Flutter integration test (or manual on simulator): daily macro screen loads, displays Garmin-sourced body fat %
- **Phase 3**:
  - Launch app on simulator with dev account `607f9dd5-6fa7-48ee-a628-720d4a0506a1` (Lee's dev user from memory) — Garmin data should be present
  - Walk each screen listed in Phase 3; confirm Garmin Connect pill badge renders everywhere Garmin data appears (not the old tag logo)
  - Check dark mode parity
  - Run `flutter analyze` and `flutter test` — no regressions
- **Phase 4**:
  - Have user review the draft email + zip bundle before sending
  - Cross-check every claim in the email against a screenshot
  - Verify screenshot filenames match email references

## Things we are NOT doing in this plan

- Not pushing planned workouts FROM our app TO Garmin devices via the Workouts/Courses API. Elena's question was about *consumption*; the reciprocal direction is a future project.
- Not implementing the Women's Health API (menstrual cycle) — separate Garmin API not enabled on our portal.
- Not rebuilding activity matching logic — it already works; just reshooting screenshots with the new badge.
- Not migrating the `.txt` files in `/docs/features/macro_calculations/` to `.md` eagerly before Notion sync — that merges into Phase 1.

## Reuse notes

- `GarminAttribution` widget already exists (`lib/features/integrations/presentation/widgets/garmin_attribution.dart`) — extend it; do not create a new attribution widget.
- `MealvanaSnackbar` is the required snackbar (per CLAUDE.md).
- `deriveFFM` in `supabase/functions/calculate-daily-macros/formulas/safety.ts` already accepts `body_fat_pct` — Iteration 5 just needs to feed Garmin-sourced value into the existing pipeline, not reimplement FFM.
- `processSession`, `zoneDistributionToIF`, `carbDemand` in `formulas/session.ts` — reuse as-is for retrospective mode when rebuilding sessions from `activities` table rows.
- Existing `garmin_health_data` table + types in `supabase/functions/_shared/garmin/types.ts` — the Iter 5 `resolveGarminContext` just queries this; no schema migration needed.
- Existing `activities` table with `garmin_summary_id` field — retrospective mode queries by `(user_id, scheduled_date, source='garmin')`.
