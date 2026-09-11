# Vana knows you: the Voodoo Doll

The spec is [`spec.md`](spec.md). The tickets are in [`issues/`](issues/), **numbered in the order
they should be done**. The old set, and the map from its numbers to these, is in
[`archive/`](archive/README.md).

Every ticket carries the same three lines at the top: **Status**, **Blocked by**, **Next**.

---

## Run them in order

```
/clear
/mattpocock-skills:implement .scratch/mealplanning/issues/09-the-companion-that-speaks-first.md
/clear
/mattpocock-skills:implement .scratch/mealplanning/issues/10-the-recovery-moment-and-the-cap.md
/clear
/mattpocock-skills:implement .scratch/mealplanning/issues/11-launcher-off-flow-screens.md
```

One ticket per session, with `/clear` between them. 11 does not depend on 09 or 10 and can go first.
12 needs a grilling before any agent builds it.

| # | Ticket | Status |
|---|---|---|
| 01 | Finish the feedback loop | **done** |
| 02 | Home location on the device | **done** |
| 03 | An episode for a still-open conversation | **done** |
| 04 | Reconcile the design SSOT mirror | **done** (app side; QA repo left to Xuan) |
| 05 | Ratify and mirror the sheet spec | **done** (app side; spec in `docs/ssot/`, awaiting Xuan) |
| 06 | The launcher and the sheet | **done** (fuel-log screen not reached on the sim) |
| 07 | The companion's conversation surface | **done** (not yet seen on a device) |
| 08 | Sheet gestures | **done** (drag checked on the simulator) |
| 09 | The companion that speaks first: the pre-workout moment | ready |
| 10 | The recovery moment and the two-a-day cap | after 09 |
| 11 | The launcher stays off flow screens | ready (independent) |
| 12 | Meal-plan moments | needs grilling, after 10 |

## Settled on 2026-09-11

- **The mirror (04):** a stale local QA checkout, not two truths. The QA repo is Xuan's and is left
  alone. Specs written app-side live in `docs/ssot/spec/design/components/` as "authored app-side,
  awaiting Xuan": `meal-image-mosaic`, `vana-sheet` and `vana-moment`. A blind sync from the QA repo
  would delete them.
- **The sheet spec (05):** Lee confirmed the three heights and the drawn speech bubble.
- **What makes Vana speak (09):** fuelling windows, decided on the device (`vana-moment.md`). The
  meal-plan beats follow in 12.
- **The launcher over bottom buttons:** hidden on flow screens (11).

## What is already done

Six tickets of the original set, all committed and — except where noted — verified live against dev:

- The database-free test seam for the shared Vana modules.
- General mode reads the Doll: one context block for both conversation kinds, LIKES from meal
  feedback, GOALS from the onboarding survey, and a twenty-message history cap.
- The Situation: fifteen screens report what they have in view, resolved server-side from ids alone.
  Built and unit-verified; its device check rides with ticket 06.
- Remember reliably: deduped writes, and an explicit "remember X" that always fires.
- Lazy extraction: opening a conversation reads the previous one back.
- Home location as a Fact, server side.
- What Vana knows: one flat list of sentences with delete.
- The feedback loop: all three kinds file a row, the acknowledgement is server-authored, and a
  brand-new athlete's first conversation carries the prompt exactly once (verified live).

## State of the world, 2026-09-10

- **Dev is current.** Both migrations applied; `vana-chat`, `jade-chat`, `vana-action`,
  `vana-day-notes` and `kroger` deployed.
- **The personalization eval passes 13 of 13** (`deno run -A scripts/vana-eval/personalization.ts`,
  dev only, `--list` to see the cases) — three new feedback cases, and the acknowledgement settled.
- **Tests are green**: 135/135 edge-function, and the Flutter suites over every touched area.
  `test/shared/ci_config_contract_test.dart` fails and has failed since before this work.
- **Nothing is pushed.** Only `develop` and `release/*` trigger Codemagic, so pushing this branch
  costs nothing.
