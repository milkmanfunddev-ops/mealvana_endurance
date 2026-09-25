# 110-013 · 16-009 steps not run on the shared account: meal count on a two-meal row, metric switch, plan edit keeping ticks, Kroger with no connection

- kind: followup-test
- status: open
- ticket: 110
- run: w30-20260925T2103Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
Run on an account of its own (not test@test.com while another run shares it):
1. A confirmed plan with an ingredient used by two meals: tap the row's count; it lists both meals and opens either recipe.
2. Settings > units metric and back: the list and Share switch units.
3. Edit the confirmed plan (remove a meal, change servings): the list rebuilds and keeps ticks.
4. Shop with Kroger with no Kroger connection: it asks to connect.
Also: on an earlier list opened from Previous lists (be6abf2f's), Farro is used by two meals but shows no count, since the count's meals come only from the plan on the Plan tab; check whether that is wanted.

**Expected.**
mp-244: the count lists both meals and leads back to either recipe; imperial unless Settings says metric; the list is rebuilt after every plan edit; Kroger without a connection asks to connect.

**Actual.**
Not run in 110: test@test.com's confirmed plan has no two-meal row; units are an account setting ticket 111 was checking on the Kroger screen; editing the confirmed plan was out of bounds; the Kroger connection was 111's.

**Evidence.**
- runs/110/09-be6abf2f-list.png — Farro with no count on an earlier list.
- runs/110/notes.md — 21:09Z skipped steps.

**Decision quote.**
> 

**Triage.**

