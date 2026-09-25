# 82: Disconnect Kroger asks first

**Status:** in-progress (wave 24, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** Disconnect on Shop with Kroger asks for confirmation before it removes the connection (21-010), like the other connected apps' disconnect.

**Findings:** 21-010 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/kroger/presentation/kroger_screen.dart, lib/features/kroger/application/kroger_controller.dart

- [ ] A widget test: Disconnect opens a confirm; Cancel keeps the connection; confirm disconnects through the real controller.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
