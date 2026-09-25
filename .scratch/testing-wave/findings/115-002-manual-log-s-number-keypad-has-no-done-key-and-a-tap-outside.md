# 115-002 · Manual log's number keypad has no Done key and a tap outside does not close it, so the fields below and Save stay hidden

- kind: followup-test
- status: open
- ticket: 115
- run: w32-20260925T2219Z
- screen: Log a Meal (Manual)
- decision: 

**Steps.**
1. Timeline > + Add Food > Manual; type a Meal name, pick Breakfast.
2. Tap Calories (kcal) and type a number: the iOS number pad opens.
3. Try to close it: tap the Time eaten label area, tap the "Log a Meal" title.
4. Try to reach Carbs, Protein, Fat and Save.

**Expected.**
A way to close the pad (a Done bar, or a tap outside), and Save reachable without guessing.

**Actual.**
Seen on the simulator 22:30-22:31Z with account B: the number pad has no Done key, and neither tap closed it. Scrolling the form up with a slow drag brought the next fields above the pad, but taps aimed at the next field while the layout moved sent two values into Calories ("321128"), which had to be retyped. Save was reached only after the pad went away on its own later. The earlier text keyboard (Meal name) also covered the fields, and typed digits went into the name (27-B-manual-form.png). Run on a device, where the tap targets are real, to see whether an athlete can close the pad and reach Save; the simulator's idb taps may be part of this.

**Evidence.**
- runs/115/27-B-manual-form.png — the keyboard over the form and stray digits in the name.
- runs/115/notes.md — the 22:30-22:31:43Z lines.

**Decision quote.**
> 

**Triage.**
