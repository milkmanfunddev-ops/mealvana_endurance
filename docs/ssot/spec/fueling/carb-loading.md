# SSOT — Carb Loading (protocol math + the pace ramp)

**Status: RATIFIED v1 (Xuan, 2026-09-24, ruling interview — full decision log in the batch
commit; list read back and confirmed verbatim).** Drafted the same day from app-38's release-1
package; the interview amended the proposal in five places (slot schedule, dead-band form, 1-Day
protocol, copy rule, breakdown-page scope) — every amendment is stamped inline below.
**Sources:** app `feature/carb-loading` `.scratch/carb-loading/spec.md`; audit
`docs/kyle/carb-loading-audit-2026-09-19/`; prototype Claude Design project
`1844f744-5700-4662-a9d4-fa71a29af87d` "Fuel Timeline.dc.html" — **extraction target v17**
(v16 added the breakdown page, v17 its protocol-chip navigation; app spec commits `c7fb742b`,
`c4f8e6e5`). 2026-09-21 Xuan+Lee sync (ops/outputs/transcripts/2026-09-21T141554Z, S7/S9).
Every §1 claim verified against app code 2026-09-24 (file:line inline).
**Scope:** the numbers — protocol generation, day/slot targets, the intraday pace ramp, display
bands, copy register, completion. The design set (LOAD face anatomy, slot cards, slot page,
breakdown page) is the design SSOT's, extracted from prototype v17; amendments to ratified
design files: `macro-dashboard.md` S-5 and `energy-card.md` v2 (folded 2026-09-24), glow
materials still at the desk. Data-store rulings are recorded in §4 as context.
**Known cross-slice gap (OPEN, filed not ruled):** loading-day carb target vs the daily-macros
engine's Formula 8 — `intake/2026-09-24-carb-loading-daily-macros-collision.md`. Until ruled,
THIS spec owns the loading-day dashboard number and `daily-macros` owns the meal-page number;
the contradiction is registered, not resolved.

## §1 — Protocol math — RULED (Xuan, 2026-09-24, interview Q-CL2/Q-CL3): adopt + one addition

