# Meal Planning Algorithm

- **Source:** https://app.notion.com/p/ab5fbeabf2b34b37bc9233484b459de6
- **Ancestor path:** Technical and Product Documentation (data source) → Technical and Product Documentation → Features → (untitled) → (untitled) → Homepage
- **Snapshot as of:** 2024-11-23T17:37:59.322Z
- **Properties:** Category: technical documentation · Creator: (user 14f3bf89-0c1a-434a-9889-8f4df81993e7, lee.b.martin@gmail.com) · Date: 2025-02-18T17:54:44.975Z · Related: technical, backend, product
- **Discussions:** 4 threads, 6 comments total (see Comments section at bottom) — this page was explicitly circulated as a work-in-progress for review/feedback.

---

# Comprehensive Report on the Meal Plan Generation Algorithm

## Introduction

This report provides a detailed overview of the meal plan generation algorithm, including its handling of user preferences such as diet, restrictions, dislikes, included ingredients, serving sizes, and meal types. It also covers the scoring system used to prioritize meals, reasons for potential issues like lack of variability or incomplete ingredient inclusion, potential failures of the algorithm, and suggestions for improvements to enhance meal variety and user satisfaction.

---

## Algorithm Overview

The meal plan generation algorithm is designed to create personalized meal plans based on user inputs and preferences. It operates in several key stages:

1. **Fetching User Preferences and Data**
2. **Compiling Candidate Recipes**
3. **Assembling Candidate Meals**
4. **Scoring and Prioritizing Meals**
5. **Finalizing the Meal Plan**
6. **Formatting the Meal Plan for Frontend Consumption**

---

## 1. Fetching User Preferences and Data

The algorithm begins by retrieving the user's preferences from the database:

- **Diet**: The user's dietary preference (e.g., vegetarian, vegan, keto).
- **Restrictions**: Any dietary restrictions (e.g., allergies, intolerances).
- **Dislikes**: Ingredients the user dislikes.
- **Liked Recipes**: Recipes the user has liked in the past.
- **Cooking History**: Recipes the user has cooked recently.
- **Requested Ingredients**: Specific ingredients (`fdc_id`s) the user wants to include.
- **Serving Size**: The number of servings the user desires.
- **Meal Requirements**: The number of meals requested for each meal type (breakfast, lunch, dinner, snack).

**Data Retrieval Functions:**
- `get_user_preferences(user_id)`: Fetches user settings and preferences.

---

## 2. Compiling Candidate Recipes

Candidate recipes are selected based on the user's preferences:

- **Recipe Selection Criteria**:
  - **Diet Compliance**: Recipes matching the user's diet unless overridden.
  - **Restrictions**: Recipes not conflicting with the user's restrictions unless overridden.
  - **Dislikes**: Recipes that do not contain ingredients the user dislikes unless overridden.
  - **Included Ingredients**: Recipes that include the user's requested ingredients (`fdc_id`s) are given priority and can override other preferences.
- **Overrides**:
  - **Requested Ingredients**: If a recipe contains a requested ingredient, it overrides diet restrictions, dislikes, and other conflicts.

**Candidate Recipe Compilation Function:**
- `get_candidate_recipes(preferences, requested_fdc_ids)`: Returns a list of recipes that meet the criteria.

---

## 3. Assembling Candidate Meals

Meals are assembled from the candidate recipes:

- **Meal Types**: Meals are categorized into breakfast, lunch, dinner, and snack.
- **Recipe Exclusivity**: Ensures that a recipe is not used in more than one meal in the plan.
- **Serving Size Options**: Considers meals and recipes that match the user's requested serving size.

**Meal Assembly Function:**
- `assemble_candidate_meals(candidate_recipes, meal_requirements)`: Collects candidate meals per meal type without prematurely stopping the search.

---

## 4. Scoring and Prioritizing Meals

Meals are scored based on various factors to prioritize them:

### Scoring Factors:

