# Testing-wave improvements

A running list of ways to make the testing loop itself better: the harness, the runbook, the
tickets, the wave lead's routine. App bugs are not listed here; they are Findings.

**How to use it.** The wave lead reads this file before opening a wave and appends to it after
the review, one entry per lesson. Pick one or two open items to fix between waves, or ask Lee
which are worth it. When an item is fixed, move it to Done with the commit.

Each entry: what went wrong or cost time, where it was seen, and the suggested fix.

## Open

### Harness and tooling

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
22. **`simulator claim` crashes with EEXIST when the other agent holds the claims lock** for more
    than about 10 seconds, and `--wait 90` doesn't cover it (07-005). The agent waited 2.5 minutes
    in a retry loop of its own. Fix: treat a held claims lock as "wait and retry" inside `claim`.
    Seen: wave 6.
23. **A hung Patrol run takes the simulator down with it** (06-009). Nothing times out a Patrol
    run, and killing it shut the device down. Fix: a timeout in the runbook's Patrol step (or a
    wrapper), plus a note on rebooting the pool device. Seen: wave 6.
24. **The flows copy each other's helpers.** Three flows each carry a noSettle copy of
    `deleteFromPaywallMenu`, and two read `user_entitlements` the same way. `_buyMonthly`,
    `_dismissWhatsNew`, `_signOut` and `_logIn` will be needed again by 08 and 09. Fix: move
    them into `integration_test/helpers/e2e_account.dart`, with a noSettle option on the delete,
    before tickets 08 and 09 write their flows. Seen: waves 5, 6.
25. **New testing-wave flows are never run by the M1 runner.** Redeem, relogin and restore are all
    excluded as clean-install, but spec story 76 asks for them on the self-hosted runner's list.
    Fix: give the runner a clean-install lane (uninstall before each such flow), or change the
    spec. Seen: waves 5, 6.

### Test data and accounts

12. **The Patrol account is lapsed, and the admin holds Pro Grants** (mp-658, 12-001). So the
    nightly Patrol job fails, and the admin-with-no-Pro case can't be seen. Waiting on Lee's
    choice in mp-658. Seen: waves 3, 4.
13. **Dev allows 2 auth emails an hour,** and two parallel tickets both sign up. A rate-limit hit
    stalls a run. Fix: stagger the two agents' signups (the slot lock could hand out a signup
    turn), or raise the dev limit. Seen as a risk: wave 5.

### Runbook and agent prompts

14. **Agents write surprises into `notes.md` and not as Findings.** Still happening in wave 6
    (four were filed by the wave lead: 06-009, 06-010, 07-010, 07-011), even with the rule in the
    prompt. Wave 5's review found three:
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

20. **Pool simulators outlive a wave if the lead forgets to drop them.** The lead dropped them in
    wave 5, but it's a manual step. Fix: `wave --close` drops idle pool devices itself. Seen:
    wave 5.

### Speed

21. **Every ticket does a cold iOS build, and the builds queue behind one lock.** Each ticket gets
    a new worktree with an empty `build/`, so Xcode starts from nothing: `run_dev.sh` took 56 s in
    wave 2 and 93–255 s in waves 4–5, and a Patrol build 68–288 s. A ticket needs one or two builds,
    and with two tickets only one builds at a time. That is about 5–10 minutes a ticket: real, but
    not most of the time (ticket 11 took 33 minutes in all). Testing tickets don't change `lib/`,
    so every ticket in a wave builds the same app. Options: build the dev app once per wave and
    install that `.app` on each pool device (needs Lee's word, since CLAUDE.md bars
    `flutter build` as assistant execution; one `flutter run` by the wave lead could produce it);
    share one Xcode DerivedData across worktrees; or reuse the last wave's worktree for the next
    ticket. Seen: waves 2–5.

## Done

- **Cleanup that can't take another run's account.** `sweep-accounts.mjs delete --id <id,id>
  --apply` deletes only the named throwaway accounts; the three flow headers point at it, since a
  bare sweep would also delete another agent's live account. Wave 6.
- **ssot-conflict quoting (#15), partly.** With the rule in the prompt, both of wave 6's
  ssot-conflicts (06-002, 07-002) quoted their decision word for word. The `index` check is still
  open.

- **#10, tickets 06–09 chained on a paid account that lapses.** 06, 07 and 08 each sign up and
  buy their own Test Store Monthly and finish within 20 minutes; 09 buys, cancels or lets the
  25-minute lapse stand in, and keeps the lapsed account for 10. Ticket 05's account and two
  wave-3 leftovers swept. Lesson for ticket writing: chain tickets only on account states that
  do not expire (lapsed, deleted), never on a paid one. 09-24, `43fdae9a`.
- **#2, run logs gitignored.** `.gitignore` now keeps `.scratch/testing-wave/runs/**/*.log`;
  the token scan still runs before the commit. 09-24, `43fdae9a`.
- **#1, `wave --open` had no ticket filter.** `sync.mjs wave ... --only NN,NN` or `--max N`
  (refuses a ticket off the frontier); the implement-lee skill says to use it when a feature
  caps its waves. 09-24, `43fdae9a`.
- **#19, the two suite tests red before the waves.** The ci_config contract test now asserts
  pr-validation is PR-only (Lee 08-21), and the wave lead runs the CI gate's own command
  (`flutter test --exclude-tags="integration || e2e"`), which leaves out the live-token
  TrainingPeaks test. 09-24, `35b706ac`.
- **#11, dev had no code fixtures.** `scripts/testing-wave/seed-codes.mjs` (`seed`, `list`,
  `own <user id>`) and the runbook's step 8 note; seeded on dev 09-24. Retests of 11-001 and
  11-008 can run now. 09-24, this commit.
- Patrol reported a skipped flow as passed; the runner now fails on skips
  (`PATROL_FAIL_ON_SKIP`, `skipFlow()`). Wave 3, `ff1baafc`.
- The redeem flow's header now says what a thrown wait leaves on dev and how to sweep it. Wave 5,
  `fe14603c`.
