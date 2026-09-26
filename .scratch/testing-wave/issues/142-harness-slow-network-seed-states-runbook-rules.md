# 142: Harness: slow network, seeded start states, runbook rules

**Status:** ready
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Owner:** wave lead (harness, not a wave agent)

**What to build:** Harness changes from the 2026-09-26 triage. No app code. Commit them before the next `wave --open`, because worktrees branch from the wave's base.
1. **`netcut.sh slow <ms>` (IMPROVEMENTS #92).** Add a slow mode next to `on`/`off`. The app's traffic then answers late but succeeds. 122's shim slept inside `connect()`, which blocked Dart's IO threads and failed TLS (122-009). Delay after the connect: for example, hold the first send on each new socket for `<ms>`, keyed off a `slow.flag` holding the delay. A host-side proxy with fixed latency for the app only also works. Which of the two holds up is unverified. Before any agent relies on it, prove it against a known timeout: `entitlementAnswerTimeout` is 2 s (`subscription_status_provider.dart:18`). With `slow 3000` that read gives up and the fallback shows; with `slow 500` it answers. Write both results in the script's header.
2. **`netcut.sh on` closes open sockets (111-004).** Today `on` blocks only new connects, so a keep-alive socket carries the first offline tap (21-007's Kroger connect reached the server). Make the library track the sockets it let connect, and `shutdown()` them when the flag appears (a watcher thread, or a check on the next send). `--relaunch` stays as the fallback. Proof: `on`, then an immediate tap on a server action (Kroger connect or Vana send). `netcut.log` shows it blocked and no server row is written.
3. **Seeded start states (IMPROVEMENTS #87).** Extend `seed-codes.mjs` (or add `seed-states.mjs` beside it, dev only, same `assertDev` and `isSweepable` guards). One command writes a start state in a second or two onto a named `lee+e2e-*` account the run made. A run never relies on another run's account, since runbook step 9 deletes it. First state: a pending coach pairing (`coach_athlete_relationships`, `status: 'pending'`). Ticket 140 makes coach-code pairings auto-accept (122-002/003), so a redeem no longer leaves a pending row. Pending rows still come from a coach's invite (`coach_service.dart:246`, `requested_by: 'coach'`) and an athlete's request (`:905`). The state is still worth seeding for the accept and decline screens. Before building it, check which retest after 140 still needs pending (11-009 as written, "a pairing that came from a code", is moot). If none does, seed an active pairing instead and say so (unverified).
4. **A free grant that lapses in about 2 minutes (IMPROVEMENTS #96, 117-015).** A seed command grants `pro` to a named `lee+e2e-*` account with an end about 2 minutes out. Lapse checks use it, never a Test Store monthly, which keeps renewing while signed out. The likely routes are RevenueCat v2's grant with a short `expires_at` or the grant helper in `supabase/functions/_shared/grace/grace.ts`. Both are unverified: RevenueCat may refuse or round very short grants. Prove it once: grant, sign in, wait past the end, see the lapsed paywall and `user_entitlements` end. Record the real lapse delay in the header.
5. **`CRED type` waits 2 s after typing (120-010).** iOS shows a password's last character for a moment, and one screenshot caught it. After `idb ui text` in `cred.mjs`'s `type`, wait 2 s before returning, so no screenshot right after can carry a character. Keep the 1 s wait before typing (#93).
6. **Runbook rules.** Each goes where a reader meets it in `RUNBOOK.md`:
   - #82: "After the wave" step 3, next to the Touches rule. A ticket that adds a timeout or a retry lists each write it covers, and says whether repeating it is safe. A write that is not safe gets an idempotency key or no timeout.
   - #87: lead step 5 and runbook step 6. Start states come from the seed script (items 3 and 4), never from another run's account.
   - #91: lead step 5. Every line of a code map in a prompt says "from code, unverified". Anything a Finding's verdict hangs on is checked on the screen.
   - #97: runbook step 6 ("Read, never write…"), and lead step 5 says every prompt repeats it: "no RevenueCat or database writes the ticket doesn't name, even on your own account".
   - #99: "After the wave" step 3 (triage). The lead rewrites or closes a follow-up a run proved impossible, and never carries it forward as written.
   - #96: runbook step 5's lapse lines (#80, "lapses about 5 minutes after sign-out") are replaced by the seeded grant.
   - Step 5 tips (the unnumbered IMPROVEMENTS item after #99): zsh does not split `$var`, so use functions. Wait 2 s after `idb ui text` before the next field and read it back. Backspace deletes forward from the tap point (keycode 76 clears a prefilled field). The Timeline's Next day arrow moves with the title width.
   - Step 5's netcut and `CRED type` lines name `slow`, the socket close and the 2 s wait.

**Findings:** 111-004, 120-010, 117-015; IMPROVEMENTS #82 (rule only; the server change is ticket 134), #87, #91, #92, #96, #97, #99.

**Decisions:** none on the page. Lee's rulings in the terminal (`triage-20260926.md`).

**Touches:** scripts/testing-wave/netcut/netcut.sh, scripts/testing-wave/netcut/netcut.c, scripts/testing-wave/seed-codes.mjs, scripts/testing-wave/cred.mjs, scripts/testing-wave/sweep-accounts.mjs (guards only, if shared), .scratch/testing-wave/RUNBOOK.md, .scratch/testing-wave/IMPROVEMENTS.md

- [ ] `netcut slow 3000` makes the 2 s entitlement read give up. `slow 500` does not. `off` restores. Results are in the header.
- [ ] `netcut on` then an immediate server tap: blocked, logged, no server row.
- [ ] The seed writes the pairing state and the short grant on a `lee+e2e-*` account in under ~2 s, refuses prod and non-sweepable accounts, and the grant lapses on screen.
- [ ] `CRED type` returns 2 s after typing. RUNBOOK and IMPROVEMENTS carry every rule above, and #87 #91 #92 #96 #97 #99 move to Done.

Next: /implement-lee testing-wave
