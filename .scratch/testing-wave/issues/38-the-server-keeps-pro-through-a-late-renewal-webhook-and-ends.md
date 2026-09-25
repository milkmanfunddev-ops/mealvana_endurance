# 38: The server keeps Pro through a late renewal webhook and ends it when RevenueCat does

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** mp-457: a paying account keeps Pro on the server for as long as it pays. `isEntitled` honours a short grace past `active_until` while the row says the subscription renews, so AI and Kroger calls are not refused between a period end and a late RENEWAL webhook; the grace is one named constant. The webhook writes the entitlement's end from the event's expiration time, not from the moment the EXPIRATION event arrives (mp-609 clause 4).

**Findings:** 06-002, 09-009 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** mp-457, mp-609

**Touches:** supabase/functions/_shared/vana/entitlement.ts, supabase/functions/revenuecat-webhook/entitlements.ts, supabase/functions/revenuecat-webhook/handler.ts

- [ ] deno tests: a renewing row a minute past `active_until` is entitled; a non-renewing one is not; past the grace neither is.
- [ ] deno test: an EXPIRATION event sets `active_until` to its `expiration_at_ms`.
- [ ] Deployed to dev, per the deploy playbook.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
