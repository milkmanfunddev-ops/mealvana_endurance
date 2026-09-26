# 111-007 · Kroger screen: Skip, Include and Add item on an unconnected draft reach kroger_drafts after a sync

- kind: followup-test
- status: triaged
- ticket: 111
- run: w30-20260925T2103Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. Not connected. On Shop with Kroger tap Skip on a line, Include on a skipped one, and Add item; leave, reopen, and read `kroger_drafts` for the plan.
2. Seen in this run: the draft for 666be167 reached `kroger_drafts` at 21:08:04Z (on a reopen) but the ZIP change at 21:09Z did not move `updated_at`; when does a local-only change sync?

**Expected.**
Each change survives a reopen and a restart, and reaches `kroger_drafts` on the next load (`ensureSynced`).

**Actual.**
Not run (look-around, ticket 111).

**Evidence.**
- runs/111/db-kroger-draft-after-zip.txt

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
