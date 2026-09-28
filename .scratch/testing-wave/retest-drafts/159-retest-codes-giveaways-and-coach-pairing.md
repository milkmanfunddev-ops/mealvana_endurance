# 159: Retest: codes, giveaways during Pro, and coach-code pairing

**Status:** ready-for-agent
**Blocked by:** 140.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix ticket 140 and the 2026-09-26 triage, about ten checks a run.

**What to build:** A retest run on the testing build (`app-build.json`). It re-runs each Finding's steps against ticket 140's code and pairing fixes (Lee's rulings: a giveaway is refused and not spent while any Pro is active; a coach code pairs at once), and runs the folded redeem follow-ups. Nothing is fixed during the run. Follow `RUNBOOK.md`.

**Accounts and start state:** `node scripts/testing-wave/seed-codes.mjs seed` at the start (resets the `E2E*` codes; this ticket owns them for its wave). App data cleared. New accounts (`CRED new`):
- V: `seed-states.mjs grant V --minutes 10` (a Grant ending today, checks 1 and 9).
- W: bought Annual (a paying subscription, check 2).
- X: never paid (checks 3, 5, 6, 8).
- Y: `seed-states.mjs pairing Y --status declined`, then later `--status archived` (check 4).
- Z: a coach account of its own: `seed-codes.mjs own <Z's id> --days 1` (checks 7 and 10).
test@test.com is the coach behind DEVCOACH30 and DEVCOACH18. Its pairings are read, never written by hand.

**Shared account:** test@test.com (read only: its coach pairings change only through the athletes' redeems). No other retest in this list runs `seed-codes.mjs seed`. If one is added to the same wave, the two must be ordered.

**COST:** none.

## Checks

1. **A giveaway is refused during a running Grant (122-001).** V (10-minute grant): Settings > Subscription > Redeem code > E2EGIVEMANY. *Pass:* "You already have free Pro until <date>". `code_redemptions` has no row for V, the code's count is unchanged (`seed-codes.mjs list`), and RevenueCat is unchanged. *Verify:* screen, SELECT, `list`, RevenueCat read.
2. **… and during a paying subscription (122-001, 123-004).** W (Annual): Subscription > Redeem code > E2EGIVEMANY. *Pass:* "You already have Pro.", with no redemption and no grant. *Verify:* same as check 1.
3. **A coach code pairs at once (122-002, 122-003).** X on the paywall: ⋯ > Redeem code > DEVCOACH30. *Pass:* "You're paired with <coach>." The `coach_athlete_relationships` row is `active`, with `accepted_at` set and `requested_by athlete`. Settings > Coach Connection reads "Paired with <coach>". *Verify:* screen, SELECT (status, accepted_at, requested_by).
4. **A coach code after a declined or archived pairing, and twice (100-008, rewritten).** Rewritten for auto-accept: Y with a seeded `declined` pairing redeems DEVCOACH30. *Pass:* the pairing reopens as active (140's reopen path). Seed `archived` and repeat: same. Then DEVCOACH30 again while active: the "already paired" answer (ticket 95) and no second grant. *Verify:* screen, SELECT after each, RevenueCat read.
5. **Redeem messages: a second code, an invalid one, offline (118-011).** X: DEVCOACH30 again, then ZZZZ, then any code after `netcut on`. *Pass:* each message is readable, clear of Continue, and Continue takes a tap while it shows. *Verify:* screenshots, `idb ui describe-point` on Continue.
6. **Redeem stays busy after a success (122-005).** X' (a fresh never-paid account), ⋯ > Redeem code > E2EGIVE365, recorded at 10 fps. *Pass:* Redeem never turns live again with the spent code before the sheet closes. *Verify:* recording frames.
7. **"1 day of Pro" (122-006).** Y2 (fresh, never paid) redeems Z's one-day code. *Pass:* "1 day of Pro", not "1 days". *Verify:* screenshot.
8. **The code field drops full stops (122-007).** ⋯ > Redeem code, type `  e2e  give  365` with double spaces. *Pass:* no "." appears, spaces are kept, and the code is accepted (or refused only for being spent). *Verify:* field read back with `idb ui describe-all`.
9. **Subscription on a Grant's last day (122-011, rewritten), and the lapse.** As written it needed the next local day, which the run cannot wait for. Rewritten: V's 10-minute grant ends today, which makes today its last local day. Settings > Subscription. *Pass:* "Last day today" (or the ticket's wording for a same-day end). Wait past the end: the lapsed paywall within about 5 s, and `user_entitlements.active_until` equals the end. *Verify:* screen with clock times, SELECT.
10. **A coach enters their own code (119-014, rewritten).** As written it used test@test.com (a write on the shared account). Rewritten: Z, which owns a coach code, Settings > Coach Connection > enter Z's own code. *Pass:* a clear refusal (you cannot pair with yourself), and no pairing row. *Verify:* screen, SELECT.

**Not counted:** 122-010 (the Redeem sheet with the software keyboard): the wave simulator uses the hardware keyboard, and toggling it needs the Simulator app's menu for that window. "Device: not run on simulator".

**Findings:** 122-001, 122-002, 122-003, 122-005, 122-006, 122-007; follow-ups 123-004, 100-008 (rewritten), 118-011, 122-011 (rewritten), 119-014 (rewritten), 119-018 (folded into check 1: Redeem code on a code-Pro account, now on V, not test@test.com), 122-010 (not counted).

**Decisions:** Lee's rulings in `triage-20260926.md` (122-001; 122-002/122-003 auto-accept, touches mp-535). 122-008 stays won't-fix.

**Touches:** accounts V, W, X, X', Y, Y2 and Z (deleted at the end, with their pairings and owned codes). The `E2E*` code fixtures (reset at the start). test@test.com's pairings through redeems only.

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/159/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding.
- [ ] Every account made is deleted. test@test.com is left with no pairing to a deleted athlete (SELECT at the end).

Next: /implement-lee testing-wave
