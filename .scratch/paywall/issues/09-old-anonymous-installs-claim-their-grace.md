# 09: Old anonymous installs claim their grace

**Status:** in-progress (wave 3, 2026-09-22)
**Blocked by:** 06 (touches supabase/functions/_shared/grace), 08 (touches lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart).
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** An install still anonymous from before the flip opens the new build, lands on the account screen, signs up onto its old user so the data stays, and gets the same 30 days, once.

**Decisions:** mp-455, mp-417; approved as mp-488.

**Touches:** supabase/functions/grace-claim, supabase/functions/_shared/grace, lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart, lib/features/auth/application

- [ ] The claim grants only to an anonymous user created before the flip with no grant (handler test).
- [ ] Sign-up links onto the old user and keeps its data (seam test).
- [ ] Checked on the dev simulator with an old anonymous session.

Next: /implement-lee paywall
