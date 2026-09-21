# 01: Granted access reaches the server

**Status:** in-progress (wave 1, 2026-09-21)
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** A dev account given `pro` by hand in RevenueCat can call Vana: the webhook takes every `pro` event, including a promotional `NON_RENEWING_PURCHASE`, asks RevenueCat for the customer's current `pro` expiry and writes that as active until. A trial started during a live grant keeps the grant's end. The fallback product list knows the eight new ids, and the function's environment on dev holds the RevenueCat secret key.

**Decisions:** mp-454, mp-452, mp-317, mp-285; approved as mp-480.

**Touches:** supabase/functions/revenuecat-webhook/handler.ts, supabase/functions/revenuecat-webhook/entitlements.ts, supabase/functions/revenuecat-webhook/index.test.ts, supabase/functions/_shared/revenuecat

- [ ] A promotional grant event opens the row to the grant's end (handler test with a fake REST client).
- [ ] A trial started during a live grant leaves the row at the later end; a lapsed trial leaves a live grant open.
- [ ] The eight `me_pro_*` ids are in the fallback list.
- [ ] `REVENUECAT_SECRET_KEY` is set on the dev project and the function is deployed to dev.
- [ ] A hand grant on a dev account in RevenueCat shows up in its row.
- [ ] `_shared/revenuecat` holds the one REST client: current `pro` expiry, grant `pro` for N days, set subscriber attributes (tested with a fake fetch).

Next: /implement-lee paywall
