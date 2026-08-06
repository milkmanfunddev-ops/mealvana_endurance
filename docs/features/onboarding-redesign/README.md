# Onboarding Replacement — feature/onboarding-redesign

> **This design document is saved in the repo at `docs/features/onboarding-redesign/README.md`** (app repo, branch `feature/onboarding-redesign`). That copy is the canonical, living feature doc — keep it updated as phases land. The visual reference is the HTML prototype at `../prototypes/onboarding/index.html` (prototypes repo, commit `9d73588`).

## Context

Replace the current 5-step onboarding (connect_training → user_profile → sports → dietary → allergies → auth) with the new design prototyped at `../prototypes/onboarding/index.html`. The new flow is value-first: sport/goal/pitfall questions, optional training-platform connect, body composition and gut/sweat self-reports, then a **computed fueling plan (carb g/hr, fluid, sodium, day-type macros) shown before account creation**. Auth stays last, reusing the existing anonymous-session + credential-linking machinery.

Why: the current flow collects data without showing value, never collects gut-training/sweat-rate (inputs the fueling formulas need — they silently default until found in Settings), and its docs/tests are stale (the Patrol test taps a screen removed in June).

### New flow (9 PageView steps + auth)
| idx | step (analytics name) | screen |
|---|---|---|
| — | splash | rebuilt `welcome_screen.dart` body — "Build My Plan" / "I already have an account" |
| 0 | `sports_selection` | rewrite: Running, Cycling, Swimming, **Triathlon**; multi-select, none pre-selected |
| 1 | `goals` | NEW `goals_screen.dart` — multi-select, non-blocking |
| 2 | `pitfalls` | NEW `pitfalls_screen.dart` — multi-select, non-blocking (reuse `expandable_more_options_widget.dart`) |
| 3 | `connect_training` | reuse `ConnectedAppsScreen` onboarding mode, restyled; TriDot "Notify Me" stub; "I don't use training plan apps" tile; never blocks |
| 4 | `personal_info` | NEW — names/email optional; gender (Non-binary → existing `Gender.other`); birth-year wheel |
| 5 | `body_composition` | NEW — unit toggle, height/weight wheels; lift Garmin weight-autofill from old `user_profile_screen.dart` |
| 6 | `nutrition_settings` | NEW — `GutTraining` (0.7/1.0/1.2×) + `SweatRateCat` (0.85/1.0/1.2×) cards, existing enums |
| 7 | `plan_reveal` | NEW — loader animation → editable long-run/long-ride g/hr, fluid mL/hr, sodium mg/hr; sweat-test note; connect-nudge if no platform |
| 8 | `daily_plan_preview` | NEW — Workout / Rest / Carb-load tabs (g/kg, grams, kcal) |
| — | auth | restyled `PostOnboardingAuthScreen` — "Your plan is ready. Don't leave it behind." |

Routes unchanged (`/welcome`, `/onboarding`, `/auth/post-onboarding`) — avoids touching router redirect logic. Verify the splash "I already have an account" login target (open item).

### Locked decisions
- **Diet/allergies dropped from onboarding**: `saveAllOnboardingData` unconditionally writes Omnivore + no-allergies defaults (commented block explaining why) so downstream food filtering keeps a defined value; users edit later via the surviving Settings dual-mode screens.
- **Plan-reveal math is client-side** (works anonymous/offline/biometrics-free); server pipeline stays authoritative after sync.
- **Preview numbers = current server parity**, not the prototype's placeholder values (rest 4.0 g/kg, preload 9.0, protein 1.4 fallback). A new daily-macro **SSOT document is coming** and the current server math is close to it — so all preview constants/formulas live centralized in one calculator file, swap-ready for when the SSOT ratifies (server + preview + fixtures update together).
- **Birth year only**, stored as `DateTime(year, 7, 1)` (documented mid-year convention).
- **Analytics clean break**: new `kOnboardingStepNames`; Mixpanel funnel rebuilt on new names (user owns this), old funnel archived.
- **Hard replace on this branch** — no feature flag.

