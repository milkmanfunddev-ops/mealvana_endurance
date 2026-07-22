# Analytics / Mixpanel — Plan & Data Hygiene

Status: pre-wiring reference. Written 2026-07-08 after the prod engagement
audit. **Read this before wiring Mixpanel identify/track or building any
engagement dashboard.**

## ⚠️⚠️ CORRECTION 2 (2026-07-08, dev/test pollution — supersedes CORRECTION 1 below)

Mixpanel is heavily polluted by internal dev/test traffic; it invalidates
several event-based claims (including some in CORRECTION 1):
- **"Invisible majority" was mostly dev traffic, NOT hidden real users.** Of
  826 non-internal distinct_ids, **546 (66%) are dev/test**: 506 in team cities
  (Birmingham/Hoover), 195 iOS **simulators** (`$model=arm64`), 13
  emulator/web builds. **Clean real users ≈ 280 — matching Supabase's 263.**
  Retract the "hundreds of hidden real users" framing.
- **Real external fuel logging ≈ 0.** All 9 `fuel_log_completed` "users" are
  Birmingham/Hoover or simulators = dev/team. So CORRECTION 1's "fuel logging
  is NOT zero / adoption not build problem" was itself fooled by pollution —
  the ORIGINAL Supabase finding (feedback loop barely used by real users)
  stands. Same for `plan_item_swapped/removed` (dev).
- **The two activity-sync "bugs" are retracted** — the flagship "authed user,
  24 logs, 0 synced activities" (`1E1ACE27…`) is an `arm64` **simulator** in
  Birmingham. No real sync bug established; re-validate on clean data only.
- **Retention curve is robust to cleaning** (D1 ~19%, D7 ~9%, D30 ~5.5% both
  polluted and clean) → those numbers stand.
- **`activity_viewed` plan-view count (24 users)** and any per-feature counts
  need re-running with the dev filter; treat as upper bounds until then.
- **Action:** Mixpanel needs a standing dev/internal-traffic exclusion before
  ANY metric is trusted — see `ops/data/feature-requests/
  2026-07-08-analytics-exclude-dev-internal-traffic.md`. Heuristic filter lives
  in `ops/scripts/mp_clean.py`.

## ⚠️ CORRECTION (2026-07-08, from raw Mixpanel event export — supersedes claims below)

Pulling the raw event stream (`ops/data/mixpanel/`, 77k events Nov 2025–Jul
2026) overturned several conclusions that were based on Supabase table state.
Trust the events over the earlier table-inferences where they conflict:

- **Fuel logging is NOT zero — and it's a SYNC/IDENTITY gap, not a wrong
  table.** 9 external users completed fuel logs (`fuel_log_completed`, 62
  events). Code trace: `activity_detail_controller.dart:~2427` writes
  `fuelLogData` into `activities.fuel_log_data` via `updateActivity`, and the
  sync handler DOES include it in the upload payload
  (`activity_sync_handler.dart:388`) — same field I queried. The reason
  Supabase showed ~0: **almost all fuel-logging happens on anonymous /
  not-yet-synced clients.** Of the 9: 2 are Android device fingerprints
  (`CP1A.*`, anonymous/local-only), 5 are iOS IDFV device-ids (mostly no synced
  activities in prod at all), and only 2 lowercase-UUID (anonymous) users
  actually synced — with 1 `fuel_log_data` row each. Notable: one non-anonymous
  device with **24 fuel logs** has ZERO activities in Supabase → a real sync
  failure even for an authed user. **Implication: Supabase = authed/synced
  state only; anonymous engagement (143 anon users) is largely invisible there
  but visible in Mixpanel. The ID-merge/anon-sync gap is the real issue.**
- **Plan editing is instrumented and used**: `plan_item_swapped` (28 ev, 9
  users), `plan_item_removed` (29 ev, 9 users). Not a gap; DB just stores only
  current state.
