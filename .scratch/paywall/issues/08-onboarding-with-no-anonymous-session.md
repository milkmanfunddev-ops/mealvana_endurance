# 08: Onboarding with no anonymous session

**Status:** done (wave 1, 2026-09-21)
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee paywall`
**Model:** fable

**What to build:** A new install goes through onboarding with no anonymous session: answers wait on the phone, the account is made, the answers are written to it, and the paywall follows. The anonymous-session code is archived except the link for old installs.

**Decisions:** mp-459, mp-417; approved as mp-487.

**Touches:** lib/features/onboarding/presentation/screens/welcome_screen.dart, lib/features/onboarding/application/onboarding_service.dart, lib/features/onboarding/presentation/providers/onboarding_controller.dart, lib/features/auth/application, lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart, lib/features/settings/presentation/providers/settings_controller.dart, test/features/onboarding

- [x] A fresh install starts no anonymous session (test through the real onboarding controller).
- [x] Answers given before sign-up are on the account after it (seam test).
- [x] The removed anonymous paths are moved to an archive, not deleted.
- [x] Walked on the dev simulator from a fresh install to the paywall.

Next: /implement-lee paywall
