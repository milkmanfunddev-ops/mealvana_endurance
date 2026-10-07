# 02-011 · Describe with the software keyboard up: is Analyze reachable

- kind: followup-test
- status: triaged
- ticket: 02
- run: w1-20261007T1103Z
- screen: Log a Meal (Describe tab)
- decision: 

**Steps.**
1. Turn the simulator's hardware keyboard off (I/O → Keyboard → Connect Hardware Keyboard off) so the iOS keyboard shows.
2. Tap "What did you eat?", type a long description, and try to reach Analyze without dismissing the keyboard.

**Expected.**
Analyze stays reachable (scrolls above the keyboard) or the keyboard has a Done that keeps the text.

**Actual.**


**Evidence.**
- runs/02/07-describe-typed.png — this run typed with the hardware keyboard, so no on-screen keyboard showed
- Old Finding: mealplanning-2026-09 23-001 (keyboard covers the Analyze button), not re-checked in this run

**Decision quote.**
> 

**Triage.**
retest ticket 31 (retest: meal logging), wave 3 (Lee: all 27 followups into four retest tickets)