### Hard requirements (Lee)
- Drift restraint: ONE new table, one version bump (15→16), no reshaping existing tables; mirror to Supabase dev + prod.
- Keep producing every downstream-consumed field in today's shape via existing services/enums.
- Integration failure paths all handled (skip → generic defaults; Runna ICS → zero biometrics; TP-without-Garmin; connect fail → MealvanaSnackbar + retry). FinalSurge ~7d / TP ~30d history-window copy.
- Garmin stays on the connect page.
- Mixpanel per step + Sentry on every failure path incl. Drift FK errors — no silent failures.
- All onboarding tests removed and rewritten; every failure point + calc sensitivity covered.
- Anonymous-user data-loss hazard mitigated (below).

## Implementation

### 1. Preview engine (verified reuse targets)
- `lib/features/nutrition_plan/data/offline_macro_calculator.dart` **already mirrors** `getDurationCarbBand`, `getGutTrainingMultiplier`, `getSportCarbCeiling`, `calculateDuringWorkoutCarbRate`, `baseSweatRateFromCategory`, `calculateDuringWorkoutHydration` — reuse as-is.
- NEW `lib/features/nutrition_plan/application/daily_baseline_calculator.dart` (pure/static): Mifflin-St Jeor exactly as `rmr.ts` (`10w + 6.25h − 5a + (male ? 5 : −161)`; `Gender.other` → non-male branch), baseline g/kg macros + clamps (3–12 carb, 1.2–2.5 protein), masters ×1.15 at ≥45, NEAT/TEF kcal factors. **All constants in this one file** — the SSOT swap point.
- NEW `lib/features/onboarding/application/plan_preview_service.dart`: `buildPreview(OnboardingDraft) → OnboardingPlanPreview`. Long-run g/hr = carb-rate calc at representative 150 min running; long-ride = 180 min cycling; fluid/sodium from sweat category. Day tabs from baseline calculator (rest = baseline; workout = baseline + representative session addition via the real formula; carb-load = 9.0 preload). Cards only for selected sports (triathlon ⇒ both). Every input nullable with documented generic defaults (70 kg / 172 cm / 35 y / non-male offset) + `isGeneric` flag → "estimates" caption. Top-level guard: capture to Sentry and fall back to generic, never blank.
- **Parity fixtures**: `test/features/onboarding/fixtures/plan_preview_parity.json`, values hand-derived from the TS sources; a small Deno test under `supabase/functions/` runs the same JSON through the TS functions. Covers: male/female/other, age 44/45 boundary, each gut × sport ceiling (run 70 cap engages), each sweat category, clamps, all-null generic case.

### 1b. Training-data intake + insight engine (connected-platform path)
When a platform is connected during onboarding, the plan reveal must be personalized from actually-pulled workouts, not the generic preview:
- **Intake reliability gate**: the onboarding auto-import (already triggered by `ConnectedAppsScreen` onboarding mode) must cover **at least a 7-day window** of workouts before insights are considered reliable. Pull what each platform allows (FinalSurge ~7d — exactly the minimum; TrainingPeaks ~30d; Runna ICS = full calendar, workouts only, zero biometrics; Garmin per its API). If the retrieved window spans <7 days or contains too few sessions (threshold constant, e.g. <3 workouts and no qualifying long session), the plan reveal **falls back to the generic preview** with an honest caption ("we'll refine once a full week syncs") — never unreliable insights, never an error.
- NEW `lib/features/onboarding/application/training_insight_service.dart` — the insight engine. Reads imported workouts read-only from the existing workout repositories/tables the integration sync services already write to (locate exact repo during implementation — no new tables). Digests them into a `TrainingInsights` value: longest run + longest ride (duration/distance), weekly session count, heavy-vs-rest day pattern, weekly load distribution, `isReliable` flag from the gate above. Designed as pure digestion over a `List<Workout>` input so it's trivially unit-testable with fixtures.
- `PlanPreviewService` consumes `TrainingInsights?`: when reliable, the representative long-session durations (150/180-min constants) are **replaced by the athlete's actual longest run/ride**, workout-day macros key off a real heavy day, and the reveal/daily screens render insight lines ("Built around your 15-mile long run", per the prototype). When null/unreliable → constants + `isGeneric` behavior as in §1.
- **Loader behavior**: "Building your plan…" awaits import+digest when a connect happened, with a hard timeout (e.g. 10s) that falls back to generic + background-completes the import; Sentry-captures import failures. No connect → loader is purely cosmetic as before.
- Biometrics-free contract holds: Runna/ICS insights (workout durations/frequency) work with zero biometric fields; body-composition inputs still come from the draft or generic defaults.

