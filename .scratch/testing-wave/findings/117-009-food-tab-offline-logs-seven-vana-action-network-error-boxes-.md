# 117-009 · Food tab offline retries a vana-action read eleven times in 38 s, each an error box

- kind: followup-test
- status: triaged
- ticket: 117
- run: w40-20260926T1052Z
- screen: Food (Plan)
- decision: 

**Steps.**
1. test@test.com, cold start offline (`netcut.sh on --relaunch`), open Food (Plan segment).
2. Read the console: eleven `[VANA_TRANSPORT] Network error calling vana-action` error boxes (red, stack through `VanaTransport.postJson`, vana_transport.dart:162) from 06:05:29.4 to 06:06:07.9 local: four within 1.5 s, then backing off to one every ~6.4 s, and they went on after the run left Food for Events, Learn and Timeline. The same eleven-try pattern answered HTTP 401 in the revoked-session leg (117-011).
3. Find which reads the Food tab sends through vana-action on open, whether they retry, and whether online opening sends them too (no vana-action request showed in the online edge log at 10:54:45Z; no vana_calls row for the account).

**Expected.**
A bounded retry that stops when the tab is left, one logged line per failure rather than a red error box each, and the screen says it is offline where a read failed. The screen itself looked fine (week's meal and the Vana card from the local database).

**Actual.**


**Evidence.**
- runs/117/51-offline-food.png
- runs/117/console-redacted.log
- runs/117/db-vana-calls-test-account.txt

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
