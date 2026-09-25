# 56: Kroger: the right location reason, the app's own name, and no 400 on every Shopping open

**Status:** in-progress (wave 19, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The location prompt's reason covers what the app uses location for (weather and the Kroger delivery area), not weather only. The system sign-in alert names the app by its display name (`CFBundleName` set to it). Opening the Shopping tab no longer sends a `kroger` request that answers 400: find the call and its reason, then fix the request or stop sending it.

**Findings:** 21-002, 21-003, 20-008 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** ios/Runner/Info.plist, lib/features/kroger/application/kroger_controller.dart, supabase/functions/kroger/index.ts

- [x] Info.plist strings checked in the diff.
- [ ] Opening Shopping on dev leaves no 400 in the `kroger` edge log.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
