# 47: The sign-out and delete dialogs say the right thing

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** mp-508: the sign-out dialog says the athlete will need to sign in again to use the app; nothing mentions a guest. The Settings delete-account confirm uses the same content-system strings as the paywall's. No hardcoded user-facing strings remain in either dialog.

**Findings:** 31-001, 06-003, 02-006 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** mp-508

**Touches:** lib/features/settings/presentation/screens/settings_screen.dart, lib/features/content/domain/content_keys.dart

- [ ] Widget test: the sign-out dialog text comes from the content system and has no "guest".
- [ ] Both delete confirms read the same.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
