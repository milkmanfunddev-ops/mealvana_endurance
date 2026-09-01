# SSOT — Pre-Workout Food Composition

**Status: RATIFIED v3 (Xuan, 2026-08-05).** Supersedes RATIFIED v2 (Xuan, 2026-08-05); v1 PROPOSED
(2026-08-03) withdrawn unratified.

> **v3 changes exactly one rule.** A sports drink, drink mix, gel or chew (**G4b**) is permitted in the
> **meal and snack tiers**, not only the top-off — reversing a v2 ruling. It is a common, familiar
> item, it clears every hard gate by the widest margin in the document, and no pre-exercise
> concentration evidence exists to restrict it. Touched: §3.4, the §3.10 matrix, a canonical snack in
> §3.11, H6's scope note, one row of §8, and check 10. **Nothing else in v2 is altered.**

**What ratification covers:** the nine food groups and their tier ratings (§3), the seven hard gates
(§5), the six soft scores (§6), and the rulings recorded at §3.4 (sports drink permitted in every
tier) and H6 (the 8 % ceiling, accepted as a design line, scoped to the top-off).
**Scope:** what a pre-workout feeding should be *made of*. **Not** how much — carbohydrate quantity is
[`pre-workout-carbs.md`](./pre-workout-carbs.md), fluid is [`pre-workout-hydration.md`](./pre-workout-hydration.md),
sodium is [`pre-workout-sodium.md`](./pre-workout-sodium.md).
**Source ranking rules:** [`../source-authority.md`](../source-authority.md).
**Open items and cross-file debts:** §9. None block this document; one is a watch item on a single
citation, the rest are defects recorded against sibling specs.

> **Read §0 before anything else.** This document has two layers and they are not equal. The food
> groups are the recommendation. The formulas are a fallback for foods the groups don't cover. When
> they disagree, **the groups win and the formula is wrong.**

---

## 0 · How to use this document

v1 of this file inverted the layers: it led with per-item percentage thresholds and treated the
cited food list as illustration. Applied to real foods, those thresholds rejected oatmeal, toast,
bagels, bananas and every form of lean meat — all of which the source list explicitly endorses. The
formulas were allowed to overrule the evidence. That is fixed here by making the precedence explicit.

| Layer | What it is | Authority | Use it when |
|---|---|---|---|
| **A — food groups** (§3) | Named groups of foods, each rated per tier | **Primary.** This is the form the literature actually supports | Always. This is the answer. |
| **B — formulas** (§4–§6) | Hard gates and soft scores | **Secondary.** Operationalises A for foods A doesn't name | A food isn't in any group, or a composed feeding needs checking |

**Precedence rule.** If Layer B rejects a food that Layer A rates acceptable for that tier, **Layer A
wins and Layer B has a bug**. Log it, don't work around it. The reverse — B rejecting something A
also dislikes — is B doing its job.

**Two failure modes this document is built to avoid.** First, *false precision*: publishing a number
because a number is convenient, when the corpus is qualitative. Every invented figure below is
tagged **[design]**. Second, *borrowed authority*: citing a source for a stronger claim than it
makes. §8 records, per source, what it actually says — including several places where the popular
version of a claim is contradicted by the document usually cited for it.

---

## 1 · The physiological spine

Everything in §3–§6 descends from five facts. They are given first so the rules can be argued with.

### 1.1 · Emptying is clamped to a roughly constant calorie delivery rate

The stomach does not release a meal at a fixed *volume* per minute; it meters *calories* into the
duodenum at a roughly constant rate. Brener 1983 gave glucose at three concentrations spanning a
five-fold range and all three emptied at **2.13 kcal/min**. The reciprocal measurement from the
duodenal side — intraduodenal glucose inhibiting saline emptying at 0.46 min/kcal — independently
implies 2.17 kcal/min. Calorie-free saline, by contrast, empties rapidly and exponentially: the
clamp is a *nutrient* feedback mechanism and simply does not engage without energy.

**The consequence that organises this whole document: the primary determinant of how long a feeding
occupies the stomach is its total energy, not its macronutrient ratio.** A tier is therefore first
and foremost an energy budget, and only secondarily a composition rule.

**What this fact will not bear.** Brener measured *liquid glucose* in *resting* subjects. Do not
present a clearance time as a computed fact. Four reasons, roughly in order of how badly they bite:

1. **Solids have a lag phase.** Solid food must be ground to ~1–2 mm before it passes the pylorus.
   Real emptying is *lag, then near-linear* — so a solid meal takes longer than `kcal ÷ rate`.
2. **The rate is volume-dependent, so the constant isn't constant.** Emptying rate rises with
   ingested volume: 400 kcal in 1000 ml clears calories faster than 400 kcal in 200 ml.
3. **The clamp is real but incomplete, and the literature range is 2–4 kcal/min, not 2.13.** Energy-
   dense meals produce *"an increased rate of delivery of energy to the duodenum"* — Hunt & Stubbs
   say so themselves — and measured caloric delivery rose roughly two-and-a-half-fold across a
   0.1 → 0.7 kcal/ml range in Calbet & MacLean. The stomach compensates for density; it does not
   fully cancel it. Use the band: a 400 kcal meal is 100–200 minutes, which is a 2× answer, not an
   answer.
4. **An empty stomach is the wrong target.** Athletes report distress from residual *volume and
   distension*, not from a non-zero calorie count. Optimising to zero over-restricts.

**Ruling: the energy budget is a soft score (S1), never a hard gate.** Anything else claims a
precision the measurement doesn't have.

### 1.2 · Energy dominates; the macronutrient ranking is second-order and genuinely contested

This is where v1 went wrong twice, so it is worth stating carefully.

The popular claim is that fat is a uniquely powerful brake on gastric emptying, and that the ranking
runs carbohydrate → protein → fat. **No single study supports that three-way ranking at matched
energy, and the best-controlled experiments disagree with each other about the direction.** What
follows is what can actually be defended.

**Energy dominates, and this is the well-replicated part.** Hunt & Stubbs pooled 33 studies across
meal volumes of 50–1250 ml and found that *"the greater the nutritive density of a meal, the less was
the volume transferred to the duodenum in 30 min"*, while the meal's original volume was **not** a
determinant of emptying rate. Their conclusion is the sentence this document rests on: the data were
*"consistent with equal slowing of gastric emptying by the duodenal action of the products of
digestion of isocaloric amounts of fat, protein and carbohydrate"* — their worked example being 4 g
of fat against 9 g of carbohydrate, both about 36 kcal. Two independent confirmations: isocaloric
*and* isovolumic milk against orange juice emptied identically at both 220 and 330 kcal, and in
primates isocaloric glucose, casein hydrolysate and MCT oil all emptied at the same rate. *Caveat
worth carrying: Hunt & Stubbs is a cross-study pooled regression, and the authors hedge to
"consistent with", not "demonstrates."*

**The contrary evidence is real and should not be buried.** An isocaloric, isovolumic comparison
(450 ml and 280 kcal in both arms) found a concentrated whey load emptying far more slowly than a
carbohydrate-plus-fat mixture — T50 **58 ± 31 against 23 ± 8 min, p < 0.001** — replicated in older
men. An isoenergetic 2.5 MJ high-fat meal emptied more slowly than a high-carbohydrate one
(p < 0.02). Against those, the MRI study v1 actually cited found fat and protein emptying **faster**
than glucose in the early phase, with volume curves thereafter *"uniform for all macronutrients"*.
So v1's citation was not merely the wrong paper — it was contrary evidence.

**The finding that reconciles them is about structure, not macronutrients.** Fat emulsions matched
for energy, volume *and* macronutrient, differing only in whether they stay emulsified in stomach
acid, empty about **two-fold** differently: the acid-unstable emulsion creams and layers and leaves
faster, the stable one stays homogeneous, empties slower, and releases more CCK. At constant energy
and constant macronutrient, physical form moves emptying more than the macronutrient identity does
in most of the studies above. That also explains the pattern in the literature — matched *liquid*
studies find little macronutrient effect, while solid and mixed-meal studies find fat slower.

**What survives, and what the rules are allowed to lean on:**

- **Fat's dominant liability is energy density.** At 9 kcal/g against carbohydrate's 4, a gram of fat
  spends 2.25× as much of the tier's energy budget. This is arithmetic, it is uncontroversial, and it
  is the reason H1 exists.
- **There is a genuine per-calorie fat signal on top of that**, of unestablished magnitude. Fatty
  acids longer than C12 release cholecystokinin, which inhibits emptying via vagal afferents bearing
  CCK-1 receptors; the chain-length dependence proves receptor-mediated signalling rather than a bulk
  effect.
- **The brake is not fat-specific.** Carbohydrate perfused into the distal ileum also potently
  inhibits emptying, via PYY — and PYY immunoneutralisation does *not* blunt fat's inhibition. Two
  signals, same output.
