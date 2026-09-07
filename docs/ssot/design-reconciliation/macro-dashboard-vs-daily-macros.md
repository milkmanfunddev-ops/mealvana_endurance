# Design ⇄ Spec Reconciliation — macro-dashboard prototype vs daily-macros SSOT

**Status: FINDINGS (2026-08-13) — nothing here is a ruling.** Dispositions marked *ruling-needed*
belong to Xuan. Design: `prototypes/macro-dashboard/index.html` (walked in-browser, all stateful
controls exercised). Specs: `qa/spec/daily-macros/` (post-rulings of 2026-08-13), plus the
pre-workout and during-workout SSOTs where the design touches them.

**Method note.** Every number on every screen was extracted and re-derived against the spec
pipeline — for **identification**, not grading. Per Xuan's correction (2026-08-13): mock-value
accuracy does not matter, because implementation takes accuracy from the spec; what matters is
whether each displayed quantity **is documented**. Classes: `TRACED` (quantity maps to a documented
field/formula), `DESIGN-FIX` (format-level: copy contradicts spec or itself; layout implies a
structure the spec contradicts), `SPEC-ADD` (displayed quantity no spec documents — the
highest-value class), `RULING-NEEDED` (intent must be decided), `MOCK-NOTE` (value sloppy, quantity
documented — **non-blocking appendix**).

**Revision (2026-08-13):** the first draft graded mock values and logged 9 DESIGN-FIX items; seven
were value-accuracy findings and are reclassified to the appendix. Finding numbers are kept stable.

---

## 1 · TRACED — displayed quantities that map to documented spec fields

| # | Design surface | Spec anchor | Verification |
|---|---|---|---|
| A1 | "Where the burn comes from": Resting / Workout / Daily movement / Digestion / Total | `README` output: `rmr / session_kcal / neat_kcal / tef_kcal / tdee` | The modal is the SSOT output object rendered. Rows sum exactly: 682+428+188+162 = 1,460; 1,091+930+300+252 = 2,573 |
| A2 | Digestion 162 so-far / 252 day's-end | `neat-tef.md` TEF | 162 = 10 % of 1,620 eaten; 252 = 10 % of the 2,520 target — the TEF rate reproduced |
| A3 | Total burned 2,573 projected | `calculateTDEE` convergence, invariant I9 | (1,091+930+300)/0.9 = 2,579 asymptote; 2,573 approaches from below with Δ6 < 10 — the early-exit signature. The design's TDEE is a plausible engine output |
| A4 | Provenance chips: `verified · Garmin`, `self-reported`, `planned (estimate)`, `estimated` | `platform-resolution.md` sources enum (Q-012) | Display classes of the 7-tag enum. **Spec now needs the display mapping** — see F-13 |
| A5 | Swim "as planned · +18 vs plan" | `delta` object, retrospective recalc | The delta concept surfaced per-session |
| A6 | Carb target 300 g | `baseline-macros`: 4.0 × 75 | Exact for the 75 kg reference athlete |
| A7 | Ride banner "+90 g carbs" | `carbDemand(IF 0.75, 1.667 h, 75 kg)` | 47.5 g/hr × 1.667 × **1.15 (dur > 1.5)** = 91.0 → 90. The design applied the long-ride multiplier correctly |
| A8 | Before-Ride: Oatmeal + Banana, 65 g C · 8 g P | `pre-workout-food-composition` v3 §3.11 | The canonical meal feeding, passing H1–H3 |
| A9 | "30–60 g carbs per hour on the bike" | `during-workout-carbs` | Inside the cited range |
| A10 | Weekly "Carb periodization" chart — carbs track load | The daily-macros thesis end-to-end | Direction correct (but see F-05 on the ramp) |

The density of traced items matters: this design was clearly built *from* the math. The gaps below
are therefore drift and holes, not ignorance — exactly what reconciliation exists to catch.

## 2 · DESIGN-FIX — format-level defects (copy and structure, not values)

