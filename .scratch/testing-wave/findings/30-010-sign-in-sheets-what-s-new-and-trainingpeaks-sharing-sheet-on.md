# 30-010 · Sign-in sheets: What's New and TrainingPeaks sharing sheet on a fresh sign-in, Turn Off Sharing and Keep Sharing

- kind: followup-test
- status: open
- ticket: 30
- run: w10-20260924T1615Z
- screen: Timeline (sign-in sheets)
- decision: 

**Steps.**
1. After a fresh sign-in the "Shake to tell us what's wrong" What's New sheet shows, then "Your fuel plan goes to your coach" (TrainingPeaks sharing), though the account's TrainingPeaks token refresh fails at the same moment (console lines 15, 18-29).
2. Try Keep Sharing, Turn Off Sharing and the close button, then sign out and in: does each sheet show again?
3. Swipe the sheets down instead of tapping.

**Expected.**
Each sheet shows once per account, and the sharing sheet does not offer sharing for a disconnected TrainingPeaks.

**Evidence.**
- runs/30/02-timeline-after-login-whats-new.png
- runs/30/03-trainingpeaks-sharing-sheet.png
- runs/30/console-excerpts.log

**Triage.**
