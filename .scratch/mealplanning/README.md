# Vana knows you: the Voodoo Doll

The spec is [`spec.md`](spec.md). The tickets are in [`issues/`](issues/), **numbered in the order
they should be done**. The old set, and the map from its numbers to these, is in
[`archive/`](archive/README.md).

Every ticket carries the same three lines at the top: **Status**, **Blocked by**, **Next**.

---

## Run them in order

```
git push                                    # the commits are only on this laptop
/clear
/mattpocock-skills:implement 02             # home location on the device
/clear
/mattpocock-skills:implement 03             # an episode for a still-open conversation
```

One ticket per session, `/clear` between. That is step 4 of the workflow, and it earns its keep: the
last tickets of the long first session were noticeably worse served than the first.

**04 and 05 are yours, not an agent's**, and they gate everything after them. Do them whenever — they
are not urgent, but 06 cannot start without them.

| # | Ticket | Status |
|---|---|---|
| 01 | Finish the feedback loop | **done** |
| 02 | Home location on the device | **done** |
| 03 | An episode for a still-open conversation | **done** |
| 04 | Reconcile the design SSOT mirror | ready-for-human |
| 05 | Ratify and mirror the sheet spec | ready-for-human |
| 06 | The launcher and the sheet | **done** (fuel-log screen not reached on the sim) |
| 07 | The companion's conversation surface | **done** (not yet seen on a device) |
| 08 | Sheet gestures | **done** (drag checked on the simulator) |
| 09 | The companion that speaks first | needs a decision |

## The three things waiting on you

1. **The mirror (04).** Fifteen design specs here, six in the QA repo. Which side is the truth? A
   verbatim sync today deletes nine ratified specs, two of which the sheet spec cites.
2. **The sheet spec (05).** Confirm the two answers the design export gave: the three rest heights,
   and the launcher being a drawn speech bubble — the first branded glyph on the shell.
3. **What makes Vana speak (09).** Three candidate trigger sets are in the ticket. My lean is the
   second: fuelling windows plus the plan beats, because `pickOpener` already decides the plan half
   server-side and is already tested.

The fourth, which lived *inside* ticket 01, is settled: the feedback acknowledgement is
server-authored, and 01 is done.

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
