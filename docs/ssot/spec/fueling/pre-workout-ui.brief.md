# Brief — pre-workout BEFORE screen: bands, numbers, display, urine check

Handoff brief for a design pass on the app's **BEFORE** card. Written to be given to a designer
together with a screenshot of the current screen and nothing else — it is self-contained on purpose.

**Source of truth:** [`pre-workout-carbs.md`](./pre-workout-carbs.md) v2,
[`pre-workout-hydration.md`](./pre-workout-hydration.md) v6,
[`pre-workout-sodium.md`](./pre-workout-sodium.md) v3 — all ratified 2026-08-03 (Xuan), plus the
PW-020 correction of the same date. Reasoning lives in [`pre-workout.notes.md`](./pre-workout.notes.md);
what is still open is in [`pre-workout.OPEN-QUESTIONS.md`](./pre-workout.OPEN-QUESTIONS.md).

A worked reference implementation of these rules is [`pre-workout-ui.html`](./pre-workout-ui.html) —
useful for checking a state, **not** a design to copy.

---

<!-- ------------------------- brief starts here ------------------------- -->

## Scope

The **BEFORE** card only. The DURING and AFTER sections are governed by separate specs not covered
by this ratification — leave them alone.

**Not in scope:** whether the displayed numbers are arithmetically correct, and which foods are
eligible for which feeding. Assume the engine hands you correct values and a valid food list.

**In scope:** what bands exist, what numbers appear, how they read, and the urine check.

---

## 1 · Which bands may exist

The screen currently shows **three** range bars. It should show **two**.

| Quantity | Band? | What it is |
|---|---|---|
| **Carbs** | **Yes** | A permissible range, much wider than the one drawn today. Inside the published window it comes from a guideline; outside it, it is Mealvana's own — and those two cases must be distinguishable. |
| **Fluid** | **Yes** | Under two hours the **floor is zero**. Over two hours it has a real floor, and a ceiling **deliberately higher than the target** because it leaves room for the urine check to add a top-up. |
| **Sodium** | **No — delete it** | No range bar, no marker, no in-range/out-of-range state, no colour change. There is no sodium target, so there is nothing for a bar to measure against. |

**No bands on the individual feeding cards.** The per-feeding tolerance is an internal constraint on
how the food engine portions. It is not a range the athlete should see or aim at. One band per
quantity, at the summary level.

---

## 2 · Which feedings exist, and when

The plan is a **sequence of feedings**, not a set of alternatives. Which ones exist is decided
entirely by **how far ahead the session was planned**.

| Planned ahead | Feedings that exist |
|---|---|
| **2 hours or more** | **Meal · Snack · Top-off** — all three |
| **30 minutes – 2 hours** | **Snack · Top-off** |
| **Under 30 minutes** | **Top-off** only |

**At two hours or more it is all three.** The snack does not drop out when a meal is present — it
carries roughly a third of the plan, and the top-off a small remainder. Someone planning three hours
ahead passes through all three feedings in sequence over the morning.

### Fluid is distributed differently from carbohydrate

This is the part most likely to be got wrong, because the two do not follow the same rule.

| Planned ahead | Where the fluid goes |
|---|---|
| 2 hours or more | Essentially **all of it sits with the meal**. The snack carries fluid *only* if the urine check comes back dark. The top-off carries **none**. |
| 30 minutes – 2 hours | **All of it sits with the snack.** |
| Under 30 minutes | **All of it sits with the top-off.** |

**Consequence: a feeding can exist and carry carbohydrate but no fluid.** That is normal and is not a
gap to fill. In particular the top-off has no fluid figure whenever a snack exists — the drink taken
there belongs to the food instruction and is counted once, elsewhere.

### Showing and hiding feedings

A feeding appears when it carries **something** — carbohydrate or fluid. It is omitted only when it
carries neither.

The edge case that catches this out: **at the start line carbohydrate is zero but fluid is not.** The
top-off still appears, carrying a drink and no food.

### Which feeding exists vs which feeding is live

Two different questions, and both need answering on screen.

- **Which exist** is fixed when the plan is created and never changes.
- **Which is live** moves with the clock: the athlete is in the meal window until two hours out, the
  snack window from two hours to thirty minutes, and the top-off in the last thirty.

