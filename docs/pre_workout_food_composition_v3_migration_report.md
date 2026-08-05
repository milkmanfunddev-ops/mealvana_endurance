# Pre-workout formula regeneration — review report

**Generated from:** qa tag `pre-workout-food-composition@v1` → spec `food-composition v3` (RATIFIED 2026-08-05, Xuan) + 87 vectors
**Target:** dev only. Nothing has been applied — this is the pre-approval report.
**Date:** 2026-08-05

| | count |
|---|---|
| Existing standard templates inspected | 30 |
| EDITED (window remap + fibre backfill) | 30 |
| DELETED (hard-gate violation) | 8 |
| NEW | 17 |
| BORDERLINE (left in place, your call) | 4 |
| Net standard pool | 30 → 39 |

---

## Lee — start here

This branch (`data/pre-workout-food-composition-v3`) is a **handoff, not a merge request**.
It is deliberately not merged to `develop` and has no PR. Collect it when you pick this up.

1. **Dev is already carrying this data.** Applied 2026-08-05 via the Supabase Management API,
   not by anything in CI. The state below is live on dev right now — including the breakage.
2. **Six code changes are needed before the app builds and behaves** — see flag #1 immediately
   below. Two of them are Drift columns and block the build outright.
3. **Prod is gated.** `docs/database/apply_all.sql` section 6 carries the gating and the run
   order. It is a pointer, not runnable SQL, so a top-to-bottom paste cannot apply it early.
4. **`apply_all.sql` sections 2 and 3 are still unapplied** and are not mine — a live 22P02 on
   cycling/swim plan generation and a 42703 breaking every profile save. Worth a look while
   you are in that file.

There are two matching intake items in the `ops` repo
(`data/bug-reports/2026-08-05-pre-workout-time-window-remap-…` and
`data/feature-requests/2026-08-05-fuel-hydration-sodium-should-query-template-foods`), but
**that repo has no git remote**, so they are unreachable from anywhere but Xuan's machine.
Everything you need is duplicated here and in `apply_all.sql` section 6 for that reason.

---

## ⚠️ Read these three first

### 1. Selection filters on the time-window **text**, not on category

The brief asked me to confirm filtering is by category. **It is not.** The primary eligibility filter is a
string equality on `time_window`:

- `supabase/functions/generate-macros-v4/pre-workout.ts:492` — `templates.filter(t => t.time_window === timeWindow)`
- `pre-workout.ts:428-430` — `getTimeWindowForPhase()` returns the literals `'1.5-3 hours'` / `'30-90 min'` / `'< 30 min'`
- `types.ts:17` — `export type TimeWindow = '< 30 min' | '30-90 min' | '1.5-3 hours'` (compile-time pin)
- `pre-workout.ts:965, 1033` — pin matching also compares `t.time_window === phaseTimeWindow`
- `lib/features/formula_kit/domain/before_sub_phase.dart:48-52` — Dart `switch` on the same three literals
- `lib/features/formula_kit/presentation/widgets/personal_formula_card.dart:31-33` — display labels

