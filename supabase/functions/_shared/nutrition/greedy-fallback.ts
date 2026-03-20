/**
 * Greedy Fallback Algorithm for Nutrition Planning
 *
 * Used when the LP solver fails to find a feasible solution
 */

import { roundToIncrement } from '../utils.ts';
import { type Food, type Phase, type MacroTargets, type PhaseSolution, deriveTimingCategory } from './types.ts';

/**
 * Greedy algorithm that selects foods based on preference and macro efficiency
 */
export function greedyFallback(
  foods: Food[],
  targets: MacroTargets,
  phase: Phase
): PhaseSolution {
  console.log(
    `[GREEDY-FALLBACK] Using greedy approach for ${phase} phase | ` +
    `targets: carbs=${targets.carbs_g}g, protein=${targets.protein_g ?? 0}g, ` +
    `sodium=${targets.sodium_mg}mg, water=${targets.water_ml}ml | ` +
    `food pool: ${foods.length} foods`
  );

  const selectedFoods: PhaseSolution['foods'] = [];
  const totals = {
    carbs_g: 0,
    protein_g: 0,
    fat_g: 0,
    sodium_mg: 0,
    water_ml: 0,
    calories: 0,
  };

  // Sort foods by preference score and macro efficiency
  const sortedFoods = [...foods].sort((a, b) => {
    // Primary: preference score
    if (a.preference_score !== b.preference_score) {
      return b.preference_score - a.preference_score;
    }

    // Secondary: carb efficiency (carbs per serving)
    const carbsA = a.per_serving.carbs_g;
    const carbsB = b.per_serving.carbs_g;

    if (phase === 'after') {
      // For after-run, also consider protein efficiency
      const proteinA = a.per_serving.protein_g;
      const proteinB = b.per_serving.protein_g;
      return carbsB + proteinB - (carbsA + proteinA);
    }

    return carbsB - carbsA;
  });

  // Greedily select foods to meet targets
  // During phase needs more items for longer runs to meet macro targets
  // After phase needs more items to meet both macro and hydration targets
  const maxFoods = phase === 'during' ? 5 : phase === 'after' ? 6 : 3;
  const carbsTarget = targets.carbs_g;
  const proteinTarget = targets.protein_g || 0;
  const sodiumTarget = targets.sodium_mg || 0;
  const waterTarget = targets.water_ml || 0;

  for (const food of sortedFoods) {
    if (selectedFoods.length >= maxFoods) break;

    // Check if adding this food would cause excessive overshoots
    const wouldOvershootCarbs =
      carbsTarget > 0 &&
      totals.carbs_g + food.per_serving.carbs_g > carbsTarget * 1.3;
    const wouldOvershootSodium =
      sodiumTarget > 0 &&
      totals.sodium_mg + food.per_serving.sodium_mg > sodiumTarget * 1.3;
    const wouldOvershootWater =
      waterTarget > 0 &&
      totals.water_ml + food.per_serving.water_ml > waterTarget * 1.3;
    const wouldOvershootProtein =
      proteinTarget > 0 &&
      totals.protein_g + food.per_serving.protein_g > proteinTarget * 1.3;

    // Skip foods that would cause major overshoots
    // Carbs check is critical: prevents high-carb user foods from dominating
    // recovery plans (e.g. 80g carb drink mix in a 52-78g carb budget).
    // Exception: when protein is critically unmet in after phase, allow
    // low-carb protein foods through (e.g. Protein Shake with 5g carbs).
    const proteinCriticallyUnmetSkip =
      phase === 'after' && proteinTarget > 0 && totals.protein_g < proteinTarget * 0.7;

    console.log(
      `[GREEDY-FALLBACK] Considering: ${food.name} (pref=${food.preference_score}) | ` +
      `per_serving: carbs=${food.per_serving.carbs_g}g, protein=${food.per_serving.protein_g}g, ` +
      `sodium=${food.per_serving.sodium_mg}mg, water=${food.per_serving.water_ml}ml`
    );

    if (wouldOvershootCarbs && totals.carbs_g > carbsTarget * 0.7 && !proteinCriticallyUnmetSkip) {
      console.log(`[GREEDY-FALLBACK] SKIP ${food.name}: carb overshoot (current=${totals.carbs_g.toFixed(0)}g, target=${carbsTarget}g)`);
      continue;
    }
    if (wouldOvershootSodium && totals.sodium_mg > sodiumTarget * 0.7) {
      console.log(`[GREEDY-FALLBACK] SKIP ${food.name}: sodium overshoot (current=${totals.sodium_mg.toFixed(0)}mg, target=${sodiumTarget}mg)`);
      continue;
    }
    if (wouldOvershootWater && totals.water_ml > waterTarget * 0.7) {
      console.log(`[GREEDY-FALLBACK] SKIP ${food.name}: water overshoot (current=${totals.water_ml.toFixed(0)}ml, target=${waterTarget}ml)`);
      continue;
    }
    if (wouldOvershootProtein && totals.protein_g > proteinTarget * 0.9) {
      console.log(`[GREEDY-FALLBACK] SKIP ${food.name}: protein overshoot (current=${totals.protein_g.toFixed(0)}g, target=${proteinTarget}g)`);
      continue;
    }

    // Calculate needed servings based on primary targets
    let neededServings = 0;

    if (phase === 'after' && proteinTarget > 0) {
      // For after-run, prioritize protein then carbs
      const proteinDeficit = Math.max(0, proteinTarget - totals.protein_g);
      const carbsDeficit = Math.max(0, carbsTarget - totals.carbs_g);
      const sodiumDeficit = Math.max(0, sodiumTarget - totals.sodium_mg);
      const waterDeficit = Math.max(0, waterTarget - totals.water_ml);

      if (proteinDeficit > 0 && food.per_serving.protein_g > 0) {
        neededServings = Math.ceil(proteinDeficit / food.per_serving.protein_g);
      } else if (carbsDeficit > 0 && food.per_serving.carbs_g > 0) {
        neededServings = Math.ceil(carbsDeficit / food.per_serving.carbs_g);
      } else if (waterDeficit > 0 && food.per_serving.water_ml > 0) {
        // Once carbs/protein are close, explicitly fill hydration.
        neededServings = Math.ceil(waterDeficit / food.per_serving.water_ml);
      } else if (sodiumDeficit > 0 && food.per_serving.sodium_mg > 0) {
        // Then fill sodium if still short.
        neededServings = Math.ceil(sodiumDeficit / food.per_serving.sodium_mg);
      }
    } else {
      // For before/during, focus on carbs
      const carbsDeficit = Math.max(0, carbsTarget - totals.carbs_g);
      if (carbsDeficit > 0 && food.per_serving.carbs_g > 0) {
        neededServings = Math.ceil(carbsDeficit / food.per_serving.carbs_g);
      }
    }

    // Reduce servings if it would cause major overshoots
    if (neededServings > 0) {
      // Check carb overshoot potential — cap servings so carbs stay within target.
      // When protein is critically unmet (after phase), relax the carb ceiling
      // to 1.5x so protein-rich foods like Protein Shake (5g carbs) can still
      // fit even after high-carb user foods consume most of the budget.
      if (carbsTarget > 0 && food.per_serving.carbs_g > 0) {
        const proteinCriticallyUnmet =
          phase === 'after' && proteinTarget > 0 && totals.protein_g < proteinTarget * 0.7;
        const carbMaxMultiplier = proteinCriticallyUnmet ? 1.5 : 1.2;
        const maxCarbServings = Math.floor(
          (carbsTarget * carbMaxMultiplier - totals.carbs_g) / food.per_serving.carbs_g
        );
        if (maxCarbServings <= 0) {
          neededServings = 0; // Skip entirely — carbs already met/exceeded
        } else {
          neededServings = Math.min(neededServings, maxCarbServings);
        }
      }

      // Check sodium overshoot potential
      if (sodiumTarget > 0 && food.per_serving.sodium_mg > 0) {
        const maxSodiumServings = Math.floor(
          (sodiumTarget * 1.25 - totals.sodium_mg) / food.per_serving.sodium_mg
        );
        neededServings = Math.min(neededServings, Math.max(1, maxSodiumServings));
      }

      // Check water overshoot potential
      if (waterTarget > 0 && food.per_serving.water_ml > 0) {
        const maxWaterServings = Math.floor(
          (waterTarget * 1.2 - totals.water_ml) / food.per_serving.water_ml
        );
        neededServings = Math.min(neededServings, Math.max(1, maxWaterServings));
      }

      // Check protein overshoot potential
      if (proteinTarget > 0 && food.per_serving.protein_g > 0) {
        const maxProteinServings = Math.floor(
          (proteinTarget * 1.2 - totals.protein_g) / food.per_serving.protein_g
        );
        if (maxProteinServings <= 0) {
          neededServings = 0; // Skip entirely — protein already met
        } else {
          neededServings = Math.min(neededServings, maxProteinServings);
        }
      }
    }

    // Cap servings at reasonable amounts
    const servingCap = phase === 'after' ? 6 : 3;
    neededServings = Math.min(neededServings, servingCap);

    // Indivisible items (tablets, gel packets) round to whole numbers;
    // everything else rounds to nearest 0.5
    neededServings = food.is_indivisible
      ? Math.max(1, Math.round(neededServings))
      : roundToIncrement(neededServings);

    if (neededServings > 0) {
      console.log(
        `[GREEDY-FALLBACK] SELECT ${food.name} x${neededServings} → ` +
        `carbs=${(food.per_serving.carbs_g * neededServings).toFixed(1)}g, ` +
        `protein=${(food.per_serving.protein_g * neededServings).toFixed(1)}g, ` +
        `sodium=${(food.per_serving.sodium_mg * neededServings).toFixed(0)}mg, ` +
        `water=${(food.per_serving.water_ml * neededServings).toFixed(0)}ml`
      );

      selectedFoods.push({
        food_id: food.id,
        quantity: neededServings,
        carbs_grams: food.per_serving.carbs_g * neededServings,
        protein_grams: food.per_serving.protein_g * neededServings,
        fat_grams: food.per_serving.fat_g * neededServings,
        sodium_mg: food.per_serving.sodium_mg * neededServings,
        fluids_ml: food.per_serving.water_ml * neededServings,
        calories: food.per_serving.calories * neededServings,
        display_name: food.display_name ?? undefined,
        display_name_plural: food.display_name_plural ?? undefined,
        description: food.description ?? undefined,
        image_address: food.image_address ?? undefined,
        is_liquid: food.is_liquid ?? false,
        is_electrolyte: food.is_electrolyte ?? false,
        is_drink: food.is_liquid ?? false,
        is_indivisible: food.is_indivisible ?? false,
        timing_category: deriveTimingCategory(food),
        product_type: food.product_type,
      });

      totals.carbs_g += food.per_serving.carbs_g * neededServings;
      totals.protein_g += food.per_serving.protein_g * neededServings;
      totals.fat_g += food.per_serving.fat_g * neededServings;
      totals.sodium_mg += food.per_serving.sodium_mg * neededServings;
      totals.water_ml += food.per_serving.water_ml * neededServings;

      // Stop if we've met carb, protein, and water targets
      const carbsMet = totals.carbs_g >= carbsTarget * 0.9;
      const proteinMet = proteinTarget <= 0 || totals.protein_g >= proteinTarget * 0.7;
      const waterStopMultiplier = phase === 'after' ? 0.85 : 0.7;
      const waterMet = waterTarget <= 0 || totals.water_ml >= waterTarget * waterStopMultiplier;
      if (carbsMet && proteinMet && waterMet) break;
    }
  }

  // Log final summary
  const carbPct = carbsTarget > 0 ? (totals.carbs_g / carbsTarget * 100).toFixed(0) : 'n/a';
  const proteinPct = proteinTarget > 0 ? (totals.protein_g / proteinTarget * 100).toFixed(0) : 'n/a';
  const sodiumPct = sodiumTarget > 0 ? (totals.sodium_mg / sodiumTarget * 100).toFixed(0) : 'n/a';
  const waterPct = waterTarget > 0 ? (totals.water_ml / waterTarget * 100).toFixed(0) : 'n/a';
  console.log(
    `[GREEDY-FALLBACK] Final: ${selectedFoods.length} foods | ` +
    `carbs=${totals.carbs_g.toFixed(0)}g/${carbsTarget}g(${carbPct}%) ` +
    `protein=${totals.protein_g.toFixed(0)}g/${proteinTarget}g(${proteinPct}%) ` +
    `sodium=${totals.sodium_mg.toFixed(0)}mg/${sodiumTarget}mg(${sodiumPct}%) ` +
    `water=${totals.water_ml.toFixed(0)}ml/${waterTarget}ml(${waterPct}%)`
  );

  return {
    foods: selectedFoods,
    totals,
    needsElectrolyte: false,
    needsWater: false,
  };
}
