> **RESOLVED 2026-09-24 → ruling interview (Xuan): prototype strings adopted verbatim (v17 extraction target); register folded as spec/fueling/carb-loading.md §2a**
type: ruling-request
bundle: carb-loading (release-1, pre-ship)

# Amendment (d) — copy registers for the LOAD face (P-3, intraday-display style)

## The question
The energy-card P-3 pattern requires every rendered string to resolve against a ratified copy
register (`spec/daily-macros/intraday-display.md` §2 is the model). The LOAD face introduces six
strings with no register:

| String | Trigger (per `spec/fueling/carb-loading.md` CL-7/CL-8, PROPOSED) |
|---|---|
| `N g behind pace` | delta > dead-band |
| `N g ahead of pace` | delta < −dead-band |
| `On pace` | |delta| ≤ dead-band |
| `planned` | future-day face ("<target> g / planned") |
| `Loaded` | eaten ≥ day target (label CARB LOAD → LOADED) |
| `of N g` | past-day outcome + LOADED sub-line ("544 of 544 g") |

## What needs ruling
Exact casing/format per string (the prototype v15 rendering is the candidate), N's rounding
(whole grams, CL-6), and register placement. Related copy defects ride the spec's Q-CL4/Q-CL5
(protocol-rate copy contradictions) — same register, separate ruling rows.

## Gates
Implementation of the face copy; the smoke layer's explanation ⇄ engine check (the drawer string
must show the engine's number — the two-layer conformance point).

## Suggested home
New §copy-register block in the carb-loading design surface spec (to be extracted from prototype
v15 via design-ssot-extract post-ratification), cross-referenced from intraday-display.md's
register pattern. Ratifier: Xuan.
