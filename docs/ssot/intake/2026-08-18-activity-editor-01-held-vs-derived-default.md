type: ruling-request
bundle:

## Why this matters
The **Create New Activity Plan** editor has no SSOT at all: nothing ratifies what its `duration` is or how it is derived, yet every fueling engine (`spec/fueling/*`, `spec/recommendation/generate-plan.md`, `spec/daily-macros/session-demand.md`) consumes that duration. Today the editor lets a 10 mi / 45 min ride become 35 mi / 45 min (≈46 mph, invisibly) and that pair reaches plan generation as "35.0 mi · 45m · 4:00 /mi" fuelled with Sports Drink Only ✅. Redesign is blocked until R1–R7 (this file and its six siblings, `2026-08-18-activity-editor-0[1-7]-*.md`) are ruled — a designer would otherwise be deciding engine-input policy.

## Observed behavior today (verified 2026-08-18 in app code — shared context for all seven items)
- **Fields shown:** Distance, a **By Duration | By Speed** segmented toggle (By Duration is the default; label is sport-aware — "By Speed" for cycling, "By Pace" for running/swimming, `lib/shared/widgets/kyle_design/inputs/duration_pace_toggle.dart:8-40`), and **one** secondary field that swaps with the toggle: Estimated Duration (hr/min) *or* Average Speed (mph) / Average Pace (min:sec/mi, min:sec/100) — `lib/features/nutrition_plan/presentation/widgets/new_activity/shared/workout_details_widget.dart:14-16`. Only two of the three quantities are ever on screen; the mode is hidden state.
- **Coupling** (`cycling_input_controller.dart:317-360, 512-535`; `running_input_controller.dart:321-375` is identical with pace):

  | mode | edit distance | edit the visible secondary field | switch mode |
  |---|---|---|---|
  | By Duration (default) | **holds duration → recomputes speed/pace (not shown)** | typing duration → recomputes speed/pace (not shown) | → By Duration re-estimates duration from current speed |
  | By Speed / By Pace | holds speed/pace → recomputes duration | typing speed/pace → recomputes duration | → By Speed re-estimates speed from current duration |

- **Baseline that already exists:** the profile stores `defaultCyclingSpeedMph` and `defaultRunningPaceMinPerMile` (Settings); the controllers prefill a *new* activity's speed/pace from it and fall back to **15 mph** (cycling, `cycling_input_controller.dart:~266`), **9.0 min/mi** (running, `running_input_controller.dart:182`), **120 s/100 m** (swimming, `swimming_input_controller.dart:66`; Zone-2 swim pace applied when known). An *existing* activity uses its own stored speed/pace.
- **Persistence:** `Activity` carries `distanceMiles`, `durationMinutes`, `paceTargetMinutesPerMile` as three independent nullable columns (`lib/features/activities/domain/activity.dart:124-126`) — no invariant links them. Garmin import has already been seen updating avg speed but not distance/duration (ops bug: [Garmin push updates start time + avg speed but not distance/duration](https://app.notion.com/p/38ee3fdb754c816989e7f95f74016a23)).
- **No plausibility check anywhere:** 35 mi @ 45 min saves; the plan screen renders 4:00 /mi.
- **Sources:** meeting 2026-08-10 (Xuan ↔ Lee), transcript S9 cues 335–380; ops-side brief with frames `../ops/design/briefs/workout-editor-coupling-2026-08-18/README.md`; Notion: [🎨 Design Discussion (Open Question)](https://app.notion.com/p/3b9e3fdb754c81b6b34cec6037e6a0cc) · [Sprint task](https://app.notion.com/p/3b9e3fdb754c818da35be2a3b0f68dec) · related-but-separate Critical bug [Stale 45m duration survives a distance/speed edit](https://app.notion.com/p/3b9e3fdb754c81d39e48ea4f356b70c3) (state-management, Lee).

## The question (R1)
When an athlete changes **distance**, which of duration / speed-pace is **held** and which is **derived**?

## Options
1. **Hold speed/pace, derive duration (recommended — Xuan's position).** "If you change your mileage from 10 to 35, you're not going to change your speed from 13 to 46." Physically the norm for a length change; and this is exactly what the existing By-Speed branch already does — no new algorithm.
2. **Hold duration, derive speed (as built).** Defensible only for time-prescribed sessions ("ride 45 min"), where the athlete would normally edit *duration*, not distance.
3. **Depends on sport / session type** (e.g. distance-first for runners, time-first for prescribed sessions). Needs the interview evidence the Design Discussion's candidate questions ask for; not available yet.

## What is already ruled (and what isn't)
- Nothing on the editor's inputs. `generate-plan.md` and `session-demand.md` take `duration_hr` as given.
- Lee's objection ("scale based off of what?") is answered by the observed baseline chain — see item 02.

## Suggested spec home
New family: `spec/activity/editor-inputs.md` (engine-input policy, alongside `fueling/` and `recommendation/`; **not** `spec/design/` — presentation lands there later as `spec/design/surfaces/activity-editor.md` after mockups). Scope ruling folded in: Running / Cycling / Swimming / Brick-per-leg obey the same rule with unit swaps (mph · min:sec/mi · min:sec/100 · per leg).

## Gates
The editor redesign (Claude Design iteration, ops brief above); the coupling table Lee needs; items 02–07.
