# 112-024 · A quick log after a sheet sits open two minutes: does the first request time out every time?

- kind: followup-test
- status: triaged
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log a Meal → quick log sheet
- decision: 

**Steps.**
1. Open a recipe sheet, wait 2 minutes online, Log it. Here (23:30:29-23:32:33Z) the insert timed out after 31 s with errno 60 on a pooled connection, while other requests from the host went through.
2. Repeat three times, and once with a 30 s wait.

**Expected.**
The upload lands within a few seconds; a stale pooled connection is retried on a fresh one.

**Actual.**


**Evidence.**
- runs/112/console-meal-uploads.txt (18:33:05)
- runs/112/38-recipe-soup-sheet-after-2min.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
