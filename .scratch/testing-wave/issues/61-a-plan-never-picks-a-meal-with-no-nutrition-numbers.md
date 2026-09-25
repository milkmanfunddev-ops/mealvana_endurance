# 61: A plan never picks a meal with no nutrition numbers

**Status:** in-progress (wave 22, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Vana's plan builder, Browse and the swap and same-as-last-time paths never offer or add a library meal whose kcal, carbs, protein or fat is null. The 31 dev meals that had none are being filled in separately (sourced or AI-estimated, flagged by `nutrition_origin`); this ticket is the guard so a future gap never reaches a plan.

**Findings:** 29-001 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** the ruling on mp-673 (Lee, 2026-09-25): a plan never picks a meal with no nutrition numbers, and the missing numbers get filled in.

**Touches:** supabase/functions/_shared/vana/meals.ts, supabase/functions/_shared/vana/plan.ts

- [ ] A deno test: a candidate set with a null-kcal meal never yields it, for plan build, Browse, swap and same-as-last-time.
- [ ] Deployed to dev.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
