# 11-003 · An overlong code is logged as 'code is required' on both server and app

- kind: idea
- status: closed
- ticket: 11
- run: w5-20260924T0840Z
- screen: Redeem code (paywall ⋯ menu)
- decision: 

**Steps.**
1. Redeem sheet: type a 40-character code, tap Redeem.
2. Idea: give the too-long case its own `details` (for example "code is longer than 32 characters") in `normalizeCode`'s caller, so a log reader can tell a blank submit from an overlong one.

**Expected.**


**Actual.**
The athlete sees the right thing (the not-found line, sheet open, as mp-458 and the ticket say). But the 400 body is `{error: invalid_input, details: code is required}`, and the app logs `[CODES] redeem-code answered 400` with that same text, because `handler.ts` uses one message for both a blank code and one over 32 characters.

**Evidence.**
- runs/11/console.log lines 468-475
- runs/11/edge-logs-redeem-requests.txt (the two 400s at 03:57:45 and 03:58:08 local)
- supabase/functions/redeem-code/handler.ts, `if (!entered) return json({ error: 'invalid_input', details: 'code is required' }, 400)`

**Decision quote.**
> 

**Triage.**
Fix ticket 81 (the wave lead, 2026-09-25: Lee asked for every bug fix that can be done without him). Closed by the retest after it merges.

Closed by retest ticket 87 (wave 25, build 5e05f8a6): pass, evidence in runs/87/verdicts.md.
