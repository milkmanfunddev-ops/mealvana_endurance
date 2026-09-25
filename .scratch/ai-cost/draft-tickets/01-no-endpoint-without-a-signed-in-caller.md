# 01: No endpoint works without a signed-in caller

**Status:** ready-for-agent
**Blocked by:** none
**Next:** `/mattpocock-skills:implement 01 ai-cost`
**Model:** opus
**Due:** before 2026-10-01

**What to build:** Close the endpoints that accept a request from anyone. Check production read-only for the same three before changing anything there; production changes go in the cutover.

**Spec:** .scratch/ai-cost/spec.md
**Research:** docs/research/ai-cost-internal-audit.md findings G

**Touches:** supabase/functions/send-nutrition-plan-email/, supabase/functions/upload-all-data/, supabase/functions/parse-meal-plan (deployed on dev, no source in repo), supabase/config.toml

- [ ] `send-nutrition-plan-email` has `verify_jwt` on and checks the caller in code; an unsigned request gets 401 (test through the handler).
- [ ] `upload-all-data` is undeployed from dev and deleted, or takes the user id from the token only. Confirm nothing in `lib/` calls it first.
- [ ] `parse-meal-plan` is either undeployed from dev, or brought into the repo with `requirePro`, a credit debit, a rate limit, an input cap and a max output.
- [ ] A read-only list of production functions with their `verify_jwt` setting is recorded in this ticket, with each of the three marked present or absent.
- [ ] Every function under `supabase/functions/` that calls a model, sends mail or writes with the service role is listed with its auth check, in this ticket.

Next: /mattpocock-skills:implement 01 ai-cost

## Comments

2026-09-21, read-only production check (Lee said "you may check"). Management API function list only; no data read.
- `send-nutrition-plan-email`: live on PROD (v36) and DEV (v51), `verify_jwt=false`, and `index.ts` has no caller check at all. Called by `lib/features/sharing/application/email_service.dart` through the Supabase client, which sends the user's token, so requiring a signed-in caller breaks nothing.
- `upload-all-data`: live on PROD (v30) and DEV (v47), `verify_jwt=false`, takes `user_id` from the request body and writes with the service-role key. Nothing on `mealplanning` calls it, but released app versions may. Lock it (user id from the token, ignore the body) rather than delete it, until the oldest supported release is confirmed not to call it.
- `parse-meal-plan`: DEV only (v14, `verify_jwt=true`), not on PROD. No source in the repo.
- `verify_jwt=false` is set on 27 of 30 PROD functions. That flag alone is not a hole where the code checks the token itself; the fifth checkbox (list every function with its in-code auth check) is what settles it.
- A production deploy of the two fixes needs Lee's or Xuan's explicit go under the deploy playbook.
