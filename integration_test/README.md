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
(currently **patrol 4.6.1**). Per the Patrol compatibility table, that pairs
with **patrol_cli 4.4.0** — newer CLIs (4.5.x) report
"Version incompatibility detected!" and refuse to run.

```bash
dart pub global activate patrol_cli 4.4.0
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
credentialed flows self-skip with a clear message rather than failing.

**iOS caveat:** OAuth flows that go through `ASWebAuthSession` (e.g. Google
login) cannot be automated on iOS and self-skip. Those are exercised on Android.

## CI (self-hosted M1 runner)

`.github/workflows/tests-selfhosted.yml` is the primary gate — it runs on the
Mac mini M1 self-hosted runner on every push and PR:

- job **`unit-web-deno`** — analyze, unit + widget tests, Deno algorithm tests,
  web e2e.
- job **`integration-patrol-ios`** — the Patrol flows, listed explicitly as
  repeated `--target` flags so the app is built **once** for all of them. Runs
  *after* `unit-web-deno`: the box has 8 GB of RAM and cannot do both at once
  without starving the runner agent into a "lost communication" failure.

Three flows are deliberately excluded from that job: `google_login_flow_test`
(interactive OAuth consent), `onboarding_signup_flow_test` (needs a clean
install with no session), and `jade_chat_flow_test` (bills real LLM tokens and
is non-deterministic). Run those by hand against a freshly-erased simulator.

## CI (Codemagic, mac_mini_m2)

Two workflows in `codemagic.yaml` run these on Apple-silicon Mac runners:

- **`integration-tests`** — auto-triggers on `release/*` pull requests. Installs
  patrol_cli 4.4.0, writes `secrets/integration_test.env` from the
  `INTEGRATION_TEST_ENV` secure var, boots a simulator, and runs the whole suite
  via `patrol test --target integration_test`.
- **`integration-test-quick`** — manual only. Runs a single flow selected by the
  `TEST_FLOW` variable (default `events_crud_flow_test.dart`).

> **One-time setup:** upload the contents of your local
> `secrets/integration_test.env` as an `INTEGRATION_TEST_ENV` secure variable in
> the Codemagic **mealvana_dev** variable group. Until then the credentialed
> flows self-skip in CI.

## Flows

| File | Covers |
|------|--------|
| `patrol_smoke_test.dart` | Toolchain smoke — app launches, one widget renders |
| `flows/auth_flow_test.dart` | Auth entry points |
| `flows/onboarding_signup_flow_test.dart` | New-user onboarding → email signup |
| `flows/google_login_flow_test.dart` | Google OAuth (Android; self-skips on iOS) |
| `flows/events_crud_flow_test.dart` | Event create → read → update → delete |
| `flows/activities_crud_flow_test.dart` | Activity CRUD |
| `flows/formula_create_pin_flow_test.dart` | Create + pin a formula |
| `flows/formula_pin_flow_test.dart` | Pin an existing formula |
| ~~`flows/fuel_timeline_flow_test.dart`~~ | RETIRED 2026-08-21 with the legacy Fuel Timeline tab (flag deleted; archived under `_archived/integration_test/`) |
| `flows/meal_card_interaction_flow_test.dart` | Meal/activity card interactions — tap to edit, swipe to delete |
| `flows/meal_log_build_flow_test.dart` | Build-a-meal: search → add → log → swipe-delete |
| `flows/event_checklist_carbload_flow_test.dart` | Event checklist + carb-load |
| `flows/integrations_connect_flow_test.dart` | Integration connect entry points |
| `flows/settings_persist_flow_test.dart` | Settings persistence |
| `flows/settings_sweep_flow_test.dart` | Settings screen sweep |
| `flows/learn_flow_test.dart` | Learn tab |
| `flows/paywall_render_flow_test.dart` | Paywall renders |
| `flows/jade_chat_flow_test.dart` | Jade chat (LLM — excluded from the M1 job) |

Helpers live in `helpers/` (`flow_launcher.dart`, `test_config.dart`,
`test_helpers.dart`, `onboarding_helper.dart`, `database_verification.dart`).
`flow_launcher.dart` owns `launchApp()` / `ensureAuthenticated()` and the shared
`authSentinel` (`bottom_nav.timeline_tab`) — prefer it over per-file auth walks.

## Per-test timeouts: size them to the healthy run, not to fear

**A failing Patrol test burns its entire declared `Timeout`.** Measured on the
M1 run of 2026-07-31: every one of five failures reported a duration exactly
equal to its declared timeout (600s, 600s, 360s, 600s, 600s), even though the
assertion that killed each one had already thrown within the first ~20 seconds.
The remaining ~9½ minutes per failure is dead wall-clock after the body has
finished.

Meanwhile every *healthy* flow in that same run finished in **1–11 seconds**:

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

The three flows excluded from the M1 job keep longer timeouts, because they
genuinely wait on humans or LLMs: `google_login` (8 min), `onboarding_signup`
(12 min), `jade_chat` (6 min).

## Troubleshooting

| Symptom | Cause |
|---------|-------|
| `Version incompatibility detected!` | patrol_cli is not 4.4.0. Re-activate it pinned. |
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