- **Push→feedback loop is not dead**: 7 external users tapped an upload/push
  notification, 9 logged fuel, **3 did both**. Instrumented via
  `activity_upload_notification_clicked` / `push_notification_opened`.
- **Instrumentation is far richer than the code grep implied**: 160 event
  types live. Real `app_opened` volume exists (8168 external) → retention is
  properly measurable; stop using write-timestamp proxies.
- **What still holds:** engagement is *low* (9 of ~104 plan-creators log fuel),
  so the qualitative story (most users don't close the loop) stands — but it's
  an **adoption** problem, not a missing/broken feature. "Zero" and "dead UI"
  were wrong.
- **Q1 answered:** plan views = **24 distinct external users, 149 views**
  (`activity_viewed` + `has_nutrition_plan=true`, internal excluded).
- Still genuinely archived/dead: `planRating` / `effort_rating` (confirmed no
  events fire).

## Real event-based retention & insights (2026-07-08 export, internal excluded)

Computed from `app_opened` in the 77k-event export (`ops/scripts/mp_retention.py`).
Replaces the write-timestamp proxies (which swung 3–4x).

- **The invisible majority.** Mixpanel has **826 distinct users** (251 authed,
  575 anon-only) vs **263 in Supabase.** Hundreds open the app, never create an
  account, never sync — invisible to every prior table-based number. Most
  people who open never authenticate. (826 is somewhat inflated by ID-merge;
  see caveat.)
- **Real retention curve (unbounded, still-active-on/after day N):** D1 19.9%,
  D3 13.3%, D7 9.1%, D14 7.2%, D30 5.2%. Honest baseline — low but early-stage.
- **The create→view cliff.** 27% of users create a plan, but only **4.5% ever
  come back to *view* one**, 1.8% edit, 1.1% log fuel. Creation is common;
  returning to use the plan is where it collapses. (Views are event-only —
  invisible in Supabase.)
- **Revised retention predictors (week-1 behavior → D14 return; baseline 7.2%):**
  authenticated +15pp (22%, n=123), **connected an integration +6pp (13.5%,
  n=74)**, viewed a plan +8pp (15%, n=26). **Generating a plan showed NO lift**
  (n=177) — this REVISES the earlier SQL claim that plan-creation was the
  activation gate. In the fuller population, plan-generation is table-stakes;
  **integration-connect and auth are the real early separators.** (fuel-log
  wk1 showed +43pp but n=4 — ignore.)
- **⚠️ Data-quality caveat (ID-merge).** Per-identity retention is contaminated
  by anon↔auth identity fragmentation: an authed user's pre-auth events sit
  under a device-id, their post-auth under a user-id, splitting one person into
  two. This is why "anon-only retains better at D7 (11%) than authed (4.8%)" —
  almost certainly an ARTIFACT, not real. **Trustworthy per-user retention
  requires fixing ID-merge first** (already an open workstream item; now clearly
  the top data-integrity blocker).
- Funnel note: `nutrition_plan_created` > `plan_generated` (non-monotonic), so
  the funnel events aren't a strict sequence — read step-conversions loosely.

## 1. Internal-account exclusion (`users.is_internal`)

Internal team/test accounts contaminated every naive engagement metric during
the audit: the top 3 "power users" in prod were all internal (Xuan ×2 + the
test coach), and **all** fuel-log / formula / carb-plan usage among recent
actives came from internal accounts.

The durable earmark is a DB column, applied to **dev + prod** on 2026-07-08:

```sql
users.is_internal BOOLEAN NOT NULL DEFAULT false
```

SQL record: `docs/database/apply_all.sql` (Section 5) and
`supabase/migrations/_archived/20260708120000_add_users_is_internal_analytics_earmark.sql`.

### Flagged accounts (prod, 8 rows)

| User ID | Who |
|---|---|
| `5c25e7b0-c152-449f-a87f-1c77c6133d15` | Xuan — main (apple auth, xh.analytics@gmail.com) |
| `f3e1c70e-ba22-454f-bd4a-6a4c0a75c71c` | Xuan — second account (email auth) |
| `d628ceab-7fe7-40ae-8fb3-171c3ab0d44d` | Xuan — athlete-side account (coach-paired) |
| `e92cb452-0368-4bb3-a888-3e86a65d097f` | Test coach "Samwise Gamgee" (test@test.com) |
| `9754a410-25e7-4d70-8110-db51b951075f` | Test athlete "samwise g" (teest@test.com) |
| `09cd66df-b38e-42c9-a738-1f002f7c1f1e` | Lee Martin — main (lee.b.martin@gmail.com) |
| `d519d63b-954d-43fb-8eb6-713f6196bcc9` | Lee Martin — second account |
| `bed7c42b-9293-4895-a724-2c1d9fb3577d` | Ray (ruitian821@gmail.com) |

Unconfirmed candidates (anonymous sessions created on team signup days —
flag once confirmed): `aada1a31-24a5-4ac0-a4d6-88e4c5e57885` (2025-11-27),
`64dd093b-28d3-4442-bfc7-59679791089d` (2025-11-29).

When a new team member joins: set `is_internal = true` on their row(s)
**before** they start dogfooding.

### How the Mixpanel wiring must use it

1. **Ingest-time (primary):** when the user profile loads with
   `is_internal = true`, do not identify/track — swap to
   `NoopAnalyticsTracker` (same mechanism the device toggle below uses) or
   call `optOutTracking()`.
2. **Super property (belt-and-suspenders):** register `is_internal` on every
   event so anything that slips through is filterable in reports.
3. **Historical cleanup:** events already ingested from these distinct_ids —
   hide via a saved "Internal" cohort inverted on every board, or GDPR-delete
   the distinct_ids for clean numbers.

Related existing mechanism: a hidden **device-level** opt-out lives in
Settings (tap version text 7× → Developer/Tester section), persisted in
SharedPreferences (`lib/shared/services/analytics/analytics_excluded_pref.dart`).
Keep it, but do not rely on it — it is per-device and resets on
reinstall/new device. The DB flag is the source of truth.

## 2. Data caveats for any engagement analysis

- **`users.last_active_at` is broken — do not use it.** It is frozen at (or
  even before) signup for most users; e.g. accounts show day-0 while their
  client writes continue for weeks. Until fixed, derive activity from client
  write timestamps: `daily_macro_targets.created_at`,
  `activities.local_updated_at`, `food_preferences.updated_at`,
  `personal_formulas.updated_at`, `user_foods.updated_at`.
- `daily_macro_targets.created_at::date` ≈ app-open days (targets are
  client-generated on open). Provider syncs (Final Surge at least) appear
  client-triggered, so `activities` sync days also indicate opens.
- Nutrition plans are **always user-created** (generate → create flow in
  `macro_targets_controller`; fires `nutrition_plan_created_from_adjusted_macros`).
  There is NO auto-generation path — `users.auto_generate_nutrition` is a dead
  column that gates nothing; do not interpret it. Plan existence on an
  activity IS deliberate intent. `nutrition_plan_data->>'updatedAt'` bumps,
  however, can be background refreshes (`needsNutritionRefresh` after provider
  schedule changes), not user edits.
- The intermediate "generate macros" step persists nothing server-side on its
  own — generate→create abandonment is invisible in the DB. Mixpanel must
  fire an event at the generate step to make that funnel measurable.
- **Plan re-saves are always user actions.** Every caller of
  `_saveNutritionPlanToActivity` is an edit (food swap/add/remove, quantity
  scaling, by-hour slot ops) except `initializeByHourData` (first open of the
  by-hour view). So `nutrition_plan_data->>'updatedAt'` >
  `createdAt` = the user came back and interacted; if no section has
  initialized `byHourData`, it was an edit. The JSON keeps no before/after,
  so Mixpanel needs explicit events for swap/remove/quantity-change and
  by-hour-view-opened to know *what* the edit was.

## 3. Audit findings snapshot (2026-07-08, internal accounts excluded)

- 263 prod users; ~6 genuinely active externals in the last 7 days.
- Cohorts: 131 day-0 churn (73% anonymous, 60% onboarded — onboarding/auth
  leak), 110 returned-then-churned (did planning setup, never started the
  logging loop), ~20 active-30d.
- **Integrations are the top retention differentiator** (~60% of actives vs
  1–2% of churned have one) — they explain the *comeback* loop (a reason to
  reopen), not the *feedback* loop.
- **Completion has two paths with opposite feedback behavior** (2026-07-08
  external numbers): manual tap → the completion flow prompts for ratings and
  **7 of 10** manual completions carry one; Garmin server-side auto-complete
  (`garmin-push`/`garmin-ping` edge functions stamp `completed_at` on a
  matched planned activity) → **0 of 17** carry any rating. The feedback loop
  converts when a human initiates it; auto-completion silently swallows the
  moment. Fuel logs remain zero among externals on both paths.
- **`activities.completion_type` is unreliable**: the column defaults to
  `'manual'` and the Garmin edge functions never set it, so auto-completed
  rows are mislabeled `manual`. Distinguish with `garmin_summary_id IS NOT
  NULL` until the edge function sets `completion_type = 'automatic'`
  (enum value exists in the app, currently dead code).
- 117-user signup spike week of 2026-05-25 almost fully churned.

### Plan engagement ↔ retention (2026-07-08, externals only)

Lifetime segments: never-created-plan (151 users) → 5% return in a 2nd week.
Created ≥1 plan (80) → 86% return in a 2nd week but only 3% reach 4+ active
weeks. Created AND edited a plan (24) → 83% / **29%** reach 4+ weeks, 25%
still active last 30d (~8x the created-only rate).

Leading-indicator test (week-1 behavior → any activity in week 3+, users
≥21 days old): week1 create+edit 95% (20/21) · week1 create-only 83% (15/18)
· no week1 plan 35%. Plan creation is the activation gate; plan *editing* is
the best available predictor of long-term retention.

Caveats: correlational (editors may simply be more motivated); N=21–24 in the
edit segments; the retention proxy uses activity write-dates which include
server-side provider syncs, inflating the 35% baseline. Mixpanel retention
cohorts on explicit events will make this precise; an onboarding nudge
experiment ("swap one food") is the way to test causation.

**Proxy sensitivity warning:** re-running the week-1 test with a strict
app-open proxy (macro-target + food-pref writes only, no activity rows)
gives week1-plan 25% vs no-week1-plan **1%** retained to week 3+. Absolute
retention numbers swing wildly with the activity proxy chosen; the *relative*
lift (plan creators retain at ~25x) is consistent across proxies. Do not
quote absolute retention until Mixpanel `app_open` exists.

### Activation funnel (255 externals, lifetime, 2026-07-08)

signup 255 → onboarded 195 (−24%) → has ≥1 activity 116 (−41%) →
created ≥1 plan 104 (−10%) → edited a plan 24 (−77%) → any feedback 5 (−79%).

**The activity→plan step converts at 90%** (only 12 users had an activity but
no plan) — plan creation is nearly automatic once an activity exists. The
real activation cliff is onboarded→first-activity: 86 onboarded users (44%)
never added one. "First activity added/synced" is the activation event to
instrument and optimize, ahead of plan creation. Week-1 integration connect
(N=8) shows the same direction as week-1 plans but is too small to rank.

### Integration ↔ plan creation (2026-07-08)

User-level correlation is negligible (φ=0.08; 57% vs 40% plan-creation rate,
N=14 integration users). Activity-level is strongly INVERSE: manually added
activities get plans at **72.4%** (165/228 — partly tautological, the plan
flow creates draft activities) vs **5.4%** for provider-synced activities
(26/480). Synced workouts are calendar filler, not plan triggers — the
sync→plan bridge is the biggest unexploited conversion surface. KPI:
"synced-activity plan rate" (now 5.4%). Instrument `plan_created` with
`source_activity_type: synced|manual` to track it.

User-level segmentation of the 26 externals with synced workouts: planned
≥1 synced workout (11 users) → 45% retained w3+; synced but planned only
manual (10) or never planned (5) → 20%. Directional 2x lift; N too small to
be conclusive. Even converters plan only ~10% of their synced volume.

**Funnel definition fix:** "added activity" conflates intentional adds with
passive sync backfill, so integration users pass it for free. Activation
must be intent-aware: manual path = first manual activity (≈ first plan);
synced path = **first plan on a synced workout** (sync alone ≠ activation).
KPI pair: synced-plan activation rate (11/26) and synced-plan coverage
(~10% among converters).

### "Truly used the plan" — depth signals (191 external plans, 104 users)

Two proposed signals: (1) plan edited/food-deleted, (2) user tapped back into
the plan later. What the DB can and can't see:

- **Edited: measurable.** 50/191 plans edited (updated>created+5s). But 43 of
  those are **same-day** (creation-session polish); only **7** are a
  later-day re-save (unambiguous return session).
- **Food *deleted* specifically: NOT measurable.** Plan JSON stores only
  current state — no soft-delete flag on food items (keys: name, quantity,
  scaleMultiplier, timing… no isDeleted). A delete is indistinguishable from
  a swap or quantity change. Needs a `plan_food_removed` event.
- **Tapped back / viewed: mostly NOT measurable.** Pure views leave no DB
  trace. The one exception: opening the by-hour fueling view WRITES
  `byHourData` into the section, so it persists — **13/191** plans show it.
- **Plan rated: 0/191 external, 0/391 internal — CONFIRMED DEAD UI.** The
  only code that sets `planRating` (PlanRatingController + `plan_how_well_screen`,
  a 1–3 scale) lives in `lib/features/_archived/user_journal/` and is routed
  nowhere active. Live code only deserializes the field. `effort_rating` is
  the same (0 internal). Do NOT instrument these — they aren't reachable.
  Reviving needs feature work, not analytics (domain field + serialization
  still exist, so no schema change). The WORKING post-plan feedback surface
  is the completion flow: `fuel_log_data` (20 internal), `completion_rating`
  (30), `nutrition_rating` (9) — all fire from live controllers, so external
  zeros there are genuine non-engagement, not broken UI.

**Return signal** (later-day edit OR by-hour view opened) = 18/191 plans,
13 users. Retention: returned-to-plan users **46%** retained w3+ / 23% active
last-30d, vs created-no-return **7%** / 10% (N=13 vs 91). ~6.5x lift —
stronger than the create/edit split. "Returned to a saved plan" is the
deepest activation signal available and should be a first-class Mixpanel
event, but the DB only captures ~2 of its many forms; instrument
`plan_viewed` (screen-view on a saved plan), `plan_food_removed`,
`plan_food_swapped`, `byhour_view_opened`, and revive `plan_rated`.

### Race event ↔ retention — CONFOUND, not a driver (2026-07-08)

Raw: race-havers retain 8% w3+ vs 5% (φ=0.065, negligible). But controlling
for plan creation kills it — 2×2 (retained w3+):
no-plan/no-race 1% (137) · no-plan/race 9% (11) · plan/no-race **16%** (50) ·
plan/race 8% (49). Race-havers create plans at 82% vs 27%; the plan drives
retention, not the race. Within planners (well-powered cells) race is
directionally *negative*. Interpretation: a race is a one-off goal →
event-driven users prep (33% carb-load) then churn post-race; training-run
planners without a race build the habit that retains. Do NOT use "add a race"
as an activation lever. Instrument race dates in Mixpanel to measure
retention relative to race day and trigger post-race re-engagement ("next
training block"), not as a retention KPI. Caveats: race-only N=11; w3+ window
may misread long pre-race lulls as churn.

### Race ↔ carb-loading — dependency, not correlation (2026-07-08)

Carb-loading is structurally race-gated: all 42 carb plans link to a real
event, **0 exist without a race**. So φ=0.518 is inflated by the dependency,
not a real association. Honest metric = funnel conversion: 64 race users →
21 carb-load = **33% attach**. Decent for a deep multi-day feature. Caution:
carb-loaders are the most-committed slice of the event-driven race cohort
that churns post-race → highest let-down/churn risk; prime target for a
"next training block" re-engagement trigger. Instrument as a funnel step
UNDER race (`carb_load_started` w/ parent event id + days_to_race), not an
independent lever. Carb-loader retention is N=21 — needs Mixpanel + race
dates to measure relative to race day.

### Carb-loading depth + post-race return (2026-07-08)

**Depth — 100% procedural, generate-and-forget.** 25 external plans / 21 users,
66 day-rows generated. Engagement against them: logged-carb days **0**, days
marked completed **0**, plans completed **0**, adherence scores **0**, day-meals
logged **0** (globally, incl internal), custom carb foods **0**. Unlike
`planRating`, the tracking UI IS built and reachable (active `lib/features/
carb_loading/` service + day-meal repository with add/update/replace; coach
portal displays `loggedCarbsGrams`/`completed`). So this is GENUINE
non-engagement, not dead code: users generate the multi-day skeleton and never
track a single day against it.

**Post-race return — 84% permanent churn, no recovery-lull pattern.** Of 19
carb-loaders whose race already passed (deliberate app-open proxy, excludes
provider syncs): only **3 (16%) ever returned** after race day, despite 17/19
having 28+ days of opportunity. The "marathon → 2 weeks off → came back"
hypothesis fails — the 3 returners came back fast (median 2 days), i.e. they
never really stopped; nobody shows the recovery-break-then-return signature.
Return is binary: kept-going or gone-for-good. Confirms carb-load+race = most
event-driven cohort with the highest post-race churn. Highest-value trigger:
re-engage in the 3–10 days after race day BEFORE the churn sets in. Caveat:
N=19; strict proxy (device re-sync without app-open not counted).

Which synced workouts get planned (26 of 480): long + Saturday +
just-in-time. 10mi+ → 20.5% plan rate (4x baseline); Saturday → 10.6% with
planned Saturdays averaging 14.0mi; Sunday → 1.6% (lowest, unexplained).
Median plan created **1 day before** the workout, 69% within a day, only 4
of 26 planned 4+ days ahead — nobody plans the week, they plan tomorrow.
**Synced swims: 0 of 121 ever planned** (25% of sync volume; possible
product gap — during_swim enum only recently added). Bridge design: prompt
the evening before long workouts (Fri → Sat long run = highest-yield slot).
Add `days_before_workout` + `workout_distance_bucket` properties to
`plan_created`.

## 4. Push-notification delivery verification (OneSignal)

Nothing in Supabase records whether a push was sent or delivered — the Garmin
edge functions only `console.log` the send (≈24h retention). OneSignal is the
system of record. Plan (agreed 2026-07-08):

1. Get a valid REST API key — the copy in `.env.prod.local` is **rejected by
   the OneSignal API** (stale or placeholder); the working key is in the
   Supabase edge-function secrets or OneSignal Dashboard → Settings → Keys &
   IDs. App ID: `335e597f-9862-4fa1-91f9-506d546ef953`.
2. `GET /apps/{app_id}/users/by/external_id/{user_uuid}` → per-user
   subscription status (answers "never subscribed vs unsubscribed vs
   subscribed-and-ignoring"). Manual alternative: OneSignal Dashboard →
   Audience → search external ID.
3. `GET /notifications?app_id=…` → sent/delivered/clicked for recent pushes
   (~30-day retention) = the delivery funnel.
4. Durable fix: edge functions write OneSignal's response (notification id +
   recipient count) to a `notification_sends` table so delivery questions
   become SQL queries. Track a server-side `push_sent` event once Mixpanel is
   wired.

**VERIFIED via OneSignal API 2026-07-08 (corrects earlier assumption):**
- Anna & Claudia are BOTH push-subscribed (iOSPush, enabled=true,
  notification_types=31, valid token). The DB `users.notifications_enabled=false`
  is NOT a deliverability signal — it's out of sync with real OS/OneSignal
  push state. Do not use it to reason about push reach.
- Recent 30 "Workout uploaded" messages: 25/30 delivered (~83%), 5/30 hard
  failed (stale tokens), **7/30 clicked (~23% tap rate)**. Pushes ARE sent,
  delivered, and tapped.
- So the auto-completion feedback gap is NOT a delivery problem. It's the
  message: "Workout uploaded" is a passive FYI that deep-links to the activity
  view, not the fuel-log/rating flow. A tap yields an app-open, not a logged
  entry. **Fix = push copy + deep-link destination** ("How did fueling go on
  your 12-miler?" → rating screen), NOT permission re-prompting. There's a
  live 23% tap audience being wasted.
- Secondary: ~17% hard-failure rate → periodic stale-token cleanup.
- App ID 335e597f-9862-4fa1-91f9-506d546ef953; working REST key is the long
  os_v2_ form (in Supabase edge-function secrets / OneSignal dashboard), NOT
  the 25-char value that was stale in .env.prod.local.

## 5. Recommended priorities (synthesis, 2026-07-08)

**Why events at all (Mixpanel or a Supabase `analytics_events` table):** tables
record state; only an event stream captures behavior + negative space. Blind
spots this session that no schema can fill: plan/screen *views*, the invisible
majority who open→browse→leave without a write, generate→create drop-off,
which edit happened (swap vs delete), reliable retention (proxies swung 3–4x;
`last_active_at` broken), acquisition source. DB stays better for state,
content, joins, ground truth — the two are complementary. You need an event
stream; Mixpanel is optional (fastest self-serve funnel/retention UI, but ships
health-adjacent data to a 3rd party — an in-house events table keeps the GDPR
posture cleaner). Capture `app_opened` + views + funnel steps regardless.

**App changes most likely to drive engagement (ranked, each evidence-backed):**
1. Rewrite auto-completion push + deep-link into fuel-log/rating screen
   (83% delivered, 23% tapped, but dead-ends on activity view; 0 external
   fuel logs). Lowest effort, highest confidence.
2. End onboarding with a first activity ("next run?") / move provider-connect
   into onboarding — 44% of onboarded never add one, ~1% retention without it.
3. Prompt a plan the evening before synced long/Saturday runs — synced plan
   rate 5.4% vs 72% manual; planning a synced workout → 45% vs 20% retention.
4. Post-race re-engagement trigger, 3–10 days after race date — 84% carb-load
   churn, no recovery-lull, immediate exit.
5. A/B test a week-1 "swap one food" nudge — editing in wk1 → 95% wk3
   retention (correlational; TEST, don't assume causal).

**Minimal event set (question each answers):** `app_opened` (retention,
foundational) · `plan_viewed` (did they look) · `plan_generate_started`
(generate→create drop) · `plan_created` +props source_activity_type/
days_before_workout/distance · `plan_food_swapped|removed|quantity_changed`
(decompose edits) · `first_activity_added`+source (cliff #2) · `push_opened`
→next-action (does #1 work). Skip plan_rated/effort_rating — archived UI.

## 6. Open items

- Fix `last_active_at` updating (or replace with a server-side heartbeat).
- Confirm + flag the two anonymous internal candidates.
- Mixpanel ID-merge check (anonymous → authed identity) — open from the
  instrumentation branch.
- Build the "Internal" exclusion cohort in Mixpanel once wired.
