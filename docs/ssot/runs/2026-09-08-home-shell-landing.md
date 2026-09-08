# home-shell@v1 — landing close-out (SHIPPED)

**2026-09-08.** `release/1.26.0` (app `8859e86f`) is on TestFlight: the liquid-glass home
shell, cut deliberately from the pre-Vana develop base (Xuan's ruling — the release carries
zero meal-planning code; Vana ships separately ~2 weeks out from develop). This lands
`qa/home-shell` → `main` (fast-forward, 23 commits) and closes the bundle.

## done_when accounting (bundles/home-shell.yaml, verbatim items)

| Item | Status |
|---|---|
| 21 gesture tests green | ✅ green locally (app `test/features/home_shell/`, 38 incl. regressions) — **CI attestation OPEN**: Lee's M1 runner has been offline throughout; verify `tests-selfhosted` green when it returns |
| 11 goldens green | ✅ green locally, blessed with the 0.5% cross-host comparator; same CI caveat |
| no TBD pin in home-shell.gestures.yaml | ✅ — remaining "TBD" strings are the header's harness-co-evolution commentary only |
| mirror re-synced | ✅ app `docs/ssot` @ this landing (SSOT_SOURCE.txt pin updated to main + tag) |
| /design-sync run | ✅ 2026-09-07 — twin ported (GlassSurface/DateHeader/CalendarSheet new, TabBar → glass contract, ViewTabs/WeekStrip retired), project c4ad6c0d @ 51 components |

Beyond the manifest: full local Patrol 23/23 (first execution since the runner went dark —
re-anchored 4 flows to home-shell surfaces en route), Tier-1 device sweep + Android-emulator
pass (review board artifact 0553d0a2), liquid-bubble intake RESOLVED (Xuan 2026-09-07) with
tab-bar.md amended.

## Handoff corrections (relayed here; the frozen handoff is not edited)

- `displayTime` resolver: lives at `macro_dashboard/domain/workout_state_resolver.dart`
  (extracted per the handoff's "extract if unreachable" rung — the third rung applied, not the
  first two). `dashboard_models.dart:49` remains the `actual ?? planned` fallback definition.
- `ActivityStatus` has **7** values (the handoff's enumeration was short — includes
  `archivedForBrick` etc.); the resolver keys off status strings + timestamps, not the enum
  arity, so no contract impact.
- Handoff watchlist item on `kyle_tab_pill.dart` was stale at implementation time; it has since
  become real — the Vana merge on develop re-uses it (`food_screen` segments). It remains
  outside the ratified library surface (no component spec).
- Judgement call (proceed-ruling cleared, recorded not silent): `jade_baseline` meal logs count
  as athlete-logged for the calendar tint (the tint channel keys off `meal_logs` rows without a
  source filter).

## Open threads leaving the bundle

1. **CI attestation** — the two ✅-local items above go fully green-in-CI when the M1 runner
   returns; nothing else blocks on it.
2. **sim-explore charter** (`.claude/skills/sim-explore/references/charter-home-shell.md`) —
   never run; the device-look of the Impeller lens is charter territory by the intake's own
   terms. Run it on a dev build during the Vana window.
3. **iPad rail branch** — renders the legacy NavigationRail; needs its own design pass/intake
   (sweep board, round 1 finding).
4. **App-side, not spec**: meal_logs never download to a fresh device (sync-all-data omits
   them; no client pull path) — product decision pending, matters more once Vana ships.
5. **Vana design drift**: develop's merge added `kyle_design` widgets (KyleTabPill,
   MacroPillRow, SelectableChipGrid) never mirrored to the design twin — next /design-sync's
   work, before or with the Vana release.
