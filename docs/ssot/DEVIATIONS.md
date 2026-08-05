# QA — Deviation Register

Behaviors observed in the app's code/UI that the **SSOT has NOT ratified**.

**Principle: implementation is not authorization.** Discovering that code does X is a reason
to log X *here*, NOT to rewrite the SSOT to say X. The SSOT stays the team's intended truth.
Resolving a deviation — fold it into the SSOT, or change the code — is a **deliberate,
separate decision**, never automatic just because the code implements it.

| status | meaning |
|---|---|
| `documented` | logged; SSOT deliberately NOT evolved; awaiting a future team decision |
| `pending-ruling` | surfaced; not yet decided how to treat |
| `resolved` | decision made (folded into SSOT, or code changed) — see note |

Conformance vectors that pin a deviation are marked `status: characterization` — a tripwire
so we notice if the behavior changes, **not** an endorsement of it as truth.

---

## D-001 — Pre-workout: fasted → zero pre-workout fuel
- **Status:** `documented` (2026-07-26). SSOT deliberately NOT evolved.
- **Observed:** with the "Fasted Workout" toggle on, `calculatePreWorkoutTargets` returns
  all-zero pre-workout carbs/protein/fat/sodium/water and `meal_type='fasted'`.
- **Code:** `app/lib/features/nutrition_plan/data/offline_macro_calculator.dart:106`.
  **UI:** Create New Activity Plan → Running / Riding / Brick → "Fasted Workout" toggle
  (`presentation/widgets/new_activity/shared/fasted_toggle.dart`; Swimming forces it off).
- **SSOT status:** the pre-workout **carbs** SSOT (the Carb Section drawer) does not mention a
  fasted mode. **Fasted training has not been discussed by the team** — it appears to have
  shipped without ratification, and was not caught until this QA pass.
- **Decision (Xuan, 2026-07-26):** document only. Do NOT change or evolve the SSOT now.
  Revisit as a deliberate future decision.
- **Conformance:** pinned by the `fasted-all-zero` vector, marked `status: characterization`.
- **Open (only if the team later rules to keep it):** fold into the SSOT + update the results
  drawer to explain the fasted case (today the fasted guidance lives only on the *input* screen).

## D-004 — Brick anomalies (UNCONFIRMED — need harness/code to adjudicate)
- **Status:** `pending-ruling` (2026-07-28). Two observations from the brick sim sweep (Ravi,
  swim/run/bike). **NOT yet confirmed as bugs** — the sim can't distinguish a real defect from a
  display/semantic quirk here; verify with the automated generate-plan harness (exact target vs
  `[low,high]`) or a code trace before acting.
- **D-004a — Brick macro-summary fluids look like ml labeled "oz".** On the brick "Adjust Your
  Macros" screen the FLUIDS row read PRE **250oz** / DURING **1356oz** / POST **1934oz** —
  implausible as oz (250oz ≈ 7.4 L pre-workout). As **ml** they're sane: 250 ml ≈ 8 oz, 1356 ml ≈
  46 oz, 1934 ml ≈ 65 oz. The brick **plan detail** (next screen) showed the sane **8oz** BEFORE,
  so the suspected unit-label bug is isolated to the **brick macro-summary aggregate** display,
  not the per-phase plan. Single-sport summaries convert ml→oz correctly (~34oz). Likely a
  brick-only ml-vs-oz display bug. VERIFY in the macro-summary widget.
- **D-004b — Brick per-segment DURING macros read below their range bars.** DURING RUN (3rd leg,
  27 min) showed **carbs 15g vs range [20,27]** and **sodium 100mg vs range [143,215]** — two
  macros pinned below the range low, with only "1 cup Sports Drink" delivered (no gap-fill topping
  it up). Could be (i) a real **H6** violation (gap-fill didn't fire for a brick sub-segment), or
  (ii) an honest **H1** shortfall the bar is displaying (marker pinned left) with no explicit
  warning text, or (iii) range-bar semantics I misread. VERIFY: does the brick During path run the
  same gap-fill as single-sport? Is a shortfall emitted? This is exactly what the automated
  invariant harness is for (reads exact target + `[low,high]`).
- **Open:** run both through the (not-yet-built) generate-plan invariant harness or trace the
  brick During + macro-summary code. Do NOT file app tasks until confirmed.

## D-003 — Safety-violating pin honored with NO warning (H2/D1 not implemented)
- **Status:** `pending-ruling` (2026-07-28). Surfaced by the generate-plan sim bug-hunt (Ravi).
  **Safety-relevant** — awaiting Xuan's ruling on whether to change the code (implement the
  D1/H2 warning) or evolve the SSOT.
- **Observed (sim + code, both confirmed):** a pinned pre-workout formula that contains an
  allergen on the athlete's list is **served in the plan with no warning of any kind**. Ravi
  (`allergies: [dairy, gluten]`) pinned the **Oatmeal** template (data-tagged with the `gluten`
  allergen — `_shared/nutrition/__fixtures__/dev-food-catalog.json:2879-2891`). The no-pin plan
  correctly excluded oatmeal and served **Banana**; after pinning, the regenerated plan served
  **"3 cups Oatmeal"** as the Full Meal, shown with a plain green ✓ in the "pins honored" banner
  and **no allergen badge / warning triangle / alert text** on the food card.
