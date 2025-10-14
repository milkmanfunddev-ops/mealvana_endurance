import { describe, it, expect } from 'vitest';

/**
 * CRITICAL BUSINESS LOGIC TESTS FOR GENERATE-AI-NUTRITION-PLAN
 *
 * Focus: Validate that the core business rules are enforced:
 * 1. Disliked foods NEVER appear in solutions (except essential foods)
 * 2. Essential foods override dislike preferences
 * 3. Food preference scoring is correct
 * 4. Available food filtering works as expected
 *
 * Note: This tests the business logic without complex LP modeling
 */

// Test scenarios representing different types of runners
const RUNNER_SCENARIOS = [
  {
    name: "Picky_Beginner_5K",
    distance: "5K",
    liked_foods: ["banana"],
    willing_foods: ["orange"],
    disliked_foods: ["gel", "bar", "oatmeal", "waffle", "chew"],
    expected_available_foods: 7, // banana, orange, sports drink (essential), dates, coconut water, toast, gel (essential)
    critical_test: "Many dislikes should not prevent nutrition planning"
  },
  {
    name: "Marathon_Gel_Lover",
    distance: "Marathon",
    liked_foods: ["gel", "sports drink", "chew"],
    willing_foods: ["bar"],
    disliked_foods: ["oatmeal", "toast"],
    expected_available_foods: 9, // Should exclude 2 disliked foods
    critical_test: "Gel lover should have energy-dense options available"
  },
  {
    name: "Ultra_Whole_Food_Purist",
    distance: "Ultra",
    liked_foods: ["banana", "dates", "orange", "coconut water"],
    willing_foods: ["toast"],
    disliked_foods: ["gel", "bar", "waffle", "chew"],
    expected_available_foods: 8, // Whole foods + essential foods (gel + sports drink)
    critical_test: "Whole food preference should still allow essential sports nutrition"
  },
  {
    name: "All_Foods_Disliked_Emergency",
    distance: "Marathon",
    liked_foods: [],
    willing_foods: [],
    disliked_foods: ["banana", "gel", "oatmeal", "bar", "sports drink", "chew", "dates", "orange", "coconut water", "waffle", "toast"],
    expected_available_foods: 2, // Should only have essential foods (GU Gel, Gatorade)
    critical_test: "Essential foods must override all dislikes in emergency scenarios"
  }
];

// Mock food database matching our seeded test data
const TEST_FOOD_DATABASE = [
  { id: "f1", name: "TEST: Banana", display_name: "banana", is_essential: false, carbs_per_serving: 27 },
  { id: "f2", name: "TEST: GU Energy Gel", display_name: "gel", is_essential: true, carbs_per_serving: 22 },
  { id: "f3", name: "TEST: Oatmeal", display_name: "oatmeal", is_essential: false, carbs_per_serving: 27 },
  { id: "f4", name: "TEST: Gatorade", display_name: "sports drink", is_essential: true, carbs_per_serving: 14 },
  { id: "f5", name: "TEST: Clif Bar", display_name: "bar", is_essential: false, carbs_per_serving: 45 },
  { id: "f6", name: "TEST: Clif Shot Bloks", display_name: "chew", is_essential: false, carbs_per_serving: 24 },
  { id: "f7", name: "TEST: Dates", display_name: "dates", is_essential: false, carbs_per_serving: 30 },
  { id: "f8", name: "TEST: Orange Slices", display_name: "orange", is_essential: false, carbs_per_serving: 15 },
  { id: "f9", name: "TEST: Coconut Water", display_name: "coconut water", is_essential: false, carbs_per_serving: 11 },
  { id: "f10", name: "TEST: Honey Stinger Waffle", display_name: "waffle", is_essential: false, carbs_per_serving: 21 },
  { id: "f11", name: "TEST: Peanut Butter Toast", display_name: "toast", is_essential: false, carbs_per_serving: 28 },
  {
    id: "f12",
    name: "TEST: Experimental Fuel",
    display_name: "experimental fuel",
    is_essential: false,
    carbs_per_serving: 18,
    to_exclude_from_solver: true
  }
];

// Food preference scoring (matches edge function)
const PREFERENCE_SCORES = {
  liked: 200,
  willing: 80,
  neutral: 20,
  essential: 50 // Edge function treats essential foods on par with willing options
};

// Core business logic functions (extracted from edge function)
function buildPreferenceSet(foodList: string[]): Set<string> {
  const set = new Set<string>();
  if (!Array.isArray(foodList)) return set;

  foodList.forEach(item => {
    if (typeof item === 'string' && item.trim()) {
      set.add(item.trim().toLowerCase());
    }
  });
  return set;
}

function matchesPreference(food: any, preferenceSet: Set<string>): boolean {
  const foodName = food.name?.toLowerCase();
  const displayName = food.display_name?.toLowerCase();

  return preferenceSet.has(food.id) ||
         preferenceSet.has(food.name) ||
         (foodName && preferenceSet.has(foodName)) ||
         (displayName && preferenceSet.has(displayName)) ||
         Array.from(preferenceSet).some(pref =>
           (foodName && pref.includes(foodName)) ||
           (foodName && foodName.includes(pref))
         );
}

