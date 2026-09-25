# 43: One AI logging call writes one row to the call log

**Status:** in-progress (wave 19, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** `analyze-meal-photo` and `describe-meal` stop inserting a second `jade_calls` row after `completeCall` has already filled the reservation row, so the weekly cost view counts each call and its tokens once.

**Findings:** 24-001 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** supabase/functions/analyze-meal-photo/index.ts, supabase/functions/describe-meal/index.ts

- [x] deno test (or a harness test) for each function: one call, one call-log row.
- [ ] Deployed to dev; one describe on dev leaves one row.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