- **Code:** the pin-override path bypasses the allergen filter
  (`generate-macros-v4/pre-workout.ts:1006-1008` — `pinOverrideActive ? pinnedForPhase :
  getEligibleTemplates(...)`; policy comment lines 994-997 "bypassing dietary/dislike/allergen
  filters … in-scope pins are honored unconditionally"), and the emitted `pin_decision` object
  (~lines 1236-1250) carries only `used_pin / pinned_template_id / pinned_template_name /
  fallthrough_reason / pin_set_size` — **no safety/allergen field**. A repo-wide grep found no
  pin-safety-warning emission anywhere. So the warning half of D1/H2 is **not implemented** —
  this is a spec-vs-implementation GAP, not a UI dropping an existing flag.
- **What DOES work (not a deviation):** **H3 pin priority PASSES** — the pin correctly overrode
  the algorithm's safe choice (Banana → Oatmeal), scaled to hit the carb target (3 cups → 81g).
  The failure is strictly the missing *warning* the ratified D1/H2 requires.
- **SSOT status:** contradicts `spec/recommendation/generate-plan.md` **H2** ("any
  safety-violating pinned formula MUST always carry a visible warning") and **D1** ("a pinned
  formula violating safety will ALWAYS have a warning sign … if a user still pins it, it
  overrides safety"). The override half is honored; the warning half is absent.
- **Secondary (timing caveat, not the finding):** the pin's effect needs a **full fresh
  generation** — the local pin write uploads to Supabase non-blocking, so an immediate
  regenerate right after pinning can still show the pre-pin plan (observed: Full Meal stayed
  Banana on the first quick regenerate, became Oatmeal on a fresh Generate→Create). A QA-harness
  caveat (confirm the pin synced before asserting) and a possible minor UX papercut.
- **Recheck (2026-08-02, qa-smoke audit run):** still reproduces on a fresh dev build at app HEAD
  `3e3dc86f` (2026-07-31). Ravi's Oatmeal pin (persisted from the 2026-07-28 run) honored as Full
  Meal "2.5 cups Oatmeal" with a green ✓ and no warning at the banner, occasion-card, or
  expanded-row level. Run log: `qa/runs/2026-08-02-ravi.md`.
- **Open:** Xuan's ruling — implement the D1/H2 warning (recommended, safety) vs. re-open D1.
  If code is to change, it's a Lee task (emit an allergen-violation flag on `pin_decision` +
  render a warning badge). Note the two pin surfaces (see the memory / sim-nav): the Formula
  Library card "Pin formula" (bookmark) and the plan "Pin your favorite formula" both write the
  same `formula_pins` store and both feed generation.

## D-002 — Pre-workout carbs: 0.5 g/kg floor below the cited research minimum
- **Status:** `resolved` — **ACCEPTED into the SSOT** (Xuan, 2026-07-26).
- **Observed:** `carbPerKg = max(0.5, min(hoursBefore, 4.0))` — for lead times < 30 min the
  floor is 0.5 g/kg, below the drawer's cited basis (Kerksick 1–4 g/kg).
- **Code:** `offline_macro_calculator.dart:131`.
- **Decision (Xuan, 2026-07-26):** ACCEPT — fold into the SSOT as a Mealvana design-choice
  minimum for very short lead times (some carbs beat none). Now a ratified constant (see the
  spec constants table); its vector reclassified `status: ratified`. This was the deliberate
  act that evolving the SSOT requires — not an automatic absorption of code behavior.

## D-005 — Pre-workout hydration drawer: "at least 4 hours" vs the 2-hour tier boundary
- **Status:** `resolved` — **resolution (a), by source verification** (Xuan, 2026-07-30, ratifying
  hydration SSOT v2). Was `pending-ruling`. **Copy defect, not a math defect.**
- **RESOLUTION.** QA subsequently read **Thomas DT, Erdman KA, Burke LM (2016)** in full — the named
  successor to Sawka 2007 — which states the protocol applies *"in the 2 to 4 hours before
  exercise."* So the ratified `≥ 120 min` lower bound was **correct all along**, and option (b)
  (moving the boundary to 240 min) would have been **actively wrong against the current standard**.
  S2's "at least 4 hours" is not a loose paraphrase: it is a faithful quotation of the **superseded**
  2007 text. Fix the drawer sentence to 2 h and re-cite to Thomas 2016.
  *Note the entry's own reasoning below — "S2's 4 h is arguably the more faithful reading" — was
  true of ACSM 2007 and false of the current standard. This is why the citation had to be read
  rather than inferred.*
- **Follow-on:** v2 additionally adopts Thomas 2016's **4-hour upper bound** as copy only (a
  numerical no-op; above 4 h is explicitly out of scope). See `spec/fueling/pre-workout-hydration.md`.

