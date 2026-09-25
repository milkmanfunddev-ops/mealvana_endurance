# 37: Shopping quantities come out in what the athlete buys

**Status:** done (wave 19, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A library ingredient given as a cooked weight ("Cooked short-grain rice 200 g") is either converted to its dry weight with a stated yield factor or keeps "cooked" in its name, so the list never asks for three times the rice. The Kroger screen shows each row's need in the same units as the Shopping tab (imperial unless Settings says metric).

**Findings:** 18-006, 22-003 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** supabase/functions/_shared/vana/grocery.ts, lib/features/kroger/presentation/kroger_screen.dart

- [x] A deno test: 8 servings of cooked short-grain rice at 200 g gives the dry amount (or a "cooked" row), never 1.6 kg of plain rice.
- [x] The Kroger screen and the Shopping tab show the same row in the same units (widget test).
- [x] Deployed to dev.
- [x] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