function applyFoodPreferences(foods: any[], liked: Set<string>, willing: Set<string>, disliked: Set<string>) {
  console.log(`\n🔍 Processing ${foods.length} foods with preferences`);
  console.log(`💚 Liked: [${Array.from(liked).join(', ')}]`);
  console.log(`⚠️  Willing: [${Array.from(willing).join(', ')}]`);
  console.log(`❌ Disliked: [${Array.from(disliked).join(', ')}]`);

  // First, filter out disliked foods (unless essential)
  const availableFoods = foods.filter(food => {
    const isDisliked = matchesPreference(food, disliked);
    const isEssential = food.is_essential === true;
    const isExcluded = food.to_exclude_from_solver === true;

    if (isDisliked && !isEssential) {
      console.log(`❌ EXCLUDING disliked food: ${food.name}`);
      return false;
    }

    if (isDisliked && isEssential) {
      console.log(`⚡ OVERRIDING dislike for essential food: ${food.name}`);
    }

    if (isExcluded) {
      console.log(`🚫 EXCLUDING solver-flagged food: ${food.name}`);
      return false;
    }

    return true;
  });

  // Then, apply preference scoring
  const scoredFoods = availableFoods.map(food => {
    const isLiked = matchesPreference(food, liked);
    const isWilling = matchesPreference(food, willing);
    const isEssential = food.is_essential === true;

    let preferenceCategory = 'neutral';
    let score = PREFERENCE_SCORES.neutral;

    if (isEssential) {
      preferenceCategory = 'essential';
      score = PREFERENCE_SCORES.essential;
      console.log(`⚡ ESSENTIAL: ${food.name} (score: ${score})`);
    } else if (isLiked) {
      preferenceCategory = 'liked';
      score = PREFERENCE_SCORES.liked;
      console.log(`💚 LIKED: ${food.name} (score: ${score})`);
    } else if (isWilling) {
      preferenceCategory = 'willing';
      score = PREFERENCE_SCORES.willing;
      console.log(`⚠️  WILLING: ${food.name} (score: ${score})`);
    } else {
      console.log(`⚪ NEUTRAL: ${food.name} (score: ${score})`);
    }

    return {
      ...food,
      preference_category: preferenceCategory,
      preference_score: score
    };
  });

  console.log(`✅ Final available foods: ${scoredFoods.length}`);
  return scoredFoods;
}

function validateNutritionFeasibility(availableFoods: any[], targetCarbs: number): boolean {
  // Simple heuristic: can we meet carb target with available foods?
  const totalAvailableCarbs = availableFoods.reduce((sum, food) => {
    const maxServings = 4; // Simplified
    return sum + (food.carbs_per_serving * maxServings);
  }, 0);

  const feasible = totalAvailableCarbs >= targetCarbs * 0.8; // 80% of target is feasible
  console.log(`🎯 Target carbs: ${targetCarbs}g, Available: ${totalAvailableCarbs}g, Feasible: ${feasible ? '✅' : '❌'}`);

  return feasible;
}