1. **Liked Recipes**: Meals containing recipes the user has liked are given higher scores.
   - **Points Assigned**: +10 points per liked recipe in the meal.
2. **Recently Cooked Recipes**: Meals containing recipes the user has cooked recently are penalized to encourage variety.
   - **Points Deducted**: −5 points per recently cooked recipe. *(See comment thread: Lee suggested this should be −10, more heavily weighted — see Comments below.)*
3. **Serving Size Match**: Meals matching the user's requested serving size are prioritized.
   - **Points Assigned**: +5 points if the meal's serving size matches.
   - **Points Deducted**: −1 point if the serving size does not match.
4. **Disliked Ingredients**: Meals containing ingredients the user dislikes are penalized but not excluded.
   - **Points Deducted**: −3 points per meal containing disliked ingredients. *(See comment thread — flagged as too lenient; see Comments below.)*
5. **Requested Ingredients**: Meals including the user's requested ingredients are heavily prioritized.
   - **Points Assigned**: +5 points per requested ingredient included in the meal.
6. **Randomness Factor**: A small random value is added to the score to introduce variety.
   - **Points Assigned**: +0 to +5 points randomly.

**Scoring Function:**
- `score_and_prioritize_meals(candidate_meals, preferences, requested_fdc_ids, serving_size)`: Calculates the score for each meal and sorts them accordingly.

---

## 5. Finalizing the Meal Plan

The algorithm selects meals to form the final meal plan:

- **Per Meal Type Selection**: Ensures the required number of meals for each meal type is met.
- **FDCIDs Coverage**: Attempts to cover all requested ingredients across the meal plan.
- **Recipe Exclusivity**: Ensures that recipes are not reused in different meals.
- **Constraint Relaxation**: If necessary, the algorithm relaxes certain constraints to fulfill the meal requirements (e.g., including meals with lower scores).

**Finalization Function:**
- `finalize_meal_plan(candidate_meals, meal_requirements, requested_fdc_ids)`: Selects the best meals while meeting all requirements.

---

## 6. Formatting the Meal Plan for Frontend Consumption

The selected meals are formatted into a structure suitable for the frontend application:

- **Meal Card Structure**:
  - **Time**: Estimated preparation time.
  - **Repeat**: Number of times the meal is repeated.
  - **Meal**: Meal name or description.
  - **m_id**: Meal ID.
  - **Recipes**: List of recipes included in the meal.
  - **s_num_opt**: Serving size options available for the meal.
  - **s_num**: Selected serving size.
  - **m_type**: Meal type (breakfast, lunch, dinner, snack).
  - **Nutrition**: Nutritional information.
  - **Shinometer**: A metric for meal healthiness or user preference.

**Formatting Function:**
- `generateCards(meal_plan, servingNumber)`: Transforms meals into the required format.

---

## Handling of User Preferences

### Diet and Restrictions

- **Diet Compliance**: Recipes must match the user's diet unless overridden by requested ingredients.
- **Restrictions** *(inline discussion anchored here — see Comments)*: Recipes conflicting with the user's dietary restrictions are penalized unless overridden.

### Dislikes

- **Disliked Ingredients**: Recipes containing ingredients the user dislikes are penalized in the scoring but are not completely excluded to ensure sufficient meal options.

### Included Ingredients

- **Requested Ingredients**: The algorithm prioritizes meals containing the user's requested ingredients (`fdc_id`s). These ingredients can override diet and restriction constraints.

### Serving Size

- **Matching Serving Size**: Meals and recipes are scored higher if they match the user's requested serving size. Serving sizes are carefully parsed and handled.

### Meal Types

- **Required Meal Counts**: The algorithm ensures that the exact number of meals requested per meal type is provided.
- **Meal Type Assignment**: Meals are correctly categorized and assigned to meal types.

---

## Point Assignment Summary

