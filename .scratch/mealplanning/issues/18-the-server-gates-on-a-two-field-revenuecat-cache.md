# 18: The server gates on a two-field RevenueCat cache

**Status:** in-progress (wave 1, 2026-09-15)
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee mealplanning`

**What to build:** A sandbox subscriber's first webhook event lands two fields on their entitlement row, and every Vana or debiting call is gated on them. The monthly and annual subscriptions get a seven-day free introductory offer on both stores through their APIs (no new product ids); the webhook writes only active until and period type and ignores an event older than the row; the server check reads those two fields and nothing app-side can grant one; the Pro gate flag and its config key are removed on the server.

**Decisions:** mp-285, mp-279, mp-266; approved as mp-296.

**Touches:** supabase/functions/revenuecat-webhook/index.ts, supabase/functions/revenuecat-webhook/entitlements.ts, supabase/functions/revenuecat-webhook/index.test.ts, supabase/functions/_shared/vana/entitlement.ts, supabase/migrations/20260916110000_user_entitlements_two_fields.sql, scripts/store

- [ ] Both stores carry a seven-day free introductory offer on the monthly and annual subscriptions, created by script and recorded in docs/implement_mealplanning.
- [ ] The webhook writes active until and period type only; an event older than the row's event time is ignored; a transfer moves the row (seam tests with fake events).
- [ ] The migration drops every other column from the entitlements table and nothing app-side can insert into it.
- [ ] requirePro reads the two fields; the Pro gate flag is gone from the server and the config key from app_config's read.
- [ ] Dev deploy of the webhook; a sandbox purchase on the dev app lands the row.

Next: /implement-lee mealplanning