describe('Generate AI Nutrition Plan - Business Logic Tests', () => {

  describe('Critical Business Rules Validation', () => {
    RUNNER_SCENARIOS.forEach(scenario => {
      describe(`${scenario.name} - ${scenario.distance}`, () => {

        it('should never include disliked foods in available options (except essential)', () => {
          console.log(`\n🏃‍♂️ Testing: ${scenario.name}`);
          console.log(`🎯 Critical test: ${scenario.critical_test}`);

          const likedFoods = buildPreferenceSet(scenario.liked_foods);
          const willingFoods = buildPreferenceSet(scenario.willing_foods);
          const dislikedFoods = buildPreferenceSet(scenario.disliked_foods);

          const availableFoods = applyFoodPreferences(
            TEST_FOOD_DATABASE,
            likedFoods,
            willingFoods,
            dislikedFoods
          );

          // CRITICAL: Verify expected number of available foods
          expect(availableFoods).toHaveLength(scenario.expected_available_foods);

          // CRITICAL: No disliked foods should appear (unless essential)
          availableFoods.forEach(food => {
            const isDisliked = matchesPreference(food, dislikedFoods);
            if (isDisliked) {
              expect(food.is_essential).toBe(true); // Only essential foods can override dislikes
              console.log(`✅ Essential food ${food.name} correctly overrides dislike`);
            }
          });

          console.log(`✅ ${scenario.name}: All business rules validated`);
        });

        it('should have proper preference scoring', () => {
          const likedFoods = buildPreferenceSet(scenario.liked_foods);
          const willingFoods = buildPreferenceSet(scenario.willing_foods);
          const dislikedFoods = buildPreferenceSet(scenario.disliked_foods);

          const availableFoods = applyFoodPreferences(
            TEST_FOOD_DATABASE,
            likedFoods,
            willingFoods,
            dislikedFoods
          );

          availableFoods.forEach(food => {
            if (food.is_essential) {
              expect(food.preference_score).toBe(PREFERENCE_SCORES.essential);
            } else if (matchesPreference(food, likedFoods)) {
              expect(food.preference_score).toBe(PREFERENCE_SCORES.liked);
            } else if (matchesPreference(food, willingFoods)) {
              expect(food.preference_score).toBe(PREFERENCE_SCORES.willing);
            } else {
              expect(food.preference_score).toBe(PREFERENCE_SCORES.neutral);
            }
          });
        });

        it('should maintain nutritional feasibility after preference filtering', () => {
          const likedFoods = buildPreferenceSet(scenario.liked_foods);
          const willingFoods = buildPreferenceSet(scenario.willing_foods);
          const dislikedFoods = buildPreferenceSet(scenario.disliked_foods);

          const availableFoods = applyFoodPreferences(
            TEST_FOOD_DATABASE,
            likedFoods,
            willingFoods,
            dislikedFoods
          );

          // Estimate carb targets based on distance
          let targetCarbs = 0;
          if (scenario.distance === '5K') targetCarbs = 30;
          else if (scenario.distance === 'Marathon') targetCarbs = 200;
          else if (scenario.distance === 'Ultra') targetCarbs = 400;

          const isFeasible = validateNutritionFeasibility(availableFoods, targetCarbs);

          // Even picky eaters should have feasible nutrition options
          // Exception: "All foods disliked" scenario may not be nutritionally feasible (by design)
          if (scenario.name === "All_Foods_Disliked_Emergency") {
            // This edge case is expected to fail feasibility - only 2 essential foods available
            console.log(`⚠️ ${scenario.name}: Intentionally infeasible scenario for testing emergency fallback`);
          } else {
            expect(isFeasible).toBe(true);
          }
        });
      });
    });
  });

  describe('Edge Cases', () => {
    it('should handle empty preference lists gracefully', () => {
      const availableFoods = applyFoodPreferences(
        TEST_FOOD_DATABASE,
        new Set(), // No likes
        new Set(), // No willing
        new Set()  // No dislikes
      );

      // Should include every non-excluded food with neutral scoring (except essentials)
      const allowedFoodCount = TEST_FOOD_DATABASE.filter(f => !f.to_exclude_from_solver).length;
      expect(availableFoods).toHaveLength(allowedFoodCount);

      const neutralFoods = availableFoods.filter(f => !f.is_essential);
      neutralFoods.forEach(food => {
        expect(food.preference_score).toBe(PREFERENCE_SCORES.neutral);
      });
    });

    it('should prioritize essential foods in severe constraint scenarios', () => {
      // Dislike everything
      const allFoodNames = TEST_FOOD_DATABASE.map(f => f.display_name);
      const dislikedFoods = buildPreferenceSet(allFoodNames);

      const availableFoods = applyFoodPreferences(
        TEST_FOOD_DATABASE,
        new Set(), // No likes
        new Set(), // No willing
        dislikedFoods // Dislike all
      );

      // Should only have essential foods
      const essentialCount = TEST_FOOD_DATABASE.filter(f => f.is_essential && !f.to_exclude_from_solver).length;
      expect(availableFoods).toHaveLength(essentialCount);

      availableFoods.forEach(food => {
        expect(food.is_essential).toBe(true);
        expect(food.preference_score).toBe(PREFERENCE_SCORES.essential);
      });
    });

    it('should exclude foods explicitly flagged to skip solver selection', () => {
      const likedFoods = buildPreferenceSet(['experimental fuel']);

      const availableFoods = applyFoodPreferences(
        TEST_FOOD_DATABASE,
        likedFoods,
        new Set(),
        new Set()
      );

      const excludedFood = availableFoods.find(food => food.display_name === 'experimental fuel');
      expect(excludedFood).toBeUndefined();
    });
  });

  describe('Preference Matching Logic', () => {
    it('should match foods by display name', () => {
      const likedSet = buildPreferenceSet(['gel', 'bar']);

      const gelFood = TEST_FOOD_DATABASE.find(f => f.display_name === 'gel');
      const barFood = TEST_FOOD_DATABASE.find(f => f.display_name === 'bar');
      const bananaFood = TEST_FOOD_DATABASE.find(f => f.display_name === 'banana');

      expect(matchesPreference(gelFood, likedSet)).toBe(true);
      expect(matchesPreference(barFood, likedSet)).toBe(true);
      expect(matchesPreference(bananaFood, likedSet)).toBe(false);
    });

    it('should match foods by partial name matching', () => {
      const likedSet = buildPreferenceSet(['coconut']);

      const coconutFood = TEST_FOOD_DATABASE.find(f => f.display_name === 'coconut water');
      const bananaFood = TEST_FOOD_DATABASE.find(f => f.display_name === 'banana');

      expect(matchesPreference(coconutFood, likedSet)).toBe(true);
      expect(matchesPreference(bananaFood, likedSet)).toBe(false);
    });
  });
});
