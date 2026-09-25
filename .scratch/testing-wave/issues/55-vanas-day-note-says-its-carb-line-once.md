# 55: Vana's day note says its carb line once

**Status:** done (wave 19, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The Plan tab's day note no longer repeats its headline around " — " ("At least 272g carbs — At least 272g carbs") and does not end with two full stops.

**Findings:** 09-002 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** supabase/functions/_shared/vana/tools.ts, lib/features/meal_planning/presentation/widgets/day_card.dart

- [x] A test on the note's assembly with a headline that the body repeats.
- [x] Deployed to dev if the fix is server-side.
- [x] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