### 2. Domain + controller
- NEW `lib/features/onboarding/domain/onboarding_draft.dart` — immutable draft (sports/goals/pitfalls enums with `dbValue` round-trips, names/email, gender, birthYear, units, height/weight, gutTraining, sweatRate, planEdits, connectedProvider, tridotNotifyRequested).
- Rewrite `onboarding_controller.dart` keeping the hard-won parts verbatim: `saveAllOnboardingData` skeleton, `_migrateOnboardingDataToNewUser`, `_uploadUserProfileToSupabase`, `_syncGarminMappingIfNeeded`, no-cached-profile guard. New save order: profile (with gut/sweat — extend `OnboardingService.createUserProfile`/AuthService signature) → diet/allergy defaults → survey row → plan-edit overrides → migrate/upload. Delete the five step caches + food-preference block. **Keep** `saveDietaryPreference`/`saveAllergies`/`saveSportPreferences` (Settings dual-mode screens call them — grep before touching).
- Plan edits persist via existing `NutritionTargetOverrides` (`duringRun`/`duringCycling` `carbRateGPerH`/`fluidRateMlPerH`/`sodiumRateMgPerH` — verified present) through `NutritionTargetGuardrails.clampAll`; write only fields the user actually edited (untouched = null = algorithm default). **No schema change.**

### 3. Persistence (the one Drift change)
- NEW table `onboarding_surveys` (user_id PK→user_profiles, sports/goals/pitfalls JSON text, `survey_payload` JSON escape hatch for tridot_notify/sweat_test_interest/future questions, completed_at, needs_upload, timestamps) — copy conventions from an existing simple table. `schemaVersion => 16`, idempotent `ensureTable` in onUpgrade, add to `diagnosticDao.migrateUserData` user-scoped tables.
- NEW `lib/features/onboarding/data/onboarding_survey_repository.dart` + registration in the sync coordinator's upload graph (locate registration mechanism in `lib/shared/services/sync/sync_coordinator.dart`), ordered after user profile (FK). Check `uploadDirtyRecords` result — no swallowed failures.
- Supabase: idempotent SQL (CREATE TABLE + RLS `user_id = auth.uid()` policies, mirroring the rls_baseline style) into `docs/database/apply_all.sql`, applied by hand (DataGrip) to **dev now, prod at release**, archived dated copy in `supabase/migrations/_archived/`. Load `supabase:supabase-postgres-best-practices` skill when authoring. `app_config.current_schema_version` → 16 **only when the schema-16 build ships** (it triggers client drop-and-resync).
- Gut/sweat, names, gender, birthday, height/weight, units, overrides, diet/allergy defaults: all existing columns — no changes.

