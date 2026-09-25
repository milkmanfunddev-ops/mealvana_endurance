# 60: Browse search matches the meal, not its research note

**Status:** in-progress (wave 22, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Browse search matches a meal's name and ingredients only: "salmon" returns meals with salmon in them, never a meal whose research note mentions salmon. The research note is not shown as a result's subtitle (show the ingredients or nothing).

**Findings:** 18-004 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** supabase/functions/_shared/vana/meals.ts, lib/features/meal_planning/presentation/widgets/meal_catalog_browser.dart

- [x] A deno test: "salmon" returns only meals whose name or ingredients contain salmon.
- [x] A widget test: a flat result's subtitle is not the research note.
- [ ] Deployed to dev.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
