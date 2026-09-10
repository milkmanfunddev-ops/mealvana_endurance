# Vana knows you: the Voodoo Doll

The spec is [`spec.md`](spec.md). The tickets are in [`issues/`](issues/), numbered and never
renumbered — commit messages cite these numbers.

Every ticket carries the same three lines at the top: **Status**, **Blocked by**, **Next**. Status
uses this repo's own vocabulary (`docs/agents/triage-labels.md`) plus `done`, `blocked` and
`deferred`.

---

## Run this next

```
git push                                    # 16 commits are only on this laptop
/clear
/mattpocock-skills:implement 14             # server-only, small, closes a gap the review found
/clear
/mattpocock-skills:implement 15             # the profile seam — give it a fresh window
```

One ticket per session, `/clear` between. That is the workflow's step 4, and it matters here: the
last four tickets of the long first session were noticeably worse served than the first four.

## Waiting on Lee, not on an agent

Three decisions. The first unblocks three tickets; the others close one each.

| # | Decision | Unblocks |
|---|---|---|
| 09 | Confirm the two answers the design export gave: the sheet's rest heights, and the launcher's mark being a drawn speech bubble — the first branded glyph on the shell | 10, then 11 and 12 |
| 01 | How the feedback acknowledgement is kept short. Recommendation: a server-authored line, the way the first-conversation prompt already works | 01 |
| 13 | What makes Vana speak unprompted. Three candidate trigger sets are in the ticket | 13 |

## Where every ticket stands

| # | Ticket | Status | Blocked by |
|---|---|---|---|
| 01 | Verify feedback lands | ready-for-human | a decision |
| 02 | Vana test harness | done | |
| 03 | General mode reads the Doll | done | |
| 04 | Situation | ready-for-human | a simulator check, riding along with 10 |
| 05 | Remember reliably | done | |
| 06 | Lazy extraction | done | |
| 07 | Home location (server) | done | |
| 08 | What Vana knows | done | |
| 09 | Vana sheet spec | ready-for-human | a confirmation |
| 10 | Vana everywhere — launcher and sheet | blocked | 09 |
| 11 | The companion's conversation surface | blocked | 10 |
| 12 | Sheet gestures | blocked | 10 |
| 13 | The companion that speaks first | deferred | a decision |
| 14 | An episode for a still-open conversation | ready-for-agent | |
| 15 | Home location on the device | ready-for-agent | |

Six done, two ready to build, three waiting on a decision, three blocked behind those, one deferred.

## State of the world, 2026-09-10

- **Dev is current.** Both migrations applied; `vana-chat`, `jade-chat`, `vana-action`,
  `vana-day-notes` and `kroger` deployed.
- **The personalization eval passes 9 of 10** (`deno run -A scripts/vana-eval/personalization.ts`,
  dev only, `--list` to see the cases). The tenth is the feedback reply length, which is decision 01.
- **Tests are green**: 97/97 edge-function, and the Flutter suites over every touched area.
  `test/shared/ci_config_contract_test.dart` fails and has failed since before this work.
- **Nothing is pushed.** Only `develop` and `release/*` trigger Codemagic, so pushing this branch
  costs nothing.

## Two things not to lose

- **The design SSOT mirror has drifted.** `docs/ssot/spec/design/` here holds fifteen component
  specs; `../mealvana_endurance_qa/spec/design/` holds six. A verbatim sync today would delete nine
  ratified specs, including the two the new sheet spec cites. Reconcile before mirroring.
- **`/design-sync` is not that mirror.** It publishes the design-system package to the claude.ai
  design project, which is an outward-facing publish and Lee's to run.