- **Liked Recipes**: +10 points per liked recipe.
- **Recently Cooked Recipes**: −5 points per recently cooked recipe. *(inline discussion anchored here — see Comments)*
- **Serving Size Match**: +5 points if matched; −1 point if not.
- **Disliked Ingredients**: −3 points per meal containing dislikes. *(inline discussion anchored here — see Comments)*
- **Requested Ingredients**: +5 points per requested ingredient included.
- **Randomness Factor**: +0 to +5 points added randomly.

---

## Exclusions and Inclusions

- **Exclusions**:
  - **Conflicting Restrictions**: Recipes conflicting with the user's restrictions diets and restrictions unless overridden.
  - **Recipe Exclusivity**: Recipes already used in other meals are excluded to prevent repetition.
- **Inclusions**:
  - **Requested Ingredients**: Recipes containing requested ingredients are included and can override other exclusions.
  - **Disliked Ingredients**: Meals with disliked ingredients are included but penalized.
  - **Serving Size Variations**: Meals with different serving sizes are included but scored accordingly.

---

## Answers to Specific Questions

### 1. Why Might There Not Be Variability in the Meal Plan?

- **Limited Recipe Pool**: If the database has a limited number of recipes matching the user's preferences, the same meals may be selected repeatedly.
- **Strict Constraints**: Tight restrictions (diet, dislikes, required ingredients) can narrow the pool of eligible recipes.
- **Scoring Bias**: The scoring system may favor certain meals consistently due to high scores (e.g., meals containing liked recipes or requested ingredients).
- **Lack of Randomness**: Insufficient randomness in the selection process can lead to repetitive meal plans.

### 2. Why Might Not All Requested Ingredients Be Included?

- **Insufficient Coverage**: The available recipes may not collectively include all the requested ingredients.
- **Constraint Conflicts**: Some requested ingredients may be present in recipes that conflict with the user's restrictions or dislikes.
- **Recipe Availability**: There may be few or no recipes containing certain requested ingredients.
- **Meal Type Limitations**: The requested ingredients may be present only in meals of a type not requested or already filled.

### 3. How Might This Algorithm Fail to Work?

- **Data Issues**: Missing or malformed data (e.g., incorrect `s_num_opt`, missing ingredient lists) can cause errors.
- **Infinite Loops**: Poor handling of loops in meal selection can lead to infinite recursion or failure to terminate.
- **Constraint Overlap**: Overly restrictive user preferences can result in no eligible meals being found.
- **Unhandled Exceptions**: Lack of error handling for unexpected data formats or missing fields can cause crashes.

### 4. How Might We Improve This Algorithm?

- **Expand Recipe Database**: Incorporate more recipes to increase variety and cover more ingredients.
- **Enhance Randomness**: Introduce more randomness in meal selection to prevent repetitive meal plans.
- **Flexible Constraints**: Implement constraint relaxation strategies to include more meal options when strict preferences cannot be fully met.
- **User Feedback Loop**: Use user feedback to adjust meal recommendations and improve future meal plans.
- **Advanced Scoring**: Refine the scoring system with machine learning techniques to better predict user preferences.
- **Allowing Substitutions**: An infrastructure algorithm to allow each recipe to be more flexible.

### 5. In What Ways Can We Introduce More Meals and Recipes to Increase Variety?

- **Recipe Curation**: Regularly add new recipes to the database, focusing on diverse cuisines and ingredients.
- **User-Generated Content**: Allow users to submit their own recipes, increasing the pool.
- **Ingredient Substitutions**: Implement ingredient substitution logic to adapt recipes to user preferences.
- **Seasonal Menus**: Introduce seasonal recipes to keep the meal plans fresh and varied.
- **Dynamic Meal Generation**: Use algorithms to create new recipes by combining compatible ingredients and cooking methods.

---

## Other Details and Considerations

### Error Handling and Data Validation

- **JSON Parsing**: All JSON fields (e.g., `s_num_opt`, `ingredient_fdcids`) are carefully parsed with error handling to prevent crashes.
- **Data Integrity**: Checks are performed to ensure that all required data fields are present and correctly formatted.

