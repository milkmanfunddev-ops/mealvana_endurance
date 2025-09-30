# Swap Food Feature Integration Roadmap

## Overview
This document outlines the implementation plan for integrating user_foods table support and unifying the food selection experience across the swap food, add food, and food preferences screens.

## Current State Analysis

### Working Well (Food Preferences - Settings)
- ✅ Searches Open Food Facts API
- ✅ Saves to user_foods table
- ✅ Syncs with Supabase via save-user-food edge function
- ✅ Shows user's added foods alongside generic foods
- ✅ Barcode scanning with category selection
- ✅ Preference indicators (Love/Willing to Try/Avoid)

### Gaps (Swap Food/Add Food)
- ❌ Not loading from user_foods table
- ❌ No Open Food Facts search integration
- ❌ No barcode → user_foods persistence
- ❌ Inconsistent UI with preferences page
- ❌ References to deprecated branded foods

## Requirements Summary

### Core Requirements
1. **Include user_foods in recommendations** alongside generic foods
2. **Remove all branded foods** references from codebase
3. **Mimic food preferences UI** but without preference selection
4. **Share functionality** between three screens (onboarding, settings, swap/add)
5. **Smart mixing** of recommendations based on product type + preferences
6. **Respect preferences** by graying out avoided foods

### UI/UX Requirements

#### Swap Food Screen Flow
1. Search bar with barcode icon + Search button (NO filter icon)
2. "Recommended Alternatives" section (max 10 items)
   - Same product_type as food being swapped
   - Sorted by preferences (Love → Willing → Neutral → Avoided[grayed])
3. Tap food → Show details with quantity selector
4. "Swap Food" button → Performs swap

#### Add Food Screen Flow
1. Search bar with barcode icon + Search button (NO filter icon)
2. "Recommended Alternatives" section (max 10 items)
   - Same category/phase as where food is being added
   - Sorted by preferences (Love → Willing → Neutral → Avoided[grayed])
3. Tap food → Show details with quantity selector
4. "Add Food" button → Adds to plan

#### Search Behavior
1. Search only queries Open Food Facts (not local foods)
2. Add Food → Saves to user_foods → Auto-selects for swap/add
3. Category selection modal after adding (same as preferences)

## Implementation Roadmap

### Phase 1: Clean Up Branded Foods References
**Goal:** Remove all deprecated branded foods code and documentation

#### Tasks:
1. **Remove from SwapFoodController**
   - Delete `_getAllFoodsIncludingBranded()` method
   - Remove branded foods filtering logic
   - Update `_getRecommendationsByProductType()` to only use generic foods

2. **Clean FoodRepository**
   - Remove `getAllFoodsIncludingBranded()` method
   - Update any references to branded foods

3. **Update Documentation**
   - Remove branded foods mentions from /docs/database/
   - Update /docs/business_logic/ files
   - Clean up any API documentation

**Files to Modify:**
- `lib/features/nutrition_plan/presentation/providers/swap_food_controller.dart`
- `lib/features/nutrition_plan/data/food_repository.dart`
- Documentation files in /docs/

---

### Phase 2: Extract Shared Services
**Goal:** Create reusable services for food operations

#### New Services Structure:
```
lib/shared/services/food_management/
├── open_food_facts_search_service.dart  # Move from barcode_scanning feature
├── user_food_crud_service.dart          # CRUD operations for user_foods
└── food_recommendation_service.dart     # Smart recommendation logic
```

#### Service Responsibilities:

**UserFoodCrudService**
```dart
class UserFoodCrudService {
  // Load user foods for a device
  Future<List<Food>> getUserFoods(String deviceId);

  // Save food from Open Food Facts
  Future<void> saveUserFood(Food food, List<int> categoryIds);

  // Delete user food
  Future<void> deleteUserFood(String foodId);

  // Check if food exists in user_foods
  Future<bool> isUserFood(String foodId);
}
```

**FoodRecommendationService**
```dart
class FoodRecommendationService {
  // Get smart recommendations
  Future<List<Food>> getRecommendations({
    String? productTypeId,     // For swap scenarios
    String? category,           // For add scenarios
    Map<String, FoodPreference> preferences,
    int maxResults = 10,
  });

  // Apply preference-based sorting
  List<Food> sortByPreferences(
    List<Food> foods,
    Map<String, FoodPreference> preferences,
  );
}
```

---

### Phase 3: Create Shared UI Components
**Goal:** Build reusable UI components for consistent experience

#### Component Structure:
```
lib/shared/widgets/food_selection/
├── food_search_bar.dart           # Search with barcode (no filters for swap/add)
├── food_item_tile.dart            # Unified food display
├── food_details_sheet.dart        # Food details with quantity
├── recommended_alternatives.dart   # Recommendations list
└── category_selection_sheet.dart  # Already exists as ScannedFoodCategorySheet
```

#### FoodSearchBar Widget
```dart
class FoodSearchBar extends StatelessWidget {
  final Function(String) onSearch;
  final VoidCallback onBarcodeScan;
  final bool showFilters;  // false for swap/add, true for preferences

  // Unified search bar used by all three screens
}
```

#### FoodItemTile Widget
```dart
class FoodItemTile extends StatelessWidget {
  final Food food;
  final VoidCallback onTap;
  final bool showPreference;     // true for preferences screen
  final bool isAvoided;          // gray out if true
  final bool showDeleteButton;   // true for user foods in preferences

  // Consistent food display across screens
}
```