<details><summary>Original entry as logged 2026-07-30 (pending-ruling)</summary>

- Surfaced while folding the Pre-Workout Fluids drawer design into the hydration SSOT.</details>
- **Observed:** in the same drawer, panel S2 ("Where does 5–7 ml/kg come from?") attributes the
  5–7 ml/kg protocol to ACSM *"consumed at least 4 hours before exercise"*, while panel S3 ("Why
  does the recommendation change with time available?") says it *"requires at least 2 hours"*.
  The ratified boundary and the code both use **≥ 120 min**.
- **Source:** `spec/fueling/pre-workout-hydration.html` (archived design artifact), panels S2/S3.
  **Ratified math:** `spec/fueling/pre-workout-hydration.md` — tier 1 at `timeBefore ≥ 120`.
- **Why it matters:** S2's 4 h is arguably the more faithful reading of ACSM 2007, so this is not
  simply a typo — it may mean the ratified tier-1 boundary is more permissive than its own cited
  source. Two different resolutions, with different blast radius:
  (a) copy-only — S2 is loose paraphrase, fix the sentence to 2 h; **or**
  (b) the 120-min boundary itself is under-cited and belongs at 240 min, which would change every
  tier-1 output for athletes with 2–4 h of lead time.
- **Decision:** none yet. **Do NOT change the tier boundary or the drawer copy on QA's authority** —
  (b) is an SSOT evolution and needs Xuan. Log only.
- **Conformance:** no vector change. If (b) is ever chosen, the existing tier-1 vectors at
  `timeBefore` between 120 and 240 min become the regression surface.

## D-006 — Pre-workout drawers render only tier 1; no gate / tier-2 / tier-3 branch
- **Status:** `pending-ruling` (2026-07-30) — **now HYDRATION-ONLY.** Layer-2 (explanation ⇄ engine)
  coverage gap.
- ✅ **Sodium half closed 2026-07-30:** pre-workout sodium SSOT v2 removes the target, so there are
  no sodium tiers to branch on. The sodium drawer needs a rewrite, but not the missing-branch work
  this entry describes.
- ⚠️ **Hydration half worsened:** hydration v2 went from three tiers to four, so the drawer now
  under-renders by one more state than when this was logged.
  **Applies to BOTH pre-workout drawers** — hydration and sodium (extended 2026-07-30 when the
  sodium design came in with the identical shape).
- **Observed (hydration):** the drawer design renders exactly one state — tier 1, 65 kg, 3 h →
  390 ml. The engine has four user-visible states. Three have no copy:
  - **gate** (`workoutDurationMin < 60 AND tempC < 30` → all zeros): the drawer has no branch
    explaining a `0 ml` target; its always-visible copy still narrates sipping 390 ml.
  - **tier 2** (10–120 min → **250 ml fixed**): the calculation chain is hardcoded `BW × 6`, which
    is wrong here — 250 ml is not body-weight-scaled. S3 also states the band `200–300 ml` but
    never the 250 ml midpoint the engine emits.
  - **tier 3** (< 10 min → all zeros): S3's chip reads `sips only` while the drawer will display
    `0 ml` beside it.
- **Observed (sodium):** same shape. Only tier 1 (450 mg) is rendered; the gate (→ 0 mg), tier 2
  (→ **150 mg**, whose midpoint the drawer never states — S2's chip shows only the `100–200 mg`
  band) and tier 3 (→ 0 mg) have no copy branch.
- **Also:** *both* designs ship `.window-chip` CSS *and* JS for a time-window tier switcher with no
  matching markup in the body — the affordance these branches need appears to have been cut or
  dropped in export. That it recurs identically in two independently-exported drawers suggests a
  shared template lost the markup, not a one-off.
- **Why it's logged, not filed:** these are **design gaps in unshipped mocks**, not observed
  behavior of the shipped app. Whether the live drawers have these branches is **unverified** —
  qa-smoke has not driven a gated or tier-2 workout. Verify on the simulator before filing
  anything for Lee.
- **Decision:** none. Raised to design in `spec/fueling/pre-workout-hydration.md` and
  `spec/fueling/pre-workout-sodium.md` ("Open design questions"). Log only.
- **Conformance:** the open action is a qa-smoke layer-2 pass over a **gated** workout (e.g. 45 min
  @ 22 °C) and a **tier-2** workout (60 min lead time), reading *both* drawers, to see what the
  shipped app actually says.

## D-007 — Pre-workout sodium: 300–600 mg is not inside its own cited source
- **Status:** `resolved` — **the constant was REMOVED, not re-derived** (Xuan, 2026-07-30, ratifying
  pre-workout sodium SSOT v2). Was `pending-ruling`.
- **RESOLUTION.** None of the three options originally framed was taken. Rather than (a) re-cite
  honestly, (b) re-derive ~180–450 mg from the source, or (c) rewrite the limitation note, **the
  pre-workout sodium target was dropped entirely.** `sodiumMg/Low/High` now emit `null`. With no
  band there is no derivation to reconcile and no limitation to document, so this entry closes
  without any of its rulings being exercised.
- **Why it went that way.** The entry's own analysis is what made the constant indefensible: the
  band is not derivable from 20–50 mEq/L at any volume (ratios 2.0× vs 2.5×), and the concentration
  inversion `75000 / BW` showed the fixed band over-concentrates **every athlete under ~65.2 kg** —
  the opposite population from the one documented. Two further facts closed it: Thomas 2016 and
  NATA 2017 both decline to give any pre-exercise sodium figure, so there is nothing current to
  re-derive from; and ordinary pre-workout food (an RXBAR + chews = 325 mg, observed in-product)
  exceeds any target we would have set.
- **Originally logged as:** surfaced while folding the Pre-Workout Sodium drawer into the sodium
  SSOT. **The engine was not wrong — the SSOT's own justification was.**
- **Observed:** the drawer's panel S2 states that ACSM's 20–50 mEq/L works out to ~460–1,150 mg/L
  (correct: 20 × 22.99 = 459.8, 50 × 22.99 = 1149.5) and concludes that, over the ~390 ml
  pre-hydration volume, *"a fixed range of 300–600 mg achieves concentrations within the ACSM
  guidance."* **That conclusion is false for the midpoint and the ceiling:**

  | sodium | in 390 ml | mEq/L | inside 20–50? |
  |---|---|---|---|
  | 300 mg (floor) | 769 mg/L | 33.5 | ✅ |
  | **450 mg (ratified target)** | **1154 mg/L** | **50.2** | ❌ just over |
  | **600 mg (ceiling)** | **1538 mg/L** | **66.9** | ❌ ~34 % over |

- **The same defect is in this SSOT, not just the drawer.** `spec/fueling/pre-workout-sodium.md`
  cites the tier-1 constant as "ACSM 2007 (20–50 mEq/L over ~390 ml)". Inverting that band over
  390 ml gives **179–448 mg** — so the ratified 300–600 mg band is shifted upward from its own
  stated derivation, and 450 mg sits fractionally outside it.
- **The documented "known limitation" points the wrong way.** Both the SSOT and drawer S3 warn that
  *heavy* athletes get an under-concentrated dose. At the 450 mg target, concentration is
  `75000 / BW` mg/L, so the ACSM band holds only for **65.2 kg ≤ BW ≤ 163 kg**:
  - under 20 mEq/L requires **BW > 163 kg** — effectively never fires;
  - over 50 mEq/L fires for **every athlete under ~65.2 kg** — a large share of the athlete base,
    and entirely undocumented. (At the 600 mg ceiling, the exceedance starts at **BW < 87 kg**.)
  The drawer's worked example, 65 kg, sits exactly on this boundary at 50.2 mEq/L.
- **Verified by QA:** arithmetic (mEq→mg at 22.99 mg/mmol, over `BW × 6 ml/kg`) **and, as of
  2026-07-30, the primary source itself.**
- ✅ **CAVEAT CLOSED 2026-07-30 — the finding does not dissolve.** This entry originally warned that
  the 20–50 mEq/L band might be a *during*-exercise figure, which "could dissolve the whole finding."
  QA has since read Sawka et al. 2007 directly: the figure is in the **"Before Exercise"** section
  (p. 384), verbatim — *"Consuming beverages with sodium (20–50 mEq·L⁻¹) and/or small amounts of
  salted snacks or sodium-containing foods at meals will help to stimulate thirst and retain the
  consumed fluids."* It is distinct from the during-exercise figure in the same document
  (20–30 mEq/L, from the IOM) and from the recovery section (no mEq/L given). **The pre-exercise
  attribution is correct and D-007 stands in full.**
- **And the ground has shifted underneath it.** Sawka 2007 is **superseded** by Thomas 2016, which
  gives **no pre-exercise sodium figure at all** — only *"Sodium consumed in pre-exercise fluids and
  foods may help with fluid retention."* NATA 2017 rec 18 (SOR: B) likewise gives no number and says
  sodium *"should be individualized based on specific losses and needs."* So resolution (b) —
  re-derive the band from the cited source — is available **only** while remaining on the superseded
  document. There is nothing current to derive from. This strengthens resolution (a): treat
  300–600 mg as a product default and re-cite honestly.
- **Note the arithmetic above uses `BW × 6 ml/kg`, which is now stale.** Hydration v2 (2026-07-30)
  moved tier-1 fluid to `BW × 7.5`, so the 65 kg volume is **488 ml, not 390**. Re-running the
  concentration table against v2 volumes is a prerequisite for any ruling that keeps a concentration
  argument.
- **Decision:** none. **Do NOT adjust 450/300/600 on QA's authority** — these are ratified
  constants and three different rulings are open:
  (a) copy-only — the constants are a deliberate practical choice, so drop the "within ACSM
  guidance" claim and re-cite honestly; (b) re-derive the band from the cited source (~180–450 mg),
  which moves every tier-1 sodium output; (c) keep the numbers but rewrite the limitation note to
  describe the over-concentration case that actually fires.
- **Immediate, ruling-independent:** S2's "within the ACSM guidance" sentence is false as written
  and should not ship in any of the three outcomes.
- **Conformance:** no vector change. Existing tier-1 sodium vectors stay `ratified` — they pin the
  ratified constants, which this entry does not overturn. If (b) is chosen they become the
  regression surface.

## D-008 — Pre-workout sodium drawer: confidence-badge and citation drift on the 10–120 min window
- **Status:** `resolved` — **moot under pre-workout sodium SSOT v2** (Xuan, 2026-07-30). Was
  `pending-ruling`.
- **RESOLUTION.** v2 removes the pre-workout sodium target entirely, so there are no longer three
  windows, no confidence badges on them, and no NATA attribution to restore (which was in any case
  unsupported — NATA 2017 contains no volumetric or mass pre-exercise sodium figure). The drawer
  panel this entry describes is being rewritten to explain why no target exists.
- **Originally logged as:** minor, but exactly the layer-2 drift this department exists to catch.
- **Observed:** the sodium drawer's panel S2 covers all three windows under a single **High
  confidence** badge and cites only *Sawka et al. (2007) ACSM Position Stand*. The ratified SSOT
  rates the **10–120 min / 150 mg [100–200]** window **Medium**, on NATA/practitioner grounds — not
  ACSM. So the drawer over-states both the confidence and the provenance of that tier.
- **Contrast:** the sibling *hydration* drawer gets this right — it carries two badges, `High
  confidence ≥ 2 hr` and `Medium confidence 10–120 min`, matching its SSOT exactly. The pattern
  exists; the sodium drawer just didn't use it.
- **Decision:** none. Copy fix for design — apply the hydration drawer's two-badge treatment and
  restore the NATA attribution. Log only.
- **Conformance:** no vector change (confidence ratings are not engine output).
- ⚠ **Superseded in part 2026-07-30:** the "restore the NATA attribution" instruction is now wrong.
  NATA 2017 was read in full and contains **no volumetric prehydration figure** — see D-010. There
  is no NATA attribution to restore. The two-badge treatment still stands.

---

# Surfaced by the 2026-07-30 primary-source verification

D-009…D-012 all come from one pass: reading **Thomas 2016** and **NATA 2017** in full rather than
citing them from the existing SSOT. All four are **explanation-layer / citation defects**; none
changes engine output. They are the reason hydration SSOT **v2** was ratified (2026-07-30).

**Method note, for weighting these:** the three sources were read directly — Sawka 2007 (ACSM
Position Stand, p. 384 verified verbatim), Thomas 2016 (via the Dietitians of Canada full-text
co-publication), NATA 2017 (via the free nata.org PDF). Arithmetic was recomputed, not inherited.

## D-009 — Tier-1 band `5–7 ml/kg` attributed to a source that says `5–10`
- **Status:** `resolved` — **corrected in hydration SSOT v2** (Xuan, 2026-07-30).
- **Observed:** `spec/fueling/pre-workout-hydration.md` v1 cited `6 ml/kg [5–7]` to
  *"ACSM 2007 / Thomas 2016 — **High**"*, and drawer panel S2 repeated it. **Thomas 2016 says
  5–10 ml/kg**, verbatim: *"a fluid volume equivalent to 5-10 ml/kg BW in the 2 to 4 hours before
  exercise."* The v1 ceiling was **30 % below** the current standard's.
- **Same defect class as D-007** (sodium's 300–600 mg not derivable from its own citation), in the
  sibling slice. Both were found the same way: recomputing a cited derivation instead of trusting it.
- **Resolution:** v2 adopts `5–10 ml/kg` for tier 1 and cites Thomas 2016 alone; ACSM 2007 is
  retained for lineage only, marked superseded.
- **Conformance:** tier-1 band vectors move (`fluidHighMl` 455 → 650 at 65 kg). Deferred — see the
  v2 spec's Conformance section.

## D-010 — Tier-2 `250 ml [200–300]` cited to NATA; NATA contains no such figure
- **Status:** `documented` (2026-07-30). The **constant survives in v2 as an explicit design
  choice**; only its citation is withdrawn.
- **Observed:** v1 rated `10–120 min fluid | 250 ml [200–300] | NATA — **Medium**`. NATA 2017 was
  read in full. Its *Hydration Before Exercise* section is **entirely cue-based** and contains no
  mL/kg, no fixed volume, and no timing tier:
  > "To ensure euhydration before activity, an athlete should be mindful of individual cues, such as
  > thirst, body weight, urine color, and voiding frequency."
  The only millilitre figure anywhere nearby — *"Maintaining 400 to 600 mL of fluid in the stomach
  optimizes gastric emptying"* — is about gastric volume **during** exercise, not prehydration.
- **Further:** NATA takes a position that cuts against a universal pre-workout fluid target —
  *"**Recreational athletes should not need to consume extra fluids before activity** but should
  begin exercise euhydrated."* Most Mealvana users are recreational. **Raised to Rachel** (see the
  v2 spec's "Questions for Rachel").
- **Provenance of the original number:** untraced. The nearest practitioner figure QA could find
  (7–10 fl oz ≈ 207–296 ml) comes from a **SCAN handout by an individual dietitian**, not a graded
  guideline — and it is specified for a **10–20 minute** top-up, not a two-hour window. v2 places a
  200–300 ml fixed top-up at **10–45 min**, which is closer to that figure's intended timing.
- **Decision:** citation withdrawn; constant retained as a Mealvana design choice, confidence **Low**.
- **Conformance:** no break — v2's tier-3 top-up keeps `200–300 ml`.

## D-011 — Drawer instructs an extra `3–5 ml/kg` the engine never computes
- **Status:** `pending-ruling` (2026-07-30). **Layer-2 violation, and the sharpest one in the file.**
- **Observed:** `pre-workout-hydration.html`, tip callout inside *Calculation*: *"If your urine is
  still dark at 2 hours before your workout, the ACSM recommends an additional **3–5 ml/kg**."*
  No second dose exists anywhere in `calculatePreWorkoutHydration`.
- **Why this is worse than D-006.** D-006 is *omission* — the drawer stays silent on branches the
  engine has. This is the drawer **actively instructing the user beyond the target it displays**, by
  up to **325 ml for a 65 kg athlete**. The number on screen and the advice beneath it disagree.
- **Also stale:** 3–5 ml/kg is Sawka 2007's *conditional second dose*, which Thomas 2016 folded into
  its single 5–10 ml/kg window. It presupposes the base dose was already taken — it is not a
  standalone figure.
- **Now conflicts with v2 as well.** The `deficit` branch (`f = 0.75`) addresses the same situation
  and delivers only **+1.25 ml/kg** over `unknown` in tier 1 (65 kg: +81 ml), versus the advisory's
  +195–325 ml. **Either the advisory is retired in favour of the branch, or `f` for `deficit` is too
  low.** Deliberately left unresolved at v2 ratification.
- **Decision:** none. Do not delete the advisory or move `f` on QA's authority. Ruling needed, and
  it is a good candidate for Rachel.

## D-012 — Both drawers frame over-drinking as inconvenience, not risk
- **Status:** `resolved` for hydration — **fixed by the v3 fine print** (Xuan, 2026-07-31).
  **Still open for the sodium drawer.** Was `pending-ruling`. **Safety-relevant copy.**
- **RESOLUTION (hydration).** The ratified asterisk copy carries a "More is not safer" paragraph
  stating that drinking beyond losses is the main cause of exercise-associated hyponatremia and
  that it "isn't just an inconvenient bathroom stop" — the exact framing this entry objected to.
  Copy at `spec/fueling/pre-workout-hydration.notes.md` §13; the SSOT makes the asterisk a shipping
  requirement, so the target cannot ship without it.
- **Still open:** the sodium drawer's equivalent copy. Note it is now lower priority — pre-workout
  sodium SSOT v2 removed that target, so the drawer is being rewritten regardless (see D-008).
- **Observed:** hydration drawer panel S2 says drinking beyond the ceiling *"provides no additional
  benefit and may require an inconvenient bathroom stop mid-warmup."* Thomas 2016, in the same
  document that supplies the band: *"**Over-drinking fluids in excess of sweat and urinary losses is
  the primary cause of hyponatremia**"* (also called water intoxication). Neither pre-workout drawer
  mentions hyponatremia anywhere.
- **Why it matters here specifically:** the team set this constraint itself in the 2026-07-29
  session — *"we know that it's very dangerous to not take electrolytes… people die from
  hyponatremia."* Framing the failure mode as a bathroom stop is a softening in exactly the copy a
  user reads before drinking.
- **Balance required.** The fix must **not** discourage fluid or electrolytes. The supportable
  framing is: match intake to thirst and sweat losses; more is not safer. Note the corollary already
  established for sodium — the EAH consensus is explicit that sodium intake *cannot* prevent EAH when
  fluid intake is excessive, so we must never imply our sodium targets do.
- **Decision:** none. Copy fix for design across both pre-workout drawers. Log only.
- **Conformance:** no vector change (advisory copy is not engine output). Layer-2 only.

## D-013 — Pre-workout sodium and hydration tier boundaries have silently diverged
- **Status:** `resolved` — **dissolved by pre-workout sodium SSOT v2** (Xuan, 2026-07-30). Was
  `pending-ruling`.
- **RESOLUTION.** Sodium no longer has tiers, so there is nothing left to keep in sync with
  hydration's four windows. Neither option (a) nor (b) was needed.
- ⚠️ **The root cause is NOT resolved and applies to every remaining slice.** A spec that *declares*
  a dependency on another spec — "same time windows as pre-workout hydration" — carries that
  dependency in prose, where nothing enforces it. Hydration v2 falsified it silently and only a
  manual read caught it. Recommend the department record cross-slice dependencies somewhere
  mechanical (a shared constant, or a conformance vector that asserts the two agree) before the next
  slice is revised in isolation.
- **Originally logged as:** surfaced while splitting the sodium SSOT.
  **Cross-slice consistency defect. No engine change yet — the engine already behaves this way;
  what broke is a claim the SSOT makes about itself.**
- **Observed:** `spec/fueling/pre-workout-sodium.md` opens its math block with *"same time windows
  + gate as pre-workout hydration."* That was true when both slices were ratified 2026-07-26.
  **Hydration v2 (2026-07-30) changed its windows; sodium did not.**

  | | Hydration v2 | Sodium |
  |---|---|---|
  | Tier 1 | ≥ 120 min | ≥ 120 min ✅ |
  | Tier 2 | **45–120 min** | **10–120 min** ❌ |
  | Tier 3 | **10–45 min** | < 10 min ❌ |
  | Tier 4 | < 10 min | — |

- **User-visible consequence:** an athlete 30 minutes out now sits in hydration **tier 3** (fixed
  250 ml top-up, not body-weight-scaled) but sodium **tier 2** (150 mg) — a pairing neither spec
  intended, and one no vector covers.
- **Why it is logged rather than fixed:** both resolutions are SSOT evolutions.
  (a) sodium adopts hydration's four windows — and someone must decide what tier 3 (10–45 min)
  carries, since no source covers it; **or**
  (b) the shared-window claim is dropped and sodium keeps three windows on its own authority.
  Either way the sentence "same time windows as pre-workout hydration" must go — it is now false.
- **Decision:** none. **Do NOT alter sodium tiers on QA's authority.**
- **Conformance:** no vector currently exercises the divergence. Whichever way it is ruled, the
  10–45 min region needs a paired fluid+sodium vector — it is the only window where the two slices
  now disagree about which tier an athlete is in.
- **Root-cause note for the department:** this is the first cross-slice breakage caused by ratifying
  one slice in isolation. Slices that declare a dependency on another slice ("same windows as…")
  should carry that dependency somewhere mechanical, or the next revision will break it silently
  again.

## D-014 — Pinned formula's intrinsic fluid pushes BEFORE fluids past the range high (UNCONFIRMED)
- **Status:** `pending-ruling` (2026-08-02). Surfaced by the qa-smoke audit run (Ravi, 12 mi run,
  90-min window, Oatmeal Meal pin). **Unconfirmed candidate — do NOT file an app task yet.**
- **Observed (sim):** plan-detail BEFORE rollup showed **FLUIDS 21 oz against a [7, 10] oz range
  bar** (diamond pinned at the right edge). Decomposition: the honored **Oatmeal Meal pin scaled
  to 2.5 cups carries 17 oz intrinsic fluid** (cooking water counted as fluid; 67 g carbs, 0 mg
  sodium), plus the Top-Off's Water + Electrolyte Packet. Carbs (101 ∈ [96,124]) and sodium
  (144 ∈ [100,200]) were in range; only fluids missed. Macro-summary PRE target was 8 oz
  (v1 250 ml), consistent with the range bar; the *delivered* fluid is what overshoots.
- **Invariant at stake:** **H6** says every macro at every phase lands within its [low, high] —
  overshooting a fluid ceiling is a miss (and pre-workout fluid highs exist partly as an
  over-drinking guard). The cause is the **H3/H6 interplay**: honoring a pin scales it to the CARB
  target with no counterpart mechanism to shed the formula's incidental fluid load.
- **Could instead be:** (i) fluid-in-food deliberately not counted against the pre-fluid range
  (then the ROLLUP display double-counts it — a display bug instead); (ii) an honest H1-style
  shortfall/overage the bar renders without warning text; (iii) range-bar semantics misread.
- **Verify:** trace whether the before-phase solver treats fluid as a constrained macro under a
  pin, and whether `pin_decision`/shortfall ledger records the overage. Exactly the automated
  generate-plan harness's job (exact target + [low,high] + delivered).
- **Conformance:** no vector covers a pinned formula whose intrinsic fluid exceeds
  `fluidHighMl`. Add one when adjudicated.

## D-015 — H5 stacking bands overlap at exactly 90 min (spec text ambiguity)
- **Status:** `pending-ruling` (2026-08-02). Spec-text clarification, not a code bug.
- **Observed (sim):** `spec/recommendation/generate-plan.md` H5 writes the bands as
  "**≤30 → {top-up}** · **30–90 → {snack, top-up}** · **≥90 → {meal, snack, top-up}**" — the
  value **90 belongs to BOTH the middle and upper bands** (and 30 to both lower bands). A
  fueling window of exactly **1 h 30 m produced {meal, snack, top-off}** — code resolves 90 into
  the ≥90 band (`BeforeSubPhase.fromTimeWindow` maps `30–90 / 1.5–3h`, upper bound exclusive).
- **Resolution options:** ratify the observed closed/open convention by rewriting the bands as
  **≤30 / 30–<90 / ≥90** (matches code, one-word fix), or rule otherwise and file for Lee.
  Same question applies at the 30 boundary (untested this run).
- **Conformance:** the eventual H5 harness needs vectors at exactly 30 and exactly 90 min —
  the two points the current spec text cannot adjudicate.

## D-016 — The app's fueling-window stepper allows 480 min; the SSOTs cap at 240
- **Status:** `open — app fix required` (2026-08-03). Surfaced by the pre-workout SSOT review.
  **Ruling (Xuan, 2026-08-03): four hours is the product's design limit. The app is wrong, not the
  algorithm.** This is a code-side divergence to be fixed in the app, not accommodated in the spec.
- **Observed (code):** the pre-workout fueling-window control is `min: 0, max: 480, step: 15` —
  `app/lib/features/nutrition_plan/presentation/widgets/new_activity/cycling_tab_content.dart:91`,
  with the same bound in the swimming and brick tabs. Running hand-rolls its own stepper with the
  same limit: `running_tab_content.dart:605`, `value + 15 <= 480`. The value flows through
  unchanged — `macro_generation_service.dart:283`, `'hours_before': timeBeforeRunMinutes / 60.0`.
  So the shipped input domain is **33 values (0–480)**, not the 17 the SSOTs specify.
- **Why it matters (all three consequences are live today, on v1 code):**
  1. `carbPerKg = min(hoursBefore, 4.0)` reaches **4 g/kg across nine grid points** (t−240 through
     t−480), i.e. 260 g at 65 kg, while `pre-workout-carbs.md` asserted 4 g/kg was unreachable.
  2. Above t−240 the plan falls out of `inWindow`, so the band reverts to ±12.5 % and
     `carbsHighG` reaches **4.5 g/kg** — above Thomas 2016's cited ceiling. This is the exact v1
     defect the v2 spec claims to have removed.
  3. Maximum dose lands precisely where `targetBasis` drops to `design_choice` — most food, least
     authority.
- **Fix (Lee):** `max: 480` → `240` in the cycling / swimming / brick tabs; `value + 15 <= 480` →
  `<= 240` in `running_tab_content.dart:605`. **Clamp persisted values on load** — existing
  activities saved at 300–480 min will otherwise render a value the stepper cannot reach.
- **Conformance:** the ratified vectors enumerate 0–240 in 15-minute steps (17 points). Add a
  boundary vector asserting the engine is never called above 240, so a regression in the widget
  fails here rather than silently producing 4.5 g/kg.

## D-017 — Landing the pre-workout bundle moved the meal occasion from ≥90 min to ≥120 min
- **Status:** `pending-ruling` (2026-08-05). Two ratified specs now disagree; the code follows the
  newer one. **This is a live, athlete-visible behaviour change and it has not been ruled on.**
- **Observed (code, this repo):** implementing `pre-workout-macros@v1` replaced the occasion
  threshold in `supabase/functions/generate-macros-v4/pre-workout.ts`. Before the bundle the
  branch was `hoursBefore >= 1.5` (**90 min**); it is now `t >= TIER_MEAL_MIN` (**120 min**), and
  `generate-nutrition-plan-v3` takes its `sub_phase_type` from that same tier result. So the plan's
  BEFORE occasions now stack at 30/120, not 30/90.
- **The conflict:**
  - `spec/recommendation/generate-plan.md` **H5** (RATIFIED 2026-07-28) states the occasion bands
    as **≤30 → {top-up} · 30–90 → {snack, top-up} · ≥90 → {meal, snack, top-up}**, and records
    "✅ *Code MATCHES*".
  - `PRE-WORKOUT-BUNDLE-DIGEST.md` (the newer ratification) states `TIER_MEAL_MIN = 120`,
    boundaries inclusive at the bottom, `t >= 120 → meal`.
  - D-015 asked only whether **90 itself** falls in the upper band. It did not contemplate moving
    the boundary, so **this is not covered by D-015's pending ruling.**
- **Who it affects:** an athlete with a fueling window of **90–119 minutes** previously got a
  Full Meal occasion and now does not. That is the same population as the 2026-07-21 fix, whose
  own code comment reads: *"These had drifted to 2.5h/1.0h, which denied a full meal to athletes
  eating 1.5-2.5h out (bug, 2026-07-21)."* Moving to 120 re-denies part of that band.
- **Resolution options:** (a) rule that the bundle supersedes H5 for occasions and amend H5 to
  30/120 — one-line spec fix, no code change; (b) rule that occasions stay at 90 while the *carb
  tier shares* use 120, and split the two constants in code; (c) rule the bundle's 120 was only
  ever about carb share allocation and restore `>= 90` for tier membership.
- **Blocking:** `integration_test/flows/recommendation_stacking_flow_test.dart` (from
  `qa/patrol-recommendation-h5-stacking`) asserts the **90-minute** stacking and is therefore
  currently asserting pre-bundle behaviour. It has been brought onto develop but is deliberately
  **NOT wired into either CI target list** until this is ruled — see the note in its header.
- **Conformance:** whichever way it is ruled, the H5 harness needs vectors at exactly 90 and
  exactly 120 min. Today neither spec can adjudicate 90–119.
