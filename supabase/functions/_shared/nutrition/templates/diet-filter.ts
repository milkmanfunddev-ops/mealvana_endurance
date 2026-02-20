/**
 * Diet & Allergen Filtering
 *
 * Filters templates and drink pool items based on user's dietary preferences
 * and allergen restrictions.
 */

import { type Template, type DrinkPoolItem } from './types.ts';

// ============================================================================
// Template Filtering
// ============================================================================

/**
 * Filter templates by dietary preference and allergens.
 *
 * A template is excluded if:
 * - Its excluded_diets array contains the user's dietary_preference
 * - Its allergens array overlaps with the user's allergies
 */
export function filterTemplatesByDiet(
  templates: Template[],
  dietaryPreference?: string,
  allergies?: string[],
): Template[] {
  return templates.filter((template) => {
    // Check dietary exclusion
    if (dietaryPreference && template.excluded_diets.length > 0) {
      const normalizedDiet = dietaryPreference.toLowerCase();
      if (template.excluded_diets.some((d) => d.toLowerCase() === normalizedDiet)) {
        return false;
      }
    }

    // Check allergen overlap
    if (allergies && allergies.length > 0 && template.allergens.length > 0) {
      const normalizedAllergies = new Set(allergies.map((a) => a.toLowerCase()));
      if (template.allergens.some((a) => normalizedAllergies.has(a.toLowerCase()))) {
        return false;
      }
    }

    return true;
  });
}

// ============================================================================
// Drink Pool Filtering
// ============================================================================

/**
 * Filter drink pool items by dietary preference and allergens.
 */
export function filterDrinksByDiet(
  drinks: DrinkPoolItem[],
  dietaryPreference?: string,
  allergies?: string[],
): DrinkPoolItem[] {
  // Drinks are generally allergen-free, but we check just in case
  return drinks.filter((drink) => {
    // No excluded_diets on drinks currently, but could be added
    // Check allergens if present (e.g., dairy in milk/chocolate_milk)
    if (allergies && allergies.length > 0) {
      const normalizedAllergies = new Set(allergies.map((a) => a.toLowerCase()));
      // If the drink name suggests dairy and user is allergic
      if (normalizedAllergies.has('dairy')) {
        const dairyDrinks = ['milk', 'milk_whole', 'chocolate_milk', 'fruit_smoothie'];
        if (dairyDrinks.includes(drink.name)) {
          return false;
        }
      }
    }

    // Exclude coffee-based drinks for vegan (optional, most vegans drink coffee)
    // Actually no - coffee is vegan, so no exclusion needed

    return true;
  });
}

// ============================================================================
// Food Preference Filtering
// ============================================================================

/**
 * Filter templates based on user food preferences (liked/disliked foods).
 *
 * A template is penalized (not excluded) if it contains disliked foods.
 * Templates with liked foods get a boost.
 * Returns templates sorted by preference score.
 */
export function scoreTemplatesByPreference(
  templates: Template[],
  likedFoods?: string[],
  dislikedFoods?: string[],
): Template[] {
  const likedSet = new Set((likedFoods ?? []).map((f) => f.toLowerCase()));
  const dislikedSet = new Set((dislikedFoods ?? []).map((f) => f.toLowerCase()));

  // Score and sort
  const scored = templates.map((template) => {
    let score = 0;
    for (const foodName of template.food_names) {
      const normalized = foodName.toLowerCase();
      if (likedSet.has(normalized)) {
        score += 10;
      } else if (dislikedSet.has(normalized)) {
        score -= 20; // Strong penalty for disliked foods
      }
    }
    return { template, score };
  });

  // Filter out templates where ALL foods are disliked
  const filtered = scored.filter(({ template, score }) => {
    if (dislikedSet.size === 0) return true;
    const allDisliked = template.food_names.every((fn) =>
      dislikedSet.has(fn.toLowerCase())
    );
    return !allDisliked;
  });

  // Sort by score descending
  filtered.sort((a, b) => b.score - a.score);

  return filtered.map(({ template }) => template);
}
