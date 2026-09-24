# 06-007 · A paid account signs out offline, and cancels the Sign Out dialog once first

- kind: followup-test
- status: open
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
