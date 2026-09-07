# Design ⇄ Spec Reconciliation — pre-workout redesign v2 vs the pre-workout SSOTs

**Status: FINDINGS (2026-08-25); R-01 and R-02 RULED by Xuan 2026-08-26, R-03 withdrawn — no open
rulings.** Nothing else here is a ruling. Design: `prototypes/pre-workout/v2.html` — the Claude Design artifact
`df67edd1-70b7-4ce6-be8a-51e793e1c46c` ("Copy of pre-workout nutrition redesign v2"), copied into
the sandbox today per `spec/design/source-authority.md` §3 (location is the state: it is a
**candidate**). Walked in-browser: all four `plannedAhead` scenarios, both layouts, all three
`targetState` values, every card expanded, every hydration-check answer and the change-answer
path, the quantity steppers driven above and below band, the `?` control.

**Specs.** The ratified pre-workout SSOTs are **carbs v2 · hydration v6 · sodium v3 · food
composition v3** (Xuan, 2026-08-03/05), plus the designer's brief `pre-workout-ui.brief.md`. **All
of these live on `qa/pre-workout-drawers` (19 commits ahead of `main`, unmerged).** `main` and this
branch still carry the v1 slices, which the design is *not* built against. Every spec anchor below
is to the drawers-branch text; the intake erratum `2026-08-25-…stale-hydration-slice` already
asks for that branch to land.

**Method note.** Same bar as the macro-dashboard pass (Xuan, 2026-08-13): **traceability, not
accuracy**. Mock values are identified, never graded. Classes: `TRACED` · `DESIGN-FIX`
(format/structure/copy) · `SPEC-ADD` · `RULING-NEEDED` · `MOCK-NOTE` (non-blocking appendix).

**Headline.** This design was built *from* the brief and it shows: the feeding structure, the fluid
distribution asymmetry, the sodium-without-a-band rule, the one-way fluid signal, the inline urine
check with four answers and the riboflavin caveat are all there and all traced. The defects are
concentrated in three places: **(1) the urine check moves the wrong quantity** (it adds delivered
water and leaves the target fixed; the spec says the opposite), **(2) the two clocks are missing**
(nothing on screen is "live", so the check is offered at t−180 where the spec forbids it), and
**(3) the three must-differ states (zero / gated / fasted) collapse to one screen** with the wrong
band hidden. Nothing here needs a new number from the spec — every fix traces to a ratified clause.

---

## 1 · TRACED — displayed quantities and structures that map to documented spec fields

