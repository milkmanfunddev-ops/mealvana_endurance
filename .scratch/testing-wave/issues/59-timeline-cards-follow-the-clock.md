# 59: Timeline cards follow the clock

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The timeline draws a meal under its own time. Two meals of the same type join one card only when the later one was eaten within 30 minutes of the card's first meal; otherwise the later meal gets its own card at its own time. Cards stay in time order, and deleting a meal never swaps two cards.

**Findings:** 27-001 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/fuel_timeline/application/day_timeline_assembler.dart, lib/features/fuel_timeline/domain/timeline_node.dart

- [ ] Assembler tests: a 3:43 PM snack after a 2:08 PM snack gets its own 3:43 PM card; a 2:20 PM snack joins the 2:08 PM card; cards are in time order before and after a delete.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
