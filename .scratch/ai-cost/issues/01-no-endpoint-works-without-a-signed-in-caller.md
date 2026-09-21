# 01: No endpoint works without a signed-in caller

**Status:** in-progress (wave 1, 2026-09-21)
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee ai-cost`
**Model:** opus

**What to build:** Nobody outside the app can send a plan email or write an athlete's data. The plan-email function refuses a caller who is not signed in. The bulk upload keeps working for released app versions but writes only to the signed-in athlete's own account. The meal-plan parser on dev, which has no source in the repo, is gone. Dev only; production waits for Lee's go.

**Decisions:** mp-432; approved as mp-466.

**Touches:** supabase/functions/send-nutrition-plan-email, supabase/functions/upload-all-data, supabase/config.toml

- [ ] An unsigned request to the plan-email function gets 401 and sends nothing (test through the handler); a signed-in request still sends.
- [ ] The bulk upload takes the user id from the token and ignores any user id in the body (handler test with a body naming another user).
- [ ] `parse-meal-plan` is undeployed from dev.
- [ ] The ticket lists every function under `supabase/functions/` that calls a model, sends mail or writes with the service role, with its auth check.
- [ ] Deployed to dev. Nothing is deployed to production.

Next: /implement-lee ai-cost
