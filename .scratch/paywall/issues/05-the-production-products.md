# 05: The production products

**Status:** done (wave 9, 2026-09-23)
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** The four `_prod` products exist on the production App Store and Play apps with prices in every territory and the free week, registered in RevenueCat for the production apps, in `default` and `founding`. Nothing is submitted for review.

**Decisions:** mp-452, mp-429; approved as mp-484.

**Touches:** scripts/store/asc.mjs, scripts/store/play.mjs, docs/implement_mealplanning/04-entitlement.md

- [x] Lee has said go in the terminal before anything is created. (Lee, "ok go prod", 2026-09-23)
- [x] `asc.mjs list` and `play.mjs list` against production show the four products, prices and free week. (`--prod`, 2026-09-23)
- [x] RevenueCat lists the production products on `pro` and in both offerings.
- [x] The ids and states are recorded in docs/implement_mealplanning/04-entitlement.md.

Next: /implement-lee paywall
