# 40: Onboarding keeps the carb target edited on the plan reveal

**Status:** ready-for-agent
**Blocked by:** 33 (touches lib/features/onboarding/presentation/providers/onboarding_controller.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A long-run carb target the athlete edits on the plan reveal reaches `users.nutrition_target_overrides` after email signup, with the rest of the onboarding profile.

**Findings:** 03-009 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/onboarding/presentation/screens/plan_reveal_screen.dart, lib/features/onboarding/presentation/providers/onboarding_controller.dart, lib/features/auth/data/user_repository.dart

- [ ] A seam test through the real onboarding notifier: an edited target is in the uploaded profile.
- [ ] On dev, a new account's `nutrition_target_overrides` holds the edited value.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
