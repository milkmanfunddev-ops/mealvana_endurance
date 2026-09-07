> **RESOLVED 2026-09-03 → twin-parity governance = food-recommendation.md §8 (confirmed explicitly by Xuan in-session: "very reasonable, I would like to ratify it")**

type: ruling-request
bundle: daily-macros-dashboard@v3

## Why this matters
A shipped surface sums four numbers from the edge function and three from the local Dart twin
into one total, and they disagree by ~104 kcal in front of the athlete. Neither side is
"wrong" — each computes correctly. What is missing is a rule about **where a computation lives
and whose answer wins**, and no existing SSOT family states one: the math family says what the
formula is, the proposed data family (Phase 5) says what the inputs look like, and nothing
governs the twin relationship itself.

## The question
Should `engineering` become a ratified SSOT family governing twinned computations, with this
rule (Xuan, 2026-08-22): *for functions that need a twin, the server side must mirror the client
side's payload and preempt the client's results*?

## Proposed clauses
0. **A twin exists only by ratification** (added by Xuan, 2026-08-22 — *"the fact there is a twin
   side is also an engineering SSOT"*). Twinning costs two implementations and a permanent parity
   burden, so a computation is twinned only where a stated requirement demands it (offline
   capability, or feedback faster than a round-trip), with that justification recorded in the twin
   registry. A twin found in code but not in the registry is a DEVIATION, not a fait accompli —
   which is what the four independent duration ladders were before 2026-08-22.
1. **Shape symmetry** — a twinned endpoint's response is never lossier than its request. N
   sessions in, N results out, at the granularity the client would otherwise compute, keyed to
   their inputs.
2. **Server preempts while fresh** — the server result displaces the local one, EXCEPT where the
   cached result has been invalidated (Q-016 `invalidateFromDate`), in which case the twin
   carries the surface until the recalculation lands. Without this refinement "preempt" can mean
   "show a stale number" the athlete has already edited away.
3. **The twin is the fallback and stays parity-pinned** — it survives to price offline and
   just-added sessions, is labelled an estimate, is superseded the moment a server result
   arrives, and remains pinned to the server implementation by parity vectors. Demote, not delete.
4. **Reconcilability** — any locally-computed figure displayed beside server-computed figures
   must be asserted equal to the server's own total for the same quantity.

## The gap that motivated it (verified in code)
- `pipeline.ts:587` discards per-session `session_kcal` / `duration_hr` / `intensity_factor` at
  the response boundary, returning only source TAGS plus a day total. The client cannot show the
  engine's per-workout number because it is never sent one. **Violates clause 1.**
- `dashboard_assembler.dart:362–370` sums local cards for the workout total; the engine's cached
  `targets.sessionKcal` is used only for weekly periodization (`:464`). **Violates clause 2.**
- `lib/features/macro_dashboard/` has no connectivity check whatsoever — the twin is the sole
  source online and offline. **Violates clause 3.**

Measured on a real prod account 2026-08-22 (Aug 29): displayed projected burn 2,933 vs fuel
target 3,037; engine's own session figure ~1,394 vs the displayed 1,290.

## Second question to rule: where does this family LIVE?
Asked 2026-08-22: a `qa/` spec family, or an `app/` principle document alongside
`docs/technical/foa-architecture.md` and `write-consistency-policy.md`?

**Recommendation: authored and ratified in `qa/spec/engineering/`, mirrored verbatim into
`app/docs/ssot/` under the existing `require_mirror` byte-check** — the same channel the
nutrition specs already use. Authorship must sit in qa because ratification, the intake loop,
`DEVIATIONS.md` and versioned bundles exist only here; a rule about how app code must behave,
authored by the people writing that code, is the conflict of interest the two-repo split removes.
Readability in app comes free from the mirror, plus a one-line pointer in `app/CLAUDE.md`.

Suggested test for future rules: does it change what an athlete sees, or whether the product
tells the truth? → `qa/spec/`. Purely internal craft with no athlete-visible consequence
(naming, folder layout, FOA layering)? → `app/docs/technical/`.

**Rule alongside this:** `app/docs/technical/write-consistency-policy.md` is the same genre and
currently lives app-side. Should it migrate, or be referenced from the new family? Leaving it
unruled leaves two homes for one kind of rule.

## Options
1. **Ratify the family with all five clauses (0–4)** (recommended). Costs an edge-function change
   (additive response field) and a deploy.
2. **Ratify clauses 1–2 only** — fix this endpoint, skip the general registry. Cheaper; the next
   twinned endpoint reintroduces the problem.
3. **Decline; treat as a one-off bug.** Closes the 104 kcal, leaves the architecture that
   produced it and the twin-vs-server precedence question unstated.

## Note on scope
Ratifying this largely dissolves `intake/2026-08-20-zoneless-if-default-engine-vs-display.md`
for the online case: if the dashboard renders the engine's figure there is no second opinion to
diverge. That ruling would still govern the fallback rung, so the two are complementary — this
one does not make it unnecessary, it makes it much less often athlete-visible.

## Registered for post-ship verification
`DEVIATIONS.md` **D-005**, with three acceptance conditions to re-observe in the app (not to read
off a diff) once this ships.

## RULING (Xuan, 2026-09-03, RULING-DESK block; content confirmed explicitly in-session)
Twin-parity governance adopted as food-recommendation.md §8: the Dart client solvers are a MIRROR,
not a fork — every selection rule binds both engines; a fix landing in one twin is a defect until
ported; ruled constants ship with differential vectors.
