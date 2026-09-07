# RULING — home-shell@v1 switchover ships WITH the bundle (RESOLVED)

**Ruled: Xuan, 2026-09-06 (live session, post-implementation walkthrough).**
**Status: RESOLVED — applied app-side the same day (feature/home-shell-v1).**

## The ruling

The bundle's staged fence — *"implemented app-side on a NEW screen (dev-visible); the shipped
fuel-timeline home is untouched until switchover"* (`bundles/home-shell.yaml`, EXPECTED-RED
note; handback sequencing) — is LIFTED. Switchover is part of `home-shell@v1`, not a later
step: `/main` itself composes the shell, and the superseded chrome is deleted, not staged.

## Why

The staged new-screen architecture was unlivable in practice: every completed flow in the app
returns home via `context.go('/main')` (deliberately — the 2026-08-20 duplicate-activity
back-stack bug is fixed by resetting the router stack), which wipes any imperatively pushed
screen. The dev-visible shell was therefore ejected after every workout creation, meal log, or
save. Xuan: "we do not need to use them anywhere — replace them in the old widget system,
wherever their position is, with the new design."

## What moved app-side under this ruling

- `TabsScreen` (`/main`) composes `HomeShellChrome` (date header over the home tab, glass
  KyleTabBar across all tabs, calendar-sheet summon); the NavigationRail mirrors the Q4 glyph
  set (house — no calendar glyphs on the shell).
- DELETED: `floating_action_buttons_bar.dart` (old nav bar), `fuel_timeline_day_header.dart`
  (ViewTabs + WeekStrip block), `fuel_timeline_screen.dart` (retired, zero production
  consumers), the standalone dev-only `home_shell_screen.dart` + its Settings/Debug entries,
  and the retired screen's test files.
- Patrol/integration selectors migrated: `bottom_nav.{timeline,events,learn}_tab` →
  `kyle_tab_bar.item.{timeline,events,learn}`; `fuel_timeline.settings` →
  `kyle_date_header.settings`.
- The surface spec's staged wording ("effective with home-shell@v1 on the new screen") now
  reads as effective on `/main`; the composition table's ViewTabs/WeekStrip row is realized.
  Note the spec's "both stay in the widget library" line for ViewTabs/WeekStrip is corrected
  by this ruling's context: they were never library widgets (private methods of the deleted
  header) and no other surface composed them — nothing to keep.

## Residue (tracked, not silent)

- Patrol cannot be validated until a runner is available (M1 offline at ruling time); the
  selector migration is mechanical but unexecuted-on-device.
- `integration_test/flows/energy_breakdown_flow_test.dart` still targets legacy
  `fuel_timeline.{add_food,breakdown_button,dash_expand_toggle,tracking_toggle}` keys that
  exist only in the now-orphaned fuel_timeline presentation widgets — pre-existing debt
  (those keys never moved to the macro dashboard), surfaced by this ruling, not caused by it.
- The rest of `lib/features/fuel_timeline/presentation/` (EnergyBreakdownSheet,
  EnergyDashboardCard, FuelFilterRow + their tests) is now fully orphaned dead code — a
  follow-up deletion sweep, deliberately not cascaded into the switchover commit.
