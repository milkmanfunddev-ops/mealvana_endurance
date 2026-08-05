# Pre-workout formula regeneration — review report

**Generated from:** qa tag `pre-workout-food-composition@v1` → spec `food-composition v3` (RATIFIED 2026-08-05, Xuan) + 87 vectors
**Target:** dev only. **APPLIED to dev 2026-08-05** and verified. Prod is gated — see `apply_all.sql` section 6.
**Date:** 2026-08-05

| | count |
|---|---|
| Existing standard templates inspected | 30 |
| EDITED (window remap + fibre backfill) | 30 |
| DELETED (hard-gate violation) | 8 |
| NEW | 17 added, then **5 dropped** — see the G4b subsection | 
| BORDERLINE (left in place, ruled on) | 4 |
| Net standard pool | **30 → 34** |

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

### Your two Notion records

Both were filed 2026-08-05. **One of them is a Sprint Task already assigned to you.**

| record | board | what |
|---|---|---|
| [Pre-workout `time_window` remap empties the meal and snack template pools](https://app.notion.com/p/Pre-workout-time_window-remap-empties-the-meal-and-snack-template-pools-full-budget-silently-lands-3b3e3fdb754c81779170e48d5ff08d98) | 🐛 Bug Reports, New | the six code sites in item 2 above |
| [Repoint `pickDrink`/`pickElectrolyte` at `template_foods`, then drop the six ingredient rows](https://app.notion.com/p/Repoint-pickDrink-pickElectrolyte-at-template_foods-then-drop-the-six-ingredient-rows-water-elec-3b3e3fdb754c817b9c8dc46d7d161458) | ✅ Sprint Tasks — **Lee, To Do** | flag #2 below; unblocks deleting Water / Electrolyte Tablet / Electrolyte Packet |

Everything actionable is also duplicated in this document and in `apply_all.sql` section 6, so the
branch stands alone if you are working offline.

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

### 2. H5 vs. the excluded hydration/sodium slices — RULED: rows stay, repoint is your Sprint Task

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

Deleting them would strip pre-workout hydration and sodium delivery entirely, so **all three are still in
the table** — a deliberate hold, not an oversight.

**Ruling (Xuan, 2026-08-05):** leave them for now. The real fix is structural and is your Sprint Task —
repoint `pickDrink` at `template_foods where is_drink_pool` and `pickElectrolyte` at
`template_foods where is_electrolyte` / `sodium_top_up_eligible`. Those columns already exist and are
populated, so it needs no schema work. **Once both passes are off this table, the six ingredient-shaped
rows can be dropped and H5 becomes enforceable literally, with no hydration/sodium regression.**

Until then the formula table cannot be cleanly conformed to its own SSOT — every future pre-workout
ratification hits the same collision, and each time the safe move is to hold rows back rather than enforce
the gate. That is the argument for doing the repoint rather than living with it.

*(`Electrolyte Packet` also has an empty `component_food_names` — a parent with no composition. Pre-existing,
and it disappears with the repoint.)*

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

> ### ⚠️ These five rows were created and then DROPPED the same day. They are not in the database.
> Migration `20260805143000_pre_workout_drop_standalone_g4b_meal_snack.sql` removes them.
> The table below is kept as the record of what was tried and why it was wrong.

**Why they were added (a misreading):** check 10 was read as requiring the *catalog* to contain a G4b
item at each tier. It does not — it requires the **engine** to permit one. See the appendix.

**Why they were dropped (the real reason):** a row must be a **standalone-sufficient** feeding for its
window; the engine does not stack two formulas inside one window. A sports drink is 15 g of carbohydrate
and a gel is 25 g. `Sports Drink (Meal)` came to 210 kcal against §2's ~240–960 kcal meal band.
**Permission to appear in a composed feeding is not sufficiency as a feeding.**

| name | window | C/P/F/fibre (g) | vector |
|---|---|---|---|
| Sports Drink (Meal) | 2-4 hours | 15.0 / 0 / 0 / 0 | `g4b-sports-drink-meal` |
| Sports Drink (Snack) | 30-120 min | 15.0 / 0 / 0 / 0 | `g4b-sports-drink-snack` |
| Energy Gel (Meal) | 2-4 hours | 25.0 / 0 / 0 / 0 | `g4b-gel-at-meal` |
| Energy Gel (Snack) | 30-120 min | 25.0 / 0 / 0 / 0 | check 10 |
| Energy Chews (Snack) | 30-120 min | 25.0 / 0 / 0 / 0 | check 10 |

**Net effect:** the meal tier ships no G4b item. That is a deliberate curation choice and needs no
deviation entry — `pre_workout_templates` must *conform* to the SSOT, not *exhaust* it. The snack tier
still carries G4b through `Pretzels + Sports Drink` (38 g carb, §3.11 canonical snack #5).

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

**Applied to dev 2026-08-05**, in this order:

| # | file | what |
|---|---|---|
| 1 | `20260805120000_..._v3_structure.sql` | CHECK widening + 2 new columns |
| 2 | `20260805120100_..._v3_data.sql` | groups, remap, 8 deletes, fibre backfill, 17 inserts |
| 3 | `20260805143000_pre_workout_drop_standalone_g4b_meal_snack.sql` | drops the 5 standalone G4b rows |

Verified against live dev: 34 rows, 0 unexpected hard-gate violations.

---

## Appendix — no deviation entry is needed (withdrawn 2026-08-05)

An earlier revision of this report staged a `D-017` entry for `qa/DEVIATIONS.md`, claiming that
dropping the standalone G4b rows put the data in conflict with §11 check 10. **That was wrong and
is withdrawn.** Do not paste it; it was never applied to the qa repo.

**The conformance vectors test a suitability function, not the Supabase catalog.** The evidence is
in the vectors themselves: `matrix-G4b-meal` takes `{tier, foodGroup, gutTolerance}` and asserts
`{available: true, rating: "FREE"}` — a pure function of the §3.10 table. `g4b-sports-drink-meal`
passes summed macros straight in. No vector reads `pre_workout_templates`, `engine` is `null`, and
the vectors' own note says food-to-macro lookup "is a separate food-database concern." The bundle
manifest puts the future entry point in app code, which is what a harness will exercise.

So check 10 asserts that **the engine must permit** a G4b item at the meal tier. It does not
require the catalog to **contain** one. `pre_workout_templates` is a curated subset that must
*conform* to the SSOT, not *exhaust* it — a formula the product chooses not to publish is a
curation decision, entirely outside the SSOT's remit and outside the deviation register's purpose
("behaviors the SSOT has NOT ratified").

The same misreading is why the five standalone G4b rows were created in the first place (see the
NEW section above, which cites check 10 as the driver). With check 10 correctly scoped, there was
never a conformance reason to add them, and the standalone-sufficiency rule that removed them
stands on its own with no SSOT tension.
