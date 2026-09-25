# 87-005 · Subscription screen on a Grant: redeem a second giveaway, and the days-left line near the end of a Grant

- kind: followup-test
- status: triaged
- ticket: 87
- run: w25-20260925T1325Z
- screen: Subscription
- decision: 

**Steps.**
1. An account holding Pro from E2EGIVE365 ("Pro from a code, 365 days left") taps Redeem code on the Subscription screen and redeems E2EGIVEMANY.
2. A Grant near its end (a short coach code, `seed-codes.mjs own <id> --days 1`) opens the screen on its last day.

**Expected.**
Step 1: the athlete is told what happened to the days (added, or not added because Pro is already running). Step 2: "1 day left" / "Last day today" per mp-615.

**Actual.**
Not run (look-around, ticket 87). This run saw only "Pro from a code", "365 days left", Redeem code and no Manage.

**Evidence.**
- runs/87/10-B-08-004-subscription-grant.png

**Decision quote.**
> 

**Triage.**
Picked for retest ticket 107 (Lee, 2026-09-25).
Moved to retest ticket 122 when 107 was split (Lee, 2026-09-25).
