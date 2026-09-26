# 111-005 · Kroger screen: a ZIP no Kroger store delivers to, and an invalid ZIP, in Set delivery ZIP

- kind: followup-test
- status: triaged
- ticket: 111
- run: w30-20260925T2103Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. Shop with Kroger, not connected, location off: Set delivery ZIP 99701 (Fairbanks, no Kroger delivery), then 1234 and ABCDE, then Cancel on the sheet.

**Expected.**
No store: a plain `no_delivery_area` message and "Set delivery ZIP" stays; a bad ZIP: `invalid_zip`, no server call; Cancel leaves the area as it was.

**Actual.**
Not run (look-around, ticket 111).

**Evidence.**
- runs/111/12-set-zip-sheet.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