An athlete who planned four hours ahead and opens the app ninety minutes before the start has three
feedings, and is standing in the second of them. Same two clocks as §5.

### Naming

The engine says what to call each feeding — do not hardcode a name per card. A large snack must be
labelled as a **light meal** rather than a snack: a "snack" larger than the meal a slightly-earlier
athlete receives is a labelling error, not a portion error.

---

## 3 · Which numbers are displayed

**Keep at the summary level:** a carbs figure, a fluid figure, a sodium figure.

**Keep on each feeding:** its own carbs figure.

**Delete:**

- The **sodium target**. What stays is only the sodium the chosen food happens to deliver — an
  observation, never compared against anything.
- The **per-feeding sodium figure**, for the same reason.
- The **fluid figure on the top-off feeding.** It currently prints `0`, and zero there is
  misleading: that drink is counted once, elsewhere.

**Three states must never look alike:**

| State | Means |
|---|---|
| A number that is **zero** | A real recommendation of none |
| **No target set** | The gated case — we decline to state one |
| **No recommendation at all** | The fasted case |

The screen currently has no way to tell these apart. It needs one.

---

## 4 · How they are displayed

**Two different quantities share each band, and both matter.** The athlete edits food and the number
moves. So the band has to show *what the food currently delivers* **and** *what we suggest*. A single
marker can only carry one of those — and it is currently carrying the one that does not change when
you add a bagel.

**The marker legitimately sits at a band edge.** At the ends of the published window the suggestion
coincides exactly with the floor or the ceiling. That is correct arithmetic and must not render as
an error or an out-of-range state.

**Fluid's floor of zero is not a failure.** Under two hours an athlete who drinks nothing is within
spec. Therefore:

- No progress ring, no `0 / N` counter, no completion state, no streak, no checkmark.
- A short fill gets **no warning of any kind**.
- **Only overshoot is worth saying anything about.** Over-drinking is the documented risk for this
  population and it presents identically to dehydration.
- Carbs may be signalled in both directions. Fluid may only be signalled in one.

**Guideline-derived and Mealvana-derived numbers must be tellable apart.** Both appear on this screen
at once, sometimes adjacent, and nothing currently distinguishes them.

**The carbs figure is a plan total across feedings, not one portion.** It must never read as a single
sitting.

**Rounding is presentational only.** The underlying values are continuous; do not let rounding
introduce a visible jump.

---

## 5 · The urine check

This does not exist on the screen and it must. **It is the only thing in the entire spec that
individualises a number** — without it, every athlete of a given body weight receives an identical
plan.

### When it appears — three conditions, all binding

1. The session was **planned two or more hours ahead**.
2. The **meal window has closed** — it is now two hours or less to the start.
3. The **snack window has not closed** — more than 30 minutes remain.

Asked earlier, the athlete has not yet drunk the thing being evaluated. Asked later, there is nowhere
for the correction to go.

> **Two different clocks.** *Planned two or more hours ahead* is frozen when the plan is created.
> *It is now two hours or less* is the current time. An athlete who planned at four hours out and
> opens the app at ninety minutes satisfies both.

### What it asks

Whether urine was pale yellow. **Four answers:** pale · dark · haven't gone yet · not sure.

- *Haven't gone yet* counts as **dark**.
- *Not sure* means **no top-up**, but must be recorded as its own answer rather than folded into
  "pale."

### A caveat that must sit beside the options

A multivitamin or B-complex turns urine yellow regardless of hydration. The bias runs toward a
**false dark** — a top-up the athlete does not need — so this caveat has to be readable at the moment
of answering, not buried behind a link.

### What it changes

The fluid **target only. The band does not move.**

This is deliberate: the band is on screen from the moment the plan is created, while the check is
answered later, so a band that shifted underneath the athlete would be worse than one with visible
headroom. **Design for the consequence — when the answer lands, one number changes and nothing else
moves.**

### How it must not appear

Not a push notification, not a banner, not a modal, not a scheduled interruption. It is a question
about a number the athlete is already looking at, and it should be met in passing.

### After answering

