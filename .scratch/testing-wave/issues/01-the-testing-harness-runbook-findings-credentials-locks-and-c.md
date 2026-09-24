# 01: The testing harness: runbook, Findings, credentials, locks and cost caps

**Status:** done (wave 1, 2026-09-23)
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** An agent picking up any testing-wave ticket finds one runbook that says how a run goes, a Finding template, a credentials file with every login it needs, a slot lock that lets two runs go at once, a build lock that lets one build go at a time, and counters that stop a wave at three new Vana plans and five AI logging calls. A script builds the Findings index and says whether the loop is finished.

**Decisions:** none.

**Touches:** scripts/testing-wave/, test/scripts/testing-wave/, .scratch/testing-wave/RUNBOOK.md, .scratch/testing-wave/findings/TEMPLATE.md

- [x] `secrets/test_accounts.md` (gitignored) holds the dev admin, Lee's Kroger shopper login and a table for created accounts (address, password, bought, when, state); worktree agents read it from the main clone's absolute path.
- [x] The Finding template carries kind (bug, ssot-conflict, followup-test, idea), status (open, triaged, fixing, closed, wontfix), ticket, run, screen, steps, expected, actual, evidence, and for SSOT conflicts the decision id and quote. Finding file names start with the ticket number so parallel agents never collide.
- [x] The index script reads every Finding, prints them grouped by kind and status, writes the index file, and exits non-zero while any Finding is open or any followup-test waits; node tests feed it hand-written Findings.
- [x] The lock script gives a slot semaphore capped at 2 and a build lock capped at 1, both with a wait and a stale-lock timeout; node tests cover contention and stale release.
- [x] The cost counter records each new Vana plan and each AI logging call per wave and refuses past 3 and 5; node tests cover the refusal.
- [x] The runbook says, step by step: claim a slot, claim a simulator, terminate the old app, take the build lock, `flutter run` the dev debug build with the console to `runs/<ticket>/console.log`, release the build lock once the app runs, drive with mobile MCP (idb for text), check RevenueCat by API and the dev database by read-only SQL, do the look-around on every screen, write Findings, stop only when a Finding makes the rest meaningless, release everything. It points at the spec and CLAUDE.md rather than restating their rules.

Next: /implement-lee testing-wave
