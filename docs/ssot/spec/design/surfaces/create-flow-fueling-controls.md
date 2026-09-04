# Design SSOT — Create-flow fueling controls (window · fasted · weather)

**Status: RATIFIED (Xuan, 2026-09-03).**
Evidence: `runs/2026-09-03-design-recording/07-window-fasted.png`. Math authority:
`spec/fueling/food-recommendation.md` §3/§3a (RATIFIED).

| # | Contract |
|---|---|
| CF-1 | **PRE-RUN FUELING WINDOW stepper**: −/+ walk the **15-min grid** (00/15/30/45 anchors — AMENDED, RULED Xuan 2026-09-03: a clamp-seeded off-grid value snaps onto the grid on its first step, never propagating its offset; the off-grid ceiling stays reachable from below — it is the real one); label `N HOUR[S] M MIN`. Its DEFAULT is §3a's table (incl. the early-start and race rules) — not the retired formula. Its MAXIMUM is the ruled clamp: `min(table cap, time-until-start)`, floor 15 min; values above the clamp are unreachable, not disabled-but-visible. A manual change persists (`preRunMinutesManuallySet`) and wins within the clamp. |
| CF-2 | When the clamp binds (short-notice plan), the stepper opens AT the clamp and stepping up is inert — the athlete sees the real ceiling, never a window implying a feeding in the past. AMENDED (RULED Xuan, 2026-09-03): the clamp-bound state must be **legible** — the caption "Capped: session in ‹remaining›" ships now (copy provisional pending the D-02 artboard), and the Q-CF1 class caption ("3 h — long session") renders whenever the value is the §3a default; a bare pinned stepper reading as stuck at an arbitrary value is the defect this closes. |
| CF-3 | **Fasted Workout toggle: REMOVED** (§7 fasted retired; feeding-card/fuel-stat A1 amendments). Until the bundle ships, the toggle renders as today — this row flips to a tombstone at implementation. |
| CF-4 | Weather steppers (temperature °F, humidity %) auto-fill from location/forecast; when location is denied they degrade to manual steppers with the line "Location permission blocked" + an "Open app settings" link — never a blocking prompt loop. |
| CF-5 | Copy register — AMENDED (RULED Xuan, 2026-09-03): the window header is **sport-dynamic** — `PRE-RUN` / `PRE-RIDE` / `PRE-SWIM` per single sport, `PRE-ACTIVITY` for brick — + "TEMPERATURE" / "HUMIDITY"; forecast affordance **"View Forecast"** (supersedes "Get Forecast"). |
| CF-6 | **Pace defaults + linkage (RULED Xuan, 2026-09-03; closes the F-27 4:30/mi class):** each sport keeps a saved "usual pace" (from history or manual edit), surfaced as the `your usual · <pace>` chip; fallback when none exists: run **9:00 /mi** (bike/swim equivalents `[design]` at implementation). Pace ⇄ duration are bidirectionally linked; the derived side wears the `EST.` badge. |
| CF-7 | **AUTO badge (RULED Xuan, 2026-09-03):** weather values carry `AUTO` while forecast-filled; a manual step removes the badge (value is now the athlete's); "View Forecast" refresh restores it. |
| CF-8 | **ENVIRONMENT · OUTDOOR / INDOOR (RULED Xuan, 2026-09-03):** segmented toggle feeding the engine's existing `is_indoor` input (1.30× sweat multiplier). Selecting INDOOR hides the TEMPERATURE/HUMIDITY block entirely (indoor sessions take no weather inputs); switching back restores it with prior values. |

## Follow-up frames (acknowledged, RULED D-02 — not blocking extraction)
The clamp-bound stepper state (CF-2: opens AT the ceiling, inert +, "Capped: session in 45 min")
and the location-blocked weather state (CF-4) still need artboards in the next design pass — the
clamp frame entangled with the not-yet-ratified date/time pickers.

## Open questions
| Q | Question | Blocks |
|---|---|---|
| Q-CF1 | RULED by the prototype + T-02 (Xuan, 2026-09-03): YES — the caption ships ("2.5 h — mid-distance", "3 h — long session") | — |

## Conformance
Widget tests: CF-1 default = §3a oracle for a given session class/start; CF-2 clamp inertness at
the bound; CF-3 toggle absence post-bundle. Goldens hold layout/hues.
