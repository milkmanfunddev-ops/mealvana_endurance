# Design SSOT — Create Activity Plan (surface)

**Status: PROPOSED (extracted 2026-09-03 from `prototypes/create-activity-plan/v1.html`; walked
in-browser — all tabs, PRECISE face, leg mutations, reload persistence).**
**Pins:** `surfaces/create-flow-fueling-controls.md` (RATIFIED, CF-1..CF-8 — window, environment,
weather, pace defaults; NOT restated here) · `components/brick-leg-builder.md` (PROPOSED).
**Scope guard (Xuan, 2026-09-03): the date and time pickers are OUT OF THIS ITERATION** — inert in
the prototype, unratified; the app keeps its current pickers untouched.

## Contracts
| # | Contract |
|---|---|
| CA-1 | **Sport tabs** RUNNING · BIKING · SWIMMING · BRICK swap the form body; single-sport tabs show Workout Details (distance/pace/duration per CF-6) + Intensity; BRICK shows the leg builder and NO distance/pace block (duration comes from legs). |
| CA-2 | **Form state persists** across close/reopen and reload (observed: sport tab + legs + values survive reload; matches the as-built quick-create behavior). See Q-CA2 for the reset rule. |
| CA-3 | **Name auto-derivation**: `<distance> mi <Sport>` single-sport; leg-ordered `…BRICK` for bricks; manual edit sets `ManuallySet` and stops derivation (existing as-built rule, kept). |
| CA-4 | **Intensity, ESTIMATE face**: preset chips (Easy/Long/Tempo/Intervals/Race Pace/Recovery per sport) — each preset IS a named `intensity_distribution`; selecting one drives the §3a nudge mapping (Long Run ⇒ +1 row; Race Pace ⇒ race row — RULED 2026-09-03). |
| CA-5 | **Intensity, PRECISE face**: dual-thumb tri-zone slider — Conversational (Z1–Z2) / Tempo (Z3–Z4) / All-Out (Z5+) with live percentages that MUST sum to 100; writes `intensity_distribution` {zone_low, zone_mid, zone_high} directly; the nudge then derives from the distribution, not a preset. |
| CA-6 | **Propagation**: any change to distance/pace/duration/legs/intensity re-derives (a) duration EST (CF-6), (b) the fueling-window default + caption from §3a — UNLESS the athlete has manually set the window (CF-1's manual-wins rule); (c) brick total (B-3). |
| CA-7 | **Generate Plan** is the single submit; Distance (single-sport) is the one required field (`*`). |

## Number traceability
Window value/caption → food-recommendation.md §3/§3a (RULED). Pace/duration → CF-6. Zone
percentages → the `intensity_distribution` wire input. Leg totals → Σ legs (B-3). No number on
this surface is invented by the design.

## Open questions
| Q | Question | Blocks |
|---|---|---|
| Q-CA1 | CF-1 recompute vs manual-set needs a class-boundary assert (94→124 min both landed in 2.5h, so the walk could not distinguish recompute from stale) — confirm the window re-derives when an edit crosses a §3a class boundary and the athlete has NOT manually set it | conformance only |
| Q-CA2 | When does persisted form state RESET? **LIVE DEFECT 2026-09-03** — keepAlive singletons with no reset path let a stepped window and its latched manual flag ride into the next activity, suppressing every ruled re-derivation. Ruling request: `intake/2026-09-03-form-state-reset-semantics.md` | CA-2 + the ruled §3a defaults reaching the athlete at all |
| Q-CA3 | PRECISE slider steps and per-zone minimums (can a zone hit 0%?) | CA-5 |

## Conformance
Goldens: each tab's face + PRECISE. Widget/Patrol: CA-2 persistence across relaunch; CA-5 sum=100
invariant; CA-6 boundary-crossing recompute (Q-CA1's assert); the leg-builder suite per its file.
Prototype = reference rendering (`prototypes/create-activity-plan/v1.html`); promotion to
`spec/design/renderings/create-activity-plan@v1.html` at rendering ratification.