`base_category` is used **only for de-duplication** (`pre-workout.ts:568, 1049` — "don't pick two of the same
category"), never for tier selection.

**Consequence:** the moment the data migration remaps the strings, the edge function's eligible set goes
empty for the meal and snack phases and `BeforeSubPhase.fromTimeWindow` returns `null` — until Lee lands
matching changes in the six places above. **This is a coordinated data + code release, not a data-only
migration.** The structure migration deliberately keeps the legacy values in the CHECK constraint so it can
be applied ahead of time, but the *data* migration must ship with the code.

Saved personal formulas are safe in a different way than assumed: they live in `personal_formulas` /
`personal_templates`, which carry their own `sub_phase` column and never read `pre_workout_templates.time_window`.

### 2. One decision I need from you before applying — H5 vs. the excluded hydration/sodium slices

Three rows fail **H5** ("the top-off must deliver carbohydrate"):

| row | carb | what it is for |
|---|---|---|
| Water | 0 g | Pass 2 `pickDrink` — fluid delivery |
| Electrolyte Tablet | 2 g | Pass 3 `pickElectrolyte` — sodium delivery |
| Electrolyte Packet | 0 g | Pass 3 `pickElectrolyte` — sodium delivery |

The engine runs three passes (`pre-workout.ts:1456, 1487`): food for carbohydrate, then `pickDrink` for
fluid, then `pickElectrolyte` for sodium. These rows exist to serve **hydration** and **sodium** — the two
slices the bundle manifest *explicitly excludes* ("shipped in `pre-workout-macros@v1` — macro quantity, not
food selection"). H5's actual text is about what may be *offered as the top-off carbohydrate item*, not about
what may exist in a table that also feeds the fluid and sodium passes.

Deleting them would strip pre-workout hydration and sodium delivery entirely. **I have left all three in
place and excluded them from the migration.** Per your freeze rule I stopped rather than reach outside the
bundle. Options: (a) leave as-is — H5 becomes an engine-side rule about *carb* candidates only; (b) add a
flag marking them ineligible as carb top-offs; (c) delete and accept the hydration/sodium regression.
**My recommendation is (a)** — it is the reading H5's own wording supports, and it keeps the excluded slices untouched.

### 3. Two NEW columns — Drift needs updating before the app builds

| table | column | why |
|---|---|---|
| `pre_workout_templates` | `fiber_per_serving numeric not null default 0` | H2 is a per-feeding **fibre** gate. The parent table stores carbs/protein/fat but no fibre, so H2 is unevaluable against a template without it. |
| `template_foods` | `food_group text` (CHECK G1…G9) | Layer A §3 is the *primary* recommendation and the §3.10 tier matrix is keyed by food group. Nothing in the schema records group membership today. |

Both are purely additive. No column is renamed or dropped.

**Correction to the bundle's conformance note, item (3):** it states "the shipped food catalog carries no
FIBRE field, so H2 is unenforceable as-is." That is **stale** — `template_foods.fiber_g` exists and is
populated for 52 of 93 foods, including every food used by a standard template. H2 is enforceable on dev
data today, and this report enforces it.

---

## EDITED — all 30 rows

**Window remap** (§2: tiers are meal 240–120 min, snack 120–30 min, top-off 30–0 min):

| from | to | rows |
|---|---|---|
| `1.5-3 hours` | `2-4 hours` | 11 |
| `30-90 min` | `30-120 min` | 11 |
| `< 30 min` | unchanged | 8 |

**Fibre backfill** — `fiber_per_serving` summed from `component_quantities` × `template_foods.fiber_g` for
every surviving row (§4: gates apply to the feeding as assembled, summed across items).

Categories keep their names, as instructed.

---

## DELETED — 8 rows, each on a HARD gate

Parent rows only. Composition is stored inline on the parent (`component_food_names` + `component_quantities`),
so there is **no child table and no orphan risk**.

| # | name | category | window | composition | gate that kills it |
|---|---|---|---|---|---|
| 1 | Fruit Bowl | Fruit Mix | meal | banana 1, dates 3, mixed_berries 0.5 | **H2** fibre 8.9 g > 8 g meal floor |
| 2 | Dates + Banana | Fruit Mix | snack | dates 2, banana 1 | **H2** fibre 6.3 g > 4 g snack floor |
| 3 | Bagel + Peanut Butter | Bagel | snack | bagel 0.5, peanut_butter 1 | **§3.10 matrix** G7 = AVOID at snack; also **H1** fat 8 g > 7 g |
| 4 | Toast + Peanut Butter | Toast / Bread | snack | toast 1, peanut_butter 1 | **§3.10 matrix** G7 = AVOID at snack; also **H1** fat 8 g > 7 g |
| 5 | Rice Cake + Peanut Butter | Rice Cake | snack | rice_cake 1, peanut_butter 0.5 | **§3.10 matrix** G7 = AVOID at snack |
| 6 | Granola Bar | Oats / Granola | snack | granola_bar 1 | **§3.10 matrix** G8 = AVOID at snack |
| 7 | Smoothie (Fruit) | Smoothie | snack | banana 0.5, blueberries 0.5, milk 0.5 | **§3.10 matrix** G8 (raw berries) = AVOID at snack |
| 8 | Coconut Water | Hydration | top-off | coconut_water 1 | **H2** fibre 2.6 g > 2 g flat top-off ceiling |

### Proofreading notes on the deletions

- **#1 Fruit Bowl is a floor-only failure.** 8.9 g fibre passes at 95 kg (ceiling 11.4 g) and fails at 65 kg
  (ceiling 8.0 g). The table has no body-mass dimension, so a row that fails for a 65 kg athlete would still
  be served to them. I deleted it, but this is the one deletion most defensible to reverse — say the word and
  it moves to BORDERLINE. **#2 by contrast fails at every body mass** (6.3 > 5.7 g even at 95 kg).
- **#3–#5 are the same rule three times.** G7 (added fats) is AVOID at the snack tier — this is a Layer A
  matrix rule, and Layer A is *primary* (§0 precedence). It costs three of eleven snack rows, the single
  biggest chunk of shrinkage in this migration. The NEW section adds five snack rows, so the snack pool goes
  11 → 13 rather than shrinking.
- **#8 Coconut Water hangs on one catalog number.** `template_foods.coconut_water.fiber_g = 2.6`. USDA puts
  coconut water fibre at ~2.6 g/cup so I gated on it, but if that value is wrong the row is legal (H6 is fine:
  9 g / 240 ml = 3.75 %, well under the 8 % sustained ceiling). **Worth a second look before applying.**
- Peanut butter survives at the **meal** tier (G7 is LIMITED there) — Bagel + PB + Jam, Toast + PB + Jam and
  Rice Cake + PB + Jam all pass H1 and are untouched.

### User data pointing at deleted rows — NOT cascaded

Per instruction, no user data is touched. Live references that will dangle:

| deleted row | live pins | soft-deleted pins | forked personal formulas |
|---|---|---|---|
| **Granola Bar** | **1** | 1 | 0 |
| Bagel + Peanut Butter | 0 | 1 | 0 |
| Fruit Bowl | 0 | 1 | 0 |
| Smoothie (Fruit) | 0 | 1 | 0 |
| Dates + Banana, Rice Cake + PB, Toast + PB, Coconut Water | 0 | 0 | 0 |

**Total live breakage: one `formula_pins` row** (user `a98cab76…`, pin `d05abb73…`, kind `pre_system`,
pointing at Granola Bar). `personal_formulas` has 9 rows sourced from `pre_system` templates and **all 9 point
at Bagel + Cream Cheese, which survives** — no forked formula loses its source. `personal_templates` has no
forked-formula rows at all.

---

## NEW — 17 rows

Every row is a complete record: all columns populated, `component_food_names` and `component_quantities`
always non-empty, deterministic `uuid5` ids so dev and prod land on the same primary keys. All 17 were
re-checked against every applicable hard gate at 65 kg — **zero failures**. No new `template_foods` rows were
needed; the catalog already carried every food the SSOT names.

### Meal tier — `2-4 hours` (§3.11 canonical meal feedings)

| name | category | composition | C/P/F/fibre (g) | driven by |
|---|---|---|---|---|
| Oatmeal + Banana + Honey | Oats / Granola | oatmeal 1, banana 1, honey 1 | 71.3 / 6.4 / 2.9 / **7.1** | §3.11 meal #1, §7 row 1 |
| Bagel + Jam + Juice | Bagel | bagel 0.5, jam 2, orange_juice 1 | 80.1 / 7.4 / 1.2 / 2.0 | §3.11 meal #2, §7 row 2 |
| Rice + Chicken + Sweet Potato | White Rice | white_rice 1, chicken 0.67, sweet_potato 0.5 | 57.0 / **22.9** / 2.5 / 2.5 | §3.11 meal #3, §7 row 3 |
| Pancakes + Maple Syrup | Pancakes *(new category)* | pancake 2, maple_syrup 2 | 70.8 / 10.0 / **14.0** / 1.0 | §3.11 meal #4 |

- **Oatmeal + Banana + Honey** reproduces §7 row 1 exactly, including its 7.1 g fibre against the 8 g floor —
  the tightest gate in the document. Do not raise the banana or oat quantity.
- **Rice + Chicken + Sweet Potato uses 2 oz chicken, not 3 oz.** §7 row 3 records the 3 oz version *failing*
  H3 at 65 kg (31.2 g vs 26 g) and names 2 oz as the fix. Encoding 3 oz would have shipped a known-failing feeding.
- **Pancakes + Maple Syrup sits at 14.0 g fat against H1's 15 g floor.** Tight by design; a third pancake breaks it.

### Snack tier — `30-120 min` (§3.11 canonical snack feedings)

| name | category | composition | C/P/F/fibre (g) | driven by |
|---|---|---|---|---|
| Applesauce Pouch | Fruit | applesauce_pouch 1 | 11.0 / 0.2 / 0.0 / 1.0 | §3.11 snack #3 |
| Pretzels + Sports Drink | Pretzels *(new category)* | pretzels 1, sports_drink 1 | 38.0 / 2.8 / 1.0 / 0.9 | §3.11 snack #5 |
| Toast + Honey | Toast / Bread | toast 1, honey 1 | 30.0 / 1.9 / 0.8 / 0.6 | §3.11 snack #1 |
| Rice Cake + Honey | Rice Cake | rice_cake 1, honey 1 | 24.6 / 0.8 / 0.3 / 0.4 | §3.11 snack #1 |
| Cereal (Dry) | Cereal | cereal 1 | 24.0 / 2.0 / 0.0 / 1.0 | §3.11 snack #4 |

### Top-off — `< 30 min` (§3.11 canonical top-off feedings)

| name | category | composition | C/P/F/fibre (g) | driven by |
|---|---|---|---|---|
| Energy Gel + Water | Quick Grab | energy_gel 1, water 1 | 25.0 / 0 / 0 / 0 | §3.11 top-off #1, §7 row 8 |
| Banana (Top-Off) | Fruit | banana 1 | 27.0 / 1.3 / 0.4 / **3.1** | §3.11 top-off #4, §7 row 10 |
| Applesauce Pouch (Top-Off) | Fruit | applesauce_pouch 1 | 11.0 / 0.2 / 0.0 / 1.0 | §3.11 top-off #4, vector `h4-applesauce-pouch-t25` |

- **Energy Gel + Water is the canonical top-off** and the existing "Energy Gel" row (gel alone, 20 ml) is not
  it. Gel plus 250 ml chase is ~8 % as mixed in the stomach — §7 row 8.
- **Banana (Top-Off) carries a documented H2 exception.** Its 3.1 g fibre exceeds the 2 g flat top-off ceiling.
  H4 grants a soft low-residue allowance from t−30 to about t−20, "not in the final 15 minutes," and §7 row 10
  asserts PASS on exactly that basis. The waiver is written into the row's `notes` rather than left silent, per
  §11 check 1. **The t−20 cutoff is not representable in the schema** — see ambiguity A4.

### G4b availability at every tier — the v3 ruling (§3.4, §11 check 10)

v3's single rule change is that a sports drink, mix, gel or chew is permitted in the **meal and snack** tiers,
reversing v2. Today every G4b item exists only at `< 30 min`, so the meal and snack phases have no G4b
candidate at all — `pickDrink` has an empty pool outside the top-off. These five rows close that gap:

| name | window | C/P/F/fibre (g) | vector |
|---|---|---|---|
| Sports Drink (Meal) | 2-4 hours | 15.0 / 0 / 0 / 0 | `g4b-sports-drink-meal` |
| Sports Drink (Snack) | 30-120 min | 15.0 / 0 / 0 / 0 | `g4b-sports-drink-snack` |
| Energy Gel (Meal) | 2-4 hours | 25.0 / 0 / 0 / 0 | `g4b-gel-at-meal` |
| Energy Gel (Snack) | 30-120 min | 25.0 / 0 / 0 / 0 | check 10 |
| Energy Chews (Snack) | 30-120 min | 25.0 / 0 / 0 / 0 | check 10 |

These are the rows most worth a sanity read: the SSOT rules them *permitted*, which is not the same as
*recommended as a standalone feeding*. Trim any you think read oddly in the UI — the gates don't require them
individually, only that G4b be available at each tier.

---

## BORDERLINE — left in place, your call

| row | window | issue | why it is not a deletion |
|---|---|---|---|
| **Water** | top-off | fails H5 (0 g carb) | Serves the excluded hydration slice — see flag #2 |
| **Electrolyte Tablet** | top-off | fails H5 (2 g carb) | Serves the excluded sodium slice — see flag #2 |
| **Electrolyte Packet** | top-off | fails H5 (0 g carb) | Serves the excluded sodium slice — see flag #2 |
| **Oatmeal + Raisins** | meal | contains raisins = G9 | G9 is LIMITED (not AVOID) at the meal tier, so it passes. Flagged only because the G9/G3 overlap below could change how raisins are read. |

Also worth noting, though neither is a gate failure:

- **`baked_potato` carries 3.8 g fibre**, which is skin-on. §3.2 is explicit that G2 means "peeled — peeling is
  the whole rule." Potato + Salt still passes H2 at the meal tier (3.8 < 8), so it is not a deletion, but the
  catalog value probably describes the wrong food.
- **Stored macros drift from component sums on 14 of 30 rows.** Examples: Bagel + Jam stores 28 g carb where its
  components sum to 33.4 g; Fruit Bowl stores 90 g against 85.2 g; Oatmeal stores 3 g protein against 5.0 g.
  I did **not** silently correct these — they change fuelling quantities and that is `pre-workout-carbs.md`'s
  remit, not this bundle's. Flagging as a separate data-integrity item.

---

## Spec ambiguities I had to judge

**A1 · Which body mass do the gates run at?** H1/H2/H3 scale with body mass, but a template row has no body-mass
dimension. **Call: gate at the floor (65 kg), which is where H1/H2 sit at their published floors and H3 at
26/13 g.** §11 check 3 makes the gates monotonic non-decreasing in body mass, so anything passing at the floor
passes for every heavier athlete; gating at 95 kg would admit rows illegal for the majority of users. Every
deletion is reported with whether it is floor-only (Fruit Bowl) or universal (all others).

**A2 · G9 overlaps G3 and G8 and the SSOT gives no precedence rule.** §3.9 says the overlap is deliberate;
§11 check 9 asserts every food belongs to exactly one group. The bundle flags this itself — vector
`matrix-groups-are-disjoint`, `status: characterization`, described as "a TRIPWIRE flagging a spec
self-conflict… Do not implement around it — it needs a spec ruling, and resolving it is a v2 of this bundle."
**Call: never delete on a G9-only reading.** Dates read as G9 are AVOID at snack; read as G3 they are FREE.
Dates + Banana is deleted anyway on **H2 fibre**, which is independent of the overlap, so no deletion in this
migration turns on the unresolved rule. The new `template_foods.food_group` column does force a single reading
per food and its comment says so.

**A3 · What is the exact new window string?** You wrote the remap semantically ("1.5 to 3 hours" → "2 to 4
hours"). The DB literals are `'1.5-3 hours'` and `'30-90 min'`. **Call: keep the existing punctuation
convention → `'2-4 hours'` and `'30-120 min'`.** Easy to change; it is one line in each migration plus the six
code sites in flag #1.

**A4 · H4's t−30…t−20 sub-window is not representable.** H4 permits a soft low-residue solid "from t−30 to
about t−20, and not in the final 15 minutes." `pre_workout_templates` has a single `time_window` of `< 30 min`
with no sub-range column. **Call: insert Banana (Top-Off) with the constraint recorded in `notes` rather than
add a column**, since the engine has nowhere to consume a sub-range today. Vector `h4-banana-too-late-t10`
expects FAIL at t−10 and **nothing in the schema can express that** — worth a column if H4 is to be enforced
rather than documented.

**A5 · `coconut_water` is in no food group.** Not named anywhere in §3.1–§3.9. Not G4b (not engineered sports
carbohydrate), not G3 (2.6 g fibre, so not "pulp-free"). **Call: leave `food_group` NULL and let H2 decide** —
which deletes it. See the caveat under deletion #8.

**A6 · Is `electrolyte_drink_mix` a G4b item?** It carries 15 g carbohydrate, so it passes H5 and reads as
"sports drink powder mixed to label strength" (§3.4). **Call: G4b, and it survives.** Its sibling
`electrolyte_tablet` (2 g) does not, and is held in BORDERLINE.

**A7 · Gate evaluation order.** The SSOT specifies none; the vectors declare an oracle convention (matrix, H4,
H5, H6, H1, H2, H3, H7) and flag it as "challengeable, not settled." **Call: followed the vectors' order.** It
only affects *which* gate is named when a row fails more than one — no row's pass/fail verdict changes.

**H7 ("nothing untried") is not evaluable here.** It is a per-athlete property, not a property of a standard
template, so no row is judged against it.

---

## Files

| file | what |
|---|---|
| `supabase/migrations/20260805120000_pre_workout_food_composition_v3_structure.sql` | CHECK widening + 2 new columns + index. Additive only. |
| `supabase/migrations/20260805120100_pre_workout_food_composition_v3_data.sql` | 79 food-group assignments, window remap, 8 deletes, 30 fibre backfills, 17 upserts. |

Both carry a provenance header naming the tag and spec version. Every statement is idempotent: `add column if
not exists`, `drop constraint if exists`, `delete … where name =`, and `insert … on conflict (id) do update`
with deterministic uuid5 ids — so the pair replays cleanly on prod.

**Not yet applied to dev.** Awaiting approval.

---

## Appendix — deviation to log in `qa/DEVIATIONS.md`

Ruling by Xuan, 2026-08-05: leave the meal tier without a G4b item and log the divergence rather
than invent a feeding to satisfy the conformance check.

This file cannot be written from the app repo (qa is read-only here). **D-017 is the next free id**
as of 2026-08-05. Paste the block below into `qa/DEVIATIONS.md`.

> **Note the inversion.** Every existing entry logs *code doing something the SSOT never ratified*.
> This one is the reverse: the SSOT ratified a rule and the product **deliberately declined to
> implement it**. Same register, opposite direction — worth a moment's care when reading it back.

```markdown
## D-017 — Meal tier ships no G4b item; v3's one rule change is not implemented in data
- **Status:** `documented` (2026-08-05). SSOT deliberately NOT evolved; data deliberately NOT
  conformed. This is a product ruling, not a defect.
- **Observed:** after the food-composition v3 data migration, `pre_workout_templates` contains
  **no meal-tier row containing a G4b item** (sports drink, drink mix, gel, chews). Five standalone
  G4b rows were created and then dropped the same day — `Sports Drink (Meal)`, `Sports Drink
  (Snack)`, `Energy Gel (Meal)`, `Energy Gel (Snack)`, `Energy Chews (Snack)`.
- **Data:** `app/supabase/migrations/20260805143000_pre_workout_drop_standalone_g4b_meal_snack.sql`
  (branch `data/pre-workout-food-composition-v3`). Applied to DEV 2026-08-05.
- **SSOT status:** directly contradicts **§3.4's v3 ruling** ("a sports drink at label strength is
  permitted in every tier") as operationalised by **§11 check 10** ("G4b is permitted in all three
  tiers. A test asserting a sports drink is unavailable at the meal or snack tier is pinning the
  superseded rule"). v3 changed exactly one rule, and this is that rule.
- **Why the product declined:** a row in `pre_workout_templates` must be a **standalone-sufficient**
  feeding for its window — the engine does not stack two formulas inside one window, so a row must
  answer the window alone. A sports drink is 15 g of carbohydrate and a gel is 25 g; neither is a
  meal, and `Sports Drink (Meal)` came to 210 kcal against §2's ~240–960 kcal meal band. §3.4's
  ruling is a statement about what a composed feeding **may contain**, not a licence to publish each
  G4b item as a feeding in its own right. **Permission is not sufficiency.**
- **Note also** that v3 permitted G4b at the meal tier on the grounds that *nothing forbids it*
  (§3.4: "no pre-exercise concentration evidence base to invoke at 30 min–4 h") — an absence of
  objection, not a positive recommendation. Fabricating a feeding no athlete would eat, purely to
  satisfy check 10, is the "false precision" failure §0 warns against.
- **Scope — snack tier does NOT diverge:** G4b remains represented at the snack tier through
  `Pretzels + Sports Drink` (38 g carbohydrate), which is §3.11 canonical snack #5. Only the **meal**
  tier is affected.
- **Conformance:** check 10 will FAIL against this data at the meal tier. There is no vector to mark
  `characterization` yet — this slice has no harness (see the bundle's conformance note: no engine,
  no runner). When one is built, the meal-tier half of check 10 must be pinned as a characterization
  vector rather than allowed to pass.
- **Open:** decide at the next food-composition revision whether to (a) keep the product rule and
  narrow check 10 to "G4b may appear in a composed feeding at any tier", or (b) add a composed
  meal-tier formula carrying a G4b item. The candidate considered and not taken was
  `Toast ×2 + jam + sports drink` (248 kcal, 54 g carb, 1.6 g fat, 1.4 g fibre) — the smallest
  invention, since §3.11 already blesses "white toast + jam, with a small glass of juice".
```