- **Food structure is a first-class variable** and this document handles it through form (H4) and
  through the refined/low-residue group rules, not through a macronutrient number.

**Consequence for rule design, stated so nobody re-derives the wrong lesson: do not build a
macronutrient ranking into the gates.** H1 caps fat on the energy-density argument, H3 caps protein
on a tolerance study, and neither claims that a gram of one empties slower than a gram of another.
The one place the evidence is strong enough to gate on is *form* (H4), and the one place it is
strong enough to score on is *total energy* (S1) — which is advisory precisely because §1.1's rate is
a band.

**On protein, v1's central inference is withdrawn.** v1 argued that because the clinical
gastric-emptying reference meal is 24 % protein and empties normally, protein must be the least
restrictive macronutrient. That does not follow: a diagnostic reference standard is chosen for
reproducible radiolabelling and low fat, and its macro split was never validated as a tolerance
threshold. 24 % of 255 kcal is about 15 g — an absolute dose far below a real pre-workout meal, and
percentage composition does not survive a 3–4× change in meal energy.

**What replaces it — and it is a stronger warrant than v1 had.** Protein belongs in the meal tier
because the top-authority position stand **actively recommends it**, not merely tolerates it. Thomas
2016 lists *"including a protein source at the meal"* among the strategies for blunting the insulin
rebound that pre-exercise carbohydrate can provoke. On top of that: the doses involved are small,
whey up to **0.4 g/kg** was tolerated before a 10 km run at 85 % of race pace, and pre-exercise
protein has **no acute endurance performance effect** either way — so there is nothing to trade
against comfort. Read the 0.4 g/kg correctly: it is the highest dose *tested* without distress,
**not a demonstrated ceiling**.

The same stand bounds it in the other direction — *"low–moderate protein content"* is the preferred
pre-event profile. Low–moderate, not absent, is exactly what H3 encodes.

### 1.3 · Fibre's pre-exercise problem is downstream of the stomach, and solubility is the wrong axis

v1 placed fibre alongside fat as a gastric-emptying inhibitor, "one step behind." That ordering does
not survive the evidence, and the reason is more interesting than a simple correction.

**Solubility is a poor predictor of anything functional.** McRorie & McKeown's 2017 review exists
specifically to retire the soluble/insoluble split: clinical effects track **viscosity and
gel-formation** on one axis and **fermentability** on another, and neither maps onto solubility.
Many soluble fibres — inulin, wheat dextrin, partially-hydrolysed guar — are non-viscous and behave
nothing like psyllium.

**Viscous fibres can delay emptying, but not at the doses food delivers.** The positive trials are
real and dose-dependent: 3.6 g of high-molecular-weight oat β-glucan moved gastric half-time from
61.9 to 78.9 min, and an elegant same-fibre/same-dose design showed high-MW β-glucan delayed
emptying while **low**-MW at 4 g did not — isolating viscosity as the causal variable. But at
ordinary food doses the nulls are consistent: 5 g of guar, ispaghula *or* cellulose changed nothing;
4 g of oat β-glucan in muesli changed nothing; 7.4 g of psyllium changed neither the solid nor the
liquid phase.

**Insoluble fibre does not meaningfully change gastric emptying**, and the widespread claim that
wheat bran *accelerates* it is a conflation with small-bowel and whole-gut transit, where bran's
effect is genuine and well established. The cleanest citation is Rydning 1985, which found a bran
effect on an unvalidated monitor and none by gamma camera — and whose authors disowned the method
that produced the positive signal.

**And meal energy beats fibre anyway.** Marciani's 2×2 MRI design separated the two: raising nutrient
content delayed emptying from 46 ± 9 to 76 ± 6 min, while raising viscosity had a smaller effect and
drove *fullness* rather than emptying. That is §1.1's spine confirmed from a second direction, and it
is decisive for rule design — **at a 2–4 hour lead time the gastric-emptying argument for limiting
fibre is largely moot**, because the largest documented fibre effect (~+17 min) is smaller than the
nutrient effect (~+30 min) and both are small against the window.

**So what is the fibre rule actually for?** Lower-gut symptoms, and the mechanism is fermentation,
not retention. Bianchi & Capurso is the cleanest demonstration: at 5 g, the two *soluble* fibres
significantly raised abdominal symptoms against control (guar p = 0.009, ispaghula p = 0.048) while
*insoluble* microcrystalline cellulose caused the fewest, gas production correlated with symptom
severity (r = 0.38, p = 0.01) — and gastric emptying did not differ at all. The symptoms were
generated distally.

Three consequences carry into the rules:

1. **H2 is a symptom control, not an emptying control**, and must never be justified by the emptying
   argument. It is a coarse cap on total fibre because total fibre is what a food label reports.
2. **Fermentability is the sharper axis** (§1.4), which is why G9 exists as a separate group cutting
   across G1–G8 rather than as a fibre subheading.
3. **Fermentability is not a complete predictor either.** Psyllium is poorly fermented and still
   raised symptoms, so bulk and water-holding contribute independently. Do not overfit to FODMAPs.

**No sports-nutrition source publishes a pre-exercise fibre limit in grams**, and no trial has
compared a soluble- against an insoluble-fibre pre-exercise meal for symptoms *during* exercise. The
strongest quantitative evidence is behavioural — 23 % of runners self-report avoiding high-fibre food
before running. The nearest clinical anchor, low-residue diets at **<10–15 g/day**, is a *daily*
figure for a *different* purpose. Every fibre gram in §5 is therefore **[design]**, and the clinical
term "residue" is deliberately avoided because there is no accepted method to quantify it.

### 1.4 · FODMAPs are the sharper tool, and they are handled by elimination

Where fibre is a blunt proxy, the fermentable-carbohydrate account is specific and better evidenced.
Short-term low-FODMAP eating before competition reduced GI symptom incidence and severity, with
**82 %** of participants improving — largest effects on flatulence, urge to defecate, loose stool and
diarrhoea. **24 hours** was sufficient in the heat-exercise work; 6+ days is the more common research
protocol.

Two things follow. First, **there is no gram target** — in either the athlete or the clinical
literature the diet is implemented by *eliminating named foods*, so any FODMAP number this document
published would be invented. Second, the literature explicitly frames this as a **targeted, not
chronic** strategy, used in the days before competition or hard sessions to avoid the microbiome and
nutritional costs of long-term restriction. Both shape §3.9 and S4.

### 1.5 · Liquid isn't magic — small and pre-triturated is

"Liquids empty faster than solids" is much weaker than commonly stated. At matched energy the
emptying curves are nearly identical: T50 of 101 ± 6.0 min for solid against 88 ± 9.8 min for liquid,
**not significant** (p = 0.24); a replication found 1.52 ± 0.08 h against 1.41 ± 0.11 h. Liquid meals
usually empty faster because they usually carry less energy, not because they are liquid.

**So the top-off tier's form rule is not justified by "liquids are faster."** It is justified by two
other things: a liquid or gel carries little energy so the clamp barely engages, and it skips the
solid lag phase because there is nothing to grind. That is the correct reasoning, and it is why a
*soft, low-residue* solid like a ripe banana behaves much more like the liquid case than a bagel does.

---

## 2 · The three tiers

| Tier | Window before start | What it is for | Energy budget at 2–4 kcal/min (S1) |
|---|---|---|---|
| **meal** | 240–120 min | The substantive feeding. Tops liver glycogen, is expected to largely clear | **~240–960 kcal** across the window |
| **snack** | 120–30 min | A smaller feeding that will only partly clear, and doesn't need to | **~60–480 kcal** across the window |
| **top-off** | 30–0 min | Carbohydrate delivery, not digestion. Absorbed during the session | **not budgeted** — the clamp barely engages |

The tiers stack: an athlete entering at 180 min receives meal, snack and top-off; at 45 min, snack and
top-off; at 20 min, only the top-off.

**The budget column is advisory and band-valued** (§1.1). Read it as "a 700 kcal breakfast at t−180
is at the upper edge of what clears" — not as a pass/fail line.

**Note the asymmetry that defines the top-off.** The meal and snack are governed by *clearance*; the
top-off is governed by *form and concentration*, because it is not expected to clear before the start
and does not need to. This is the one tier where the energy logic is deliberately abandoned.

---

## 3 · LAYER A — the food groups

This is the operative recommendation. Nine groups, then a per-tier matrix, then canonical feedings.

**Rating key:** **FREE** = build the feeding from these · **LIMITED** = permitted within the §5 gates,
prefer smaller amounts · **AVOID** = do not select for this tier.

### 3.1 · G1 — Refined starches
White rice · white bread and toast · seedless bagels · plain pasta · low-fibre cereal · rice cakes ·
pretzels · plain crackers · flour tortilla · English muffin · plain pancakes and waffles.

The backbone of every tier that eats solid food. Low fat, low fibre, fast to triturate, and named
almost item-for-item in the reference race-day list.