### 4. Integrations step
Reuse `ConnectedAppsScreen(onContinue:, stepIndex: 3)`; changes confined to its onboarding branch: prototype restyle, TriDot `_ComingSoonProviderConfig` Notify-Me → analytics + `survey_payload` flag, "I don't use training plan apps" tile (analytics `connect_training_declined`, distinct from skip), history-window subcaptions, audit every `_connect*` catch for MealvanaSnackbar + retry state + Sentry capture (`connect_training_controller.dart`). Temp-user-id stamping untouched.
Verify each provider's onboarding auto-import requests the widest window it supports (≥7 days minimum for the §1b reliability gate); record the achieved window span alongside the import so the insight engine can evaluate reliability.

### 5. Auth-last
`PostOnboardingAuthScreen`/controller mechanically as-is (credential-linking, same-uid, saveAll call, background upload, Settings anon→upgrade branch untouched). Copy restyle via content keys + optional plan-summary chip from the draft.

### 6. Observability
- `kOnboardingStepNames` → new 9-name list (funnel contract; clean break per decision).
- New events: `goals_selected`, `pitfalls_selected`, `plan_preview_viewed {is_generic}`, `plan_target_edited {field, from, to}`, `daily_preview_tab_viewed {tab}`, `sweat_test_link_tapped`, `integration_notify_me_tapped`, `connect_training_declined`.
- Sentry `captureException` with `{feature: 'onboarding', step}` tags on: each saveAll sub-step, survey repository Drift writes (FK/constraint SqliteException explicitly), connect failures, preview-engine guard. Existing kept `catch { DebugLogger }` blocks gain Sentry capture.

### 7. Anonymous-user hazard mitigation
Anonymous users have real Supabase sessions (2026-07 policy) so drop-and-resync normally re-pulls them; residual risks are offline-at-upgrade and lost keychain session. In scope:
1. Survey table participates in standard needs_upload sync (restored by re-pull).
2. `onboarding_snapshot_v1` JSON in SharedPreferences written at saveAll success ({profile essentials, survey, overrides}); after DB recreate, if no user row returned and snapshot exists → re-import locally with needs_upload=true.
3. Verify/add a `VersionCheckService` guard deferring delete-and-resync for anonymous users with dirty rows while offline.
4. PR note: broader anonymous upgrade safety is its own future workstream.

Sweat-test link on plan-reveal does NOT deep-link mid-onboarding: sets `sweat_test_interest` in survey_payload + analytics + "anytime in Settings → Sweat Profile" caption.

### 8. Tests (all new; old ones deleted)
- Unit (`test/features/onboarding/`): `plan_preview_service_test.dart` (parity fixtures; gender-flip changes RMR/kcal; gut flips g/hr; run ceiling; sweat flips fluid+sodium; generic case sane), `daily_baseline_calculator_test.dart`, `training_insight_service_test.dart` (workout fixtures: full reliable week → correct longest-run/ride + heavy-day pattern; sparse week → isReliable=false; Runna-style zero-biometrics workouts still digest; empty list → generic; 7-day-window boundary), `plan_preview_service` with-insights cases (actual longest run replaces the 150-min constant; insight lines populated), `onboarding_draft_test.dart` (enum round-trips), `onboarding_controller_test.dart` (save ordering, defaults written, failure → AsyncError + Sentry mock, overrides only-when-edited).
- Drift: `test/db_flows/onboarding_survey_test.dart` (insert/update, FK violation captured not silent, migrateUserData temp→real, onUpgrade idempotency ×2).
- Widget: one per new screen (toggle→draft, gate rules, edited values render, tabs, nudge-card iff no provider).
- Patrol (`integration_test/flows/onboarding_signup_flow_test.dart` rewrite): happy path → email signup → `/main` with plan data; skip-everything → anonymous with local survey row; connect-fail → snackbar → retry → skip proceeds.
- TS: shared-fixture Deno parity test only.
- Delete: `test/db_flows/onboarding_test.dart`, `test/smoke_tests/onboarding_smoke_test.dart`, old Patrol flow. `allergy_json_list_test.dart`: verify whether it covers live Settings parsing; likely keep/relocate.

