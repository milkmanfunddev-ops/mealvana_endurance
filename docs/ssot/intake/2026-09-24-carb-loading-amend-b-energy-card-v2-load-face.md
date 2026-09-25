> **RESOLVED 2026-09-24 → ruling interview (Xuan); folded as energy-card.md §LOAD-face amendment; sub-question 4 (E2) ruled: breakdown page INTO release-1 scope, built in prototype v16/v17**
type: ruling-request
bundle: carb-loading (release-1, pre-ship)

# Amendment (b) — energy-card contract v2: the fourth face (LOAD)

## The question
`spec/design/components/energy-card.md` (ratified 2026-08-25) fixes `face ∈ {ALL, WORKOUT, MEALS}`,
E1 (chevron toggles expansion), P-1 (expansion persists across face switches), E2 (Full Breakdown
opens the face's sheet). The LOAD face breaks all four clauses as written. A v2 contract must rule:

1. **Fourth face** `LOAD`, chosen by the SURFACE (day ∈ an existing carb-loading plan — data, not a
   setting, per the 2026-09-19 ruling), never by the filter lens; it REPLACES the All-lens face on
   loading days; WORKOUT and MEALS untouched.
2. **E1 suppressed on LOAD** — the face is collapsed-only (ruled 2026-09-19): one row, 26 px loader
   bar two-thirds + pace words one-third.
3. **P-1 becomes remember-not-clear**: `expanded` state survives across a face that cannot expand —
   switching ALL→(loading day)→LOAD→WORKOUT must restore WORKOUT's expansion, not reset it.
4. **E2's destination on LOAD**: today stubs to the old net-balance pager (a known gap, spec Q-CL6);
   release-1 needs a destination decision — options: (i) keep the stub and name it a known
   deviation, (ii) route to the Meals sheet, (iii) hide Full Breakdown on LOAD until the breakdown
   page is designed.

## Why this matters
Every clause is currently conformance-tested (goldens L1, Patrol L2) — an unamended contract makes
the release-1 implementation red by definition.

## Gates
LOAD face implementation; the L1/L2 conformance manifests for energy-card.

## Suggested home
`spec/design/components/energy-card.md` → v2, per source-authority §3.3. The prototype v15 is the
rendering candidate. Ratifier: Xuan. Sub-question 4 = spec Q-CL6 — one ruling covers both.