### 3.2 · G2 — Cooked starchy vegetables
Potato and sweet potato, peeled, boiled or baked · cooked seedless vegetables.
Skins carry most of the fibre; peeling is the whole rule. No added fat.

### 3.3 · G3 — Low-residue fruit
Ripe banana · applesauce and fruit purée · cooked or canned fruit · pulp-free juice · melon.
Ripeness matters for banana specifically: under-ripe fruit carries more resistant starch. "Low
residue" here means seedless, skinless and pulp-free.

### 3.4 · G4 — Sugars, syrups and sports carbohydrate

**G4a — sugars and syrups as an ingredient.** Honey · jam and jelly · maple syrup · table sugar.
Used as a topping or a carbohydrate source within a meal or snack.

**G4b — engineered sports carbohydrate.** 6–8 % sports drink · sports drink powder mixed to label
strength · energy gels · energy chews.

Effectively pure carbohydrate, zero fat, zero fibre, no trituration. **The only group the top-off may
be built from**, and the only group that clears every gate in every tier on composition alone.

**Ruling (Xuan, 2026-08-05, superseded same day): a sports drink at label strength is permitted in
every tier.** An earlier v2 ruling confined G4b to the top-off. **That is reversed in v3** — a sports
drink is a common, familiar item and there is no reason to withhold it from the meal or snack window.
Specifically:

- **Nothing physiological forbids it.** A 6–8 % drink is zero fat, zero fibre, zero protein and pure
  carbohydrate; it clears H1, H2 and H3 by the widest margin of any item in this document, at any tier.
- **Nothing in the concentration literature forbids it either.** Every published carbohydrate-
  concentration threshold — the 4–8 % in the position stand, the "<10 %" commonly quoted — is scoped
  to *during-exercise* replacement fluid (§10). There is no pre-exercise concentration evidence base
  to invoke at 30 min–4 h.
- **The gel and the chew travel with it.** G4b is one group; splitting the drink from the gel would be
  arbitrary.

**G4b remains the group the top-off is *built* from** — that is a statement about what the top-off may
contain, not a restriction on where G4b may otherwise appear.

### 3.5 · G5 — Lean protein
Egg white · skinless poultry · white fish · lean deli turkey · low-fat plain yoghurt (see G6) ·
whey or plant protein isolate.

Meal tier only, in modest amounts. No performance case for it pre-exercise (§1.2) — it is here
because athletes eat real meals and there is no evidence it hurts inside the H3 dose.

### 3.6 · G6 — Dairy and alternatives
Skim/low-fat milk · plain low-fat yoghurt · lactose-free milk · fortified plant milks.

**Conditional, not banned.** The source caution is explicitly conditional — athletes who *frequently*
experience stomach problems may want to avoid milk products or use lactose-free versions. A splash of
milk on cereal three hours out is fine for a tolerant gut. Gated by `gutTolerance` (§3.10).

### 3.7 · G7 — Added fats and fatty foods
Butter · oil · cream cheese · nut butters · whole nuts and seeds · avocado · cheese · full-fat dairy ·
fatty meat · fried food · chocolate spreads.

**The group to spend the least of the budget on**, for the energy-density reason in §1.2 — not
because fat is uniquely toxic. A tablespoon of peanut butter on a bagel three hours out is defensible;
two tablespoons thirty minutes out is not.

*Correcting a v1 error worth recording: v1 stated peanut butter is "~50 % energy" from fat. It is
**~77 %** (USDA 172470: 2 tbsp = 191 kcal, 16.4 g fat). The 50 % figure is fat by* weight *(51.4 g per
100 g), mislabelled as percent of energy.*

### 3.8 · G8 — High-residue whole foods
Whole-grain and seeded bread · bran and high-fibre cereal · brown rice · legumes and pulses · raw
vegetables · seeded and skin-on fruit · raw berries · popcorn · whole nuts and seeds.

Excellent food; wrong timing. These are restricted by *proximity to the start*, not condemned.

**Honesty note on this group.** A gram threshold does **not** cleanly separate G8 from G1 — two slices
of commercial whole-wheat bread carry only 3.8 g fibre and pass the meal gate H2. The refined/
whole distinction is therefore a **Layer A group rule**, and H2's grams only catch gross offenders.
Do not expect the formula to do the group's job.

### 3.9 · G9 — High-FODMAP items
Fructans: wheat in large amounts, onion, garlic · lactose: milk, yoghurt, soft cheese · excess
fructose: honey in quantity, apple, mango, pear, high-fructose corn syrup · polyols: sorbitol and
mannitol, stone fruit, dried fruit, sugar-free products · GOS: legumes and pulses.

Overlaps G8 and G3 deliberately — this is a *different axis*, not a different shelf. Restriction is
by elimination and is targeted at the pre-competition window only (§1.4).

**Dried fruit belongs here, not in a fibre rule.** v1 hard-excluded raisins and dates on fibre
grounds; USDA shows ¼ cup of raisins carries 1.8 g fibre and 2 Medjool dates 3.2 g — both pass every
fibre gate in H2. If dried fruit is restricted near the start, the defensible reason is its
concentrated fructose and polyol load, not its fibre.

### 3.10 · The tier matrix

| Group | meal (240–120) | snack (120–30) | top-off (30–0) |
|---|---|---|---|
| **G1** refined starches | FREE | FREE | AVOID (solid, needs trituration) |
| **G2** cooked starchy veg | FREE | LIMITED | AVOID |
| **G3** low-residue fruit | FREE | FREE | LIMITED — banana/purée to ~t−20; juice see H6 |
| **G4a** sugars & syrups | FREE | FREE | FREE |
| **G4b** sports drink · mix · gel · chews | FREE | FREE | **FREE — build the top-off from this group** |
| **G5** lean protein | LIMITED (H3) | LIMITED, small | AVOID |
| **G6** dairy & alternatives | LIMITED; **AVOID if `gutTolerance == low`** | AVOID if `low`, else LIMITED | AVOID |
| **G7** added fats | LIMITED (H1) | AVOID | AVOID |
| **G8** high-residue whole foods | LIMITED | AVOID | AVOID |
| **G9** high-FODMAP | LIMITED | AVOID | AVOID |

`gutTolerance` takes `low · moderate · high · unknown`. **`unknown` resolves to `moderate`** — the
source caution is conditional on frequent stomach problems, and absent evidence of them the
restrictive branch is not licensed. (Following the sibling precedent that `unknown` must resolve
explicitly, never left undefined.)

### 3.11 · Canonical feedings

What "good" actually looks like. Each is checked against §5 in §7.

**Meal (240–120 min)**
- Oatmeal made with water + sliced ripe banana + honey
- Bagel or white toast + jam, with a small glass of juice
- White rice + skinless chicken breast + peeled cooked vegetable
- Plain pancakes + maple syrup
- Low-fibre cereal + milk *(G6 — tolerant guts only)*

**Snack (120–30 min)**
- White toast or a rice cake + jam or honey
- Ripe banana
- Applesauce pouch
- Small bowl of low-fibre cereal, dry or with a little lactose-free milk
- Pretzels + a sports drink

**Top-off (30–0 min)**
- Energy gel + water *(the canonical case)*
- 6–8 % sports drink, 200–300 ml
- Energy chews
- Ripe banana or an applesauce pouch, at the far edge (t−30 to t−20), not the last 15 minutes

---

## 4 · LAYER B — how the formulas are applied

Read this before §5 and §6 or the numbers will be misapplied. This is the definitional failure that
broke v1.

**The gates apply to the FEEDING as assembled, not to each item.** A *feeding* is everything eaten at
one sitting for one tier — "bagel + jam + juice" is one feeding, three items. Fat, fibre and protein
in §5 are summed across the feeding and compared once.

**Why this matters more than it sounds.** v1 applied its thresholds per item and required each item to
be ≥ 60 % carbohydrate by energy. No lean meat can ever satisfy that: 3 oz of chicken breast is 75 %
protein and 0 % carbohydrate by energy. So v1 rejected a food its own cited list explicitly
approves — and did the same to oatmeal, toast, bagels, bananas and applesauce. **A per-item
percentage rule cannot work**, because a plate is composed of items that are individually lopsided
and jointly fine. That is the whole reason percentages appear only as soft scores here.

**Units and conventions, stated so they can't drift.**

- **Grams** are the unit for every hard gate. Grams are per feeding, and they mean what the label says.
- **Percent of energy**, where it appears in §6, uses **9 / 4 / 4 kcal per g** for fat / carbohydrate /
  protein, computed on the feeding's macro-derived energy, not on label kcal. Label rounding routinely
  shifts a result several points — a 23 g gel reads 92 % carbohydrate against a 100 kcal label and
  100 % against its own macros.
- **Fibre is not counted as a separate energy term.** It is part of carbohydrate. v1's table implied a
  fourth macro, which double-counts energy and flips verdicts depending on whether fibre is valued at
  4 or 2 kcal/g. Fibre is gated **in grams only** and never as a percentage.
