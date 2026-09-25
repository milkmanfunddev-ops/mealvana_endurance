# 84: Shopping lists read clearly

**Status:** in-progress (wave 24, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Grains such as Farro and Spelt, and Mixed vegetables, land in their aisles, not Other; a plan's list is named in words ("Week of Sep 20"), not an ISO date (16-007). Previous lists tells the confirmed plan's list apart from archived drafts' lists (19-005), for example a "This week's plan" label on it.

**Findings:** 16-007, 19-005 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** supabase/functions/_shared/vana/ (the shopping list builder and its category map), lib/features/meal_planning/presentation/widgets/ (the Previous lists sheet)

- [x] A deno test: Farro, Spelt and Mixed vegetables get their aisles; a new list's name reads "Week of Sep 20".
- [x] A widget test: Previous lists marks the confirmed plan's list.
- [ ] Deployed to dev.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
