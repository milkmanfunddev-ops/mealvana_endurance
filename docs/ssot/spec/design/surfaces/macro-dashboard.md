# Design SSOT — Surface: Macro Dashboard

**Status: RATIFIED v1 (Xuan, 2026-08-14).**
**Surface contract** — owns composition and cross-component behaviour. Component internals live in
their own specs; this file **pins the component-contract versions it composes**, the way a bundle
manifest pins slices.

## Composition

| Component | Contract | Pinned version |
|---|---|---|
| Workout card | [`../components/workout-card.md`](../components/workout-card.md) | v1 (ratified) |
| Energy summary card | [`../components/energy-card.md`](../components/energy-card.md) | v1 (ratified) |
| Tokens | [`../tokens.md`](../tokens.md) | v1 (ratified) |
| Meal card · filter row · AI card · timeline rail | **no component spec yet** — they earn one when their states/gestures get contracted; until then their truths live here or nowhere |

## Surface contracts

| # | Contract |
|---|---|
| S-1 | **A card state change is a whole-dashboard state change.** Consuming the workout card's G7 emission, the surface updates net balance, band copy, Active Energy and every open sheet together — never a local repaint. (Verified working in the reference rendering: swipe flipped −133 ⇄ −1,338 with copy following) |
| S-2 | Deletion scope for G5: the workout's kcal, fuel-plan windows and timeline entry leave **every** surface figure in the same frame. Upstream, deletion is a **soft delete** (`status = deleted`, row persists — `intraday-display.md` §4b) so a later platform sync cannot resurrect the card |
| S-3 | Numbers shown anywhere on this surface obey the traceability rule: every quantity maps to a documented spec field (`intraday-display.md` for so-far arithmetic; `platform-resolution.md` for sources/chips) |
| S-4 | Persistent UI state survives component state changes — the energy card's own P-1 states it from the component side; this surface guarantees the environment honours it (reference-rendering defect W-8; do not encode) |
| S-5 | Scope guard for this iteration (Xuan): no phase indicator, no safety states, no sodium on this surface — deferred, not forgotten |
| S-6 | **AI-card copy scope.** Fueling *instructions* may reference today and tomorrow only; a future day may be mentioned as schedule awareness, never instructed about (F-18 ruling). **No surface copy anywhere states an unconditional refueling deadline** — post-workout phrasing follows the two-branch contract in `spec/fueling/post-workout.md` (RATIFIED), with unknown-schedule taking the relaxed branch. *(Previously held only in the design brief; a brief is a handoff, not a contract — this row makes it ratifiable.)* |

## Conformance

Surface-level Patrol flows (L2): G1 swipe → assert net balance text, band copy, and Active Energy
sheet all change in the same pump (S-1); delete → assert S-2; expanded energy card survives a
swipe (S-4). **S-6 string-level check:** no rendered copy in any surface state matches an
unconditional-deadline pattern ("within \d+ min", "within the hour") — the same check style the
intraday no-congratulatory-deficit rule uses.