- **No percentage is evaluated on a feeding under 50 kcal.** Below that, percentages are noise: a
  teaspoon of mustard reads 47 % of energy from fat on 0.2 g, and black coffee reads 100 % protein.
- **`≤` is inclusive.** A feeding at exactly the limit passes.

---

## 5 · Hard gates — a feeding must pass all that apply

Seven gates. Deliberately few, because only a few things are defensible as pass/fail.

### H1 · Fat ceiling per feeding · **[design]**

| meal | snack | top-off |
|---|---|---|
| ≤ **max(15 g, 0.22 g/kg)** | ≤ **max(7 g, 0.10 g/kg)** | ≤ **2 g** flat |

### H2 · Fibre ceiling per feeding · **[design]**

| meal | snack | top-off |
|---|---|---|
| ≤ **max(8 g, 0.12 g/kg)** | ≤ **max(4 g, 0.06 g/kg)** | ≤ **2 g** flat |

**Why `max(floor, per-kg)` and not a flat gram or a percentage.** A heavier athlete is prescribed a
larger feeding — carbohydrate is already g/kg — so a flat gram cap tightens as body mass rises,
which is backwards. Scaling fixes that. The floor exists so the gates never punish a light athlete
eating an ordinary breakfast: at 50 kg a straight 0.12 g/kg would cap fibre at 6 g and reject
oatmeal with a banana (7.1 g), which is exactly the over-restriction v1 was guilty of. So these
scale **up only**. The floor binds up to about 68 kg; above that the per-kg term takes over.

| Body mass | fat, meal | fat, snack | fibre, meal | fibre, snack |
|---|---|---|---|---|
| 50 kg | 15.0 g | 7.0 g | 8.0 g | 4.0 g |
| 65 kg | 15.0 g | 7.0 g | 8.0 g | 4.0 g |
| 80 kg | 17.6 g | 8.0 g | 9.6 g | 4.8 g |
| 95 kg | 20.9 g | 9.5 g | 11.4 g | 5.7 g |

**Percentage of energy was considered and rejected for these two.** It is no longer *broken* — v2
evaluates gates on the composed feeding, which is what made percentages fail in v1 — but it has a
worse defect here: **a percentage rewards bulk.** At a 15 % cap, a 900 kcal breakfast buys 15 g of
fat while a 400 kcal one buys 6.7 g, so the athlete who eats more is permitted more of the thing the
gate exists to limit. Body mass tracks the actual driver — bigger athlete, bigger prescribed
feeding, proportionally more headroom — without that inversion. Percentage of energy survives only
as a soft preference (S2), where rewarding bulk does no harm.

H1's *direction* is cited — Thomas 2016 names a **"low-fat"** profile as preferred for the pre-event
menu, and separately licenses this as an acute rule specifically: *"If such focused restrictiveness
around fat intake is practiced, it should be limited to acute scenarios such as the pre-event
diet."* Read that as permission to be strict here and only here — this document must never be read
as a reason to lower an athlete's habitual fat intake.

H1's *number* is not cited. It is anchored to §1.2's energy-density argument: 15 g of fat is
135 kcal, a meaningful slice of a two-hour budget, and it tightens as the window closes. It admits
every canonical feeding in §3.11 and every staple on the reference list, and rejects 2 tbsp of nut
butter at every tier and 1 tbsp at the snack.

H2's direction is likewise cited — Thomas 2016 names **"low-fiber"** in the same sentence — but its
floors have no source at all, because **no sports-nutrition document publishes a pre-exercise fibre
gram limit** (§1.3). They are set to admit the §3.11 feedings (oatmeal plus a banana is 7.1 g and
must pass) while catching bran cereal, legumes and berry-loaded bowls.

**Do not justify H2 by gastric emptying.** §1.3 sets out why: at food-realistic doses the emptying
evidence is a set of nulls, and the largest documented fibre effect is smaller than the effect of the
meal's own energy. H2 is a lower-gut symptom control. It is also a *coarse* one — the
refined-versus-whole-grain distinction is G1-vs-G8's job (§3.8) and the fermentability distinction is
G9's (§3.9); total grams is simply the only fibre variable a food label reports.

*The top-off stays flat at 2 g for both. It is a gel or a mouthful of drink, not a scaled portion —
there is nothing for body mass to scale.*

### H3 · Protein ceiling per feeding · **[design, anchored]**

| meal | snack | top-off |
|---|---|---|
| ≤ **0.4 g/kg** | ≤ **0.2 g/kg** | ≈ **0** |

A *ceiling on a recommended ingredient*, not a grudging allowance: Thomas 2016 recommends including a
protein source at the pre-event meal while specifying a **"low–moderate protein content"** profile,
and H3 is where "moderate" gets a number. Anchored to the whey tolerance study — 0.4 g/kg tolerated
before a hard 10 km — with the §1.2 caveat that this was the highest dose *tested*, not a
demonstrated ceiling. At 65 kg the meal allows 26 g, which admits a 3 oz chicken breast (26.3 g)
exactly; at 95 kg, 38 g.

### H4 · Top-off form gate · **[design, mechanism-anchored]**
The top-off may be **liquid, gel, chew, or a soft low-residue purée** — anything requiring no
meaningful trituration (§1.5). Ordinary solids are excluded. A ripe banana or an applesauce pouch is
permitted from t−30 to about t−20, and not in the final 15 minutes; note this is a **soft-solid
allowance made explicitly against H2's 2 g line** (a banana is 3.1 g), documented rather than hidden.

### H5 · The top-off must deliver carbohydrate · **[contractual]**
Water, electrolyte tablets and electrolyte powders are valid answers to hydration and sodium. They are
**not** valid top-off carbohydrate items. An athlete handed an electrolyte tablet has received no fuel
and believes they are fuelled — the tier's entire purpose, silently unmet.

### H6 · Drink carbohydrate concentration · **[design]** · **scope: the top-off tier only**
- **Sustained drinking: ≤ 8 % carbohydrate.** 6–8 % preferred, matching the during-workout standard.
- **Single bolus exemption: up to ~12 %**, for one serving of ≤ 300 ml taken with chase water.

**Scope: the top-off tier only.** Drinks taken with a meal or a snack — a sports drink, juice, milk,
a glass of water — are **not** concentration-gated. Two reasons, and note that neither is "they have
time to clear", which v2 asserted and which is wrong: emptying is in fact *slower* with food, not
faster.

1. **Concentration stops being the control variable once a drink joins a feeding.** The stomach meters
   total calories to the duodenum at a broadly regulated rate irrespective of source (§1.1), so a
   drink taken with food is not an independently regulated object — its own percentage no longer
   governs anything. A per-drink concentration gate assumes exactly the opposite.
2. **There is no pre-exercise concentration evidence to apply.** Every published threshold is scoped
   to during-exercise replacement fluid (§10).

*In practice this is mostly moot for a sports drink, which is 6–8 % at label strength and so inside
the ceiling anyway. It matters for a drink mixed stronger than label, and for juice.*

**RATIFIED AS-IS (Xuan, 2026-08-05), with its provenance stated honestly.** The familiar
justification — "5–8 % empties about like water" — is *contradicted by the NRC/IOM volume usually
cited for it*, whose gastric-emptying chapter states that even <2 g/100 ml of simple carbohydrate
empties slower than water, and that commercial drinks at 5.9 % and 7.1 % both emptied significantly
slower than water. **So 8 % is not an emptying-equivalence threshold, and this document does not
claim it is.**

It is kept because the decision is cheap and the alternative is worse. The rule governs exactly one
small serving close to the start; a 6–8 % drink is the during-workout standard, so the athlete meets
one concentration convention rather than two; and the line usefully keeps juice (~11 %), cola and
over-mixed powder out on a stated rule rather than a taste judgement. Were the evidence pushed
harder it would move the ceiling *up* — the documented distress point is nearer 12 % — so 8 % errs
conservative, which is the correct direction for a rule of this weight. **Treat it as a design line,
never cite it as a physiological threshold.**

The bolus exemption is empirical, not mechanical: a 35.5 g gel with 250 ml water is roughly 11 % in
the stomach and improved time-trial distance by 3.1–3.4 % at t−15 without incident. **Do not justify
it by "the gel is diluted on the way down"** — that was v1's reasoning and the arithmetic disproves
it. It is justified because it was tested.

*Consequence: **pulp-free juice is not a top-off drink.** At ~11 % it fails the sustained rule, and it
is not a gel-plus-chase bolus. v1 approved it for the top-off while also publishing the 8 % rule.
Juice stays FREE in the meal and snack tiers.*

### H7 · Nothing untried · **[position stand]**
No item an athlete has not already eaten before a training session of similar intensity.

**Upgraded from consensus to a cited rule.** Thomas 2016's executive summary states that the pre-event
meal *"should be **well trialed and individualized** according to the preferences, tolerance, and
experiences of each athlete"* — so this is the position stand's own instruction, not merely folklore.
It remains true that no trial has directly compared novel against familiar pre-competition food; what
changed is that the recommendation no longer rests on that missing trial. Its mechanism is still
indirect — the gut is demonstrably adaptable and inter-individual tolerance varies widely, so an
untested food is the uncontrolled variable. See S6 for the constructive half.

