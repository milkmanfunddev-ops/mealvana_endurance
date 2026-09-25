# 22: Kroger matches the list and hands off to checkout

**Status:** ready-for-agent (wave 18 failed, 2026-09-25)
**Blocked by:** 21.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** With Kroger connected, the athlete sends the shopping list, sees each item matched to a product, and is handed off to Kroger's checkout.

**Decisions:** none.

**Touches:** the dev test account's Kroger cart

- [x] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [x] Uses the entitled dev test account from the credentials file; no new account.
- [ ] Matching runs without connecting Kroger (22-004): no sign-in, dev stays on certification.
- [ ] Unmatched items and wrong matches are each a Finding with the list row and the product.

Out of scope (Lee, 2026-09-25, IMPROVEMENTS #52): the cart hand-off. Kroger's certification site
refuses Lee's shopper login and there is no test shopper account, so the hand-off stays untested
on dev.

Next: /implement-lee testing-wave
