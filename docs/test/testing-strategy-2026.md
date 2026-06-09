# Mealvana Endurance — Testing & Observability Strategy (June 2026)

This is the multi-pronged plan for making the app testable without it being a nightmare.
It is grounded in an audit of the repo (June 9, 2026) and current research on testing
services, device farms, and Sentry/Supabase capabilities.

---

## 0. Reality check: what we actually have (it's more than we think)

| Area | Actual state |
|---|---|
| Unit tests | **105 test files, ~26.5K lines** in `test/` — real coverage of nutrition explanations, sync, mappers |
| Edge function tests | **43 `.test.ts` files** — LP solver, template solver, hydration, sodium scoring; runner at `supabase/functions/run-algorithm-tests.sh` |
| Patrol | v4.3.0 configured in `pubspec.yaml`; **only a smoke test is active** — real flows parked in `integration_test/flows/_legacy/` |
| CI | GitHub Actions `test.yml` runs Flutter tests + edge tests on PR; Codemagic has `pr-validation` and `integration-tests` workflows |
| Sentry | Fully initialized in all four entrypoints; **replay-on-error-only already configured** (`sessionSampleRate: 0.0`, `onErrorSampleRate: 1.0`); screenshots on; symbol upload configured |
| Mixpanel | Integrated behind an abstract `AnalyticsTracker`; only ~5–10 distinct events tracked |
| Integrations (TP/FS/VDOT/Garmin) | **Zero tests** despite being the spikiest code in the app |

### Known rot to fix immediately
1. **GitHub Actions pins Flutter 3.24.0** but `pubspec.yaml` requires Dart `^3.8.1`
   (ships with Flutter ~3.32+). The test workflow is likely failing or silently stale.
   → `.github/workflows/test.yml`
