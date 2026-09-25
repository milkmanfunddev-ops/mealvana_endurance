# 33: Sign-out clears the last account from the device

**Status:** in-progress (wave 19, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** Signing out, or signing in as a different account, leaves nothing of the previous account on the phone. The local Drift rows of the old account are cleared (plans, logs, activities, events, integrations, preferences), the RevenueCat SDK is logged out (`Purchases.logOut`, which the app never calls today), and the entitlement cache is cleared without the "Ref used after dispose" failure. Onboarding's integration prefill never offers or saves another account's name or email, and it no longer changes a provider during build.

**Findings:** 02-001, 02-002, 14-004, 14-003, 03-002, 02-003, 32-002 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/settings/presentation/providers/settings_controller.dart, lib/features/onboarding/presentation/screens/personal_info_screen.dart, lib/features/onboarding/presentation/providers/onboarding_controller.dart, lib/features/ai_credits/data/revenuecat_service.dart, lib/features/subscription/application/subscription_status_provider.dart, lib/shared/database/app_database.dart

- [x] After sign-out the local database holds no row of the signed-out account (a seam test through the real sign-out path).
- [x] After sign-out the RevenueCat SDK is anonymous: no `customer info updated {active: true}` line on Welcome.
- [x] Sign-out logs no "Pro entitlement clear failed".
- [ ] A new account right after another account's sign-out never logs `active: true` before its own RevenueCat login.
- [x] Onboarding on a phone that held another account's TrainingPeaks connection pre-fills nothing from it, and `public.users.email` equals the signup address.
- [x] No Riverpod "modify a provider while building" assertion on Personal Info.
- [x] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
