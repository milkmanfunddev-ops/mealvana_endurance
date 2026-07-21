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
| `flows/fuel_timeline_flow_test.dart` | Fuel timeline |
| `flows/meal_card_interaction_flow_test.dart` | Meal/activity card interactions |
| `flows/integrations_connect_flow_test.dart` | Integration connect entry points |
| `flows/settings_persist_flow_test.dart` | Settings persistence |

Helpers live in `helpers/` (`test_config.dart`, `test_helpers.dart`,
`onboarding_helper.dart`, `database_verification.dart`).

## Legacy

`run_tests.sh` predates the Patrol migration (it shells out to `flutter test`
against renamed files) and is kept only for reference — prefer `patrol test`
above.

## References

- [Patrol docs](https://patrol.leancode.co/)
- [Patrol compatibility table](https://patrol.leancode.co/documentation/compatibility-table)
- [Flutter integration testing](https://docs.flutter.dev/testing/integration-tests)
