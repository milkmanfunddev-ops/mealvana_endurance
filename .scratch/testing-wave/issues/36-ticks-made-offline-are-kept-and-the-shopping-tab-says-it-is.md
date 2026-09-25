# 36: Ticks made offline are kept, and the Shopping tab says it is offline

**Status:** in-progress (wave 19, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** A box ticked with no network is written locally first with upload-state tracking (CLAUDE.md offline-first) and sent when the network returns; it survives a restart. A failed write shows a `MealvanaSnackbar` instead of rolling back in silence. The offline copy says it is offline and hides or disables Shop with Kroger and Share while it cannot act.

**Findings:** 20-001, 20-002 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/meal_planning/application/shopping_list_controller.dart, lib/features/meal_planning/presentation/screens/shopping_tab.dart, lib/features/meal_planning/presentation/widgets/shopping_list.dart

- [x] A tick made offline shows ticked after a restart and reaches `shopping_items.checked` once online (seam test through the real notifier with the transport failing).
- [x] The offline copy carries a visible offline notice.
- [x] A write that fails for good tells the athlete.
- [x] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
