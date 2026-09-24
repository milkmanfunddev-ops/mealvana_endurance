# Integration Tests (Patrol)

End-to-end integration tests for Mealvana Endurance, written with
[**Patrol**](https://patrol.leancode.co/). Patrol wraps Flutter's
`integration_test` with a native XCUITest / JUnit harness so tests can drive
native UI (permission dialogs, system webviews) in addition to Flutter widgets.

Every test in this directory uses `patrolTest(...)` and **must** be run with
`patrol test` — NOT `flutter test`. `flutter test integration_test/...` does not
build the native harness and will not run these correctly.

## Toolchain

`patrol_cli` must match the `patrol` package version in `pubspec.lock`
(currently **patrol 4.10.0**). Per the Patrol compatibility table, that pairs
with **patrol_cli 4.8.0**: 4.8.0 emits the `PATROL_INTEGRATION_TEST_IOS_RUNNER_STATIC_BASE`
runner macro and no longer accepts the older `_STATIC_BEGIN`/`_END` form, so it
needs patrol 4.10.0 or newer. A mismatched pair fails at link time with undefined
XCTest symbols (`XCUIApplication`, `__swift_FORCE_LOAD_$_XCTestSwiftSupport`) in
`PatrolImpl.o`, not with a version warning.

```bash
dart pub global activate patrol_cli 4.8.0
export PATH="$HOME/.pub-cache/bin:$PATH"
patrol doctor
```

The iOS native harness is already wired: the `RunnerUITests` target
(`ios/RunnerUITests/RunnerUITests.m` → `PATROL_INTEGRATION_TEST_IOS_RUNNER`)
plus the Podfile's `PATROL_ENABLED` gate. Patrol regenerates
`integration_test/test_bundle.dart` on every run — it is gitignored, do not
commit it.

## Running

```bash
# One flow (see each test file's header for its exact documented command)
patrol test \
  --target integration_test/flows/events_crud_flow_test.dart \
  --flavor dev \
  --dart-define-from-file=.env.dev.local \
  --dart-define-from-file=secrets/integration_test.env \
  --device "iPhone 17 Pro"        # newest-SDK simulator (Patrol-on-iOS needs it)

# Whole suite (builds the app once, runs every patrolTest under integration_test/)
patrol test \
  --target integration_test \
  --flavor dev \
  --dart-define-from-file=.env.dev.local \
  --dart-define-from-file=secrets/integration_test.env \
  --device "iPhone 17 Pro"
```

`secrets/integration_test.env` (gitignored) supplies `INTEGRATION_TEST_EMAIL` /
`INTEGRATION_TEST_PASSWORD` for the email-login-backed flows. Without it,
credentialed flows self-skip with a clear message rather than failing. Pass
`.env.dev.local` too: without it `TestConfig` falls back to built-in defaults,
and its default dev anon key is stale (testing-wave Finding 02-007).

**iOS caveat:** OAuth flows that go through `ASWebAuthSession` (e.g. Google
login) cannot be automated on iOS and self-skip. Those are exercised on Android.

**Bundle order.** A multi-target run executes the files alphabetically in one
app install, and the first flow that calls `ensureAuthenticated` leaves a
session behind. The flows that need a clean install (see the exclusion list
below) self-skip after that, so run them on their own after
`xcrun simctl uninstall <udid> com.milkman.mealvanaendurance.dev`.

## CI (self-hosted M1 runner)

`.github/workflows/tests-selfhosted.yml` is the only CI that runs this suite.
It runs on the Mac mini M1 self-hosted runner on every push and PR:

- job **`unit-web-deno`**: analyze, unit + widget tests, Deno algorithm tests,
  web e2e.
- job **`integration-patrol-ios`**: the Patrol flows in one `patrol test` call
  with one `--target` per file, so the app is built **once** for all of them.
  Runs *after* `unit-web-deno`: the box has 8 GB of RAM and cannot do both at
  once without starving the runner agent into a "lost communication" failure.

The job does not keep its own list. `scripts/patrol-targets.mjs` gives it
every `*_test.dart` in `integration_test/` and `integration_test/flows/`,
minus the files named in **`runner_exclusions.json`**, and the expected
number of `patrolTest` cases across them. The job fails when fewer cases ran
or any skipped. So:

- **A new flow joins the runner by existing.** Do not edit the workflow.
- A flow that spends on AI, needs a clean install, or needs interactive OAuth
  goes on `runner_exclusions.json` with a `reason` (`ai-spend`,
  `clean-install`, `interactive-oauth`) and a `why`. An entry naming a file
  that no longer exists fails the job.
- A file that registers its cases in a loop declares the count with a
  `// runner-cases: N` line (see `integrations_connect_flow_test.dart`).
- **A skip must be visible.** Patrol's native harness reports a
  `markTestSkipped` test as passed, and its `Skipped:` count stays 0. Flows
  call `skipFlow(reason)` from `flow_launcher.dart` instead; the runner passes
  `--dart-define=PATROL_FAIL_ON_SKIP=true`, which turns every skip into a
  failure. Pass the same define locally when a skip must not look green.
- **The account must hold live Pro (or be an Admin).** A signed-in account the
  Gate keeps closed sits on the paywall, where `ensureAuthenticated` sees
  neither the shell nor the welcome screen and the flow skips.

```bash
node scripts/patrol-targets.mjs targets    # what the job runs
node scripts/patrol-targets.mjs count      # how many cases it expects
node scripts/patrol-targets.mjs excluded   # what it leaves out, and why
node --test test/scripts/patrol-targets.test.mjs
```

Codemagic's Patrol workflows (`integration-tests*` in `codemagic.yaml`) have
had no triggers since 2026-08-20: Codemagic bills minutes and never runs this
suite. Run it locally or on the M1.

## Flows

| File | Covers | Runner |
|------|--------|--------|
| `patrol_smoke_test.dart` | Toolchain smoke: the app launches, one widget renders | yes |
| `flows/account_delete_flow_test.dart` | Sign up at `lee+e2e-*`, delete from the paywall ⋯ menu, sign up again as a new account | clean-install |
| `flows/activities_crud_flow_test.dart` | Activity create → plan (deterministic macro edge function) → edit → delete | yes |
| `flows/ai_coach_chat_flow_test.dart` | One turn in the Vana general chat (`/jade` redirects there) | ai-spend |
| `flows/ai_credits_balance_flow_test.dart` | AI credits pill → top-up sheet resolves; buys nothing | yes |
| `flows/auth_flow_test.dart` | Email login | yes |
| `flows/barcode_scanner_entry_flow_test.dart` | Barcode scanner entry from the add-food sheet | yes |
| `flows/brick_plan_flow_test.dart` | Brick workout create → plan → verify the stored legs → clean up | yes |
| `flows/energy_breakdown_flow_test.dart` | Energy breakdown (`daily_macros` read path) | yes |
| `flows/event_checklist_carbload_flow_test.dart` | Event → race-day checklist → carb-load entry | yes |
| `flows/events_crud_flow_test.dart` | Event create → read → update → delete | yes |
| `flows/formula_create_pin_flow_test.dart` | Personal formula create → add food → save → pin | yes |
| `flows/formula_pin_conflict_flow_test.dart` | Pin conflict lifecycle | yes |
| `flows/formula_pin_flow_test.dart` | Pin an existing formula | yes |
| `flows/fueling_window_persistence_flow_test.dart` | A fueling window belongs to its activity across edits | yes |
| `flows/google_login_flow_test.dart` | Google OAuth (Android; self-skips on iOS) | interactive-oauth |
| `flows/integrations_connect_flow_test.dart` | Garmin / TrainingPeaks / FinalSurge connect entry points (3 cases) | clean-install |
| `flows/learn_flow_test.dart` | Learn tab | yes |
| `flows/macro_dashboard_flow_test.dart` | Macro dashboard walk | yes |
| `flows/meal_card_interaction_flow_test.dart` | Meal/activity card: tap to edit, remove with Undo | yes |
| `flows/meal_log_build_flow_test.dart` | Build-a-meal: search → add → log → delete (no AI) | yes |
| `flows/meal_plan_build_flow_test.dart` | New Vana plan → confirm → shopping list → "Ate it" → a `meal_logs` row | ai-spend |
| `flows/onboarding_signup_flow_test.dart` | Onboarding → email signup → the paywall's onboarding shape | clean-install |
| `flows/pro_gate_flow_test.dart` | The app gate: shell, paywall, `/food` and `/vana` agree | yes |
| `flows/recommendation_stacking_flow_test.dart` | Pre-workout occasion stacking (2 cases) | yes |
| `flows/settings_persist_flow_test.dart` | Settings persistence | yes |
| `flows/settings_sweep_flow_test.dart` | Every top-level settings screen opens without a crash | yes |

"Runner" is `yes` when the M1 job runs the file, otherwise the reason it is on
`runner_exclusions.json`. The last result of each flow, and every problem a
run found, live in the testing-wave folders:
`.scratch/testing-wave/runs/03/results.md` and `.scratch/testing-wave/findings/`.

Helpers in `helpers/`:

| File | What it gives a flow |
|------|----------------------|
| `flow_launcher.dart` | `skipFlow()` (see above), `launchApp($)` (flavor-aware boot; answers the fresh-install notification prompt with Don't Allow), `ensureAuthenticated()`, `noAuthSkipMessage()`, the shared `authSentinel` (`kyle_tab_bar.item.timeline`), `ensureTimelineOnToday()`, `waitForOnTimeline()`, `revealCentered()`. Prefer it over per-file auth walks. |
| `test_config.dart` | `TestConfig`: flavor-matched login credentials, the Supabase URL and anon key the probes use, timeouts, test data. |
| `test_helpers.dart` | Finders, tap and wait helpers. |
| `supabase_probe.dart` | `SupabaseProbe`: read-only PostgREST reads as the test user, to assert a write landed. |
| `e2e_account.dart` | Throwaway `lee+e2e-*` accounts (`E2eAccount`, dev only via `e2eAccountsAllowed`): `onWelcomeScreen()`, `walkOnboardingToSignup()`, `signUpToPaywall()`, `deleteFromPaywallMenu()`, and `CodeProbe` for email codes. |

## Per-test timeouts: size them to the healthy run, not to fear

**A failing Patrol test burns its entire declared `Timeout`.** Measured on the
M1 run of 2026-07-31: every one of five failures reported a duration exactly
equal to its declared timeout (600s, 600s, 360s, 600s, 600s), even though the
assertion that killed each one had already thrown within the first ~20 seconds.
The remaining ~9½ minutes per failure is dead wall-clock after the body has
finished.

Meanwhile every *healthy* flow in that same run finished in **1–11 seconds**
(a 2026-07-31 measurement; `fuel_timeline` and `paywall_render` have since been retired):

| flow | healthy |
|------|---------|
| `integrations_connect` (per case) | 1 s |
| `auth` | 2 s |
| `fuel_timeline`, `learn` | 3 s |
| `paywall_render` | 7 s |
| `settings_persist`, `formula_create_pin` | 8–9 s |
| `meal_log_build`, `events_crud`, `settings_sweep` | 11 s |

The declared timeouts were 6–20 minutes — 50–100× the real runtime. Five
failures consumed ~48 of that run's 50 minutes.

So the CI-run flows are pinned at **5 minutes**, which is still ~30× the
slowest healthy flow and leaves room for a cold start (`ensureAuthenticated`
polls up to 90 s) plus a slow edge-function call (up to 90 s). Raising a
timeout to "fix" a flake just makes the next real failure more expensive —
bound the individual `waitUntilVisible` instead, which fails fast and says
which finder gave up.

The flows excluded from the M1 job keep longer timeouts, because they
genuinely wait on humans, signups or LLMs: `google_login` (8 min),
`onboarding_signup` (12 min), `ai_coach_chat` (6 min).

## Troubleshooting

| Symptom | Cause |
|---------|-------|
| `Version incompatibility detected!`, or undefined XCTest symbols in `PatrolImpl.o` | patrol_cli does not pair with the `patrol` package. For patrol 4.10.0 activate patrol_cli 4.8.0. |
| `target lib/main_dev.dart is invalid` | `-t` was used as "entrypoint". For patrol_cli `-t` IS `--target`. Drop it. |
| `Device iPhone … is not attached` | Simulator not booted, or the name does not exist locally (`xcrun simctl list devices available`). |
| Every test reports "skipped" | `secrets/integration_test.env` missing or empty. |
| A flow hangs for its full timeout | A default-settle action is burning `pumpAndTrySettle` against the timeline's persistent spinner. Use `SettlePolicy.noSettle` gated by `waitUntilVisible`. |
| Runner job dies at exactly 10m00s | The M1 is out of disk/RAM and dropped its GitHub heartbeat. Free space; keep ≥25 GB. |

## Legacy

The pre-Patrol flow tests (`flows/_legacy/`) and their `run_tests.sh` runner
were deleted on 2026-07-21. They had been dead for some time — their
`../helpers/...` imports pointed at a directory that does not exist, so they
could not compile, and `analysis_options.yaml` excluded them from the analyzer
to hide that. The Patrol CLI does **not** read `analysis_options.yaml`: it globs
every `.dart` file under `integration_test/` into the generated
`test_bundle.dart`, so those seven files broke `patrol test --target
integration_test` for the whole suite (xcodebuild exit 65) while a
single-file `--target` still built fine. Retrieve them from git history if ever
needed.

**Keep this directory compiling.** Anything added under `integration_test/`
enters the bundle whether or not it is a Patrol test, and one bad import takes
down every flow.

## References

- [Patrol docs](https://patrol.leancode.co/)
- [Patrol compatibility table](https://patrol.leancode.co/documentation/compatibility-table)
- [Flutter integration testing](https://docs.flutter.dev/testing/integration-tests)
