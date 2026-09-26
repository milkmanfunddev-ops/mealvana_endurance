# 124-005 · Log In chooser: the back arrow is not in the accessibility tree at all

- kind: bug
- status: triaged
- ticket: 124
- run: w37-20260926T0221Z
- screen: Log In (chooser: Apple, Google, email)
- decision: 

**Steps.**
1. Welcome > I already have an account.
2. Read `idb ui describe-all`.

**Expected.**
The back arrow at the top left is a button named "Back", like Log In with email's.

**Actual.**
The arrow is drawn (screenshot, top left) but describe-all lists only the Apple, Google and email rows and the two dev buttons; the arrow has no element at all, so VoiceOver cannot reach it. Tapping it at (32,90) goes back to Welcome. Not in 118-005's list.

**Evidence.**
- runs/124/16-login-chooser-no-back.png

**Decision quote.**
> 

**Triage.**

Fix ticket 141, Accessibility, dev buttons, small fixes (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
