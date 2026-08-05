# SSOT — Pre-Workout Sodium

**Status: RATIFIED v3 (Xuan, 2026-08-03).** Supersedes v2 RATIFIED (Xuan, 2026-07-30).
**Engine:** sodium fields of `OfflineMacroCalculator.calculatePreWorkoutHydration`, mirrored by the
`generate-macros-v4` edge function. **Code implements v1 (450/150/0 mg) — not this spec.**
**Reasoning, close calls and concerns:** [`pre-workout.notes.md`](./pre-workout.notes.md).
**What is still open:** [`pre-workout.OPEN-QUESTIONS.md`](./pre-workout.OPEN-QUESTIONS.md) — the
ratification register.

> **Mealvana does not set a pre-workout sodium target.**
> This is a deliberate decision, not an omission.

**v3 changes no behaviour.** `sodiumMg` stays `null` everywhere. What v3 adds: the mechanism behind
the qualitative copy, per-tier sourcing now that the plan has tiers, and one **explicit non-goal**
that did not need stating when there was a single fluid number.

## The rule

```
sodiumMg = sodiumLowMg = sodiumHighMg = null      # in every tier, and on the gate path
```

- **`null`, not `0`.** Zero is a recommendation ("consume no sodium"); null means no target is set.
  A consumer that cannot distinguish them will misreport this.
- No bands, no gate branch. Time-to-workout, body weight, duration, temperature and
  `hydrationCheck` do **not** affect pre-workout sodium, because there is no pre-workout sodium
  output.

## Non-goal — contractual

**Sodium exists here to help retain a euhydrating dose. It is never a reason to raise `fluidMl`.**

Retaining what you drink (euhydration) and deliberately expanding body water or plasma volume
(hyperhydration) are different targets — the second *reduces* plasma osmolality rather than
maintaining it. They are also the same lever at different doses: J&G fig. 9.15 (Shirreffs 1996)
shows the **same fluid volume** leaving mild dehydration at 23 mmol/L sodium and achieving
**hyperhydration** at 61 mmol/L.

Hyperhydration has unstable evidence, a transient effect, a doping history, and a risk profile that
matches this product's users. Thomas 2016:

> "Over-hydration is typically seen in recreational athletes since their work outputs and sweat
> rates are lower than competitive athletes, while their opportunities and belief in the need to
> drink may be greater."

**Any future change that couples sodium to a larger fluid target crosses that line. Reject it at
review.** Notes §2.12.

Note this is *not* an argument against the qualitative copy: sodium trades a dangerous failure mode
(dilutional hyponatremia) for a benign one (fluid overload). Notes §5.12.

## Sodium by tier

The plan is delivered in three tiers (`pre-workout-carbs.md`). Sodium's treatment differs by tier
but **no tier gets a number.**

| Tier | Where sodium comes from | Engine action |
|---|---|---|
| `meal` | The food itself. All three sources place pre-exercise sodium **with food** | none — do not strip salt from meal-tier items |
| `snack` | The food itself | none |
| `top_off` | **The carbohydrate-electrolyte solution itself.** `pre-workout-carbs.md` names a 6–8 % CE drink as the preferred top-off item, and it carries sodium natively | none — do not strip electrolytes from top-off items |

The food selector MUST NOT treat a salted item as a defect — *potato and salt* is doing its job.
Delivered sodium is reported, not targeted.

**The top-off question is CLOSED (Xuan, 2026-08-03).** It narrowed in v3 — hydration no longer
places fluid in the top-off tier when a snack window exists, so the only liquid there is the
carbohydrate chase — and the carbohydrate spec then answered it: a 6–8 % CE solution delivers the
tier's carbohydrate and its sodium in one product. **No number attaches to that sodium.** It is
reported as delivered, exactly like the meal and snack tiers' food-borne sodium.

**And it earns no retention claim.** Maughan 2016's beverage hydration index puts a sports drink at
**the same retention as plain water** — only oral rehydration solution and milk beat it. So the CE
drink is the right top-off because of *carbohydrate and emptying rate*, not because it holds fluid
in. Do not let the qualitative retention copy migrate onto it. Notes §4.4, §5.15.

## What is still produced

| | Behaviour |
|---|---|
| **Delivered sodium** | The BEFORE phase reports the sodium its foods contain. An observed total, not a target — display without a range bar, a target marker, or an in-range/out-of-range state. |
| **Qualitative copy** | *"A salty snack or an electrolyte drink with your pre-run fluid helps that fluid stay in."* Supported in words by both current position statements; not a computed quantity. |
| **During-workout sodium** | Unaffected. See `during-workout-sodium.md`. |

**Do not quantify the copy.** A typical sports drink carries 10–25 mmol/L sodium; the rehydration
studies demonstrating the retention effect used **77 mmol/L** — three to seven times higher. The
copy may say sodium helps; it may not promise the studied magnitude. Notes §4.4.