### 9. Deletions (grep-verify zero refs before each; build_runner after provider removals)
Delete: `welcome_screen_controller.dart`(+.g), `food_preferences_v2_screen.dart`, `food_preferences_controller.dart`(+.g), `food_selections_cache_provider.dart`(+.g), `user_profile_screen.dart` (after autofill lift), stale docs `docs/features/onboarding-revamp/*`, `docs/test/screen_audit/02_onboarding/*` → replaced by new `docs/features/onboarding-redesign/README.md`.
**Survive** (Settings routes): `dietary_preference_screen.dart`, `allergies_screen.dart`, `running/cycling/swimming_details_screen.dart` (`/settings/*` ScreenMode.settings), `ConnectedAppsScreen`, controller save methods they use.

### 10. Phasing (commit-sized chunks)

> **Status (2026-08-06):** phases 0–4 landed. Phase 4 notes: shared step
> layout lives in `presentation/widgets/onboarding_multi_select_step.dart`
> (rows reuse the existing `FigmaCheckboxCard`); pages 4–8 are stubs
> (`_StubStepScreen` in the pageview file) awaiting phase 5; the connect step
> still shows its internal 3-segment progress bar — phase 5 restyle switches
> it to the 9-segment bar; copy is hardcoded with ValueKeys, matching the
> sibling-screen convention (no onboarding.* content keys exist).

0. **Plan doc** — commit this plan into the repo as `docs/features/onboarding-redesign/README.md` (first commit on the branch; it doubles as the feature doc that replaces the stale `onboarding-revamp` docs, updated as phases land).
1. **Engine + domain** — draft, calculator, preview service, insight engine (`training_insight_service.dart` + workout fixtures), parity fixtures + unit tests (pure Dart, no codegen).
2. **Persistence** — Drift v16 + repository + sync registration + migrateUserData; dev SQL applied + archived; Drift tests. `dart run build_runner build --delete-conflicting-outputs`.
3. **Controller rewrite** — draft-based controller, saveAll rework, service signature, Sentry, unit tests. Codegen.
4. **Screens A** — splash, sports/goals/pitfalls, PageView rewrite (later steps stubbed), `kOnboardingStepNames`, widget tests.
5. **Screens B** — personal info, body comp, nutrition settings, plan reveal (incl. insight-driven personalization + loader await/timeout), daily preview; connect restyle + import-window verification; widget tests.
6. **Auth restyle + anon snapshot mitigation + Patrol rewrite** (3 flows).
7. **Deletions + docs + final sweep**; prod SQL + `current_schema_version` bump deferred to release (after phase 6's mitigation is in).

Run `/task-checker` before each commit per CLAUDE.md.

### Open items (flagged, not blockers)
- Splash "I already have an account" login route target — confirm the existing sign-in entry point when building the splash.
- Exact workout repository/tables the integration sync services write during onboarding import — locate in phase 1 for the insight engine's read path.
- Per-provider max import windows in the existing sync services (vs the documented FS ~7d / TP ~30d) — verify during phase 5.
- Workout-day representative session addition constant — pick from the real session formula; ratify against the incoming daily-macro SSOT doc when it lands (single swap point in `daily_baseline_calculator.dart`).
- Sync-coordinator repository registration mechanism — locate during phase 2.

## Verification
- `flutter test test/features/onboarding/ test/db_flows/` green; Deno parity test green (`deno test` in the edge-function dir).
- `dart run build_runner build` clean; `flutter analyze` clean.
- Manual: sim-dev-login script → walk full flow on the booted simulator (happy, skip-all, connect-fail via airplane mode); verify plan numbers vs a hand-computed fixture case; verify anonymous "continue without account" lands on `/main` with local data, then account-create from Settings binds it.
- Patrol suite on device/simulator before merge; CodeMagic Mac-Mini lane green.
- Supabase dev: survey row appears after signup with RLS blocking cross-user reads.