| # | Design surface | Spec anchor | Verification |
|---|---|---|---|
| A1 | Feedings by lead time: 3+ h → Meal · Snack · Top-off; 90 min → Snack · Top-off; 20 min / start line → Top-off only | `pre-workout-carbs.md` inv. 6 (`meal` iff t ≥ 120, `snack` iff t ≥ 30, `top_off` always) | All four scenarios match; the snack does not drop out when a meal exists (brief §2's most-likely error, avoided) |
| A2 | Per-feeding carb targets 60 / 30 / 10 g of a 100 g plan; 33 / 11 g of 44 g | carbs inv. 5: shares 0.60/0.30/0.10 with a meal, 0.75/0.25 without | Exact: 60+30+10 = 100; 33+11 = 44 → 0.75/0.25. The mock was generated from the share rule |
| A3 | Summary CARBS = plan total across feedings (89 g = 52+24+13) | carbs *Tiers stack*; *`tiers` is load-bearing* | Sums exactly; never presented as one sitting |
| A4 | Fluid sits with the meal at 3+ h (16 oz), with the snack at 90 min (12 oz), with the top-off at 20 min / start line (8 / 6 oz); **top-off carries no fluid when a snack exists** | hydration *Tier integration*; notes §1.4, §2.6 | All four scenarios correct, including the asymmetry the brief flags |
| A5 | Start line: 0 g carbs, 6 oz fluid — the top-off card is **kept** ("Water", 0g / 6oz) | carbs *At t = 0 the plan is zero*; brief §2 "showing and hiding" | The edge case the brief calls out is handled |
| A6 | Snack carries fluid **only** after a dark answer (8 oz row "added by hydration check") | hydration algorithm `snackMl = topUpMl`; correction lands in the snack window | Structure right; see F-01 for what is wrong about it |
| A7 | Sodium: a delivered figure (310 mg), **no band, no marker, no state** — summary and per-food | `pre-workout-sodium.md` *The rule*, *What is still produced*; brief §1, §3 | Exactly the "observed, not targeted" presentation. Per-food lines ("150mg sodium") are reports, not targets — consistent with the spec's "delivered sodium reported"; the brief's "delete the per-feeding sodium figure" is satisfied at the card-header level |
| A8 | Fluid band floor is **0 oz** in every sub-2 h scenario; ≥2 h floor is non-zero (12 oz) with a ceiling (26 oz) well above the target (16 oz) | hydration *Outputs* (`fluidLowMl = 0`, not null); inv. 6/8 (`high = 12·BW` above `T_REF`) | 16 oz ≈ 473 ml ⇒ BW ≈ 63 kg; 12·63 = 756 ml ≈ 25.6 oz ⇒ the 26 oz ceiling is `12·BW`. The headroom-for-the-check structure is reproduced |
| A9 | Fluid marker turns Dragonfruit **only above** the ceiling; a short fill is unsignalled (driven to 0 oz: marker stays teal) | hydration *What `fluidMl` means* §4; notes §5.12; brief §4 | `band(…, oneWay=true)` in the prototype; verified by driving water to 0 and to 32 oz |
| A10 | Carbs marker signals **both** directions (driven to 37 g under a 50 g floor: Dragonfruit) | brief §4 "carbs may be signalled in both directions" | Verified |
| A11 | Two quantities on each band: delivered (diamond) and suggested (orange triangle beneath) | brief §4 "two different quantities share each band" | The delivered marker moves with the steppers; the suggestion does not |
| A12 | Meal window copy "FINISH BY 2H OUT" | hydration *What `fluidMl` means* — "finish about two hours before you start, not sip until you start"; notes §6 | The terminal edge is stated on the meal card. **Absent from the fine print** — see F-05 |
| A13 | Window labels "2H TO 30 MIN OUT", "LAST 30 MIN", "NOW UNTIL 30 MIN OUT", "NOW UNTIL THE START" | carbs `TIER_MEAL_MIN = 120`, `TIER_TOPOFF_MAX = 30` | Boundaries match the ratified constants |
| A14 | Urine check: inline inside the snack card, four answers (pale · dark · haven't gone yet · not sure), riboflavin caveat beside the options, result visible, change-answer reverts the write | hydration *The urine check*; check table; *Riboflavin confounds*; notes §6; brief §5 | "Haven't gone yet" → treated as dark ("Treated as dark for now — update after you go") ✓; "Not sure" → recorded, no change ✓; not a modal / push / banner ✓ |
| A15 | Only the snack's fluid changes on a dark answer; band, tiers, other cards untouched | hydration inv. 8b; brief §5 "one number changes and nothing else moves" | Visually quiet, as required — but it is the *wrong* one number (F-01) |
| A16 | Hydration check absent below 2 h (90 / 20 / start-line scenarios) | hydration "`hydrationCheck` only affects output when `timeBeforeWorkoutMin >= T_REF`" | Correct on the frozen-lead-time condition; the two live-clock conditions are missing (F-02) |
| A17 | Oatmeal with banana as the meal; energy chews as the top-off | `pre-workout-food-composition.md` §3.11 canonical meal; G4b (chews) permitted in every tier | Mock foods drawn from the ratified list (RXBAR is the exception — M-06) |

The traced set covers the brief's §1, §2, §4 and most of §5. What follows is where it departs.

## 2 · DESIGN-FIX — format-level defects (structure and copy, not values)

| # | Finding | Evidence | Fix |
|---|---|---|---|
| **F-01** | **The urine check moves *delivered* fluid and leaves the *target* fixed. The spec says the reverse.** On "Dark" the prototype inserts an 8 oz water row; the summary reads 16 → 24 oz *delivered*, while the orange target marker stays at 16 oz | hydration algorithm: `fluidMl = mealMl + snackMl`, `snackMl = 4·BW` on dark — **the target rises**; *"only `fluidMl` changes on the recompute"*; brief §5 "What it changes: the fluid **target** only" | The target marker must move (+4 ml/kg, ≈ +8–9 oz at 63 kg). Auto-adding a water row is a legitimate *means* of meeting the new target and can stay — but the number the athlete is told to aim at is what changes, and the design currently changes the number they have already met instead |
| **F-02** | **No "live" state — the two clocks are missing.** Every card is drawn identically whether the athlete is at t−180 or t−45; nothing marks which window is open. Consequence: the check is offered in the meal window (t−180), which the spec forbids | hydration *The urine check* — `offerCheck` needs **all three**: planned ≥ 120 (frozen) AND `currentLeadMin ≤ 120` AND `currentLeadMin ≥ 30`; PW-020; brief §2 "which feeding exists vs which feeding is live", §5 "three conditions, all binding" | Add a `currentLeadMin` state to the prototype: highlight the live feeding; show the check only while the snack window is open; drop it (not disable it) past t−30 |
| **F-03** | **The three must-differ states collapse to one screen, and the gated state hides the wrong band.** `Gated — no target` and `Fasted session` both render the full 3-h plan with all numbers, removing only the **carbs** band. But the gate is a **fluid** rule (carbs never gates) and fasted returns **no carbs at all** (empty tiers) | hydration gate → `fluidMl: null`, `regime: "gated"`; carbs *"The spec never gates"*; carbs `isFasted` → `carbsG: 0`, `tiers: []`, `targetBasis: "none"`; brief §3 "three states must never look alike" | Gated: fluid shows *no target set* (no band, no marker, no number), carbs and feedings unchanged. Fasted: no carb figures or bands anywhere; fluid plan stands. Zero (start line): a real `0g`. Three distinct renderings |
| **F-04** | **Cited vs Mealvana-derived numbers are indistinguishable.** The carbs band at 3+ h (cited 1–4 g/kg) and at 20 min (Mealvana ±12.5 %) look identical; likewise fluid above/below 2 h | `targetBasis` in all three SSOTs (`evidenced_band` / `design_choice` / `none`); brief §1, §4 "must be tellable apart" | One visible affordance keyed on `targetBasis` — a band style, a label, or the calculation panel's opening line. The brief lists this as a hard requirement |
| **F-05** | **Fine print is absent; the `?` control is inert.** `fineOpen` toggles in state but renders nothing | notes §7 "ships with the numbers, never bare"; brief §6 "also required, and absent" — starting point not prescription; no minimum under 2 h; over-drinking looks like dehydration; finish two hours out | Render the §7 copy behind `?` (or as an asterisk panel). The "finish by 2h out" instruction is on the meal card (A12) but the *why* — voiding time — is only in the fine print |
| **F-06** | **The urine cue does not ride with the number below 2 h.** The 90 / 20 / start-line scenarios show a fluid target with no cue of any kind | hydration *What `fluidMl` means* §3 "**Any** surface showing `fluidMl` MUST show the cue with it"; notes §6 "in every tier" | Below `T_REF` the cue is advisory copy, not a question: one line ("aim for pale-yellow urine; if you're already there, you may not need any of this"). Different affordance from the ≥2 h check, same cue |
| **F-07** | **Same label, two semantics.** The card header "60g CARBS" is the tier *target* (it stays 60 when oatmeal is stepped to 0), while the summary "89g CARBS" is *delivered*. Nothing distinguishes them | claim-inventory kind 2 (relationships the layout implies); carbs *Two ranges, two jobs — do not present them alike* (same principle, one level up) | Either show delivered on the card too (delivered / target pair), or label the header as the aim. The reader currently cannot tell that the meal is 8 g under its portion |
| **F-08** | **Feeding names are hardcoded; the light-meal rule is missing.** "Pre-Workout Snack" regardless of size | carbs `LIGHT_MEAL_G_PER_KG = 1.0` (snack at or above 1 g/kg renders as *light meal*); notes §3.8; brief §2 *Naming* | Name from a threshold on the tier's grams, not per card. At t−105, 65 kg, the 85 g snack must read "Light Meal" |
| **F-09** | **Start-line carbs band "0g – 15g" is drawn.** At t = 0 the plan band is `[0, 0]` and the spec says suppress it | carbs † "the consumer MUST suppress the range rather than render `0 – 0`"; notes §3.10 | No carbs band at t = 0; the 15 g ceiling is invented |
| **F-10** | **Copy: "Was your urine pale yellow *this morning*?"** mis-times the check. The check evaluates the meal-window dose at the 2-hour mark; for a 6 pm session planned at 2 pm, "this morning" is the wrong sample | hydration *The urine check* — evaluated after the base dose is consumed, at `currentLeadMin ≤ 120`; ACSM 2007 "about 2 h before the event" | "Is your urine pale yellow now?" (or "since your meal") |
| **F-11** | **Copy: the riboflavin caveat stops short.** "don't read that as dark" tells the athlete what *not* to answer, not what to answer | hydration *Riboflavin* — "the mitigation is copy … letting the athlete self-select into **'not sure'**"; notes §6 suggested line | Append "— choose *Not sure*" |

## 3 · SPEC-ADD — the design exercises behaviour no spec owns

| # | Design behaviour | What the spec must say (or explicitly defer) |
|---|---|---|
| **F-12** | **The dark-path write is conditional on what the plan already delivers.** Three branches in the prototype: *added* (insert 8 oz water), *over* ("Your plan already covers your fluid target, so nothing was added. Don't force extra fluid."), *sports* ("Your snack already carries fluid from a sports drink, so no water was stacked on top.") | The hydration spec fixes the **target** (+4·BW, unconditional) and says the engine is stateless about intake — "the amount still to take is `fluidMl` minus that intake, floored at 0" (§*What `fluidMl` means* 2). That covers *over* once F-01 is fixed (target rises; if delivered already exceeds it, nothing to add). The **sports-drink exception has no basis anywhere**: sodium v3 says a CE drink retains no better than water (Maughan 2016), so there is no reason *not* to stack the correction on it. Needs a line in the drawer contract (notes §6): the correction is added as plain water to the snack regardless of what else the snack carries, or a ruling that says otherwise |
| **F-13** | **Display units and rounding in oz.** Every fluid figure is whole fluid ounces; cups = 8 oz | notes §6 defines rounding only in ml (`round25`, `floor25`, `ceil25`) and 5 g carbs. Nothing states the display unit, the ml→oz conversion, or the oz rounding rule (the prototype rounds to 1 oz ≈ 30 ml, coarser than 25 ml). Needs: the unit rule (locale? profile setting?) and the oz analogue of `round25` — see R-01 |
| **F-14** | **User edits to a generated plan.** ± steppers on every food (step 0.5 for chews, cap 8), "+ Add Food", and the delivered figures re-total live | `generate-plan.md` governs *selection* (H1–H10) and says nothing about post-generation edits. Needs: after an edit, does the plan **re-solve** toward the range (H6 — gap-fill) or merely **report** the new delivered figure against the unchanged target? The prototype reports. Also: is the ±12.5 % tier window shown to the athlete during editing (brief §1 says no) |
| **F-15** | **"Water (cups)" as a food row with 0 carbs / 8 oz / 0 mg.** Fluid delivered through the food list, and the hydration-check row inserted with a provenance note ("added by hydration check") | `pre-workout-food-composition.md` has no water entry — its groups are foods. Either water is a first-class plan item with its own row semantics (provenance tag, removable, counted once), or fluid is tracked outside the food list. The design chose the former; the spec should say so |
| **F-16** | **Delivered totals as the summary's headline.** The large teal figure is *delivered* (89 g / 16 oz / 310 mg); the target is the small orange tick | Neither spec nor brief says which of the two quantities is the headline. The brief says both must be shown and that the delivered one must move; it does not rank them. Worth a one-line rule so the app and the drawer agree on which number the athlete "has" |

## 4 · RULING-NEEDED — R-01 and R-02 RULED (Xuan, 2026-08-26); R-03 demoted to M-08

| # | Question | Readings and what each implies |
|---|---|---|
| **R-01** | **Fluid display unit: ml or oz?** The ratified spec, notes §6 and all worked examples are in ml; the prototype and (presumably) the athlete base are US-oz | (a) **oz for display, ml in the contract** — needs F-13's conversion + rounding rule and a golden that pins e.g. 487.5 ml → 16 oz. (b) **ml everywhere** — design fix, no spec change. (c) **per-profile setting** — needs a profile field and both rounding rules. The choice decides whether `round25` is a display rule or an internal one |
| **R-02** | **Is a sports drink in the snack a reason to withhold the dark-path water?** (F-12 *sports* branch) | (a) **No** — correction is plain water on top, per hydration v6 + sodium v3's Maughan finding; the branch is deleted. (b) **Yes** — needs a new rule in the hydration spec conditioning `snackMl` on snack composition, which also breaks inv. 8b's "engine pure w.r.t. `hydrationCheck`" framing. Recommend (a) but it is a spec change either way if the branch survives |
**R-01 — RULED (Xuan, 2026-08-26): fl oz.** Display in US fluid ounces; the engine, vectors and
notes §6 stay in ml. Drawer rule, the oz analogue of `round25`: target `round(ml / 29.5735)` to the
whole ounce; range `[floor(low), ceil(high)]` in whole ounces. One golden pins the conversion
(487.5 ml → 16 oz; 756 ml → 26 oz). "Cups" remains a food-row unit only. No per-profile toggle.
→ F-13 is now a drafting task against notes §6, not an open spec question.

**R-02 — RULED (Xuan, 2026-08-26): delete.** The *sports* path in the prototype's dark-answer
handler (withhold the correction when the snack carries a non-water fluid item) is removed. The
dark-path correction is plain water on top of whatever the snack holds, per hydration v6 and
sodium v3 (Maughan 2016). → F-12 reduces to the *over* case, which hydration §*What `fluidMl`
means* 2 already covers once F-01 is fixed.

**R-03 — withdrawn as a ruling.** The meal card *is* the 2–3 h window; the question was only that
no scenario is drawn for a plan *created* inside it (t−120…t−180, the PW-004 region). That is a
missing mock state, not an intent question — moved to M-08.

## 5 · Disposition summary

| Class | Count | Blocking? |
|---|---|---|
| TRACED | 17 | — |
| DESIGN-FIX | 11 (F-01 … F-11) | **F-01, F-02, F-03 block handoff** — a coding agent would port the inverted check, the missing clock and the collapsed states as-is |
| SPEC-ADD | 5 (F-12 … F-16) | F-13 is a notes §6 drafting task (R-01); F-12 is closed by R-02 + F-01 |
| RULING-NEEDED | 2 ruled, 1 withdrawn | none open |
| MOCK-NOTE | 8 | never |

**Order of work.** F-01/F-02/F-03 (+ R-02's deletion) in the prototype as a `v3.html` candidate →
F-13 (oz rule), F-15 folded into notes §6 / the drawer contract → re-run this pass; TRACED must not shrink.

**Branch note for QA.** This register is written on `qa/design-source-authority`; the specs it cites
are on `qa/pre-workout-drawers`. Once that branch lands, the anchors resolve on `main` unchanged.

## 6 · MOCK-NOTES appendix — value sloppiness in documented quantities (NON-BLOCKING)

| # | Note |
|---|---|
| M-01 | **3+ h carbs band 50–140 g, target 100 g.** 100 g at 3 h ⇒ 33 kg on the diagonal, while 16 oz fluid ⇒ 63 kg. The two mock athletes disagree. At 63 kg the cited band is 63–252 g and the 3-h plan 189 g |
| M-02 | **90 min carbs band 30–70 g.** 90 min is *inside* the cited window (≥ 60 min), so the band is `[1·BW, 4·BW]`, not a narrow envelope; and it should look like the 3-h band (F-04), not like the 20-min one |
| M-03 | **20 min carbs band 0–30 g.** Design-choice regime ⇒ ±12.5 % of 15 g = 13–17 g. A zero floor is a *fluid* property; carbs has none. Cosmetic here, but it is the same confusion F-09 makes structural at t = 0 |
| M-04 | **Sub-2 h fluid targets.** At 63 kg: f(90) = 416 ml ≈ 14 oz (shown 12); f(20) = 287 ml ≈ 10 oz (shown 8); f(0) = 250 ml ≈ 8.5 oz (shown 6). Ceilings: `min(10·BW, clearance)` = 630 ml ≈ 21 oz at 90 and 20 min (shown 20 and **12**); 400 ml ≈ 13.5 oz at t = 0 (shown 12) |
| M-05 | **Dark-path water is a flat 8 oz.** Spec: `4·BW` ml — 252 ml ≈ 8.5 oz at 63 kg, 400 ml ≈ 13.5 oz at 100 kg. The quantity is documented; the mock is not body-weight-scaled |
| M-06 | **RXBAR Blueberry as the snack.** A nut/egg-white bar (~9 g fat, 12 g protein per 52 g) is unlikely to pass the snack-tier composition gates in food-composition v3; the canonical snack there is a low-fat carbohydrate item. Mock food choice, not a design defect |
| M-08 | **No scenario for a plan created between 2 h and 3 h ahead** (e.g. "2h15 ahead"): meal window of 15 min, the PW-004 region. Add the state to the next candidate |
| M-07 | **Chews at 0.5 packet = 13 g carbs.** A half-packet top-off illustrates PW-006 (top-off below one unit inside the meal window) rather nicely; the spec's answer is a minimum-portion rule *if* it becomes a problem, so this is on the record, not a finding |

---

*Prototype state controls are Claude Design props, not on-page controls: driven via
`__dcSetProps('v2', {plannedAhead, targetState, layout})`. Extracted logic saved at the session
scratchpad as `preworkout-v2.html` for re-checking without the browser.*

---

## Re-run — v3 (2026-08-26) · ratified as `spec/design/renderings/pre-workout@v1.html`

Candidate: `prototypes/pre-workout/v3.html` (standalone export of "Before Card v3", same Claude
Design project, five iterations driven from this register). Walked in the browser as the ratified
copy: all five `plannedAhead` scenarios, all three `targetState` values, the check's four answers
and change-answer, `?`.

**TRACED grew monotonically** — every A-row from §1 still holds; new traced rows:

| # | v3 surface | Spec anchor |
|---|---|---|
| A18 | Dark answer: target 16 → 25 oz (`+4·BW`), triangle moves, band 12–26 oz fixed; water row added as the *means*; change-answer reverts both | hydration algorithm `snackMl = TOPUP_ML_KG·BW`; inv. 8b; **F-01 closed** |
| A19 | Gated: fluids shows "No fluid target for this session", no band/marker; carbs untouched. Fasted: "No carbs this session", no carb band, no per-feeding carb pair; fluid plan stands. Start line: real `0g`, no carb band | hydration gate → `null`; carbs `isFasted` → `tiers: []`; carbs † suppress `[0,0]`; **F-03, F-09 closed** |
| A20 | "guideline" / "our estimate" caption under each band; solid rail everywhere; 90-min carbs = guideline (lead ≥ 60 min), 20-min/start-line carbs and all sub-2 h fluid = estimate | `targetBasis`; **F-04 closed** (rail dashing tried and dropped — carries no decodable meaning) |
| A21 | `?` opens "About these numbers" — the four notes §7 paragraphs | **F-05 closed** |
| A22 | Card headers "52 / 60g · DONE / AIM" | **F-07 closed** |
| A23 | First card always "Pre-Run Meal"; snack tier named by `LIGHT_MEAL_G_PER_KG` (≥ 63 g at 63 kg → "Light Meal"); "2h15 ahead" scenario (142 g = 85/43/14, meal window "15 MIN WINDOW") | carbs `renderAs` threshold; **F-08 closed, M-08 covered** |
| A24 | "Is your urine pale yellow right now?"; caveat ends "— choose Not sure." | **F-10, F-11 closed** |
| A25 | Check row: teal ring, "adjusts your fluid target", timing copy "Do this about two hours before you start, once you've finished your pre-run meal."; present on 3+ h and 2h15 only | hydration v6 as amended by **PW-021**; **F-02 closed by ruling** — no live clock; the offer window is copy, not a predicate |
| A26 | No sports-drink branch on the dark path | **R-02 applied; F-12 closed** |
| A27 | Below 2 h: fluid column is figure + band only; the cue lives in the fine print | PW-021 point 3; **F-06 closed by ruling** |

**Open after v3:** none blocking. F-13 (oz rounding rule → notes §6) and F-15 (water as a plan row)
remain drafting tasks on the drawers branch; F-14 / F-16 stay SPEC-ADD for the surface spec that
`design-ssot-extract` will write. Mock-notes M-01…M-07 unchanged and still non-blocking.

**Amendments this pass produced:** PW-021 (`qa/pre-workout-drawers` `e7739a9`, `dfbb047`,
`9f0f46b`) — live clock retired; check athlete-timed, stays in the snack card; sub-2 h cue in the
fine print.
