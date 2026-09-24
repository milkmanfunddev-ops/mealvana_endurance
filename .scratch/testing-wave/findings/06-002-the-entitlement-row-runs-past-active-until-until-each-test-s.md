# 06-002 · The Entitlement row runs past active_until until each Test Store renewal lands (2.5 min here), and the server's Pro check has no grace, so a paying account's AI calls would be refused in that gap

- kind: ssot-conflict
- status: open
- ticket: 06
- run: w6-20260924T1117Z
- screen: none
- decision: mp-457

**Steps.**
1. Account C bought Test Store Monthly at 11:28:37.722Z. RevenueCat: `pro` until 11:33:37.722Z,
   `will_renew`. The Entitlement row: `active_until` 11:33:37.722, the same.
2. Read the row and RevenueCat around the period end: 11:33:22Z, 11:36:05Z, 11:36:36Z.
3. Read the dev `revenuecat-webhook` logs for 11:25Z-11:40Z.

**Expected.**
A paying account with a renewing subscription counts as having Pro on the server for the whole
time it pays. The server refuses AI calls only for an account without Pro (mp-457).

**Actual.**
At 11:36:05Z, 2.5 minutes after the period ended, the row still said `active_until` 11:33:37.722
and RevenueCat still said `current_period_ends_at` 11:33:37.722, `gives_access: true`,
`will_renew`. The RENEWAL webhook arrived at 11:36:13Z and moved the row to 11:38:37.722. Ticket 05
saw a similar lag: the 08:55:45 renewal landed at 08:59:37.
`supabase/functions/_shared/vana/entitlement.ts` `isEntitled` is `active_until > now` with no
grace, and `requirePro`/`refuseUnlessPro` read that row. So from 11:33:37 to 11:36:13 the server
counted C as having no Pro while RevenueCat, and the app, counted it as paid. No AI call was made
in that window, so no refusal was seen live. It follows from the code and the row. On the App
Store, Apple usually renews ahead of the period end, so the gap may be smaller or absent. A late
or retried webhook would open the same gap. On the Test Store every simulator run can hit it every
5 minutes.

**Evidence.**
- runs/06/db-C-after-renewal.txt (11:36:05Z, row still at 11:33:37.722)
- runs/06/db-C-after-renewal-2.txt (11:36:36Z, row at 11:38:37.722)
- runs/06/edge-logs-webhook.txt (RENEWAL for d3d962e6 at 11:36:13Z)
- supabase/functions/_shared/vana/entitlement.ts (`isEntitled`)

**Decision quote.**
> The Gate gives one of two answers: open (Pro is live, or the account is an Admin) or closed (no live Pro, whether the account never had it or it ran out). Closed lands on the full-screen paywall and stays there; there is no read-only mode, no plan-ended bar and no write check in the app. The server refuses AI calls for an account without Pro on its own. Example: an athlete's trial ends unpaid on 8 October; on 9 October the app opens on the paywall, just as it did on the day they signed up.

**Triage.**
