# 117-013 · TrainingPeaks sharing sheet: Keep Sharing, Turn Off Sharing and swipe-down on an account whose TrainingPeaks works

- kind: followup-test
- status: open
- ticket: 117
- run: w40-20260926T1052Z
- screen: Timeline (sign-in sheets)
- decision: 

**Steps.**
1. Use an account with a working TrainingPeaks connection (test@test.com's needs a reconnect: `requires_reauth`, and ticket 64 hides the sheet then; do not reconnect the shared account).
2. Clear the app, sign in: What's New, then "Your fuel plan goes to your coach".
3. Once each: Keep Sharing; Turn Off Sharing (check the setting it writes); swipe each sheet down instead of tapping. Sign out and in: does either show again?

**Expected.**
Each sheet shows once per device/account as coded, Turn Off Sharing turns TrainingPeaks write-back off, and a swipe-down leaves sharing on like the close button.

**Actual.**


**Evidence.**
- runs/117/db-integrations-state.txt

**Decision quote.**
> 

**Triage.**

