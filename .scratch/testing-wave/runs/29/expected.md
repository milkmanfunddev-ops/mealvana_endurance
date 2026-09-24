# Ticket 29 expected records (run w16-20260924T2100Z)

Ticket 29 is read only. Its criteria name no RevenueCat or database records to change.

## Before
- RevenueCat: test@test.com (dev admin) as it is; this run reads nothing it needs to change.
- Dev database: test@test.com as the prompt describes it: week of 2026-09-20 has confirmed plan
  `be6abf2f` with no shopping list (19-001), conversations `d8efbdb3` and `4d62c862`, meal logs from
  09-23/24.

## After
- Same as before. The only writes expected from this run are the sign-in session itself (auth
  session, device/sign-in events) and whatever the app writes by itself on cold start. Any
  plan, conversation, meal log, shopping list or `vana_calls` row added between the run's start and
  end that ticket 18 (sharing the account, browsing Vana on wave-pool-1) did not cause is a Finding.
- Console: every error or exception line from cold start, sign-in, and the first screen of each tab
  is a Finding or listed as known noise with a reason.
