# Design SSOT — Surface: Macro Dashboard

**Status: RATIFIED v2 (Xuan, 2026-08-17 — carries the workout-card v2 skip contract, Q-D6;
supersedes v1, RATIFIED Xuan 2026-08-14).**
**Reference rendering:** [`../renderings/macro-dashboard@v1.html`](../renderings/macro-dashboard@v1.html)
(rendering ratified Xuan 2026-08-25; frozen copy of `prototypes/macro-dashboard/index.html` @ `5a22ca8`).
Rendering versions track the rendering, not this spec — see [`../source-authority.md`](../source-authority.md) §3.
**Changes from v1:** pins workout-card v2; S-2 is now the *skip* scope (delete deferred to a future
bundle); S-7 added (timeline position of a skipped card).
**Surface contract** — owns composition and cross-component behaviour. Component internals live in
their own specs; this file **pins the component-contract versions it composes**, the way a bundle
manifest pins slices.

## Composition

| Component | Contract | Pinned version |
|---|---|---|
| Workout card | [`../components/workout-card.md`](../components/workout-card.md) | v2 (ratified — skip replaces delete, Q-D6) · **v3 (ratified 2026-08-18, Q-D7: mark-done writes `= planned_time`, not offered on a future day; a confirmed card keeps its planned slot — this surface's own contracts S-1–S-7 are unchanged; ships with `daily-macros-dashboard@v3`)** |
| Energy summary card | [`../components/energy-card.md`](../components/energy-card.md) | v1 (ratified) |
| Tokens | [`../tokens.md`](../tokens.md) | v1 (ratified) |
| Meal card · filter row · AI card · timeline rail | **no component spec yet** — they earn one when their states/gestures get contracted; until then their truths live here or nowhere |

## Surface contracts

| # | Contract |
|---|---|
| S-1 | **A card state change is a whole-dashboard state change.** Consuming the workout card's G7 emission, the surface updates net balance, band copy, Active Energy and every open sheet together — never a local repaint. (Verified working in the reference rendering: swipe flipped −133 ⇄ −1,338 with copy following) |
| S-2 | **Skip scope for G5 (v2; was deletion scope in v1):** a skipped workout's kcal, fuel-plan windows and timeline entry leave **every** surface figure in the same frame — net balance, band copy, Active Energy sheet, by-end-of-day burn, and any open sheet — and re-enter them all on Unskip, G1 recovery, or a matching sync (G6). Upstream write is `status = 'skipped'` on the workout row (never a delete). *Deferred, not repealed:* the soft-delete tombstone (`status = 'deleted'`, `intraday-display.md` §4b) stays in the data model; no surface affordance writes it in v2 |
| S-3 | Numbers shown anywhere on this surface obey the traceability rule: every quantity maps to a documented spec field (`intraday-display.md` for so-far arithmetic; `platform-resolution.md` for sources/chips) |
| S-4 | Persistent UI state survives component state changes — the energy card's own P-1 states it from the component side; this surface guarantees the environment honours it (reference-rendering defect W-8; do not encode) |
| S-5 | Scope guard for this iteration (Xuan): no phase indicator, no safety states, no sodium on this surface — deferred, not forgotten |
| S-6 | **AI-card copy scope.** Fueling *instructions* may reference today and tomorrow only; a future day may be mentioned as schedule awareness, never instructed about (F-18 ruling). **No surface copy anywhere states an unconditional refueling deadline** — post-workout phrasing follows the two-branch contract in `spec/fueling/post-workout.md` (RATIFIED), with unknown-schedule taking the relaxed branch. *(Previously held only in the design brief; a brief is a handoff, not a contract — this row makes it ratifiable.)* |
| S-7 | **Timeline position of a `SKIPPED` card (v2, Q-D6):** it loses its slot — renders with **no timestamp**, tucked **after every timed card** of that day (planned or done), rail ink neutral (dimmed `cream`, not `electrolyte`, not `orange`). Unskip / G1 recovery restores `planned_time` (or `actual_time`) and the card returns to its time-ordered slot. Order among several skipped cards is `planned_time` ascending `[design]` (ratified v2) |

## Conformance

Surface-level Patrol flows (L2): G1 swipe → assert net balance text, band copy, and Active Energy
sheet all change in the same pump (S-1); skip → assert S-2 and S-7 (figures leave, card tucks;
unskip restores both); expanded energy card survives a swipe (S-4). **S-6 string-level check:** no rendered copy in any surface state matches an
unconditional-deadline pattern ("within \d+ min", "within the hour") — the same check style the
intraday no-congratulatory-deficit rule uses.
