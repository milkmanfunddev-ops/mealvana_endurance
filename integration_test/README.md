# Integration Tests (Patrol)

End-to-end tests that drive the real app on a real iOS simulator using
[Patrol](https://patrol.leancode.co/). Patrol wraps Flutter's `integration_test`
with a native XCUITest host, which is what lets these tests survive permission
dialogs, keyboards, and native sheets.

> **`flutter test` cannot run these.** Patrol tests need `patrol test`, which
> builds the XCUITest host and boots the simulator itself. Anything in this
> directory that a `flutter test` command would accept is legacy.

## Prerequisites

1. **patrol_cli, pinned.** The unpinned latest (4.6.1) is *incompatible* with the
   `patrol` package this repo resolves (4.6.1) and refuses to run. Use 4.4.0 —
   see the [compatibility table](https://patrol.leancode.co/documentation/compatibility-table):

   ```bash
   dart pub global activate patrol_cli 4.4.0
   export PATH="$HOME/.pub-cache/bin:$PATH"
   ```

2. **A booted iOS 26.2 simulator.** Every device profile on the CI runner is
   iOS 26.2; `iPhone 17 Pro` is the canonical target.

   ```bash
   xcrun simctl boot "iPhone 17 Pro"
   xcrun simctl bootstatus "iPhone 17 Pro"
   ```

3. **`.env.dev.local`** with `SUPABASE_URL` / `SUPABASE_ANON_KEY` for the dev
   project. It is bundled as a Flutter asset, so an empty file means the app
   boots with no backend.

4. **`secrets/integration_test.env`** (gitignored) with the dev test account.
   Without it every flow calls `markTestSkipped` and passes without testing
   anything:

   ```
   INTEGRATION_TEST_EMAIL=test@test.com
   INTEGRATION_TEST_PASSWORD=test
   ```

## Running

```bash
export PATH="$HOME/.pub-cache/bin:$PATH"

# One flow
patrol test \
  --target integration_test/flows/meal_log_flow_test.dart \
  --flavor dev \
  --dart-define-from-file=secrets/integration_test.env \
  -d "iPhone 17 Pro"

# Every flow — ONE app build, all targets. Repeat --target; do not loop
# `patrol test`, which rebuilds the Xcode host per file.
patrol test \
  --target integration_test/patrol_smoke_test.dart \
  --target integration_test/flows/auth_flow_test.dart \
  --target integration_test/flows/fuel_timeline_flow_test.dart \
  --target integration_test/flows/meal_log_flow_test.dart \
  --target integration_test/flows/activities_crud_flow_test.dart \
  --target integration_test/flows/events_crud_flow_test.dart \
  --target integration_test/flows/formula_pin_flow_test.dart \
  --target integration_test/flows/formula_create_pin_flow_test.dart \
  --target integration_test/flows/settings_persist_flow_test.dart \
  --target integration_test/flows/integrations_connect_flow_test.dart \
  --flavor dev \
  --dart-define-from-file=secrets/integration_test.env \
  -d "iPhone 17 Pro"
```

**`-t` is `--target`, not "entrypoint".** Passing `-t lib/main_dev.dart` (the
`flutter test` idiom) makes patrol_cli reject the run with
`target lib/main_dev.dart is invalid`.

## Coverage

| Flow | What it exercises | File |
|------|-------------------|------|
| **Toolchain smoke** | App launches, first frame renders | `patrol_smoke_test.dart` |
| **Auth** | Email login lands on the dashboard | `flows/auth_flow_test.dart` |
| **Fuel Timeline** | Filter pills, tracking + time-rail toggles | `flows/fuel_timeline_flow_test.dart` |
| **Meal logging** | `+ Add Food` → Manual tab → save → read → remove | `flows/meal_log_flow_test.dart` |
| **Activities CRUD** | `+ Add Activity` → macro engine → plan → delete | `flows/activities_crud_flow_test.dart` |
| **Events CRUD** | Create / read / delete an event | `flows/events_crud_flow_test.dart` |
| **Formula pin** | Pin an existing formula | `flows/formula_pin_flow_test.dart` |
| **Formula create + pin** | Build a formula, then pin it | `flows/formula_create_pin_flow_test.dart` |
| **Settings persistence** | Settings survive a round-trip | `flows/settings_persist_flow_test.dart` |
| **Integrations** | Connect-training OAuth entry points | `flows/integrations_connect_flow_test.dart` |

### Not in the batch

* `flows/google_login_flow_test.dart` — drives the native Google OAuth sheet;
  needs a real Google account and interactive consent.
* `flows/onboarding_signup_flow_test.dart` — needs a clean install with no
  session, which it cannot have once another flow has logged in. Run it against
  a freshly-erased simulator (`xcrun simctl erase "iPhone 17 Pro"`).

### No AI surfaces

Nothing here touches an LLM. The meal-log flow drives the log sheet's **Manual**
tab, not **Describe** (the AI path). The activities flow uses the deterministic
`generate-macros` edge function, not AI plan generation.

## The dashboard changed — key names moved

Activities + Nutrition merged into a single **Fuel Timeline** tab. The old
`calendar.create_activity_fab` no longer exists anywhere in `lib/`. Current keys:

| Purpose | Key |
|---------|-----|
| "am I authenticated / on the dashboard" sentinel | `fuel_timeline.settings` |
| Dashboard tab | `bottom_nav.timeline_tab` |
| Filter pills | `fuel_timeline.filter_{all,workout,meals}` |
| Add a meal | `fuel_timeline.add_food` |
| Add an activity | `fuel_timeline.add_activity` |
| Log sheet root | `log_sheet.root` |
| Log sheet tabs | `log_sheet.tab_{recent,favorites,search,describe,manual}` |
| Manual entry fields | `manual_log.{name,calories,carbs,protein,fat,sodium,notes}_field` |
| Manual entry save | `manual_log.save_button` |
| Meal-slot chips | `slot_chip.{breakfast,lunch,dinner,snack}` |
| Expanded meal actions | `timeline_node.{swap,remove}_button` |

`+ Add Food` and `+ Add Activity` only render under certain filters
(`showsAddFood` / `showsAddActivity`), so tap `fuel_timeline.filter_all` first.

## Conventions

* **Drive by `ValueKey`, never by visible text.** User-facing strings come from
  ContentService and change without notice.
* **Never `pumpAndSettle` at startup.** A persistent `CircularProgressIndicator`
  makes it hang forever. Poll with `waitUntilVisible` or an explicit loop —
  see `_ensureAuthenticated` in any flow.
* **Unfocus before typing into the next field.** The keyboard overlays lower
  fields and makes them un-hit-testable.
* **Stamp created records** with `DateTime.now().millisecondsSinceEpoch` and
  delete them at the end, so repeat CI runs neither collide nor accumulate rows
  in the dev project.

## CI

`.github/workflows/tests-selfhosted.yml` runs everything on the M1 self-hosted
runner on every push and PR:

* job `unit-web-deno` — analyze, unit + widget tests, Deno algorithm tests, web e2e
* job `integration-patrol-ios` — every flow above (runs *after* `unit-web-deno`;
  the box has 8 GB of RAM and cannot do both at once without starving the runner
  agent into a "lost communication" failure)

Codemagic's `integration-tests` / `integration-test-quick` workflows are manual
fallbacks only.

## Troubleshooting

| Symptom | Cause |
|---------|-------|
| `Version incompatibility detected!` | patrol_cli is not 4.4.0. Re-activate it pinned. |
| `target lib/main_dev.dart is invalid` | `-t` was used as "entrypoint". Drop it. |
| `Device iPhone … is not attached` | Simulator not booted, or the name does not exist locally (`xcrun simctl list devices available`). |
| Every test reports "skipped" | `secrets/integration_test.env` missing or empty. |
| Test hangs at launch | Something added a `pumpAndSettle` before auth. |
| Runner job dies at exactly 10m00s | The M1 is out of disk/RAM and dropped its GitHub heartbeat. Free space; keep ≥25 GB. |

## `flows/_legacy/`

Pre-Patrol tests written against `flutter test` and the pre-merge Calendar
dashboard. They do not run and are kept for reference only.

## References

- [Patrol docs](https://patrol.leancode.co/)
- [Patrol compatibility table](https://patrol.leancode.co/documentation/compatibility-table)
