> **RESOLVED 2026-08-22 → intraday-display.md §4c (post-ratification addition), vectors `zoneless-if-default` + `zoneless-cost-mockday-run`, bundle re-tag `daily-macros-dashboard@v3.1`.** Display adopts the engine's 70/20/10 default distribution; the DISTRIBUTION is the ratified constant, the IF stays derived. Mock day moves 1,205 -> 1,310 kcal.

type: ruling-request
bundle: daily-macros-dashboard@v3

## Why this matters
Two ratified-adjacent defaults disagree for sessions WITHOUT an intensity distribution, so the
engine and the display price the same zoneless session ~8.6% apart — and resolving it in either
direction CHANGES PUBLISHED TARGETS, which only the spec owner may do.

## The question
When a session has no zone distribution, which IF governs — everywhere?
- The app's engine payload builder (`daily_macro_service.dart _sessionFromActivityRow`) and the
  plan-creation flow both default absent zones to **70/20/10**, i.e. RMS IF ≈ **0.771**, so the
  deployed engine computes zoneless sessions at 0.771.
- The display layer's ruled fallback (2026-08-20 bug-batch dispatch, applied in
  `dashboard_assembler._sessionKcal`) is flat **0.74**.

## What is already ruled (and what isn't)
The dispatch ruled "zones when present, 0.74 documented fallback" for the DISPLAY surfaces
(applied, tested). The SSOT itself (session-demand.md / platform-resolution.md F22 ladder) appears
silent on a zoneless default — the 70/20/10 payload default predates the register and was never
ratified; neither was 0.74 as an ENGINE input. Vectors pin no zoneless case.

## Options
1. **0.74 flat everywhere** — extend the dispatch ruling to the engine payload (client stops
   inventing 70/20/10; sends no zones / a flat-IF marker; engine's resolve ladder gains a ruled
   0.74 rung). Zoneless targets DROP ~8.6% on the session term. One number everywhere.
2. **70/20/10 everywhere** — ratify the long-standing engine default; the display's 0.74 becomes
   the deviant and moves up to 0.771. Published targets unchanged; display numbers rise.
3. Status quo (documented divergence) — rejected by test-plan I4's own words unless re-ruled.

## Recommendation
None strong; (1) is the dispatch's spirit, (2) is number-stability. Either way the chosen default
belongs in `platform-resolution.md`'s IF ladder as a ratified rung with a vector.

## Gates
The residual cross-surface kcal delta on zoneless sessions (bug
`ops/data/bug-reports/2026-08-20-session-kcal-three-surfaces-disagree.md` is otherwise fixed);
a one-line change in `daily_macro_service` + creation flow OR in the assembler, plus a vector.