### Performance Optimization

- **Data Caching**: Frequently accessed data can be cached to improve performance.
- **Efficient Queries**: Database queries are optimized to retrieve only necessary data.

### User Experience Enhancements

- **Meal Diversity**: Algorithms can be adjusted to ensure a diverse selection of meal types and cuisines.
- **Customization Options**: Provide users with options to adjust the strictness of constraints (e.g., allowing occasional inclusion of disliked ingredients).

### Logging and Monitoring

- **Logging**: Implement logging to track algorithm performance, user selections, and potential issues.
- **Monitoring**: Regularly monitor the algorithm's output to ensure it meets user expectations and make adjustments as needed.

---

## Conclusion

The meal plan generation algorithm is a comprehensive system that personalizes meal plans based on user preferences and requirements. While it effectively incorporates various user constraints, potential issues like lack of variability or incomplete ingredient inclusion can arise due to limitations in the recipe database or overly strict user preferences. By expanding the recipe pool, refining the scoring system, and implementing additional features, the algorithm can be improved to offer more diverse and satisfying meal plans.

---

# Comments / Discussion Threads

## Thread 1: page-level (3 comments, unresolved)

**Comment** — user lee.b.martin@gmail.com (Lee Martin) — 2024-11-23T00:09:21.504Z:

> Please write inside here somewhere any comments and suggested changes. This is still a work in progress and I know there are a few changes vis-a-vis what we talked about. That's ok. I will refactor as needed to make sure it is perfect. Just if you see anything at all that stands out, please just let me know. Thanks! 🙂

**Comment** — user xh.analytics@gmail.com — 2024-11-23T17:37:15.651Z:

> The document is so well written and I am very proud of your work. I made comments and edits in a few places below, but my main suggestion would be to set up a way to measure how satisfying the recommendation is.
> One way to measure is debug the scoring process by observing the scoring results to judge how effective it is — [page mention: https://app.notion.com/p/147e3fdb754c80a1aa99c6d6fc6d1ac7]

**Comment** — user noruler@gmail.com — 2024-11-26T15:41:53.720Z:

> I think the core part is the scoring system. If we design it in rule based, I suggest
> 1. Introduce the matrix table to add more possible parameters.
> 2. Need to add regression test.
> 3. We need to isolate same samples for validation
> 4. We need to have validation methods in the test environment (inhouse).
> 5. Design some data collection and validation methods in the production environment as well, that means the real data.
>
> More questions and feedbacks:
> 1. How do we solve the problem of contextual recommendations? That is to say, in each MEAL Planning, the user may keep having interactive actions, and as the user give more actions, we can get more and more ready to make good recommendations this time?
> 2. Current scoring system is a kind of static system, which could only give an average user expectation recommendation, but not a satisfactory one.

## Thread 2: inline, anchored to "Restrictions...overridden." (1 comment, unresolved)

**Comment** — user xh.analytics@gmail.com — 2024-11-23T16:54:57.476Z:

> I assume by restrictions you meant allergies. I think recipes MUST avoid user's allergies unless overridden by requested ingredients. It does seems like you are doing that by looking at the remaining parts of the document.

## Thread 3: inline, anchored to "-5 points ...ed recipe." (1 comment, unresolved)

**Comment** — user xh.analytics@gmail.com — 2024-11-23T16:55:36.813Z:

> This is more or less subjective and maybe there is a way for us to measure objectively. I'd set this score higher at −10.

## Thread 4: inline, anchored to "-3 points ... dislikes." (1 comment, unresolved)

**Comment** — user xh.analytics@gmail.com — 2024-11-23T16:57:56.303Z:

> If we can design a way to substitute the disliked ingredients, that will be a better way to go. For now, −3 seems to be too lenient. But then again, the penalty score is more or less subjective unless we can quantify how satisfying the recommendations are.
