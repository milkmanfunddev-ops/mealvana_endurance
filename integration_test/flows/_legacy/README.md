# Archived integration tests

These files were the integration test suite written against the **old**
onboarding UI (Welcome → Profile → Sport → Food sliders → Auth). The app has
since moved to the new onboarding (Connect → Profile → Sport → Diet →
Allergies → Foods → Create Account) — see `docs/test/SCREEN_MAPPING.md`.

The active screen audit lives in `docs/test/screen_audit/`. New integration
tests, built on top of that audit and the `ValueKey` instrumentation PR,
will land under `integration_test/flows/` (not `_legacy/`).

Import paths inside these files reference `flows/...` and will not resolve
from this directory. They are kept here for reference only — read them, port
patterns where useful, but do not run them.

## Contents
- `all_flows_test.dart`, `email_login_flow_test.dart`, `event_management_flow_test.dart`,
  `food_management_flow_test.dart`, `nutrition_plan_flow_test.dart`,
  `onboarding_auth_flow_test.dart`, `settings_flow_test.dart` — top-level flows.
- `shared/` — flow primitives shared across the top-level flows.
- `app_test.dart`, `test_runner.dart`, `e2e_production_readiness_test.dart` — old entry points.
