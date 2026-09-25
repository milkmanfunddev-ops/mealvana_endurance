# 44: The barcode scanner keeps its caller and survives the camera prompt

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The `/barcode-scanner` route passes the caller's context, so a scan from Log a Meal or Build a Meal goes back to meal logging, not to the nutrition plan's food page. Granting camera access on first open does not leave the package's raw "already running" error: the resumed start waits for the first one, and the scanner has an error builder with plain words.

**Findings:** 28-002, 28-001 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/shared/core/app_router.dart, lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart

- [ ] A router test: `barcode_scanner_opened` logs the caller's context from meal logging.
- [ ] A widget test: a second start during the first shows no raw controller error.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
