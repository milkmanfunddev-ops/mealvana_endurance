# Testing-wave improvements

A running list of ways to make the testing loop itself better: the harness, the runbook, the
tickets, the wave lead's routine. App bugs are not listed here; they are Findings.

**How to use it.** The wave lead reads this file before opening a wave and appends to it after
the review, one entry per lesson. Pick one or two open items to fix between waves, or ask Lee
which are worth it. When an item is fixed, move it to Done with the commit.

Each entry: what went wrong or cost time, where it was seen, and the suggested fix.

## Open

### Harness and tooling

1. **`wave --open` has no ticket filter.** Waves 4 and 5 were opened with a scratchpad script
   calling `wavePlan`/`waveOpen` to keep to two tickets at a time. Fix: `sync.mjs wave ... --open
   --only 14,15` (or a `--max 2` that takes the lowest numbers). Seen: waves 4, 5.
2. **Run logs are gitignored, and agents forget `git add -f`.** In wave 5, both console logs were
   left out of the commit, though three Findings cite them. The wave lead copied them in from
   the worktrees before removing them. Fix: add `!.scratch/testing-wave/runs/**/*.log` to
   `.gitignore`, so the token scan and a plain `git add` are enough. Seen: waves 2, 5.
3. **Nothing checks that a Finding's evidence exists.** `findings.mjs index` parses the Finding
   but not the paths under **Evidence.** Fix: `index` warns on an evidence path missing from
   `runs/`. Seen: wave 5.
4. **No reliable "build finished" signal.** Each agent writes its own wait loop. In wave 5, one
   matched "error" inside a Swift Package Manager warning and released the build lock early
   (11-013). Fix: a `LOCK wait-build <console.log>` helper that waits for `Flutter run key
   commands`, `Completed building` or a real failure line, then releases the lock. Seen: wave 5.
5. **`scripts/edge_logs.sh` is broken.** Supabase removed the `logs.all` endpoint, and the script
   prints "no rows" instead of failing (05-006). The runbook's step 8 depends on it. Fix: move
   it to the replacement endpoint, and make it fail on any non-row answer. Seen: wave 5.
6. **The mobile MCP can't drive pool simulators** ("Agent is not installed"), so agents fall back
   to idb and `simctl` screenshots. Fix: put idb in the runbook as the default, with the MCP as
   an option. Seen: waves 4, 5.
7. **Worktrees start with no `.env` files.** Each agent copies or rebuilds `.env.dev.local` by
   hand. Fix: a `scripts/testing-wave/worktree-env.sh <worktree>` that copies the dev env files
   only, never prod, and have the runbook call it. Seen: waves 2, 4, 5.
8. **`touched-screens` counts other sessions' uncommitted `lib/` edits,** so the wave lead skips
   the picture refresh. Fix: a `--committed` flag that reads only `base..HEAD`. Seen: waves 3, 5.
9. **`undrawn` skips open questions,** but the convention draws them, so the wave lead has to
   remember to draw them by hand. Fix: `undrawn --questions`, or include open questions by
   default. Seen: wave 5.

### Test data and accounts

10. **Tickets 06–09 build on a paid account that can't stay paid.** The Test Store products have
    no trial (05-002), and a monthly purchase lapses 25 minutes later (05-003). Needs Lee's
    call: each ticket buys again and finishes within 25 minutes, each starts from a Grant, or
    ticket 07 uses the natural expiry as its case. Lesson for future tickets: don't chain tickets
    on an account whose state expires. Seen: wave 5.
11. **Dev lacks the code rows the redeem scenarios need.** Both coach codes belong to
    test@test.com, which has already used them. No influencer, giveaway, expired or used-up
    codes exist (11-001, 11-008). Fix: a dev-only seed script with one row per code kind, each
    owned by a throwaway coach account, that the ticket can reset. Seen: wave 5.
12. **The Patrol account is lapsed, and the admin holds Pro Grants** (mp-658, 12-001). So the
    nightly Patrol job fails, and the admin-with-no-Pro case can't be seen. Waiting on Lee's
    choice in mp-658. Seen: waves 3, 4.
13. **Dev allows 2 auth emails an hour,** and two parallel tickets both sign up. A rate-limit hit
    stalls a run. Fix: stagger the two agents' signups (the slot lock could hand out a signup
    turn), or raise the dev limit. Seen as a risk: wave 5.

### Runbook and agent prompts

14. **Agents write surprises into `notes.md` and not as Findings.** Wave 5's review found three:
    redemptions deleted with the account, the early lock release, and the clock jump. Fix: add a
    runbook rule that any line in `notes.md` naming something unexpected gets a Finding, or a
    "known noise" reason next to it. The wave lead's review greps `notes.md` for them. Seen:
    wave 5.
15. **`ssot-conflict` is under-used.** 05-005 tests mp-457 but was filed as an idea, and 05-002
    paraphrases mp-279 instead of quoting it. Fix: a runbook example of when a Finding is an
    ssot-conflict, and a check in `index` that an ssot-conflict has a **Decision quote.** Seen:
    wave 5.
16. **Live-timing scenarios can go unobserved.** In ticket 05 the clock jumped two hours between
    steps, so the expiry the ticket watched was read afterwards from logs (05-011). Fix: for a
    step that must be seen live, the runbook says to note the time before and after each wait,
    and to write "not seen live" when the gap is larger than planned. Seen: wave 5.
17. **Agents skip the Patrol flow a ticket's Touches line names** when the criteria don't ask for
    it (05-012). Fix: every ticket either lists the flow as a criterion or leaves it off
    Touches. Seen: wave 5.

### Tickets

18. **Tickets can contradict themselves.** Ticket 05 said both "delete the account at the end"
    and "keep the paid account for 06–09". Fix: `/to-tickets-lee` checks account-lifecycle
    criteria against the tickets that depend on them. Seen: wave 5.

### The wave lead's routine

19. **The suite has two failures that were already red before the waves began,** and every
    wave has to explain them: `test/shared/ci_config_contract_test.dart` (a push-to-develop
    check against a trigger Lee made PR-only, 11-011) and
    `test/manual_live/training_peaks_api_test.dart` (needs a live token). Fix: update the
    contract test to the PR-only trigger, and exclude `test/manual_live/` from the gate. Seen:
    waves 2–5.
20. **Pool simulators outlive a wave if the lead forgets to drop them.** The lead dropped them in
    wave 5, but it's a manual step. Fix: `wave --close` drops idle pool devices itself. Seen:
    wave 5.

## Done

- Patrol reported a skipped flow as passed; the runner now fails on skips
  (`PATROL_FAIL_ON_SKIP`, `skipFlow()`). Wave 3, `ff1baafc`.
- The redeem flow's header now says what a thrown wait leaves on dev and how to sweep it. Wave 5,
  `fe14603c`.