| # | Finding | Evidence | Fix |
|---|---|---|---|
| F-03 | **Two labelled quantities where the spec defines one.** "Target 2,520" and "projected TDEE 2,573" displayed as distinct fields; under the assembly, with fat above its floor, intake target ≡ TDEE | The *structure* implies an undocumented distinction between "target" and "TDEE". This is a format finding, not a mock-value one | Collapse to one field, or show the one state where they legitimately differ (`energy_basis = pre_override`), or get a ruling defining "target" as its own quantity |
| F-07 | **Recovery-window copy conflicts with itself:** "within 30 minutes after" (ride card, After-Ride badge) vs "refuel within the hour after" (meals AI card) | Copy ships as-is — it is not regenerated from the spec at runtime, so it is held to the accuracy bar | Pick one pending the F-16 ruling; the chosen figure then needs a literature check before ship |

## 3 · SPEC-ADD — the design exercises behaviour no spec owns

Each of these is a place an engineer will otherwise invent math.

| # | Design behaviour | What the spec must say (or explicitly defer) |
|---|---|---|
| F-10 | **Intraday proration.** "62 % of the day done", resting 682/1,091 (= 62.5 % linear), NEAT 188/300, "on pace to burn 2,573" | The SSOT computes day totals only. Needs a stated proration rule (linear-in-clock-time is what the design implies) or an explicit "display-layer arithmetic" deferral |
| F-11 | **Net energy balance** ("eaten − burned = +160, slight surplus") and its copy bands | Not an SSOT concept. If it ships, the bands ("slight surplus" vs what?) need numbers, and the interaction with `energy_basis = pre_override` (intake > TDEE **by design** on gated days) must be stated — the current copy would call a safety override a "surplus" |
| F-12 | **Planned-but-uneaten meals** ("logged + planned" rings, PLANNED chips, "900 to go") | No spec models intraday planned intake. Needs: does "remaining" mean target−logged or target−(logged+planned)? |
| F-13 | **Sources → display-class mapping.** 7-tag enum vs 4 chips | One table in `platform-resolution.md`: GARMIN→verified; MANUAL→self-reported; TP_PLANNED/TP_CALENDAR/FORMULA→planned (estimate); ZONE_DIST→?; TP_ACTUAL→verified? |
| F-14 | **Meal-level distribution.** Six named meals with per-meal macros; "spread carbs evenly and anchor each meal with protein" | Daily-macros stops at day totals. Meal-splitting is a new spec (or explicitly the food-selector's job, cross-referenced) |
| F-15 | **Daily meal suggestion / swap engine** (Chocolate Milk & Banana, Grilled Chicken & Rice Bowl, Roasted Sweet Potato; Swap/Remove/Add in fuel windows) | Food-composition v3 covers pre-workout only. The daily-meal analogue has no SSOT |
| F-16 | **Post-workout recovery window and composition** (Recovery Shake 30 g C · 20 g P, "within 30 min") | **No post-workout SSOT exists at all.** The 30-min-window claim is exactly the kind that needs the literature check before it ships as copy |
| F-17 | **Tracking-off mode** (all numbers stripped) | What is still computed vs merely hidden? Does EA safety still evaluate? Safety gate silently off is a real hazard |

## 4 · RULING-NEEDED — all four RULED (Xuan, 2026-08-13)

| # | Conflict | Ruling |
|---|---|---|
| F-18 | Multi-day carb ramp vs tomorrow-only `preLoadOverride` | **No new formula.** The weekly chart is already correct — seven independent day-computations, each with its own `tomorrow`, produce the ramp emergently. Only the Wednesday AI copy naming Saturday overreaches: scope look-ahead copy to tomorrow, or phrase multi-day mentions as schedule awareness, never fueling instruction |
| F-19 | EA safety surfaces absent | **The dashboard owns them.** SOFT info banner · HARD raised-target state with explanatory copy · BLOCK replaces the entire plan with the health warning · `energy_basis = pre_override` explains intake > TDEE. Caution from the persona runs: ordinary balanced days land EA 39–44 (SOFT), so SOFT's treatment must not train alert fatigue |
| F-20 | Sodium invisible in the ride plan | **Reclassified — never a ruling gap.** `during-workout-sodium.md` is RATIFIED with a live engine computing `sodiumRateMgph` / `sodiumTotalMg`; the quantity is fully documented (TRACED territory) and the ride plan simply fails to display it. Design wiring: during-ride items surface the ratified outputs. Pre-workout absence stays correct (deliberate null, `pre-workout-sodium.md`) |
| F-21 | Phase/mode invisible | **Show phase, hide mode.** Phase chip near the date header (athlete setting per Q-005, and the natural home for the "racing tomorrow — consider Race Week" nudge). Mode stays internal; its one user-visible consequence is already surfaced as "+18 vs plan" |

## 5 · Disposition summary

- **10 traced** — the design's quantity-vocabulary is overwhelmingly the spec's. A3 (the
  convergence early-exit reproduced in a designer's mock) and A7 (the ×1.15 multiplier applied)
  double as evidence the pipeline spec is implementable from its prose.
- **2 design fixes**, both format-level: one duplicate-quantity structure (F-03), one
  self-conflicting copy claim (F-07).
- **8 spec additions** — the highest-value class under the traceability bar: eight quantities and
  behaviours the design displays that no document owns. F-10 (proration), F-12 (planned intake) and
  F-16 (post-workout) are the ones an engineer cannot proceed without.
- **4 rulings** — F-18 (multi-day ramp) is the substantive one; it decides whether a new formula
  exists.
- **7 mock notes**, non-blocking (below).

## 6 · MOCK-NOTES appendix — value sloppiness in documented quantities (NON-BLOCKING)

Per the traceability ruling these do not gate handoff and require no design iteration. Recorded
because a coding agent may glance at the mock values; the one wholesale remedy — generating the
mock day by running the spec pipeline on a declared athlete — would clear all seven at once, and is
worth suggesting, not requiring.

| # | Note | Detail |
|---|---|---|
| F-01 | During-ride mix illustrated at 12 % (60 g/500 ml) | The *quantities* (carbs g, fluid ml) are documented; the illustrated ratio contradicts the 6–8 % during-workout standard. The engine will generate real values at runtime; a 6 % illustration would read better |
| F-02 | Macro targets 300/140/75 vs kcal target 2,520 | 4/4/9 gives 2,435 — an 85 kcal hole between mock values of documented quantities |
| F-04 | Protein 140 / fat 75 not pipeline-derivable | Reachable values are 130/138 and 84–90 |
| F-05 | Resting 1,091/day implies LBM ≈ 27 kg | Cunningham inversion; reference-athlete RMR is 1,908 |
| F-06 | Same ride costed +520 (banner) and 502 (panel) | One quantity, two mock values |
| F-08 | Two irreconcilable mock days across surfaces | Timeline 3 meals/1,162 vs modals 6 meals/1,620; pre-ride 3:45/55 g vs 2:15/65 g |
| F-09 | "~2 H BEFORE" example sits exactly on the t−120 tier boundary | An interior value (t−150, t−90) illustrates without ambiguity |

---

# Re-run — prototype revision `aa81d21` (2026-08-14)

Second pass under the traceability bar, per the skill's definition of done. **Verdict: compatible.
One defect remains.**

## TRACED — newly verified (was the old F-08 drift class)

| Check | Result |
|---|---|
| Single dataset across all surfaces | **Fixed.** Timeline, energy card and all three sheets read one day |
| Burn rows cross-foot | 1,192+229+197+165 = **1,783** ✓ · 1,907+1,434+396+415 = **4,152** ✓ |
| Logged meals cross-foot to the rings | 640+330+680 = **1,650 kcal**; 262 C / 68 P / 36 F — exact ✓ |
| One target number (F-03) | **4,152 everywhere**; 4,152 − 1,650 = 2,502 "to target" ✓ |
| Q-014 fat cap | fat 138 g = **30.0 %E** — the ruled cap, reproduced ✓ |
| Carb band | 596 g = 7.95 g/kg — inside Thomas 6–10 for the load ✓ |
| TDEE closed form | (1908+396+1434)/0.9 = 4,153 ≈ 4,152 ✓ |
| `intraday-display` §1 — BMR clock proration | 1908 × 15/24 = **1,192** ✓ |
| §1 — TEF intake-driven, not clock | 10 % × 1,650 = **165**; day-end 10 % × 4,152 = **415** ✓ |
| §1 — sessions ATOMIC | swim 229 counted; run contributes **0** until done ✓ |
| §1 — NEAT waking-window | 396 × 8/16 = 198 ≈ **197** ✓ |
| §2 — net-balance band | −133 → **"on track"** (|net| < 200) ✓ |
| §3 — remaining = target − logged | 2,502; rings show logged + planned ✓ |
| F-13 chip mapping | verified·Garmin / self-reported / planned (estimate) / estimated — all four, no others ✓ |
| Workout card states | swim = verified·Garmin; run = Planned; swipe affordance present ✓ |
| Scope discipline | no phase chip, no safety states, no sodium — as instructed ✓ |

## DESIGN-FIX — one, unchanged from the first pass

| # | Finding |
|---|---|
| **F-07** | **The retired recovery copy is still live.** Workout filter: *"…and refuel within 30 minutes after."* Meals filter: *"…then refuel within the hour after."* Both contradict `post-workout.md` (RATIFIED v1), which retires unconditional deadlines and replaces them with the two conditional branches. The "All" filter card is compliant. This was change 2 of 9 in the brief and is the only one that did not land |

## Not verifiable in this harness

Swipe gestures need touch events; mouse drag selects text instead. The affordance
("Swipe right to mark done · left to delete") renders, and the Planned state is correct, but
**swipe-right→done, swipe-left→delete, the ⋯ parity, and the undo toast remain unverified** — check
on a touch device.

## Workout-card UX findings — hands-on pass, prototype `aa81d21` (2026-08-14)

Gestures driven via synthetic pointer events (the cards listen on `pointerdown/move/up`,
`touch-action:pan-y`). All findings are DESIGN-FIX; none affect spec compatibility.

**Works, and worth keeping:**
- Swipe-right toggles done ⇄ undone reliably, and **the state propagates through the whole
  dashboard** — chip flips Planned ⇄ self-reported, net balance −133 ⇄ −1,338, banding copy follows
  ("on track" ⇄ "deficit — time to eat"). The full loop is correct.
- Swipe-left is a **partial reveal with a labeled Delete button**, not a full-swipe commit — the
  safer of the two patterns, correctly chosen for the destructive action.
- Card states read at a glance: verified = solid fill + teal `verified · Garmin`; planned = dashed
  outline + `Planned` chip.
- Discoverability effort is real: a hint line under the planned card plus a two-cycle `wkHint`
  nudge animation on load.

**Defects, highest first:**

| # | Finding |
|---|---|
| ~~W-1~~ | **CORRECTED (Xuan, 2026-08-14): working as intended.** The verified card's gesture moves visually but the mark-undone *action is inert* — it only fires on planned workouts. Residual nit, non-blocking: an affordance that reveals "Mark undone" and then does nothing may read as broken; consider suppressing the reveal (or bouncing back with a "verified by Garmin" toast) on verified cards |
| ~~W-2~~ | **ACCEPTED AS-IS (Xuan, 2026-08-14).** Two-step delete (reveal, then explicit button press) is judged sufficient protection; the clipped title is tolerated |
| **W-3** | **Delete does not complete.** Clicking the revealed Delete button leaves the card in place; the workout is never removed |
| **W-4** | **No undo anywhere** — not after mark-done, not after delete. Destructive and semi-destructive actions both need it |
| **W-5** | **Workout cards have no `⋯` menu while meal cards directly above them do.** Swipe is the only route to these actions — inconsistent, and invisible to anyone who misses the hint |
| **W-6** | **The reveal never dismisses.** The card rests at −132 px indefinitely; tapping elsewhere or scrolling does not close it |
| ~~W-7~~ | **RULED (Xuan, 2026-08-14): mark-done restamps to NOW.** Two time fields exist per workout — `planned_time` (immutable by the gesture) and `actual_time` (written by Garmin sync **or** by mark-done = current time; **cleared** by mark-undone, after which the card shows the planned time again). Data-model consequence folded into `platform-resolution.md`; Supabase carries both columns. **SUPERSEDED 2026-08-18 (Q-D7 / Q-018, ratified, `@v3`): mark-done writes `actual_time = planned_time`, not now — the confirmation says it happened as planned; not offered on a future day. `= now` remains the `@v1`/`@v2` contract only** |
| **W-8** | **The energy card collapses on every state change** — expanded state is not preserved across a swipe |
| ~~W-9~~ | **ACCEPTED (Xuan, 2026-08-14, = Q-D2 ruling):** the current `dragonfruit` delete weight is the contract as-is; open to future iteration, not a defect |
| **W-10** | **(prototype @ `5a22ca8`, 2026-08-17)** On the previous-day view, the second right-swipe on a recovered card lands on `scheduled`, rendering a **PLANNED card on a past day** — a state Q-D5/Q-D6 forbid. The app derives past-day unresolved as `SKIPPED`; do not encode. Guarded by `skipped_swipe_right_recovers` |
