# Feature test plan — Home Shell (tab bar v2 · date header · calendar sheet)

- **Feature:** the `home-shell@v1` bundle scope — the liquid-glass home shell on the NEW
  dev-visible screen (shipped home untouched until switchover). Excluded per bundle: AI elements,
  ride-fuel-plan editor, utility-slot occupant, tint intensity scaling, light-surface glass,
  the events-calendar feature.
- **Status:** PINNED (2026-09-06 — implemented against the `home-shell@v1` tag; all manifest
  rows landed as pinned tests in one pass)
- **Source documents:** `spec/design/components/{tab-bar,date-header,calendar-sheet}.md` (v1,
  RATIFIED 2026-09-06) · `spec/design/tokens.md` §Materials ·
  `spec/design/surfaces/macro-dashboard.md` §home-shell recomposition · manifests:
  `conformance/design/home-shell.{gestures,goldens}.yaml`
- **App test taxonomy:** `$APP_ROOT/docs/test/README.md`

## Manifest rows (the pinned set)

| Row | Pinned by (app repo) | CI |
|---|---|---|
| tb1–tb7 (gestures manifest) | `test/features/home_shell/home_shell_gestures_test.dart` — test names are the manifest ids | ✅ automatic (`flutter test`, tests-selfhosted) |
| dh1–dh6 | same suite | ✅ automatic |
| cs2–cs9 | same suite | ✅ automatic |
| 11 goldens (goldens manifest) | `test/features/home_shell/home_shell_goldens_test.dart` — test names are the golden ids; PNGs blessed from the pinned mock month | ✅ automatic |
| tint rollup + dot day-key seams | `test/features/home_shell/home_shell_calendar_seam_test.dart` — producer-shaped rows through the real Drift repository; displayTime-vs-scheduled divergence pinned | ✅ automatic |

Filled pins (formerly `TBD-at-implementation`, now in the gestures manifest): tab-bar collapse 88
px / expand 64 px / hysteresis 24 px; switch 340 ms `cubic-bezier(0.32,0.72,0,1)`; lens 6.0 px
displacement, 8.0 px half-displacement falloff band; header compact 56 px; sheet commit 90 px.

## Open cells (tracked, not silent)

| Contract | Gap |
|---|---|
| tb1/tb2 on-device scroll feel | widget-test only; no Patrol flow yet (`EXPECTED_PATROL_TESTS` unchanged at 24). `/sim-explore` charter `charter-home-shell.md` covers the first dev build |
| tb6 refraction on Impeller hardware | the widget test pins filter activation and goldens pin the software-rendered look; real-device GPU appearance is charter territory |
| dh2 summon parity after process death | freeplay only |
| Calendar month paging at year boundaries | pinned in the assembler seam only for in-month keys; December→January chevron paging is exercised, not asserted per-cell |

## Exclusions (per bundle `excludes` — not tested because not built)

AI elements · ride-fuel-plan editor · utility-slot occupant · tint intensity scaling ·
light-surface glass · `features/calendar/` screens (out of scope; untouched).
