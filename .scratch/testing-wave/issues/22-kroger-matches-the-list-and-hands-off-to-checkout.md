# 22: Kroger matches the list and hands off to checkout

**Status:** in-progress (wave 18, 2026-09-25)
**Blocked by:** 21.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** With Kroger connected, the athlete sends the shopping list, sees each item matched to a product, and is handed off to Kroger's checkout.

**Decisions:** none.

**Touches:** the dev test account's Kroger cart

- [x] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [x] Uses the entitled dev test account from the credentials file; no new account.
- [ ] Unmatched items and wrong matches are each a Finding with the list row and the product.
- [ ] The hand-off opens Kroger's cart with the matched items.

Next: /implement-lee testing-wave
