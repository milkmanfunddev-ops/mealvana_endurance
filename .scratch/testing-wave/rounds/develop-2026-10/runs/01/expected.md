# Ticket 01 expected records (run w1-20261007T1103Z)

Written before the first tap. App build `ce1a1527`. Dev project `vlmtsdzpnjnavdgytcmi`.

## Pass A: first signup at address A
- Before signup: no `auth.users` row for A.
- After signup form, before the code: `auth.users` row exists, `email_confirmed_at` NULL.
- Code email from `support@mealvana.io` arrives within 2 minutes.
- After the code: `auth.users.email_confirmed_at` set; one `public.users` row with that id.
  `token_wallets` row: recorded either way (wallet is provisioned on first wallet read).
- Timeline (`/main`) shows; no paywall, Pro, "Go Pro" upsell or entitlement wording anywhere.
- Settings -> Delete Account -> "Delete Account?" dialog -> Cancel: dialog closes, account stays
  (auth + public.users rows still there).
- Delete: lands on Welcome. `auth.users` row gone, `public.users` row gone,
  `sweep-accounts.mjs footprint <id>` reports no rows.
- RevenueCat: `delete-user` makes no RevenueCat call (code: `supabase/functions/delete-user/index.ts`).
  If the app logged a customer in with the user id, it stays after delete (earlier round 02-005).
  Recorded by lookup, not judged as pass/fail beyond citing 02-005.

## Pass B: second signup at address A
- New `auth.users` id, different from pass A's; no rows carried over from pass A
  (public.users created fresh, no other tables pre-populated with the old id).
- Delete again: same as pass A.

## Pass C: UK region, address C
- Code read: `privacy_region.dart`, `analytics_consent.dart`, `privacy_region_service.dart`.
- Region resolution: the cached geo answer (`privacy_region_source` = `geo`, from
  `https://app.mealvana.io/api/region`) wins over device locale. From this Mac the endpoint answers
  `{"country":"US","region":"AL"}` (curl at 11:05Z), which resolves to `standard` -> no consent
  screen, whatever the `en_GB` locale says. The consent screen shows only when the geo lookup
  fails (2 s timeout, non-200, no country) so the device fallback runs: locale `GB` -> `strict`.
  So by code the UK pass with `AppleLocale en_GB` alone is expected NOT to show the screen while
  the geo lookup succeeds. If the screen does not appear, read the stored
  `privacy_region_source` / `privacy_geo_country` / `privacy_geo_region` before filing.
- If the consent screen shows: Decline stores
  `analytics_consent_status=denied`, `analytics_consent_regime=strict`,
  `analytics_consent_at=<ISO local time>`, `analytics_consent_version=1`.
  Accept stores the same with `granted`.
- US pass (A, B, en_US, geo US/AL): no consent screen (`needsPrompt` false: standard regime).
- After signup + code: same records as pass A; delete leaves nothing.

## End
- `sweep-accounts.mjs list`: no `lee+e2e-01-*` account from this run.
