# 02: Delete account, plus-address signup and the account sweep

**Status:** in-progress (wave 2, 2026-09-23)
**Blocked by:** 01 (touches scripts/testing-wave/sweep-accounts.mjs).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** An agent signs up a new account at a plus address on Lee's work mailbox, reads the code with the Gmail tool, and deletes the account through the app. Afterwards the dev database has no row for it and RevenueCat shows what deletion leaves. Signing up again at the same address starts a new account. A sweep script removes leftover test accounts. If deletion fails, the ticket stops and says so.

**Decisions:** mp-494; approved as mp-622.

**Touches:** scripts/testing-wave/sweep-accounts.mjs, integration_test/helpers/e2e_account.dart, integration_test/flows/account_delete_flow_test.dart

- [x] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [x] A code sent to `lee+e2e-02-<time>@rightpathprogramming.com` arrives and is read with the Gmail tool; if it never arrives, the Finding says so and the fallback is the plain address.
- [x] Delete account from the paywall's ⋯ menu (and from Settings once past the paywall) removes the auth user and its rows on dev; the expected rows are listed before the run and checked by SQL after.
- [x] RevenueCat's customer for the deleted account is looked up by API and its state recorded.
- [x] Signing up again at the same address gives a new user id that the Gate treats as never paid.
- [x] A failed delete is a hard stop: the Finding is written and the ticket ends.
- [x] The sweep script lists and deletes `lee+e2e-*` accounts on dev only, with a dry-run default; node test on its selection.
- [x] A Patrol flow signs up at `lee+e2e-<timestamp>`, meets the paywall and deletes the account; the helper it uses reads codes from a probe the flow can call.

Next: /implement-lee testing-wave