## Invariants (conformance must assert all)

1. `sodiumMg`, `sodiumLowMg`, `sodiumHighMg` are `null` in every tier and on the gate path.
2. Never `0`. A `0` in any of the three fields is a failure, not a pass.
3. No input — body weight, duration, temperature, lead time, tier, `hydrationCheck` — changes any
   of the three.
4. Delivered-sodium reporting is present and is not compared against a target.

## Constants — basis and confidence

| Constant | Value | Basis | Confidence |
|---|---|---|---|
| Pre-workout sodium target | **none** | Both current position statements affirm the mechanism and decline to quantify it | **High** |
| Sodium aids fluid retention | qualitative | Thomas 2016: *"Sodium consumed in pre-exercise fluids and foods **may** help with fluid retention"* | **High** |
| Mechanism (osmolality → diuresis) | qualitative | J&G 2019 ch. 9 | **High** |
| Sodium belongs with food | — | Thomas 2016 (*"fluids and foods"*), ACSM 2007 (*"salted snacks… at meals"*), J&G p. 252 | Medium |
| A sports drink does **not** out-retain water | — | **Maughan 2016** (beverage hydration index): sports drink BHI ≈ water; only ORS and milk exceed it. Bounds the qualitative copy | **High** |
| Hyperhydration is a non-goal | — | Thomas 2016 (over-hydration risk profile); J&G ch. 9 (evidence unstable, effect transient) | **High** |
| 20–50 mEq/L | **not used** | Sawka 2007 only — superseded for dosing | — |

## Literature

- **Thomas DT, Erdman KA, Burke LM.** *ACSM Joint Position Statement.* Med Sci Sports Exerc.
  2016;48(3):543–568. Its complete statement on pre-exercise sodium:
  > "Sodium consumed in pre-exercise fluids and foods may help with fluid retention."

  On hyperhydration:
  > "Although some athletes attempt to hyper-hydrate prior to exercise… the use of glycerol and
  > other plasma expanders for this purpose is now prohibited by the World Anti-Doping Agency"

  *(Stale on one point — glycerol was removed from the WADA list in 2018. Notes §5.9.)*

- **McDermott BP, et al.** *NATA Position Statement.* J Athl Train. 2017;52(9):877–895.
  Recommendation 18, **SOR: B** — affirms the mechanism, gives no number:
  > "Pre-exercise sodium ingestion can expand vascular fluid volumes… Sodium supplementation before
  > and during exercise should be individualized based on specific losses and needs and should be
  > practiced."

- **Jeukendrup A, Gleeson M.** *Sport Nutrition.* 3rd ed. 2019. **Mechanism only.** Ch. 9:
  > "Because sodium is the major electrolyte in the extracellular fluids (accounting for 50% of
  > plasma osmolarity)… Even small reductions in plasma osmolarity invoke a marked increase in urine
  > output (diuresis)."

  > "Plasma volume is more rapidly and completely restored if some sodium chloride (77 mmol/L) is
  > added to the water consumed (Nose et al. 1988)."

  **Scope caveat:** that is the **post-exercise rehydration** section, and it states its own
  boundary conditions — *"when rapid and complete restoration of body fluid balance is necessary
  **and when all intake is in liquid form**."* Neither holds pre-workout. Notes §4.4.

  **Do not propagate the book's "77 mmol/L or 0.45 g/L".** 77 mmol/L NaCl is **4.5 g/L**; the
  printed figure is off by a factor of ten.

- **Maughan RJ, et al.** *A randomized trial to assess the potential of different beverages to
  affect hydration status: development of a beverage hydration index.* Am J Clin Nutr.
  2016;103(3):717–723. Thirteen beverages against still water. **Oral rehydration solution, full-fat
  milk and skimmed milk retained better than water; sports drink, cola, juice, tea, coffee and beer
  did not.** Bounds what the qualitative copy may promise for an electrolyte drink.

- **Sawka MN, et al.** *ACSM Position Stand.* Med Sci Sports Exerc. 2007;39(2):377–390.
  Superseded for dosing. Sole source of the 20–50 mEq/L figure v1 rested on (Before Exercise
  section, p. 384, verified verbatim) — **do not cite it for a sodium number.** *(Its urine-check
  branch is cited by `pre-workout-hydration.md` for a different reason — see notes §2.4.)*

## Conformance

Vectors: `qa/vectors/fueling/pre-workout-sodium.json` — **all 7 pin v1 and are obsolete.**
Replace with assertions that the three sodium fields are `null` in every tier and on the gate path,
and that no input — including `hydrationCheck` — perturbs them.
Runner: `qa/conformance/run_dart.sh pre-workout-sodium`.
