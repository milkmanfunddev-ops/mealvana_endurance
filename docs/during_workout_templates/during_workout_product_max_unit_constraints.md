# During-Workout Product Max Unit Constraints

Source: [Notion Page - During-Workout Product Max Unit Constraints](https://www.notion.so/During-Workout-Product-Max-Unit-Constraints-337e3fdb754c81a39d5fd0cc4d81bb0b)

## Overview

This document defines the maximum number of units per hour for each product category used in during-workout nutrition templates. These constraints prevent the solver from producing unrealistic plans (e.g., 5 gels per hour) and are applied at the **product level**, not the template level, since the same product appears across multiple templates.

These constraints work alongside the template selection logic and carb ratio algorithm described in the companion doc: During-Workout Template Selection & Carb Ratio Algorithm.

---

## Tiered Max Units by Gut Training Level

Max units are not one-size-fits-all. An athlete with a well-trained gut can tolerate more frequent feeding than one who is new to structured fueling. The constraint tiers align with the existing gut training gate system (Low / Moderate / High).

| Product | Unit Size (carb) | Low Gut Training | Moderate Gut Training | High Gut Training | Rationale |
|---------|-----------------|-----------------|----------------------|------------------|-----------|
| Gel | ~25g carb/gel | 2/hr | 3/hr | 3/hr | Each gel requires a water chase (~4 oz). At 3/hr, that is 12 oz of water just for chasing, which starts crowding the fluid budget. Each gel is a concentrated osmotic load; spacing more than 3 into 60 min compresses absorption windows. Low gut athletes cap at 2 because the osmotic stress of back-to-back gels triggers GI distress. |
| Chew | ~25g carb/serving (4-6 pieces) | 1 serving/hr | 2 servings/hr | 2 servings/hr | A serving is typically 4-6 individual pieces. 2 servings means roughly 10 individual chews per hour. The chewing time alone becomes a limiting factor. Low gut athletes stick to 1 serving to minimize GI volume load. |
| Bar | ~22g carb/bar | 0.5/hr | 1/hr | 1/hr | Bars require significant chewing and have the slowest gastric emptying of any template food due to fat and fiber content. Even on a bike, more than 1 bar/hr risks gastric pooling. Low gut athletes should eat half a bar (split into small bites over 30 min). |
| Stroopwafel | ~25g carb/wafel | 1/hr | 1/hr | 2/hr | Easier to eat than bars (thin, soft, melts in the mouth), but still a solid. 2/hr is achievable only for well-trained guts. Low and Moderate athletes cap at 1 because the sugar and syrup content can cause osmotic diarrhea at higher volumes. |
| Banana | ~27g carb/banana | 0.5/hr | 1/hr | 1/hr | Bulky, contains fiber that slows digestion. Requires peeling or pre-peeling and storing. Even at High gut training, 1/hr is the practical and GI ceiling because of the fiber and fructose content. |
| Rice Cake | ~35g carb/cake | 1/hr | 1/hr | 2/hr | Homemade rice cakes are usually small portions. 2/hr is realistic only for pro-level fueling with a trained gut. Most athletes will naturally eat 1/hr. Rice cakes are denser in carbs per unit than other solids, so even 1/hr contributes meaningfully. |
| Sports Drink | ~7% concentration (70g carb/L) | 16 oz/hr (480ml) | 20 oz/hr (600ml) | 24 oz/hr (700ml) | This is a volume ceiling on the sports drink portion of total fluid, not the total fluid target. The remaining fluid need is met by plain water. At 24 oz of 7% sports drink, the athlete gets ~50g carb from liquid alone. Going higher means almost no plain water, which creates problems for gel chasing and mouth rinsing. Low gut athletes cap lower because high sports drink volumes can cause sloshing and nausea. |
| High Carb Drink Mix | 80-100g carb/bottle (500-750ml) | N/A | N/A | 1 bottle/hr | Only available to High gut training athletes (matches Template 6 and Templates 17-20 gut gate). Bounded by product mixing directions. More than 1 bottle per hour pushes past even well-trained gut tolerance. The high osmolality requires a separate plain water bottle for rinsing and dilution. |

---

## Algorithm Implementation Notes

### How to Apply These Constraints

The max unit constraint is a **ceiling**, not a target. The solver should:

1. Calculate the ideal food units from the carb allocation (see Carb Ratio Algorithm doc)
2. Clamp each product to its max based on the athlete's gut training level
3. If clamping reduces total carb delivery below target minus tolerance (10g/hr), the algorithm should either increase sports drink sipping to compensate (if within sports drink ceiling) or flag to the coach that the carb target may be too aggressive for this template and gut training level

```javascript
function applyMaxConstraints(foodUnits, product, gutTrainingLevel):
    maxAllowed = MAX_TABLE[product][gutTrainingLevel]
    if foodUnits > maxAllowed:
        foodUnits = maxAllowed
        shortfall = (originalUnits - maxAllowed) * product.carbPerUnit
        tryCompensateWithSportsDrink(shortfall)
    return foodUnits
```

### Interaction with the 1:1 Unit Ratio (Triple-Source Templates)

For triple-source templates (8, 10, 12, 14), the 1:1 solid-to-gel unit ratio and the max constraints interact:

- If the solid max is lower than the gel max (e.g., bar at 1/hr vs gel at 3/hr), the 1:1 ratio means the gel is effectively capped at the solid's max too
- Example: Template 8 (Bar + Gel) for a Moderate gut athlete. Bar max = 1/hr, Gel max = 3/hr. But 1:1 ratio means the plan is 1 bar + 1 gel per hour. The gel max of 3 is not the binding constraint; the bar max of 1 is.
- The binding constraint is always `min(solid_max, gel_max)` for both products in a triple-source template

```javascript
function applyTripleSourceConstraints(solidUnits, gelUnits, solidMax, gelMax):
    bindingMax = min(solidMax, gelMax)
    solidUnits = min(solidUnits, bindingMax)
    gelUnits = solidUnits  // enforce 1:1
    return solidUnits, gelUnits
```

### Rounding Rules

When applying max constraints, round food units to the nearest 0.5:

- 0.5 of a bar = half a bar, eaten in small bites (realistic)
- 0.5 of a banana = half a banana (realistic)
- 0.5 of a gel = not realistic. Gels are all-or-nothing. Round to 0 or 1.
- 0.5 of a chew serving = 2-3 individual chew pieces (realistic)
- 0.5 of a stroopwafel = half a wafel (realistic but messy; prefer rounding to 1)
- 0.5 of a rice cake = half a rice cake (realistic)

The algorithm should use product-specific rounding rules:

| Product | Min increment | Notes |
|---------|--------------|-------|
| Gel | 1 | All-or-nothing. No half gels. |
| Chew | 0.5 serving | Half a serving is 2-3 pieces, which is practical |
| Bar | 0.5 | Half bars are common in practice |
| Stroopwafel | 1 | Hard to split cleanly; treat as whole unit |
| Banana | 0.5 | Half banana is practical |
| Rice Cake | 0.5 | Half rice cake is practical |
| Sports Drink | Continuous (oz) | No rounding needed; athlete sips freely |

### Edge Case: Carb Target Exceeds Product Capacity

If the carb rate target is so high that even at max product units + max sports drink, the template cannot deliver enough carbs, the algorithm should:

1. Flag this condition to the coach
2. Suggest either reducing the carb target, upgrading gut training level, or switching to a higher-density template (e.g., from regular sports drink templates to high carb drink mix templates)
3. Never silently exceed the max unit constraints

---

## Future Considerations

**Per-product allergen and dietary interaction:** Some athletes cannot use certain product categories at all (e.g., gluten-free athletes cannot use stroopwafels or most bars). The max constraint for excluded products should be set to 0, effectively removing them from the solver's feasible set. This interacts with the template selection filter (if all products in a template are excluded, the template itself is filtered out).

**Condition-based adjustment:** In hot conditions, GI tolerance drops. A future version could apply a condition multiplier to the max constraints (e.g., multiply all solid food maxes by 0.7 in heat index > 90F), effectively tightening the ceiling without changing the base table.

**Progressive overload in training:** Coaches may want to gradually increase max units as part of a gut training program. The algorithm could support a "training mode" where maxes are set 1 tier below the athlete's current gut training level, encouraging the athlete to build tolerance incrementally.