---

## 6 · Soft scores — preferences, never rejections

A feeding that scores poorly here is *worse*, not *invalid*. Nothing in this section may reject a food.

**S1 · Energy load against the clearance band.** Prefer `kcal ≤ 2 × minutes available`; consider
flagging above `4 × minutes`. **Calorie count is explicitly not a gate and must never become one.**
The underlying measurement supports a 2× band and nothing tighter (§1.1), so any pass/fail line drawn
on it would be false precision — and food still in the stomach at the start is a comfort risk, not a
failure: emptying continues during moderate exercise and the residue is still fuel. If this rule is
ever dropped entirely, nothing else in the document breaks; §1.1 stands on its own as the reason the
tiers are ordered the way they are.

**S2 · Carbohydrate should dominate the feeding's energy.** Prefer carbohydrate as the largest energy
contributor. **No floor, at any tier** — this is the rule that must never become a gate, because
that is precisely what made v1 reject lean meat. Quantity is `pre-workout-carbs.md`'s job anyway.

**S3 · Refinement rises as the window closes.** Prefer G1 over G8 with decreasing lead time; below
about 60 minutes, prefer G1/G3/G4 exclusively. This is the rule that actually implements
white-over-whole-grain, since H2's grams do not separate them (§3.8).

**S4 · FODMAP load falls as the window closes.** Prefer eliminating G9 items in the last two hours,
and across the preceding 24 hours before a competition. Elimination-based; **no gram target exists**
and none is invented (§1.4). Targeted, not chronic.

**S5 · Prefer lower volume near the start.** Emptying rate rises with volume, but tolerance does not.
The published pre-exercise fluid prescriptions — 500–600 ml at 2–3 h, 200–300 ml at 10–20 min — are a
reasonable proxy for comfortable volume, with the caveat that they are *hydration prescriptions, not
measured tolerance ceilings*.

**S6 · Prefer practised foods, and treat tolerance as trainable.** Gastric emptying and stomach
comfort adapt to repeated feeding, and carbohydrate intake upregulates intestinal SGLT1 abundance and
activity. The prescription that carries evidence is to rehearse the competition feeding strategy at
least weekly. This is the constructive half of H7.

---

## 7 · Worked examples

Checked against §5 with USDA values. `gutTolerance = moderate`, **65 kg** athlete — so H1/H2 sit at
their floors (15 / 7 g fat, 8 / 4 g fibre) and H3 at 26 / 13 g protein.

**The kcal column is informational, not a gate.** No verdict below turns on it. Energy is the spine
of the physiology (§1.1) but it is deliberately not a pass/fail criterion, because the measurement
underneath it is a 2× band (§6, S1). It is shown so the reader can see the size of a feeding, not so
anything can be rejected for it.

| Feeding | Tier | kcal | fat g | fibre g | protein g | Verdict |
|---|---|---|---|---|---|---|
| Oatmeal (1 cup) + ripe banana + 1 tbsp honey | meal, t−180 | 341 | 4.0 | 7.1 | 7.3 | **PASS.** Fibre 7.1 against 8 — the tightest gate, and correctly so |
| Bagel + 2 tbsp jam + 1 cup juice | meal, t−150 | 494 | 2.0 | 3.0 | 12.4 | **PASS** |
| White rice (1 cup) + 3 oz chicken + peeled carrot | meal, t−240 | 372 | 3.5 | 2.9 | 31.2 | **FAIL H3** — 31.2 g against 26 g. Reduce to 2 oz chicken → 22.4 g, passes. *Note this feeding is impossible under v1, which required every item to be ≥ 60 % carbohydrate*. At 95 kg the same plate passes: H3 rises to 38 g |
| Bagel + 2 tbsp peanut butter | meal, t−180 | 461 | 17.9 | 3.9 | 17.6 | **FAIL H1** — 17.9 g against 15 g. With 1 tbsp: 9.7 g, passes. At 85 kg it passes as served (H1 = 18.7 g) |
| White toast (1 slice) + jam | snack, t−60 | 121 | 0.8 | 0.9 | 2.4 | **PASS** |
| Ripe banana | snack, t−45 | 105 | 0.4 | 3.1 | 1.3 | **PASS** |
| Oatmeal (1 cup) | snack, t−90 | 166 | 3.6 | 4.0 | 5.9 | **PASS** — fibre exactly at 4 g. *v1 rejected this on three separate columns* |
| Energy gel (23 g CHO) + 250 ml water | top-off, t−15 | 100 | 0 | 0 | 0 | **PASS** — ~8 % as mixed in the stomach. Simpson's larger 35.5 g gel with the same chase is ~11 %, which is what H6's bolus exemption actually covers |
| 300 ml sports drink at 7 % | top-off, t−20 | 84 | 0 | 0 | 0 | **PASS** |
| Ripe banana | top-off, t−25 | 105 | 0.4 | 3.1 | 1.3 | **PASS by the H4 soft-solid allowance**, over H2's 2 g. Documented exception, not a silent one |
| 300 ml pulp-free juice | top-off, t−20 | 140 | 0.6 | 0.6 | 2.1 | **FAIL H6** — ~11 %, sustained-drink rule. Fine as a snack |
| Electrolyte tablet in water | top-off, t−20 | 0 | 0 | 0 | 0 | **FAIL H5** — zero carbohydrate |

---

## 8 · Basis and confidence

| Element | Value | Basis | Confidence |
|---|---|---|---|
| Emptying is calorie-clamped | 2.13 kcal/min measured; **use 2–4** | Brener 1983 (primary) | **High** for the mechanism; **Low** for any single rate |
| Clearance budget as a *time* prediction | — | Extrapolation from the above | **Low** — soft score only (S1) |
| Fat's liability is mainly energy density | 9 vs 4 kcal/g | Arithmetic + CCK chain-length work | **High** |
| A per-calorie fat effect exists beyond density | qualitative | CCK-1 / vagal afferent literature | Medium — magnitude unestablished |
| Fat is *uniquely* inhibitory | **rejected** | Carbohydrate has its own ileal brake via PYY | — |
| Energy content dominates emptying | — | **Hunt & Stubbs 1975** (33 pooled studies); **Okabe 2015** (isocaloric + isovolumic, milk vs juice) | **High** |
| The clamp fully cancels energy density | **rejected** | Denser meals do deliver energy faster (Hunt & Stubbs; Calbet & MacLean) — compensation is partial | **High** |
| "carbohydrate → protein → fat" ranking at matched energy | **not asserted** | No study supports the three-way ranking; best-controlled trials disagree in direction (§1.2, §9) | — |
| A residual macronutrient effect exists | contested | Giezenaar 2018 (protein slower) vs Goetze 2007 (fat/protein faster early) | Low — direction unresolved |
| Food structure moves emptying at constant energy *and* macronutrient | ~2× | Marciani fat-emulsion acid-stability work | **High** |
| "Protein is the least restrictive macro" | **withdrawn** | v1's inference from a diagnostic reference meal is invalid (§1.2) | — |
| Protein ≤ 0.4 g/kg tolerated pre-exercise | 0.4 g/kg | Whey tolerance trial, 10 km at 85 % race pace | Medium — highest dose tested, not a ceiling |
| Pre-exercise protein has no acute performance effect | null | Substrate-oxidation trial vs fasted | Medium |
| Fibre acts mainly colonically, not gastrically | qualitative | Symptom literature; low-residue is being deprecated clinically | Medium |
| Soluble vs insoluble fibre differ on emptying | **rejected as the framing** | Solubility is the wrong axis entirely — see the four rows below | **High** |
| Low-FODMAP before competition reduces symptoms | 82 % improved; 24 h sufficient | Lis 2018; Gaskell/Costa | **High** |
| FODMAP gram target | **none exists** | Implemented by elimination in both literatures | **High** (that none exists) |
| Liquid empties faster than solid at matched energy | **rejected** | T50 101 ± 6.0 vs 88 ± 9.8 min, p = 0.24 | **High** |
| Drink ≤ 8 % carbohydrate (top-off only) | 8 % | **[design, ratified as-is]** — convention + conservatism, *not* emptying equivalence. Bounded scope: one small serving | Medium |
| Sports drink / gel permitted in every tier | — | **Ruling (Xuan, 2026-08-05, v3).** Clears H1–H3 by the widest margin of any item; no pre-exercise concentration evidence exists to restrict it (§3.4) | **High** |
| "5–8 % empties like water" | **rejected** | Contradicted by the volume usually cited for it | **High** |
| "~12 % retards absorption" attributed to NRC/IOM 1994 | **not cited** | Could not be located in that source | — |
| Bolus exemption to ~12 % with chase water | ~11 % tested | Simpson 2011, +3.1/+3.4 % TT at t−15 | Medium |
| Pre-exercise fluid volumes 500–600 / 200–300 ml | as stated | NATA 2017 — **prescriptions, not tolerance ceilings** | Medium |
| Gut is trainable; rehearse the strategy weekly | qualitative | Jeukendrup 2017, SGLT1 upregulation | **High** |
| "Nothing new on race day" (H7) | qualitative | **Thomas 2016** — pre-event meal *"should be well trialed and individualized"*. No head-to-head trial exists, but the recommendation is a position stand's, not folklore | **High** |
| Direction "low-fat, low-fiber, low–moderate protein" | qualitative | **Thomas 2016**, verbatim narrative sentence (§10). The single strongest citation in this document | **High** |
| Protein belongs in the pre-event meal | qualitative | **Thomas 2016** — *"including a protein source at the meal"*, recommended against insulin rebound | **High** |
| Solubility predicts fibre's GI effect | **rejected** | McRorie & McKeown 2017 — viscosity and fermentability are the real axes | **High** |
| Viscous high-MW fibre delays emptying at sufficient dose | T½ +17 min | β-glucan RCTs; high- vs low-MW at matched dose isolates viscosity | **High** for the effect; **Low** for its relevance at food doses |
| Ordinary food doses (4–7 g) of viscous fibre delay emptying | **rejected** | Three independent nulls (guar/ispaghula/cellulose 5 g; β-glucan 4 g; psyllium 7.4 g) | **High** |
| Insoluble fibre changes gastric emptying | **rejected** | Rydning 1985 — positive signal was a method artifact the authors disowned | **High** |
| Meal energy outweighs fibre/viscosity for emptying | 46→76 min vs smaller | Marciani 2001, 2×2 MRI — corroborates §1.1 from a second direction | **High** |
| Fermentability drives exercise lower-gut symptoms | see Lis effect sizes | Bianchi & Capurso 2002; Lis 2018 | Medium — consistent direction, small trials |
| Low-fermentability fibre is the safer pre-exercise choice | — | **Plausible, weakly evidenced** — no exercise RCT compares fibre types | Low |
| GI is not a selection filter | — | Burdon meta-analysis: *"weak evidence"* for low-GI benefit | **High** |
| Osmolality is not a separate filter | — | Suggestive only in the source; energy content dominates | Medium |
| Temperature is not a filter | — | **No effect size available either way** — unsupported, not disproven | Low |
| **All fat / fibre / protein grams in §5** | §5 tables | **[design]** — no source publishes per-macro pre-exercise thresholds | **Low–Medium** |
| Fat and fibre gates scale with body mass | `max(floor, g/kg)` | **[design]** — matches how the sibling specs scale; floor prevents over-restricting light athletes | **Low–Medium** |
| Percent-of-energy as a *gate* | **rejected** | Rewards bulk: a larger feeding buys more absolute fat at the same percentage | **High** (as reasoning) |
| Calorie count as a *gate* | **rejected** | Underlying rate is a 2× band (Brener scope caveats) — cannot support a pass/fail line | **High** (as reasoning) |
| Peanut butter is ~77 %E fat | 77 % | USDA 172470 — corrects v1's 50 % | **High** |

