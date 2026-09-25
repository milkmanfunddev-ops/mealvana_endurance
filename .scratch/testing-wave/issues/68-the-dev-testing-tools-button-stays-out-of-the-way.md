# 68: The dev testing-tools button stays out of the way

**Status:** in-progress (wave 22, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** The dev "Open testing tools" button no longer sits on Ask Vana, Vana's Send or a sheet's main button. It stays visible on dev (no hide flag, CLAUDE.md); move it where no control lives, or let it be dragged.

**Findings:** 12-002 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/shared/widgets/root_app_widget.dart

- [ ] A widget test: the button's rect does not overlap Ask Vana's.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