2. **Codemagic release workflows removed all testing** ("REMOVED ALL TESTING for faster
   deployment testing" comment in `codemagic.yaml`). Releases currently ship unvalidated.
3. `docs/test/README.md` references deleted edge functions and stale test counts.

---

## 1. Sentry: why no errors surface, and the fix

### Root cause
The architecture rule "controllers must use `AsyncValue.guard()`" means **every controller
exception is caught into `AsyncError` state and never propagates** to `runZonedGuarded`.
There is no `ProviderObserver` in the app (verified by grep), and only 9 explicit
`captureException` sites. Sentry is configured correctly but starved of events.

### Fixes, in priority order
1. **Add a Riverpod `ProviderObserver`** that reports provider failures:
   ```dart
   class SentryProviderObserver extends ProviderObserver {
     @override
     void providerDidFail(ProviderObserverContext context, Object error,
         StackTrace stackTrace) {
       Sentry.captureException(error, stackTrace: stackTrace, withScope: (scope) {
         scope.setTag('provider', context.provider.name ?? context.provider.runtimeType.toString());
       });
     }
   }
   ```
   Wire into `ProviderScope(observers: [SentryProviderObserver()], ...)` in all entrypoints.
   This one change surfaces ~all controller errors.
2. **Audit silent catch sites.** `uploadDirtyRecords()` catches and returns
   `UploadResult.failed()` silently (documented gotcha). Every `catch` that swallows
   should at minimum `Sentry.captureException` or add a breadcrumb.
3. **Add `SentryNavigatorObserver`** to GoRouter (`app_router.dart`) — route breadcrumbs
   make replays and error reports navigable.
4. **Add `sentry_supabase` (9.21.0)** — wrap Supabase init with
   `httpClient: SentrySupabaseClient()`. Every PostgREST/edge-function call becomes a
   breadcrumb + span; `propagateTraceparent: true` carries the trace into edge functions.
5. **Verify `sentry_drift` is actually wired** (it's in pubspec but confirm the
   `SentryQueryInterceptor` wraps the Drift executor in `app_database.dart`).
6. **Edge functions report nothing.** Add `@sentry/deno` to `_shared/` with a small
   `withSentry(handler)` wrapper; adopt in `generate-nutrition-plan-v3`,
   `generate-macros-v4`, `garmin-push` first. Supabase edge runtime supports it.
7. **Upgrade `sentry_flutter`/`sentry_drift` 9.6.0 → 9.21.0.**
8. **Replay**: already exactly what we want (record only on errors, 100% of error
   sessions, nothing else — zero bandwidth when healthy). After fix #1, replays will
   start appearing. Review masking defaults (Text/Image auto-masked) before launch.
9. **`beforeSend` drops all `TimeoutException`s.** Reasonable, but consider sampling
   them at 1% instead — sync timeout patterns are diagnostic for the integrations.

---

## 2. The algorithm parity harness (highest-value new investment)

Problem: "the nutrition plan doesn't meet the targets from generate-macros." This is a
**property violation**, and property-based testing is the cure. The solver stack is pure
TypeScript in `_shared/nutrition/` — no mocks needed.

### Build: `supabase/functions/_shared/nutrition/parity-harness.test.ts`
1. **The invariant:** for any input, run `generate-macros-v4` targets → plan solver →
   assert per-slot and per-day totals within tolerance (e.g. ±5% or ±5g, whichever is
   larger) of targets. Also assert: non-negative quantities, hydration within bounds,
   pinned foods honored, no NaN/Infinity.
2. **Corpus, not examples:** a `fixtures/` directory of real-shaped inputs (athlete
   weight/sweat rate/duration/intensity/food prefs/pins). Every production miss becomes
   a new fixture file — the corpus only grows.
3. **Nightly fuzz:** a seeded random-input generator producing thousands of cases in a
   scheduled GitHub Actions job. On violation, write the failing input to the job
   summary as ready-to-commit fixture JSON. Seeded = reproducible.
4. **Client parity:** record server responses as fixtures; replay through
   `offline_macro_calculator.dart` and `by_hour_apportionment_service.dart` in Dart
   tests asserting the client agrees with the server within tolerance. This catches
   drift between the Dart fallback and the Deno solver.
5. **Production telemetry for the same invariant** (see §7): emit a
   `plan_target_deviation` metric on every generated plan. The test harness catches
   what we can imagine; production telemetry catches what we can't.

---

## 3. Integration contract tests (TP / FinalSurge / VDOT / Garmin)

Zero tests today; spikiest code in the app; four production bugs in this area in the
last two months (token refresh, re-delete churn, duplicate sync, auth id) — none of
which became regression tests. All clients are constructor-injected via Riverpod, so
faking is cheap.

### Layer 1 — Recorded-fixture contract tests (fast, on every PR)
- Capture real (sanitized) API responses from each provider into
  `test/features/integrations/fixtures/` — auth handshakes, workout lists, edge cases
  (empty days, deleted workouts, tz-naive datetimes, `sportType: other`).
- Fake clients replay fixtures; test sync services end-to-end against in-memory Drift:
  change detection, dedup, soft-delete handling, upload-state transitions.
- **Backfill regression tests for the four recent bugs** (VDOT `+` in auth code, refresh
  creds in body, re-delete churn, dup sync). Each is a known input→bad output pair.
- Garmin is push-only: replay recorded push payloads against `garmin-push` via
  `supabase start` (see §4) — match-only logic, tz-naive matching, body comp mirror.

### Layer 2 — Live canary (nightly, not on PR)
- Dedicated test accounts on TP/FS/VDOT. A nightly GitHub Actions job
  (`flutter test --tags live_canary`) runs real auth + sync against real APIs and
  alerts on failure. This is the only way to catch **provider-side API drift**, which
  no amount of local testing can see. Keep it to ~3 tests per provider.

---

## 4. Supabase round-trip tests (does it actually upload?)

"Making personal formulas and seeing if things upload to Supabase properly" — test it
against a real local stack, not mocks.

- `supabase start` runs the full stack (Postgres + PostgREST + edge runtime) in Docker;
  GitHub Actions ubuntu runners have Docker preinstalled; `supabase/setup-cli@v1` is the
  official action.
- **Round-trip tests** (Dart, tagged `@Tags(['supabase'])`): create personal formula →
  `uploadDirtyRecords()` → assert the row exists remotely with the right shape →
  wipe local → hydrate → assert equality.
- **pgTAP via `supabase test db`** for RLS policies and constraints — this is where
  "uploads silently fail in prod" bugs (RLS denies, 42P10 partial-index upserts) live.
  Write an explicit regression test for the 42P10 onConflict gotcha.
- **Edge function integration tests** per official pattern: `supabase/functions/tests/`
  + `deno test --allow-all` against the local stack. Pure-module tests (the existing 43)
  keep running without the stack.

---

## 5. Device reality: release mode on real phones

"Works on simulator, fails in release on real phones" has a specific fix: **run the
critical-path suite in release mode on physical devices in a device farm.**

### Patrol → Firebase Test Lab (the chosen farm)
- FTL is the only farm with official Patrol support for **both** Android and iOS.
- Pricing: physical $5/hr, virtual $1/hr, **free daily quota of 30 physical + 60
  virtual minutes** — a nightly critical-path run on 2 physical devices costs ~$0.
- Flow: `patrol build android|ios` (release mode) → `gcloud firebase test ... run`.
  Codemagic has a first-class integration (build on Codemagic ~$0.25/run, devices
  billed by Google). Patrol's own docs say *don't* run on CI machines directly — farm
  is the intended path.

### Revive Patrol with a small, ruthless suite (5–8 flows, not everything)
1. Onboarding → first plan generated
2. Generate plan → totals visible and sane
3. Create personal formula → appears after restart (sync round-trip)
4. Pin/unpin formula
5. Swap food
6. Connect integration (against a stub/test account)
7. Sign out → sign in → data intact (the historical dup-bug flow)

Promote from `_legacy/` only what maps to these. Everything else stays unit-level.

### Test the *known causes* of release-only failures explicitly
- `.env` bundled as asset going stale (already bit us — empty `client_secret`): add a
  startup assertion / Patrol check that required secrets are non-empty in release.
- R8/ProGuard stripping (Drift natives, OAuth deep links), tree-shaken icons,
  cleartext HTTP policy. A single release-mode smoke on a physical device catches
  the whole class.

### Maestro as a free complement
Maestro (maestro.dev) drives Flutter via the semantics tree from YAML — no Dart build
coupling, free local CLI, and an MCP server so Claude can write/run flows. Good for
quick exploratory smokes; Patrol stays the framework for CI-grade flows. (Maestro
Cloud is $250/device/month — skip until the suite is stable and proven.)

---

## 6. Paying humans to test (yes, this exists; most of it is overkill)

| Option | Cost | Verdict |
|---|---|---|
| **TestFlight external beta** (10K testers) + Play open testing | Free | **Do first.** Recruit endurance athletes from running/tri Discords, r/TestFlight, BetaList. Wiredash is already in the app for structured feedback. |
| **BetaTesting.com** | $23–39/tester credit, 5 free credits, no contract | **The realistic paid option.** Buy ~10 testers filtered to "endurance athletes with Garmin/iPhone 13+" for a device-zoo + real-human pass before big releases. |
| Ubertesters | Free tier | Light option for build distribution + bug reports. |
| Rainforest QA | ~$200/mo + hourly | Web-focused; poor Flutter fit. Skip. |
| Applause/uTest, Testlio, Global App Testing, Test IO | $5K+/cycle, enterprise sales | Skip at current scale. |
| QA Wolf (managed, now does Android) | $2–5K+/mo | Revisit if/when there's budget to outsource QA wholesale. |
| AI testers (Sofy $49/mo tier, Waldo→Tricentis, Autify, Momentic) | varies | Flutter support is shaky (custom renderer); Maestro free tier beats them all for us. |

---

## 7. Mixpanel: from 5 events to a real funnel

Define a small taxonomy (typed event constants behind the existing `AnalyticsTracker`):
- **Activation:** `onboarding_step_completed(step)`, `first_plan_generated`
- **Core loop:** `plan_generated(sport, duration_bucket)`, `plan_viewed`, `food_swapped`,
  `formula_created(kind)`, `formula_pinned`
- **Integrations:** `integration_connected(provider)`, `sync_completed(provider,
  activity_count, duration_ms)`, `sync_failed(provider, error_class)`
- **Quality (the killer one):** `plan_target_deviation(carb_pct, protein_pct, sodium_pct,
  fluid_pct)` on every plan generation — this turns "the algorithm sometimes misses
  targets" into a measurable production distribution, joined with the §2 harness.

Pair with Sentry: when deviation exceeds tolerance, also `Sentry.captureMessage` with
the full solver input attached — production misses feed the fixture corpus.

---

## 8. CI/CD pipeline (target state)

```
PR opened
 ├─ GitHub Actions: analyze + format + flutter test (fix Flutter version!) + deno test (pure)
 └─ blocks merge
Merge to develop
 ├─ Codemagic: build dev flavor (re-enable unit-test gate)
 └─ GH Actions: supabase start round-trip + edge integration tests
Nightly
 ├─ Algorithm fuzz (seeded, thousands of cases)
 ├─ Live canary: TP/FS/VDOT real-API sync tests
 └─ Patrol critical-path → Firebase Test Lab (release mode, 1 physical Android +
    1 physical iPhone — inside free quota)
Pre-release
 ├─ Full Patrol suite on FTL device matrix
 └─ BetaTesting.com pass for major releases
```

---

## 9. Sequenced rollout

### Weeks 1–2 — stop flying blind (small diffs, huge payoff)
1. `SentryProviderObserver` + `SentryNavigatorObserver` + audit silent catches
2. `sentry_supabase`, verify `sentry_drift` wiring, bump to 9.21.0
3. Fix GH Actions Flutter version; make the PR check actually gate merges
4. Re-enable unit tests in Codemagic `pr-validation`/builds
5. `withSentry()` wrapper in the top 3 edge functions

### Weeks 3–4 — attack the algorithm problem
6. Parity harness + initial fixture corpus (§2)
7. `plan_target_deviation` telemetry (§7)
8. Regression tests for the four recent integration bugs (§3)

### Month 2 — integrations + round trips + devices
9. Recorded-fixture contract tests for TP/FS/VDOT/Garmin
10. `supabase start` round-trip + pgTAP RLS tests in CI
11. Revive 5–8 Patrol flows; wire Codemagic → Firebase Test Lab nightly

### Month 3 — outer loop
12. Nightly fuzz + live canaries
13. TestFlight external beta program (recruit endurance communities)
14. Mixpanel taxonomy rollout; first BetaTesting.com cycle before next major release

### Monthly cost at steady state
- Firebase Test Lab: ~$0–20 (free daily quota covers nightly; matrix runs extra)
- Codemagic: existing plan + ~$0.25/Patrol build
- BetaTesting.com: ~$300–400 per major release (optional)
- Maestro local, TestFlight, supabase-in-CI, GH Actions ubuntu: $0
- Everything else (Applause, BrowserStack, Maestro Cloud, QA Wolf): deliberately skipped