**The claim that no quantified per-macro pre-exercise threshold exists** survived a deliberate
falsification attempt across the position stands and the exercise-GI literature. State it in its
honest form — *"no consensus gram threshold has been published"* — rather than the unfalsifiable
universal, which one paywalled document could overturn.

---

## 9 · Open items and known tensions

**Nothing here blocked ratification.** Two of the three items that did are cleared; the third is
resolved in its strong form and reduced to one citation to check, and **no rule in §5 or §6 depends
on how it resolves**. Recorded in full so the reasoning survives the people who did it.

**Formerly blocking.**

1. ~~Thomas 2016 full text.~~ **CLEARED (2026-08-05).** Verified verbatim against the MSSE full text
   and independently against the Dietitians of Canada edition. It yielded more than the sentence
   sought: a direct composition recommendation, a positive recommendation for protein, the low-GI
   demotion, the "well trialed" instruction behind H7, and an explicit licence for acute fat
   restriction. All are quoted in §10 and have been folded into §1.2, H1, H2, H3 and H7.
2. **The macronutrient-emptying question.** **RESOLVED AS UNRESOLVABLE IN THE STRONG FORM
   (2026-08-05), with one live sub-item.** The claim "at matched energy, fat and protein empty more
   slowly than carbohydrate" cannot be sourced: no single study supports the three-way ranking at
   matched energy, and the best-controlled experiments disagree in *direction* — one isocaloric
   isovolumic study finds concentrated protein far slower, another finds fat and protein faster than
   glucose early on. §1.2 has been rewritten to state the energy-dominance backbone (Hunt & Stubbs,
   Okabe), present both sides, and lean the rules on energy and form rather than on any ranking.
   There is no meta-analysis on the isocaloric question, and the two nearest physiology reviews
   decline to take a position — which is itself informative.

   **Live sub-item.** Farivar et al., Int J Legal Med 2026 (PMID 42151629), MRI, n = 15, reports
   exactly the disputed ranking: t50 high-carbohydrate 132 ± 33 < high-protein 158 ± 37 (p = 0.010) <
   high-fat 188 ± 41 min (p < 0.001). **Do not cite it until its meal design is checked.** Forensic
   "standard meals" are conventionally matched on *weight*, not energy — and a weight-matched high-fat
   meal carries roughly twice the energy of a weight-matched high-carbohydrate one, which would make
   the whole ranking an energy artifact. If the meals turn out to be isocaloric, it becomes the best
   citation in this section and §1.2's hedging can be relaxed.
3. ~~Soluble versus insoluble fibre.~~ **CLEARED (2026-08-05) — and the answer inverted the
   assumption.** Solubility is not the operative axis at all; at food-realistic doses viscous fibre
   does not reliably delay emptying, insoluble fibre does not either, and meal energy outweighs both.
   §1.3 was rewritten and H2 re-based on lower-gut symptoms rather than emptying.

**Tensions, recorded rather than smoothed over.**

- **The 8 % ceiling — CLOSED for this file (Xuan, 2026-08-05); still open for its siblings.** The
  number is ratified as a design line (H6). What remains true, and must not be quietly forgotten: the
  notes' §5.15 ruling rests partly on "5–8 % is of little importance for emptying," attributed to
  NRC/IOM 1994, and the gastric-emptying chapter of that volume says the opposite; the "~12 % harm"
  figure could not be located there at all. **This file no longer depends on either claim** — H6 is
  scoped to one small top-off serving and defends 8 % on convention and conservatism, not physiology.
  **`pre-workout-hydration.md` and `pre-workout-carbs.md` still rest on the discredited reading and
  need their own correction.** Not a blocker here; a debt recorded against them.
- **The reference-meal retention band is misquoted repo-wide.** "30–60 % retained at 2 h" fuses two
  different criteria: 60 % is the 95th-percentile *upper* limit at 2 h, while 30 % is the *rapid*-
  emptying criterion at **1 h**. The published cutoffs are one-sided (>60 % at 2 h or >10 % at 4 h
  indicates delay). This file no longer uses the band; `pre-workout-carbs.md` still cites it as the
  basis for its 120-minute tier boundary and needs a separate correction.
- **The chase water has no owner.** This file's H6 and `pre-workout-hydration.md` both assign the
  gel's 250 ml to `pre-workout-carbs.md`, which contains no fluid rule at all. One of the three must
  take it.
- **A large meal near the 2-hour edge sits at the top of the clearance band.** A 65 kg athlete's
  meal-tier carbohydrate at t−180 is ~468 kcal before protein and fat, against a 360–720 kcal band.
  Inside the band, but in its upper half — which is the honest reading, and an argument for S1 staying
  advisory rather than becoming a gate.

---

## 10 · Literature

- **Brener W, Hendrix TR, McHugh PR.** *Regulation of the gastric emptying of glucose.*
  Gastroenterology. 1983;85:76–82. Glucose at 0.05 / 0.125 / 0.25 g/ml all emptied at **2.13
  kcal/min**; intraduodenal glucose inhibited saline emptying at 0.46 min/kcal. **Scope caveat: liquid
  glucose, resting subjects — a carbohydrate result, not a demonstrated cross-macronutrient constant.**

- **Hunt JN, Stubbs DF.** *The volume and energy content of meals as determinants of gastric
  emptying.* J Physiol. 1975;245(1):209–225. PMID 1127608. **The backbone citation for §1.1 and
  §1.2's energy-dominance claim.** Pooled reanalysis of 33 studies, meal volumes 50–1250 ml:
  > "The greater the nutritive density of a meal, the less was the volume transferred to the duodenum
  > in 30 min"

  and the load-bearing conclusion:
  > "consistent with equal slowing of gastric emptying by the duodenal action of the products of
  > digestion of isocaloric amounts of fat, protein and carbohydrate"

  Worked example: 4 g fat versus 9 g carbohydrate, both ≈ 36 kcal. **Scope caveat: a cross-study
  pooled regression, not a within-subject randomised comparison, and the authors' own hedge is
  "consistent with", not "demonstrates."** Also the source for the clamp being *incomplete* — denser
  meals do deliver energy faster.

