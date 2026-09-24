# 13: The store checks before release

**Status:** in-progress (wave 10, 2026-09-24)
**Blocked by:** 01, 02, 03, 04, 05.
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** Claude checks from the APIs and the signed-in browser that the products, prices, free weeks and offerings are right on both stores and RevenueCat, that a hand-granted account shows `pro` and has its row. Lee then does the phone part on both stores: the founding purchase, the day-five reminder with the clock moved on, and Restore.

**Decisions:** mp-463, mp-289; approved as mp-492.

**Touches:** scripts/sandbox-trial-wizard.sh, docs/release/sandbox-trial-runs

- [x] The wizard carries the three new steps and marks which are Claude's and which need a phone.
- [x] Claude's checks run and are logged under docs/release/sandbox-trial-runs.
- [ ] Lee's phone run is logged green on both stores.

Next: /implement-lee paywall
