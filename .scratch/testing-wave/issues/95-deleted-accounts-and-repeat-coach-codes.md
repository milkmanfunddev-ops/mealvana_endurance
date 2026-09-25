# 95: Deleted accounts leave nothing in RevenueCat; a repeat coach code says so

**Status:** in-progress (wave 25, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Two server-side rulings by Lee (2026-09-25).
1. Deleting an account (the `delete-user` function, and the sweep if it deletes accounts) also deletes the account's RevenueCat customer (v2 API `DELETE /projects/{project}/customers/{id}`, the customer id is the Supabase user id). A RevenueCat failure does not block the delete: log it with the user id so it can be retried. The app's "deletes your account and all of its data" is then true of RevenueCat (02-005).
2. Redeeming a code from a coach the athlete has already asked to pair with (pairing pending or active) answers "You've already asked this coach to pair" (content system). It spends no claim (no `code_redemptions` row) and leaves RevenueCat's `coach_code` attribute as the first code (11-002, mp-660).

**Findings:** 02-005, 11-002. Retest ticket 100 closes them; this ticket does not.

**Decisions:** Lee's rulings above (2026-09-25, in the terminal). mp-458 and mp-535 for redeem behaviour. mp-660 is still open on the page. Do not write to the page; the SSOT is updated later in one pass.

**Touches:** supabase/functions/delete-user/, supabase/functions/redeem-code/, supabase/functions/_shared/ (a RevenueCat client if one exists), the redeem sheet's message mapping in lib/features/subscription/ and assets/config/content_defaults.json. Migration timestamp if one is needed: `20260925169500`.

- [ ] Deno tests: delete-user calls RevenueCat's customer delete with the user id, and a RevenueCat error still deletes the account and logs it.
- [ ] Deno tests: a second code from the same coach with a pending pairing answers `already_paired` (or the existing name for it), writes no `code_redemptions` row and does not set `coach_code`. The same for an active pairing.
- [ ] A widget or controller test: the redeem sheet shows the already-asked message.
- [ ] `flutter analyze` clean on touched files, deno tests for both functions. Deploy: wave lead.

Next: /implement-lee testing-wave
