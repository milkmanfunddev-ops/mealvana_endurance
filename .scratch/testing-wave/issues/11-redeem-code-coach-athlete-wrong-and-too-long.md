# 11: Redeem code: coach, athlete, wrong and too long

**Status:** in-progress (wave 5, 2026-09-24)
**Blocked by:** 03 (touches integration_test/flows/redeem_code_flow_test.dart), 04.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A new athlete redeems codes from the paywall's ⋯ menu: a coach's own code gives 30 days of Pro and marks the account a coach; an athlete entering a coach code gets a pending pairing; a wrong code and an overlong code are each refused as not found and the sheet stays open.

**Decisions:** mp-458, mp-535, mp-598; approved as mp-631.

**Touches:** integration_test/flows/redeem_code_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Signs up its own account at a new plus address, logs it in the credentials file, and deletes it in the app at the end (a failed delete is a Finding).
- [ ] Uses the dev codes `DEVCOACH30` and `DEVCOACH18` and one made-up code; expected `code_redemptions` rows and Grants are written before the run and checked by SQL and API after.
- [ ] Each code works once per account; a second redemption of the same code is refused.

Next: /implement-lee testing-wave
