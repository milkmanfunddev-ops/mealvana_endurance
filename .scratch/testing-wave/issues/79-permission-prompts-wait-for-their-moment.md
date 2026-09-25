# 79: Permission prompts wait for their moment

**Status:** done (wave 24, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A fresh install never asks for notification permission before the Welcome screen: the prompt comes after sign-in, at the existing in-app moment (Finding 31-010 saw it on the second launch). Opening a Vana chat never asks for Speech Recognition: the mic button asks the first time it is tapped.

**Findings:** 03-004, 09-004 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/shared/services/notification_service.dart, lib/features/meal_planning/presentation/widgets/vana_mic_button.dart

- [x] A test: startup and the Welcome screen make no notification permission request.
- [x] A widget test: building the mic button makes no speech permission request; the first tap does.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
