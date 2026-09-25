# Design SSOT — Surface: Carb-Loading Dashboard (loading-day timeline · LOAD face · slot page · breakdown)

**Status: RATIFIED (Xuan, 2026-09-25, riding confirm on the Q-D batch read-back; extraction from the prototype v21 walk, Q-D9/Q-D10 RULED — see §4). The v22 strip chore is DONE and verified (QA walk 2026-09-25, bundle sha `f1c232d958a98bfe`).**
**Composition pins:** `components/energy-card.md` §LOAD-face amendment (the face) ·
`components/carb-slot-card.md` (the six groups) · the slot interior page (a COMPOSITION of
shipping surfaces per the 2026-09-24 ruling: Add Food shell + Formula Kit + Log-a-Meal path —
no new bespoke surface; only the slot header and Logged section are new pixels) · the breakdown
overlay (read-only; protocol chips navigate; `Manage plan ›` footer per CE-7).
**Numbers authority:** `spec/fueling/carb-loading.md` — every displayed quantity traces (§3
below); this file adds no arithmetic.

## §1 — Surface contracts (walked)
| # | Contract |
|---|---|
| CD-1 | **LOAD replaces the All-lens energy-card face on loading days**; Workout/Meals faces untouched, one tap away. Regular day: NO carb surface exists in the DOM (walked negative) — breakdown unreachable even with stale state |
| CD-2 | **One write ripples everywhere in the same frame** (walked: Banana ×1→×2): the interior receipt row, the slot page header, the timeline card's eaten figure and peek receipt, the day total, and the face's owed/band/delta/copy all update together — face flipped "31 g behind" → "On pace · 322 of 544 g" in one action. No local repaints |
| CD-3 | **The six slot groups ARE the loading-day meal timeline** (no Recovery group); non-slot timeline entries (the ride node) interleave by clock and count toward `eaten` per CL-11 |
| CD-4 | **Day variants are surface states, not settings**: TODAY = full pace machinery; FUTURE = `<target> g / planned` face, empty track, no tick/pace copy, EMPTY-form cards at that day's targets; PAST = outcome face `<eaten> g / of <target> g`, summaries only. Walked: 680/planned with 170/68/170/102/136/34; 521 of 544 with slots summing 521 exactly |
| CD-5 | **Completion flips the face label** CARB LOAD → LOADED (walked at 10 PM: "LOADED · DAY N OF N / Loaded / 547 of 544 g" — eaten over target renders actual grams, no clamp) |
| CD-6 | **Breakdown day-navigation** (protocol chips) and the CE-7 `Manage plan ›` footer per the ruled flows (walked v20/v21; chips ring follows, back chevron restores origin day) |

## §2 — Copy verification (register v1 ⇄ on-screen, walked)
`N g behind pace` (45/31/26 walked) · `On pace` + grams sub-line `322 of 544 g` · `Loaded` +
`547 of 544 g` · `<target> g / planned` · past-day `of <target> g` — all render verbatim.
**Un-registered strings found → Q-D9** (expanded face: `249 g to go`, `pace <N> g by now`).

## §3 — Number traceability (all walked values reproduce the ratified math)
Face deltas at 7AM/3PM/9PM = 45/31/26 = owed(t) − eaten under CL-5..7 exactly (9 PM is the W7
band-edge case: delta 26 vs band 25.85). Slot targets = CL-4 for 544 and 680. Day totals =
sums of logs (295→322 across the ripple). The surface invents no arithmetic — every figure
traced to `carb-loading.md` fields.

## §4 — Findings (ruling-needed; the prototype is the reference, NOT the truth here)
| Q | Finding |
|---|---|
| **Q-D9 — RULED (Xuan, 2026-09-25): option (b) — expansion ADMITTED; energy-card amendment rewritten, strings registered.** Original finding: | **The LOAD face has an expanded state (E1 chevron) — the then-ratified contract said collapsed-only.** Worse than cosmetic: in v21, `Full Breakdown` lives ONLY in the expanded state, so reaching the ruled breakdown page REQUIRES the forbidden expansion; and the expanded state carries two un-registered strings (`249 g to go`, `pace N g by now`). Options for Xuan: (a) enforce the ruling — collapse-only, Full Breakdown moves onto the collapsed face (as the 2026-09-19 ruling literally states), expanded state and its strings deleted; (b) amend the LOAD-face ruling to admit the expansion and register its strings. The prototype currently implements neither ruled option |
| **Q-D10 — RULED (Xuan, 2026-09-25): STRIP from the prototype (v22 chore); composition exclusion stands.** Original finding: | **Sparkle button + "Today's Fuel" insight box render on loading days — including the clock-free FUTURE day — despite being ruled OUT of release-1.** Known unstripped chrome (open with Xuan since the v18 charter). Do not encode as truth; the ratified composition excludes both. Needs either the strip in a prototype revision or an explicit re-ruling to keep them |

## §5 — Conformance map (staged with the bundle)
- L1 goldens: face states (behind / on-pace / ahead / loaded / future / past), the six-slot
  timeline at the canonical 3 PM mock, slot page, breakdown. **Updating a golden is a
  ratification act — never to green a red.**
- L2/Patrol: CD-2 ripple (one write, five surfaces asserted in one frame); CD-1 negative
  (regular day has no carb DOM); slot-card rows (its file); CE-7/chip navigation; copy strings
  verbatim; the smoke layer's engine ⇄ drawer number check rides qa-smoke.
- Prototype defects/deviations: none found beyond Q-D9/Q-D10 this walk.
