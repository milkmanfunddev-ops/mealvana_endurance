# 65: garmin-push logs why a record failed

**Status:** in-progress (wave 22, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** The `garmin-push` edge function logs each failed record's error with its kind and the Garmin user mapping (no tokens, no personal data), so a fan-out like 18-012's "epochs processed 0, errors 45" names its cause.

**Findings:** 18-012 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** supabase/functions/garmin-push/index.ts

- [ ] A deno test: a failing record's error reaches the log with its kind.
- [ ] Deployed to dev.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
