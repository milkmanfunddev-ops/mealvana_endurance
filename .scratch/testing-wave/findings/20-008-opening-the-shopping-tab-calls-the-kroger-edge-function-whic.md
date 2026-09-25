# 20-008 · Opening the Shopping tab calls the kroger edge function, which answers 400 every time

- kind: bug
- status: triaged
- ticket: 20
- run: w10-20260924T1614Z
- screen: Food > Shopping
- decision: 

**Steps.**
1. Sign in as test@test.com (confirmed plan `be6abf2f`, list `03c4c52b`, no Kroger connection used in this run).
2. Open Food > Shopping (16:18:15Z), cold-restart and open it again (16:19:03Z), relaunch with the per-app network cut (16:21:19Z).

**Expected.**
Opening the Shopping tab makes no failing call; if it asks Kroger for anything (delivery area, connection state), the call succeeds or the app shows why not.


**Actual.**
The dev edge-request log shows `POST /functions/v1/kroger` answering 400 at 11:18:21, 11:19:48 and 11:21:52 CDT (16:18:21Z, 16:19:48Z, 16:21:52Z), each a few seconds after ticket 20 opened the Shopping tab on test@test.com. Ticket 30, on the same account at the same time, opened no Kroger or Shopping screen. Nothing on screen showed an error, and ticket 20's run did not notice the calls; the request body and the 400's reason were not read. Filed by the wave lead from ticket 30's edge-request extract and ticket 20's notes.


**Evidence.**
- runs/30/edge-function-requests.txt (the three kroger 400 lines)
- runs/20/notes.md (times the Shopping tab was opened)

**Decision quote.**
> 

**Triage.**
Fix ticket 56 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 111 when 90 was split (Lee, 2026-09-25).
