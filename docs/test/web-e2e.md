# Web E2E Testing (Flutter Web)

## Why not Playwright / Selenium / Cypress / the MCP browser
Flutter web renders the entire UI into a single `<canvas>` (CanvasKit/Skwasm).
There is no DOM for buttons, text fields, or labels — DOM-based tools see one
opaque canvas and cannot locate or assert on widgets. (This is also why the live
audit walkthrough used screenshots + pixel coordinates rather than selectors.)

## What we use instead: `flutter drive` + `integration_test`
`flutter drive` runs the **real app in a real Chrome**, but the test is written
in Dart against the **widget tree** (`find.byType`, `find.text`, `tester.tap`,
`pumpAndSettle`). It sees widgets, so it works where Playwright can't, and it
exercises the real web bootstrap (Supabase init, routing, real network) — which
is what catches **web-only** regressions like the edge-function CORS bug
(`fix/web-edge-functions-cors`) that unit/widget tests in the Dart VM cannot.

> The mobile `integration_test/` suite uses **Patrol** (native automation, mobile
> only). Patrol does not drive web, so the web e2e lives separately to avoid
> colliding with Patrol's `test_bundle.dart` / `test_directory` wiring.

## Layout
- `test_driver/integration_test.dart` — the `flutter drive` driver entry.
- `web_e2e/app_boot_test.dart` — boot smoke: launches the real app, asserts it
  reaches the welcome screen with no exceptions (no login — robust first rung).
- `scripts/run_web_e2e.sh` — starts chromedriver, runs the drive with dev defines.

## Running
No manual chromedriver setup: `scripts/run_web_e2e.sh` detects your installed
Chrome and auto-provisions a **version-matched** chromedriver from Chrome for
Testing (cached under `.dart_tool/chromedriver/<major>/`, gitignored). This
matters because ChromeDriver enforces a matching major version — `brew install
chromedriver` gives the latest and often mismatches.
```bash
scripts/run_web_e2e.sh                              # dev (.env.web.local)
ENV_FILE=.env.web.prod.local scripts/run_web_e2e.sh # prod defines
CHROMEDRIVER=/path/to/chromedriver scripts/run_web_e2e.sh  # force a binary
```
Status: **green** — boots the real app in real Chrome and asserts the welcome
screen renders. (It already caught a real `AppStartupService` teardown-race.)

## Extending to authenticated flows (recommended next step)
The boot smoke intentionally skips login. To cover real coach/athlete flows:
1. Add `Key`s to the email/password fields + submit button in
   `email_login_screen.dart` (e.g. `Key('login_email')`), so the test can target
   them deterministically (text-field finding on canvas is reliable via Keys).
2. Use a dedicated **dev** test account (dev needs its own signup — `test@test.com`
   is a prod account; see memory `project_signup_email_verification`).
3. Drive: enter email/password → tap Log In → `pumpAndSettle` → assert the
   coach portal (`find.text('Coach Portal')`, athlete list) renders.
4. This would have caught the CORS storm directly: the Today view never settles
   while macros fail, so a `pumpAndSettle` timeout = regression.

## CI (Codemagic)
Wired as the **`web-e2e`** workflow in `codemagic.yaml` (separate, non-gating —
a failure does NOT block `pr-validation`). Triggers on pull_request for
develop / feature/* / fix/* / release/*. chromedriver is auto-provisioned by the
script, so there's no driver setup step.

**One-time setup:** add a `DOTENV_WEB_LOCAL` secret to the Codemagic
`mealvana_dev` variable group — the JSON contents of your `.env.web.local` (at
minimum `APP_ENVIRONMENT`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`). The workflow
writes it to `.env.web.local` before running.

Promote it to a required check once it has proven stable across a few runs, or
move it to a `schedule` trigger if you prefer nightly over per-PR.
