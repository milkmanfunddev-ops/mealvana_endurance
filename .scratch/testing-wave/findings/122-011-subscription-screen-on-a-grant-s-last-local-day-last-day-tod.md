# 122-011 · Subscription screen on a Grant's last local day: Last day today

- kind: followup-test
- status: triaged
- ticket: 122
- run: w38-20260926T0340Z
- screen: Subscription
- decision: 

**Steps.**
1. A new account redeems its own coach code made with `seed-codes.mjs own <id> --days 1` late in the local day.
2. Open Settings -> Subscription the next local day (or seed a code with a shorter grant, if the server allows one, e.g. hours), then again after the Grant ends.

**Expected.**
"Last day today" on the Grant's last local day, then the Gate closes and the paywall shows after the end (mp-457).

**Actual.**
Not seen live. The one-day Grant (2026-09-26 04:08Z -> 2026-09-27 04:08Z) read "Pro from a code / 1 day left" at 23:08 local on 25 September, as expected. Its last local day is 26 September, after the run's end. The account was deleted at the end of the run.

**Evidence.**
- runs/122/46-D-subscription-1day.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