Shipping code adopted as ratified design choices ("Adopt as is"); re-verified at source, not from
the audit. **The 1-Day protocol is a ratified ADDITION (does not exist in code yet — app-side
gate G3):** rate 11.0 g·kg⁻¹, the middle of the ACSM 10–12 band ("11 is the middle of the 10-12
acsm standards").

- **CL-1 — Weight.** `kg = lb × 0.453592` (`carb_loading_repository.dart:345`).
- **CL-2 — Protocol day rates** (existing two verified at `carb_loading_repository.dart:827-849`):

  | Protocol | Day −3 | Day −2 | Day −1 | Status |
  |---|---|---|---|---|
  | 3-Day Classic | 8.0 | 8.0 | 10.0 g·kg⁻¹ | shipping, adopted |
  | 2-Day Quick | — | 9.0 | 11.0 g·kg⁻¹ | shipping, adopted |
  | 1-Day | — | — | 11.0 g·kg⁻¹ | **RULED addition** — chooser card + generator branch are app work |

  The generator's blanket 8.0 fallback for unknown `protocolDays` stays out of contract: with the
  1-Day added, every reachable protocol is enumerated; the fallback is defensive code only.
- **CL-3 — Day target.** `day_target_g = round(rate × kg)`.
- **CL-4 — Meal split.** Six slots at **25 / 10 / 25 / 15 / 20 / 5 %** (Drift schema defaults,
  `carb_loading_days_table.dart:32-44`). `slot_target_g = round(split_i × day_target_g)`.
- **CL-4a — Editable day target — RULED (Q-CL10, "both yes").** An edited day re-derives slots,
  checkpoints, ramp, bar and copy from the **stored** `carbTargetGrams`; rate copy shows the
  stored per-day rate (the engine's number), never the protocol constant.
- **CL-12 — Rate copy — RULED (Q-CL4/Q-CL5, "Option one").** All protocol and help copy states
  **point values** — the actual per-day rates above — never ranges. Retires: the 2-Day card's
  "8–10 / 10–12", the protocol card's "7–9", the Edit Target help's "8-12g/kg".

**Observed but NOT canonized** (logged deviations): plan-level cross-day average → **D-019**;
writer-less `logged_carbs_grams`/`completed` → **D-020**; mapper's percent-scale split fallback
→ **D-021** (app-side fix gated in the handback).

## §2 — The pace ramp — RULED (Xuan, 2026-09-24, interview)

- **CL-5 — Slot schedule — RE-RULED at interview (supersedes the package's 7:30-anchored
  defaults):** a 3-hour grid, device-local — Breakfast **6:00** · Morning Snack **9:00** ·
  Lunch **12:00** · Afternoon Snack **15:00** · Dinner **18:00** · Evening Snack **21:00**;
  the last window closes **22:00** (kept, un-objected). A slot's grams accrue across its eating
  window (its time → the next slot's time); the same "superseded" clock drives the slot cards —
  one clock, two surfaces. Times are **fixed ruled values in release-1**; user-configurable
  times are future work (Q-CL9 confirm).
- **CL-6 — Owed — basis re-challenged and RE-RULED: Option A stands (D8 upheld).** `owed(t)` is
  piecewise-linear through checkpoints at the slot times. **Anchor arithmetic — RULED Option R
  (Xuan, 2026-09-24, vector-emission addendum; Q-CL11):** the anchor at slot *i*'s time is the
  **running sum of the rounded slot targets** of the slots before it (so the ramp and the six
  cards are one arithmetic — the tick is verifiable by adding the cards), with the **22:00
  anchor forced to `day_target`** (companion rule: an edited day target can make the rounded
  slots sum to ±2 g off; only the last window's slope absorbs it). `owed = 0` before 6:00.
  Never a step; and per the interview, **never a flat uniform fill** (rejected a second time
  after the 8:00/16:10 comparison). Display rounds to whole grams; the interpolation itself is
  exact. *(Supersedes this file's earlier exact-fraction sentence, which failed worked examples
  W6–W8 — caught by the vector oracle; the rounded-anchor reading passes all ten.)*
- **CL-7 — Pace delta and band — RULED (Q-CL1): the dead-band is RELATIVE.**
  `delta = owed(t) − eaten` · `band(t) = max(0.05 × owed(t), 10 g)` ("±5% of that specific
  time" + "floor of 10g"). `delta > band` → behind · `delta < −band` → ahead · else On pace.
  N = round(|delta|), whole grams.
- **CL-8 — Completion.** `eaten ≥ day_target` → label CARB LOAD → LOADED.
- **CL-9 — Loader bar.** `fill = min(eaten/day_target, 1)`; tick at `owed/day_target`; tick
  hidden when `owed = 0` or complete.
- **CL-10 — Time.** Device-local minutes only; no timezone logic (Lee objection #3 concession).
- **CL-11 — Eaten — RULED (Q-CL8, "All-day logs").** ALL carbs logged on the loading day count,
  slot-tagged or not; slot cards may sum to less than the face's eaten, by design.

### §2a — Copy register — RULED (amendment d, "adopt verbatim"; prototype v17 is the rendering)
| String | Trigger |
|---|---|
| `N g behind pace` | delta > band(t) |
| `N g ahead of pace` | delta < −band(t) |
| `On pace` | \|delta\| ≤ band(t) |
| `<target> g / planned` | future-day face |
| `LOADED` + `N of N g` | eaten ≥ day target (label flip + sub-line) |
| `N g to go` | expanded face headline while eaten < day_target — RULED addition (Q-D9) |
| `Target met` | replaces the to-go figure on completion (eaten ≥ day_target) — RULED amendment (Xuan, 2026-09-25 morning interview; restores v21’s organic string into the register) |
| `pace N g by now` | expanded face pace anchor; N = round(owed(t)) — RULED addition (Q-D9) |
Point-value protocol copy rows ride CL-12. The design surface spec extracted from v17 mirrors
this register; drift between them is a conformance failure, not a fork.

### Day variants
- **Today:** everything above. **Future:** clock-free — "<target> g / planned", empty track, no
  tick, no pace copy, header-only cards at that day's own targets; `owed(t)` undefined.
  **Past:** outcome — final grams "of <target> g", fill without tick, summaries only.
- **Breakdown page (v16/v17):** read-only overlay; protocol chips navigate protocol days
  (ruled by Xuan with app-38, 2026-09-24); back chevron restores the origin day.

## §3 — Research basis (unchanged from the proposal; verified pre-ratification)

Rates: Bergström & Hultman 1966 (supercompensation); Sherman et al. 1981 (3-day taper loads
fully); Bussau et al. 2002 (one day at 10 g·kg⁻¹ suffices — the 1-Day protocol's evidence);
Burke 2011 / ACSM-AND-DC 2016 / IOC 2017 (10–12 g·kg⁻¹ per 24 h for 36–48 h). The Classic's
8.0 on days −3/−2 sits below the contemporary band — flagged at interview, **adopted knowingly**
(Q-CL2). The ramp, split, slot grid, relative band and 22:00 close are Mealvana design choices;
no literature doses intraday loading pace (§5's contested-mechanic record applies).

## §4 — Data contract (ruled 2026-09-21 S9 + 2026-09-24)

One store: shared meal library + `is_carb_loading` + per-slot suitability (old `meal_types`
migrate). Log Path A, D4 = YES: slot logs are ordinary food-log entries tagged to a slot,
counting toward daily calories. `carb_loading_day_meals` gets no new writers.
`carb_loading_plans/days` rows remain (targets, split, protocol). The daily-macros coupling is
the OPEN collision filed in the header.

## §5 — Honesty line

The pace mechanic ships over Lee's standing S7 objection (2026-09-21, never withdrawn),
deliberately, to learn (Rachel Mitchell, N = 1). Planning-mode objection answered by the
future/past variants; timezone objection by CL-10. His minimal pole stays on record.

## §6 — Release-1 exclusions — AMENDED at interview

Excluded: the sparkle/suggest button (no function behind it; the six-slot scaffold is
loading-day-driven and sparkle-independent — Q-CL7 confirm) · the "Today's Fuel" insight box ·
recommendation prioritization (fixed curation) · overlapping-loads behavior ·
**reminder-to-start** (named per Q-CE6, 2026-09-24 — belongs to the fuel-CTA notifications
workstream, consuming the plan's `startDate` seam later; `carb-loading-entryway.md` CE-6).
**Removed from the exclusion list (Q-CL6, "close at this refactoring"):** the read-only
breakdown page — now IN scope, built in prototype v16/v17; E2 on the LOAD face routes to it.

## §7 — Worked examples (regenerated for the ruled schedule; the oracle checks these)

Athlete 149.9 lb → 67.99 kg. Day targets: Classic **544/544/680 g**; Quick **612/748 g**
(9, 11 × 67.99); 1-Day **748 g**. Day-1 slots: **136/54/136/82/109/27**; day-3:
**170/68/170/102/136/34**; 1-Day: **187/75/187/112/150/37**. Day-1 checkpoints:
0 @ 6:00 · 136 @ 9:00 · 190 @ 12:00 · 326 @ 15:00 · 408 @ 18:00 · 517 @ 21:00 · 544 @ 22:00.

| # | t | eaten | owed(t) | band(t) | delta | display |
|---|---|---|---|---|---|---|
| W1 | 05:30 | 0 | 0 | 10 (floor) | 0 | On pace, tick hidden |
| W2 | 08:00 | 0 | 136 × 120/180 = 90.7 | 10 | 90.7 | "91 g behind pace" |
| W3 | 09:00 | 126 | 136 | max(6.8, 10) = 10 | 10 | On pace (boundary: not > band) |
| W4 | 09:00 | 125 | 136 | 10 | 11 | "11 g behind pace" |
| W5 | 09:00 | 152 | 136 | 10 | −16 | "16 g ahead of pace" |
| W6 | 13:30 | 100 | 190 + 136 × 90/180 = 258 | max(12.9, 10) = 12.9 | 158 | "158 g behind pace" |
| W7 | 21:00 | 491 | 517 | max(25.85, 10) = 25.85 | 26 | "26 g behind pace" (just outside — the relative band earning its keep) |
| W8 | 21:00 | 492 | 517 | 25.85 | 25 | On pace |
| W9 | any | 544 | — | — | — | LOADED, full bar, tick hidden, "544 of 544 g" |
| W10 | 15:00, viewed day = tomorrow | — | undefined | — | — | "680 g / planned", no tick, no pace copy |

W7 matches app-38's independently-computed v16 scenario readout — two implementations of the
ruled math agreeing is the point of this table.

## §8 — Question register (all interview items closed 2026-09-24; venue noted)

| Q | Disposition |
|---|---|
| Q-CL1 | **RULED** — relative band `max(5% owed, 10 g)` (CL-7) |
| Q-CL2 | **RULED** — adopt rates as-is, literature flag recorded (§1, §3) |
| Q-CL3 | **RULED** — 1-Day protocol added @ 11.0 g·kg⁻¹ (CL-2; app gate G3) |
| Q-CL4 | **RULED** — point-value copy (CL-12) |
| Q-CL5 | **RULED** — same ruling retires both contradictory strings (CL-12) |
| Q-CL6 | **RULED** — breakdown page INTO release-1; E2 routes to it (§6; v16/v17) |
| Q-CL7 | **CONFIRMED** — scaffold loading-day-driven; sparkle stays excluded (§6) |
| Q-CL8 | **RULED** — eaten = all-day logs (CL-11) |
| Q-CL9 | **CONFIRMED** — fixed slot times in release-1; configurability future (CL-5) |
| Q-CL10 | **RULED** — edited target drives everything; copy shows stored rate (CL-4a) |
| Q-CL11 | **RULED 2026-09-24 (addendum)** — ramp anchors = Option R: running sum of rounded slot targets, 22:00 anchor forced to day target (CL-6); exact-fraction reading rejected (flipped W7's verdict) |
| — | **OPEN elsewhere:** glow materials + D7 electrolyte-vs-orange → ruling desk (A/B on the v17 face); daily-macros collision → `intake/2026-09-24-carb-loading-daily-macros-collision.md` |
