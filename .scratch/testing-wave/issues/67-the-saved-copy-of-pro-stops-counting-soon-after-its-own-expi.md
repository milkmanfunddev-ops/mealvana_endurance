# 67: The saved copy of Pro stops counting soon after its own expiry

**Status:** in-progress (wave 22, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** On a phone the Gate reads RevenueCat's saved copy (mp-335). A saved copy whose own `expires_at` has passed keeps the Gate open for the same 15-minute renewal grace the server uses (`RENEWAL_GRACE_MS`, wave 19), then counts as closed until a fresh answer arrives. A fresh answer always wins.

**Findings:** 07-002 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** mp-335, and the ruling on mp-666 (Lee, 2026-09-25): the saved copy counts for 15 minutes past its own expiry, then not.

**Touches:** lib/features/subscription/data/subscription_service.dart, lib/features/subscription/domain/entitlement.dart, lib/features/subscription/application/subscription_status_provider.dart

- [x] Tests: a saved copy 2 minutes past expiry is open; 16 minutes past is closed; a fresh active answer reopens it.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