- **Okabe T, Terashima H, Sakamoto A.** *Determinants of liquid gastric emptying: comparisons between
  milk and isocalorically adjusted clear fluids.* Br J Anaesth. 2015;114(1):77–82. PMID 25260696.
  Isocaloric **and** isovolumic (500 ml), a fat-protein-carbohydrate emulsion against a
  pure-carbohydrate fluid:
  > "There were no significant differences in liquid gastric emptying after drinking equal volumes of
  > either orange juice or milk as long as both had the same amount of calories."

  The 220 kcal drinks emptied faster than the 330 kcal drinks. **The cleanest human demonstration
  that energy, not macronutrient identity, is the variable.**

- **McHugh PR, Moran TH.** *Calories and gastric emptying: a regulatory capacity with implications for
  feeding.* Am J Physiol. 1979;236(5):R254–60. PMID 109014. Origin of the "the stomach regulates
  caloric delivery" formulation; isocaloric casein hydrolysate and MCT oil emptied at the same rate as
  glucose. **Rhesus monkeys, n = 4, intragastric infusion — cite as mechanism, not human evidence.**

- **Giezenaar C, et al.** *Effects of substitution, and adding of carbohydrate and fat to whey-protein
  on energy intake, appetite, gastric emptying…* Nutrients. 2018;10(10):1451 (PMID 30301241) and
  2018;10(2):113 (PMID 29360778, older men). **The strongest contrary evidence to energy-dominance.**
  450 ml and 280 kcal in *both* arms: pure whey against a mixed drink, T50 **58 ± 31 vs 23 ± 8 min,
  P < 0.001**; replicated at 78 ± 11 vs 26 ± 2 min. **Read the limits: 70 g of whey in 450 ml is an
  extreme, non-food-like load and the comparator contained fat, so it licenses "concentrated protein
  versus a mixed drink", not "protein versus carbohydrate" — and it is untested at the 15–30 g doses
  H3 actually permits.**

- **Sidery MB, Macdonald IA, Blackshaw PE.** *Superior mesenteric artery blood flow and gastric
  emptying in humans and the differential effects of high fat and high carbohydrate meals.* Gut.
  1994;35(2):186–190. PMID 8307468. Isoenergetic 2.5 MJ meals, **t50 significantly greater after fat
  (p < 0.02)**. **Caveats: emptying was not the primary endpoint, and while energy was matched, mass,
  volume and sieving burden were not — a 2.5 MJ high-fat meal is physically much smaller.**

- **Marciani L, et al.** *Effect of intragastric acid stability of fat emulsions on gastric emptying,
  plasma lipid profile and postprandial satiety.* Br J Nutr. 2009 (PMID 18680634); and *Enhancement of
  intragastric acid stability of a fat emulsion meal delays gastric emptying and increases
  cholecystokinin release and gallbladder contraction.* Am J Physiol Gastrointest Liver Physiol. 2007.
  **The reconciling finding, and the reason §1.2 refuses to rank macronutrients.** Emulsions matched
  for energy, volume *and* macronutrient, differing only in acid stability, empty roughly **two-fold**
  differently — the unstable one creams and leaves faster, the stable one empties slower with greater
  CCK release. Structure outweighs macronutrient identity at constant energy.

- **Goetze O, et al.** *The effect of macronutrients on gastric volume responses and gastric emptying
  in humans: a magnetic resonance imaging study.* Am J Physiol Gastrointest Liver Physiol.
  **2007**;292(1):G11–G17. PMID 16935851. **Cited by v1 for the opposite of what it found.** Note the
  year: the DOI carries 2005 (submission year), which is how v1 acquired a wrong date. Isovolumic
  500 ml, near-isocaloric: **initial emptying was *higher* for fat and protein than for glucose**, and
  thereafter *"the characteristics of the volume curves for stomach and meal were uniform for all
  macronutrients."* Retained in the literature list precisely so the error is not made again.

- **Foster C.** *Gastric Emptying During Exercise: Influence of Carbohydrate Concentration,
  Carbohydrate Source, and Exercise Intensity.* Ch. 6 in Marriott BM (ed.), *Fluid Replacement and
  Heat Stress*, National Academies Press, 1994. Verbatim:
  > "Even very low concentrations (<2 g per 100 ml) of simple CHO decrease the rate of emptying to
  > less than that of water."

  > "Glucose polymers may allow gastric emptying in the range of water up to about 5 g per 100 ml."

  Commercial drinks at 5.9 % sucrose and 7.1 % polymer-fructose **both emptied significantly more
  slowly than water**. Also: emptying rate **increases with ingested volume**; 150–350 ml boluses are
  workable. **This is the source that contradicts the popular "5–8 % ≈ water" line.** The commonly
  attributed "12 % retards absorption and causes distress" claim could not be located in this chapter
  — treat as unsourced. A separate chapter in the same volume is cited elsewhere in this repo for the
  opposite reading; §9 flags the conflict.

