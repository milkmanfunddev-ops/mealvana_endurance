# Design SSOT — Brick leg builder

**Status: PROPOSED (extracted 2026-09-03 from `prototypes/create-activity-plan/v1.html`).**
Domain authority: `spec/domain/brick.md` R1a (inline creation path), R2 (same-sport legs), R3
(eligible sports), R8 (positional transition identity), R9 (max 3 legs). Used only by the
`create-activity-plan` surface.

## States
| State | Condition | Chips | Helper copy |
|---|---|---|---|
| AVAILABLE | legs < 3 | all three sport chips enabled, each with a `+` badge | `TAP A SPORT TO ADD A LEG · <n> OF 3 LEGS` |
| FULL | legs = 3 | all chips disabled (dimmed) | `BRICK IS FULL · 3 LEGS` |

## Gestures & data writes
| # | Gesture | Write | Side-effects (surface-level, see S-rows) |
|---|---|---|---|
| G1 | Tap a sport chip (AVAILABLE) | append leg {sport, default duration} at the END | renumber; name re-derives; total recomputes; FULL check |
| G2 | Tap ✕ on a leg row | remove that leg | rows RENUMBER POSITIONALLY (1..n — R8: transition identity follows position, so removing leg 1 makes the old T2 the new T1); name re-derives; total recomputes; chips re-enable |
| G3 | Drag a leg row by its handle | reorder legs | renumber + name re-derive + **the transition identities change with position (R8)** — the surface must regenerate transition slots, never remap them by sport name |
| G4 | Leg duration dropdown | set that leg's duration | total = Σ legs recomputes; fueling-window class re-derives from the TOTAL (§3a) |
| G5 | Tap a chip while FULL | **nothing** — inert, no toast (negative test) | — |

## Contracts
| # | Contract |
|---|---|
| B-1 | Same-sport legs are legal in any arrangement (R2); eligible sports = swim/bike/run only (R3). |
| B-2 | Leg numbering is strictly positional and continuous (1..n) after every mutation — the number IS the R8 identity anchor. |
| B-3 | TOTAL DURATION = Σ leg durations, always visible, recomputed synchronously with any G1–G4. |
| B-4 | The auto-derived workout name = `<SPORT>/<SPORT>[/<SPORT>] BRICK` in leg order; a manually edited name stops auto-derivation (the as-built `activityTitleManuallySet` rule). |

## Open questions
| Q | Question | Blocks |
|---|---|---|
| Q-BLB1 | Leg duration dropdown's value set (the prototype shows 30/67/27 — free minutes, or a stepped list?) | the dropdown contract only |

## Conformance
Goldens: AVAILABLE (2 legs) + FULL states. Widget: G2 renumber+rename; G3 reorder ⇒ transition
regeneration (the R8 seam test's design twin); G5 negative (FULL chip tap writes nothing); B-3
sum after each mutation.
