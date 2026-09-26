# 06-007 · A paid account signs out offline, and cancels the Sign Out dialog once first

- kind: followup-test
- status: closed
- ticket: 06
- run: w6-20260924T1117Z
- screen: Settings
- decision: 

**Steps.**
1. Paid account, Settings → Sign Out → Cancel. Check that it is still signed in and still has the
   Settings screen.
2. Turn the network off. Settings → Sign Out → Sign Out.
3. Turn the network on, then sign in again.

**Expected.**
Step 1: nothing changes. Step 2: the app still lands on the welcome screen (local sign-out,
`SignOutScope.local`) and never on the paywall. Step 3: sign-in lands in the app, the same as
online (mp-335).

**Actual.**
Not run. This run only signed out online, which landed on welcome with no paywall frame.

**Evidence.**
- runs/06/11-sign-out-dialog.png, runs/06/19-sign-out-frames-5fps.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 125 when 109 was split (Lee, 2026-09-25).

Run by retest ticket 125 (run w37-20260926T0221Z, build 72d3723e): fail, carried by new bug Finding 125-001 (Cancel works, but signing out a Test Store-paid account routes through the paywall; offline a full paywall frame shows before Welcome).