- **Thomas DT, Erdman KA, Burke LM.** *Position of the Academy of Nutrition and Dietetics, Dietitians
  of Canada, and the ACSM: Nutrition and Athletic Performance.* Med Sci Sports Exerc.
  2016;48(3):543–568. PMID 26891166. Co-published J Acad Nutr Diet 2016;116(3):501–528.
  **The top authority in this repo (`source-authority.md` R2), and the direct basis for §3 and §5's
  direction.** Verified verbatim against the MSSE full text and independently against the Dietitians
  of Canada edition of the same joint paper. *Cite by table caption, not number — MSSE prints it as
  Table 2, the DC edition as Table 1.*

  **Table, "Summary of guidelines for carbohydrate intake by athletes", row "Pre-event fuelling"**
  (adapted from Burke 2011):
  > ● Before exercise > 60 min | **1–4 g/kg consumed 1–4 h before exercise**

  Same row, comments column, all three bullets:
  > ● Timing, amount and type of carbohydrate foods and drinks should be chosen to suit the practical
  > needs of the event and individual preferences/experiences.
  > ● **Choices high in fat/protein/fiber may need to be avoided to reduce risk of gastrointestinal
  > issues during the event.**
  > ● Low glycemic index choices may provide a more sustained source of fuel for situations where
  > carbohydrate cannot be consumed during exercise.

  **The narrative sentence that actually licenses a composition rule** — stronger and more specific
  than the table's avoid-list, and the single most important citation in this document:
  > "Generally, foods with a **low-fat, low-fiber, and low–moderate protein content** are the
  > preferred choice for this pre-event menu since they are less prone to cause gastrointestinal
  > problems and promote gastric emptying."

  *(Its reference 120 is Rehrer NJ, et al., "Gastrointestinal complaints in relation to dietary intake
  in triathletes", Int J Sport Nutr. 1992;2(1):48–59 — the primary observation behind the advice.)*

  **On protein in the pre-event meal** — this is a positive recommendation, not a tolerance:
  > "Strategies to circumvent this problem include ensuring at least 1 g/kg carbohydrate in the
  > pre-event meal to compensate for the increased carbohydrate oxidation, **including a protein
  > source at the meal**, including some high-intensity efforts in the pre-exercise warm up… and
  > consuming carbohydrate during the exercise."

  **On low glycemic index** — the demotion, verbatim:
  > "pre-exercise intake of low glycemic index carbohydrate choices has not been found to provide a
  > universal benefit to performance… Furthermore, consumption of carbohydrate during exercise…
  > dampens any effects of pre-exercise carbohydrate intake on metabolism and performance."

  **On rehearsing the pre-event meal** (executive summary) — the basis for H7:
  > "The type, timing and amount of foods and fluids included in this pre-event meal and/or snack
  > should be **well trialed and individualized** according to the preferences, tolerance, and
  > experiences of each athlete."

  **On acute fat restriction** — licenses H1 as an *acute* rule specifically:
  > "If such focused restrictiveness around fat intake is practiced, it should be limited to acute
  > scenarios such as the pre-event diet or carbohydrate-loading where considerations of preferred
  > macronutrients or gastrointestinal comfort have priority."

  **What it still does not do: give a number.** "Low-fat, low-fiber, low–moderate protein" is
  direction, not a threshold. Every gram in §5 remains **[design]**.

- **Burke LM, Hawley JA, Wong SHS, Jeukendrup AE.** *Carbohydrates for training and competition.*
  J Sports Sci. 2011;29(sup1):S17–S27. Origin of the comment column above. Also qualitative.

- **Jeukendrup A, Gleeson M.** *Sport Nutrition.* 3rd ed. Human Kinetics; 2019. **Secondary source —
  mechanism only, never a standard** (see `source-authority.md` §2). Used here for the race-day food
  list at p. 491–492, which is the ancestor of §3's groups:
  > "refined grains (e.g., white rice), cooked cereals, corn- and rice-based cereals, white bread,
  > bagels (without seeds), pancakes, cooked vegetables (without seeds), cooked potatoes, ripe
  > bananas, cooked fruits, applesauce or fruit blends, lean meat, rice cakes, honey, syrup, and
  > pulp-free juice"

  and the conditional exclusion: *"avoid breakfasts that are high in fiber, fat, and protein and may
  want to avoid milk products (or use lactose-free products)."* **Conditional in the source,
  conditional here** (§3.10).

- **Burdon CA, et al.** *Effect of Glycemic Index of a Pre-exercise Meal on Endurance Exercise
  Performance: A Systematic Review and Meta-analysis.* Sports Med. 2017. Verbatim:
  > "weak evidence supports the claim that endurance performance following a pre-exercise LGI meal is
  > superior to that following a pre-exercise HGI meal."

  **Basis for GI not being a filter.**

- **McRorie JW, McKeown NM.** *Understanding the Physics of Functional Fibers in the Gastrointestinal
  Tract: An Evidence-Based Approach to Resolving Enduring Misconceptions about Insoluble and Soluble
  Fiber.* J Acad Nutr Diet. 2017;117(2):251–264. PMID 27863994. **The basis for §1.3's central move.**
  Solubility predicts almost nothing functionally; effects track **viscosity/gel-formation** and
  **fermentability**, which do not map onto the soluble/insoluble split (inulin, wheat dextrin and
  partially-hydrolysed guar are soluble and non-viscous).

- **Marciani L, et al.** *Effect of meal viscosity and nutrients on satiety, intragastric dilution and
  emptying.* Am J Physiol Gastrointest Liver Physiol. 2001. PMID 11352816. 2×2 MRI design separating
  viscosity from nutrient load: raising **nutrient** content delayed emptying **46 ± 9 → 76 ± 6 min
  (p < 0.004)**; raising **viscosity** had a smaller effect and drove *fullness*, not emptying.
  **Independent corroboration of §1.1 — energy dominates.**

- **Bianchi M, Capurso L.** *Effects of guar gum, ispaghula and microcrystalline cellulose on abdominal
  symptoms, gastric emptying, orocaecal transit time and gas production in healthy volunteers.* Dig
  Liver Dis. 2002. PMID 12408456. At 5 g: **no fibre changed gastric emptying**, while the two
  *soluble* fibres significantly raised abdominal symptoms (guar p = 0.009, ispaghula p = 0.048) and
  *insoluble* cellulose caused the fewest; gas production correlated with symptom severity
  (r = 0.38, p = 0.01). **The cleanest single demonstration that the symptoms are distal.** n = 10.

- **Rydning A, et al.** (1985) PMID 2988108. Guar versus fibre-enriched wheat bran on gastric emptying
  of a semisolid meal: **no effect by gamma camera.** The apparent bran effect appeared only on an
  unvalidated isotope monitor which the authors concluded "cannot be recommended." **The reason the
  "wheat bran speeds gastric emptying" claim should not be repeated** — bran's genuine effect is on
  small-bowel and whole-gut transit, a different organ.

- **Fibre nulls at food-realistic doses** — the evidence that H2 cannot be justified by emptying:
  Hlebowicz 2008 (PMID 18978166), 4 g oat β-glucan in muesli, no effect on emptying or satiety;
  Rigaud 1998 (PMID 9578335), 7.4 g psyllium, no delay of either solid or liquid phase.
  **Against**, at higher viscosity: PMID 38500209 (3.6 g high-MW β-glucan, T½ 61.9 → 78.9 min,
  p = 0.005) and PMID 31828287 (high- versus low-MW at the same 4 g dose — only high-MW delayed
  emptying, isolating viscosity as the causal variable). *Effect exists; food doses rarely reach it.*

- **Lis DM, et al.** *Low FODMAP: A Preliminary Strategy to Reduce Gastrointestinal Distress in
  Athletes.* Med Sci Sports Exerc. 2018. Six-day randomized single-blind crossover, 11 recreationally
  competitive runners. Daily GI symptom **AUC mean difference −13.4 (95 % CI −22 to −4.60,
  p = 0.003)**; flatulence p < 0.001, urge to defecate p = 0.04, loose stool p = 0.03, diarrhoea
  p = 0.004 — precisely the lower-gut cluster §1.3 attributes to fermentation. With the Gaskell/Costa
  heat-exercise work: 24 h sufficient, 6+ days typical, **82 %** improved. **No gram target in either
  literature.** **Read the limits honestly: n = 11, six days, single-blind — this is not a robust
  evidence base, and three studies in the ultra-endurance review reported athletes could not meet
  energy requirements on low-FODMAP.** That energy-availability cost is why S4 is time-boxed to the
  pre-competition window rather than standing advice.

- **Costa RJS, et al.** *Systematic review: exercise-induced gastrointestinal syndrome.* Aliment
  Pharmacol Ther. 2017;46:246–265. Qualitative pre-exercise guidance only.

- **Wilson PB.** *Dietary restrictions in endurance runners to mitigate exercise-induced
  gastrointestinal symptoms.* J Int Soc Sports Nutr. 2020. 23 % of runners self-report avoiding
  high-fibre food. **Behavioural evidence — the strongest quantitative fibre data available, and it
  is not a prescription.**

- **Jeukendrup AE.** *Training the Gut for Athletes.* Sports Med. 2017;47(Suppl 1):101–110.
  PMID 28332114. The GI tract is *"highly adaptable"*; gastric emptying and comfort are trainable;
  carbohydrate intake upregulates SGLT1. Rehearse the competition strategy at least weekly. **Basis
  for S6. Does not demonstrate H7's "nothing new on race day" — that remains consensus.**

- **McDermott BP, et al.** *NATA Position Statement: Fluid Replacement for the Physically Active.*
  J Athl Train. 2017;52(9):877–895. 500–600 ml at 2–3 h; 200–300 ml at 10–20 min. **Hydration
  prescriptions, not measured tolerance ceilings** — S5 uses them as a proxy and says so.

- **Simpson, et al. 2011.** 65 g carbohydrate-electrolyte gel (35.5 g CHO) with 250 ml water at t−15;
  time-trial distance +3.1 % and +3.4 %. **Basis for H6's bolus exemption — empirical, not mechanical.**

- **Abell TL, et al.** *Consensus Recommendations for Gastric Emptying Scintigraphy.* J Nucl Med
  Technol. 2008;36(1):44–54; Tougas normal values. The 255 kcal / 72 % carbohydrate / 24 % protein /
  2 % fat reference meal. **No longer used by this document** — see §1.2 for why the inference drawn
  from it in v1 was withdrawn, and §9 for the misquoted retention band it left elsewhere in the repo.

- **USDA FoodData Central.** All gram and percent-energy figures in §3.7 and §7. Peanut butter 172470;
  chicken breast 171477; oats 173905; banana 173944; whole-wheat bread 172688.

---

## 11 · Checks a conformance suite should assert

Stated as properties of the document, deliberately not tied to any engine interface.

1. Every canonical feeding in §3.11 passes every hard gate in §5 for its tier — **except** the two
   documented exceptions (t−25 banana against H2; 3 oz chicken against H3), which must be asserted as
   *known* exceptions rather than silently tolerated.
2. No soft score in §6 can reject a feeding. A test that shows S1–S6 gating selection is a bug.
   **Specifically assert that no feeding is ever rejected on calorie count**, at any body mass or
   lead time — S1 is advisory by construction and a regression here would be silent.
3. H1 and H2 scale with body mass and never fall below their floors: at 50 and 65 kg they equal the
   floor exactly; at 95 kg they equal the per-kg term. A feeding that passes at 65 kg must still pass
   at 95 kg (the gates are monotonic non-decreasing in body mass).
4. Hard gates are evaluated on the summed feeding, never per item (§4).
5. No percentage is evaluated on a feeding under 50 kcal.
6. `gutTolerance == low` removes G6 from the meal and snack tiers; `unknown` behaves as `moderate`.
7. A drink over 8 % carbohydrate is rejected from the top-off unless it is a single ≤ 300 ml bolus
   with chase water — and pulp-free juice specifically is rejected there.
8. A zero-carbohydrate item is never offered as a top-off (H5).
9. Every group in §3 has a rating for all three tiers, and every food named in §3.1–§3.9 belongs to
   exactly one group.
10. **G4b (sports drink, drink mix, gel, chews) is permitted in all three tiers** (v3 — reverses the
    v2 top-off-only ruling). A test asserting a sports drink is unavailable at the meal or snack tier
    is pinning the superseded rule.
11. H6 is evaluated **only** on top-off drinks. A juice or milk taken with a meal or snack must not be
    concentration-gated — a test that rejects one is reading H6 out of scope.
