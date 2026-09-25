# 81: Code fields fit their codes and fill themselves

**Status:** in-progress (wave 24, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** The Redeem code field takes at most 32 characters (the longest code), and an overlong code is refused as too long, not logged as `code is required`, on the app and on the server (11-003, 11-004). Every screen that takes an emailed code (Verify your email, Enter Reset Code) offers iOS/Android one-time-code autofill (32-007).

**Findings:** 11-003, 11-004, 32-007 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/subscription/presentation/widgets/redeem_code_sheet.dart, supabase/functions/redeem-code/index.ts, lib/features/auth/presentation/screens/verify_email_screen.dart, lib/features/auth/presentation/screens/ (the reset-code screen)

- [ ] A widget test: the field stops at 32 characters.
- [ ] A deno test: a 40-character code answers "too long".
- [ ] A widget test: each code field carries the one-time-code autofill hint.
- [ ] Deployed to dev (if the server changed).
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