#### RecommendedAlternatives Widget
```dart
class RecommendedAlternatives extends StatelessWidget {
  final List<Food> foods;
  final Function(Food) onFoodSelected;
  final String title;  // "Recommended Alternatives" or "Search Results"

  // Displays list of foods with proper styling
}
```

---

### Phase 4: Refactor SwapFoodController
**Goal:** Integrate user_foods and new services

#### Key Changes:
1. **Load user foods alongside generic foods**
```dart
Future<SwapFoodState> _loadFoodsForSwapping(SwapFoodParams params) async {
  // Load generic foods
  final genericFoods = await _foodRepository.getAllFoods();

  // Load user foods
  final userFoods = await _userFoodService.getUserFoods(deviceId);

  // Combine and get recommendations
  final allFoods = [...genericFoods, ...userFoods];

  // Get smart recommendations
  final recommendations = await _recommendationService.getRecommendations(
    productTypeId: originalFood?.productTypeId,
    category: params.category,
    preferences: userPreferences,
    maxResults: 10,
  );

  return SwapFoodState(
    availableFoods: allFoods,
    recommendations: recommendations,
  );
}
```

2. **Integrate Open Food Facts search**
```dart
Future<void> searchOpenFoodFacts(String query) async {
  final results = await _openFoodFactsService.search(query);
  // Display results in UI
}

Future<void> addFoodFromSearch(Food food) async {
  // Save to user_foods
  await _userFoodService.saveUserFood(food, categoryIds);

  // Auto-select for swap/add
  selectFood(food);
}
```

3. **Remove branded foods loading**
   - Delete `_getAllFoodsIncludingBranded()` method
   - Clean up any branded-specific logic

---

### Phase 5: Update Swap Food Screen UI
**Goal:** Implement new UI matching preferences page style

#### Changes to swap_food_screen.dart:
1. **Replace current search field** with FoodSearchBar widget
2. **Remove filter functionality** (no filter pills)
3. **Update food list** to use RecommendedAlternatives widget
4. **Keep quantity selector** in food details
5. **Maintain swap/add logic** with new UI

#### New Screen Structure:
```
SwapFoodScreen
├── AppBar (title: "Swap [Food Name]" or "Add Food")
├── FoodSearchBar (no filters)
├── Scan Barcode button (integrated in search bar)
├── RecommendedAlternatives
│   ├── Max 10 items
│   ├── Smart sorted by preference
│   └── Avoided foods grayed out
├── Selected Food Details (when food selected)
│   ├── Food info
│   ├── Quantity selector
│   └── Nutritional values
└── Action Button ("Swap Food" or "Add Food")
```

---

### Phase 6: Update Food Preferences Content
**Goal:** Refactor to use shared components

#### Changes:
1. **Extract search logic** to shared service
2. **Use shared FoodSearchBar** component
3. **Use shared FoodItemTile** for display
4. **Keep preference-specific features** (filters, preference selection)

---


## File Change Summary

### Files to Create:
- `lib/shared/services/food_management/user_food_crud_service.dart`
- `lib/shared/services/food_management/food_recommendation_service.dart`
- `lib/shared/widgets/food_selection/food_search_bar.dart`
- `lib/shared/widgets/food_selection/food_item_tile.dart`
- `lib/shared/widgets/food_selection/food_details_sheet.dart`
- `lib/shared/widgets/food_selection/recommended_alternatives.dart`

### Files to Modify:
- `lib/features/nutrition_plan/presentation/providers/swap_food_controller.dart`
- `lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart`
- `lib/features/nutrition_plan/data/food_repository.dart`
- `lib/shared/widgets/food_preferences_content.dart`
- `lib/features/onboarding/presentation/screens/food_preferences_screen.dart`
- `lib/features/settings/presentation/screens/food_preferences_edit_screen.dart`

### Files to Review for Cleanup:
- Any documentation mentioning branded foods
- Any other controllers/services referencing branded foods

---

## Success Criteria

1. ✅ User can see their added foods in swap/add recommendations
2. ✅ Avoided foods are visually distinguished (grayed out)
3. ✅ Search works consistently across all screens
4. ✅ Barcode scanning saves to user_foods
5. ✅ UI is consistent between preferences and swap/add screens
6. ✅ No branded foods references remain in codebase
7. ✅ Maximum 10 recommendations shown
8. ✅ Recommendations are smart (product type for swap, category for add)
9. ✅ Code reuse maximized between three screens
10. ✅ All data properly persists to user_foods table

---

## Timeline Estimate

- Phase 1 (Cleanup): 1 hour
- Phase 2 (Services): 2-3 hours
- Phase 3 (UI Components): 2-3 hours
- Phase 4 (Controller): 2 hours
- Phase 5 (Swap Screen): 2 hours
- Phase 6 (Preferences Refactor): 2 hours

**Total Estimate: 12-15 hours**

---

## Next Steps

1. Review and approve this roadmap
2. Create feature branch: `feature/swap-food-user-foods-integration`
3. Implement Phase 1-7 sequentially
4. Test thoroughly on both iOS and Android
5. Deploy to staging for QA
6. Merge to main after approval