The athlete should be able to see what changed, and be able to change their answer. An answer given
without actually checking is worse than no answer.

---

## 6 · Also required, and absent

**An instruction that the fluid is to be *finished* about two hours before the start**, not sipped up
to the gun. The window is bounded at both ends; the gap exists so the body can clear what it does not
need. The screen currently says nothing about when to stop.

**Fine print shipping with the numbers.** At minimum: the plan is a starting point rather than a
prescription; there is no minimum under two hours; over-drinking is the real risk and looks exactly
like dehydration.

<!-- -------------------------- brief ends here -------------------------- -->

---

## Provenance of each requirement

For QA use, not for the designer. Every line above traces to a ratified clause.

| Brief section | Clause |
|---|---|
| Feeding membership: meal ≥120, snack ≥30, top-off always | `pre-workout-carbs.md` inv. 6; *The algorithm* |
| All three exist at ≥2 h (60 / 30 / 10 split) | `pre-workout-carbs.md` inv. 5; notes §3.6 |
| Fluid goes to the earliest window, not split | `pre-workout-hydration.md` — *Tier integration*; notes §2.6 |
| Snack carries fluid only on the dark path | `pre-workout-hydration.md` — *The algorithm*, `snackMl = topUpMl` |
| Top-off carries no fluid when a snack exists | `pre-workout-hydration.md` — *Tier integration*; notes §1.4 |
| Zero-carb feedings omitted, but fluid keeps the card | `pre-workout-carbs.md` — *At `t = 0` the plan is zero* |
| Exists vs live — two clocks | `pre-workout-hydration.md` — frozen `timeBeforeWorkoutMin`; notes §5.19 |
| Naming is engine-driven; large snack → light meal | `pre-workout-carbs.md` — `renderAs`; notes §3.8 |
| Sodium has no band, no target | `pre-workout-sodium.md` — *The rule*; *What is still produced* |
| Carbs band is the cited 1–4 g/kg, not ±12.5 % | `pre-workout-carbs.md` — *Outputs*; notes §3.4 |
| Per-feeding tolerance is not displayed | notes §5.2; `pre-workout-carbs.md` — *Two bands, two jobs* |
| Fluid floor is 0 below `T_REF` | `pre-workout-hydration.md` — *Outputs*; notes §2.3 |
| Ceiling above `T_REF` exceeds the target | `pre-workout-hydration.md` inv. 8, 8a, 8b; notes §2.4 |
| No progress ring / quota framing | `pre-workout-hydration.md` — *What `fluidMl` means* §4; notes §5.12 |
| Only overshoot is signalled | notes §5.12 |
| Marker may pin at a band edge | `pre-workout-carbs.md` — *Worked examples* |
| Zero vs null vs no-recommendation | `pre-workout-hydration.md` — *Outputs*; `pre-workout-carbs.md` §3.10; notes §3.10 |
| Cited vs design-choice must differ | `targetBasis` in all three SSOTs; notes §1.2 |
| Carbs is a plan total | `pre-workout-carbs.md` — *Tiers stack*; *`tiers` is load-bearing* |
| Rounding is presentational | notes §6 |
| Top-off carries no fluid | `pre-workout-hydration.md` — *Tier integration*; notes §1.4, §2.6 |
| Check: three conditions | `pre-workout-hydration.md` — *The urine check*, as corrected by **PW-020** |
| Check: four answers, unknown distinct | `pre-workout-hydration.md` — check table; notes §6, §5.18 |
| Riboflavin caveat beside the options | `pre-workout-hydration.md` — *Riboflavin confounds the reading*; notes §6 |
| Only the target moves on answer | `pre-workout-hydration.md` inv. 8b; notes §2.4, §6 |
| Not a push / banner / modal | notes §6 |
| Finish two hours before the start | `pre-workout-hydration.md` — *What `fluidMl` means*; notes §2.2 |
| Fine print ships with the numbers | notes §7 |

**Deliberately excluded from the brief:** food composition rules (`pre-workout-carbs.md` —
*Composition*), tier boundary values, body-weight scaling, and the 240-minute input domain. Those are
engine and food-selector concerns, and Xuan scoped this brief to bands, numbers, display and the
check on 2026-08-03.
