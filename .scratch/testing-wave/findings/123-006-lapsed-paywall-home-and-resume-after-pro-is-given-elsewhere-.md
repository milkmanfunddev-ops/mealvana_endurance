# 123-006 · Lapsed paywall: Home and resume after Pro is given elsewhere (a Grant) does not refetch

- kind: followup-test
- status: triaged
- ticket: 123
- run: w38-20260926T0341Z
- screen: Paywall (lapsed)
- decision: 

**Steps.**
1. A lapsed account sits on the full-screen paywall.
2. Give it Pro from outside the app (a RevenueCat Grant, or a purchase on another device).
3. Press Home, wait a minute, resume. Then wait on the paywall without touching it.

**Expected.**
mp-335: a fresh answer opens the Gate. Say whether resume fetches (07-011 saw no fetch on resume from the Subscription screen; the app fetches only at a copy's expiry and on screen opens), and how long an athlete who paid elsewhere waits on the paywall.

**Actual.**
Not run (look-around, ticket 123).

**Evidence.**
- runs/123/notes.md

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
