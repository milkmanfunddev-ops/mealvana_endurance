# 88-022 · A message sent offline from the Ask Vana sheet disappears: only the offline line with Retry shows

- kind: bug
- status: open
- ticket: 88
- run: w29-20260925T1949Z
- screen: Ask Vana sheet
- decision: 

**Steps.**
1. Retest of 12-009 (the parts that need no model call). Ask Vana: Close, reopen: the same conversation and chips come back (pass). App relaunched with netcut; netcut on (20:33:41Z).
2. Type "is rice ok tonight" in the sheet and send.

**Expected.**
12-009: the companion never loses a sent message; offline it shows the athlete's message with a failed/retry state.

**Actual.**
The sheet shows "You're offline — Vana will reply when you're back." with Retry, but the athlete's message is not shown anywhere (no bubble, the composer is empty) and the chips are gone. Retry was not tapped and the app was closed offline (the wave's chat cap was used), so whether Retry resends the lost text is untested. Nothing reached the server (0aeabaa0 still has 1 message).

**Evidence.**
- runs/88/129-12-009-sheet-reopened.png
- runs/88/130-12-009-offline-send-3s.png, runs/88/131-12-009-offline-send-13s.png

**Decision quote.**
> 

**Triage.**
