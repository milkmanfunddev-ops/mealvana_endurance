# Onboarding Revamp v2 - Implementation Roadmap

## Overview

This document outlines the complete redesign of the Mealvana Endurance onboarding flow based on the December 2025 Figma designs. The goal is to create a streamlined, chip-based onboarding experience with new dietary preference and allergy screens.

**Priority**: ASAP/High Priority (1-2 weeks)
**Created**: December 10, 2025
**Figma File**: [Endurance - Figma](https://www.figma.com/design/eA4HqttH0XBdJk0kSfcIWe/Endurance---Figma)

---

## Design Decisions Summary

| Decision | Choice |
|----------|--------|
| Welcome Screen | Keep current (unchanged) |
| User Profile Screen | Keep current (unchanged) |
| Progress Bar Segments | 4 segments: Profile → Sports+Details → Diet+Allergies → Food |
| GI/Stomach Sensitivity | Remove entirely |
| Sport Detail Screens | Conditional separate screens per selected sport |
| Dietary Preference | NEW - Single-select, 8 options, optional/skippable |
| Allergies | NEW - Multi-select, 9 allergens, optional/skippable |
| Food Preferences | Chip-based UI (tap to like), no barcode in onboarding |
| Food Preference Model | Like + Neutral only (no dislike in onboarding) |
| Settings Food Prefs | Keep current 5-point slider (not refactored) |
| Diet/Allergy Filtering | Real-time filter on food chips |
| Navigation | Swipe enabled + back/continue buttons |
| Selected Foods Display | Show in both sections (highlighted in common + at top) |
| Search Scope | Common foods only (show_in_preferences=true) |
| Existing Users | No re-onboarding required |
| Post-Onboarding Auth | Keep current (unchanged) |

---

## New Onboarding Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                     ONBOARDING FLOW v2                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  [Welcome Screen] - UNCHANGED                                        │
│         │                                                            │
│         ▼                                                            │
│  ┌──────────────────┐  Segment 1                                    │
│  │  User Profile    │  ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░             │
│  │  - Gender        │  (UNCHANGED)                                   │
│  │  - Birthday      │                                                │
│  │  - Height/Weight │                                                │
│  └────────┬─────────┘                                                │
│           │                                                          │
│           ▼                                                          │
│  ┌──────────────────┐  Segment 2                                    │
│  │ Sports Selection │  ████████░░░░░░░░░░░░░░░░░░░░░░░░             │
│  │  □ Running       │                                                │
│  │  □ Cycling       │                                                │
│  │  □ Swimming      │                                                │
│  └────────┬─────────┘                                                │
│           │                                                          │
│           ▼ (conditional based on sports selected)                   │
│  ┌──────────────────┐  Segment 2 (continues)                        │
│  │ Running Details  │  ████████░░░░░░░░░░░░░░░░░░░░░░░░             │
│  │  - Water bottle  │                                                │
│  └────────┬─────────┘                                                │
│           │ (if cycling selected)                                    │
│           ▼                                                          │
│  ┌──────────────────┐                                                │
│  │ Cycling Details  │  ████████░░░░░░░░░░░░░░░░░░░░░░░░             │
│  │  - FTP           │                                                │
│  │  - Water bottles │                                                │
│  │  - Aero bottles  │                                                │
│  │  - Bento box     │                                                │
│  └────────┬─────────┘                                                │
│           │ (if swimming selected)                                   │
│           ▼                                                          │
│  ┌──────────────────┐                                                │
│  │ Swimming Details │  ████████░░░░░░░░░░░░░░░░░░░░░░░░             │
│  │  - CSS           │                                                │
│  │  - Wetsuit       │                                                │
│  │  - Swim cap type │                                                │
│  └────────┬─────────┘                                                │
│           │                                                          │
│           ▼                                                          │
│  ┌──────────────────┐  Segment 3 (NEW!)                             │
│  │Dietary Preference│  ████████████████░░░░░░░░░░░░░░░░             │
│  │  ○ Omnivore      │  (Optional/Skippable)                         │
│  │  ○ Vegetarian    │                                                │
│  │  ○ Pescatarian   │                                                │
│  │  ○ Vegan         │                                                │
│  │  ○ Mediterranean │                                                │
│  │  ○ Paleo         │                                                │
│  │  ○ Keto          │                                                │
│  │  ○ Low-Carb      │                                                │
│  └────────┬─────────┘                                                │
│           │                                                          │
│           ▼                                                          │
│  ┌──────────────────┐  Segment 3 (continues)                        │
│  │    Allergies     │  ████████████████░░░░░░░░░░░░░░░░             │
│  │  □ Dairy         │  (Optional/Skippable)                         │
│  │  □ Eggs          │                                                │
│  │  □ Fish          │                                                │
│  │  □ Gluten        │                                                │
│  │  □ Peanuts       │                                                │
│  │  □ Sesame        │                                                │
│  │  □ Shellfish     │                                                │
│  │  □ Soy           │                                                │
│  │  □ Tree nuts     │                                                │
│  └────────┬─────────┘                                                │
│           │                                                          │
│           ▼                                                          │
│  ┌──────────────────┐  Segment 4                                    │
│  │ Food Preferences │  ████████████████████████████████             │
│  │  - Search bar    │  (Filtered by diet/allergies)                 │
│  │  - Selected chips│                                                │
│  │  - Common foods  │                                                │
│  └────────┬─────────┘                                                │
│           │                                                          │
│           ▼                                                          │
│  [Post-Onboarding Auth] - UNCHANGED                                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Figma Screen References

| Screen | Node ID | URL |
|--------|---------|-----|
| Sports Selection | 154:993 | [Link](https://www.figma.com/design/eA4HqttH0XBdJk0kSfcIWe/Endurance---Figma?node-id=154-993) |
| Running Details | 154:965 | [Link](https://www.figma.com/design/eA4HqttH0XBdJk0kSfcIWe/Endurance---Figma?node-id=154-965) |
| Cycling Details | 154:1029 | [Link](https://www.figma.com/design/eA4HqttH0XBdJk0kSfcIWe/Endurance---Figma?node-id=154-1029) |
| Swimming Details | 154:1081 | [Link](https://www.figma.com/design/eA4HqttH0XBdJk0kSfcIWe/Endurance---Figma?node-id=154-1081) |
| Dietary Preference | 105:411 | [Link](https://www.figma.com/design/eA4HqttH0XBdJk0kSfcIWe/Endurance---Figma?node-id=105-411) |
| Allergies | 105:455 | [Link](https://www.figma.com/design/eA4HqttH0XBdJk0kSfcIWe/Endurance---Figma?node-id=105-455) |
| Food Preferences | 147:1036 | [Link](https://www.figma.com/design/eA4HqttH0XBdJk0kSfcIWe/Endurance---Figma?node-id=147-1036) |

Local screenshots saved in: `/docs/onboarding_revamp/screenshots/`

---

## Database Schema Changes

### 1. New Enum Types

```sql
-- Dietary preference enum (single-select)
CREATE TYPE dietary_preference_enum AS ENUM (
  'omnivore',
  'vegetarian',
  'pescatarian',
  'vegan',
  'mediterranean',
  'paleo',
  'keto',
  'low_carb'
);

-- Allergy enum (for array usage)
CREATE TYPE allergy_enum AS ENUM (
  'dairy',
  'eggs',
  'fish',
  'gluten',
  'peanuts',
  'sesame',
  'shellfish',
  'soy',
  'tree_nuts'
);
```

### 2. Users Table Changes

```sql
ALTER TABLE users
ADD COLUMN dietary_preference dietary_preference_enum,
ADD COLUMN allergies allergy_enum[] DEFAULT '{}';

COMMENT ON COLUMN users.dietary_preference IS 'User dietary preference: omnivore, vegetarian, pescatarian, vegan, mediterranean, paleo, keto, low_carb';
COMMENT ON COLUMN users.allergies IS 'Array of user allergies for food filtering';
```

### 3. Foods Table Changes

```sql
ALTER TABLE foods
ADD COLUMN allergens allergy_enum[] DEFAULT '{}',
ADD COLUMN excluded_diets dietary_preference_enum[] DEFAULT '{}';

COMMENT ON COLUMN foods.allergens IS 'Allergens contained in this food (dairy, gluten, etc.)';
COMMENT ON COLUMN foods.excluded_diets IS 'Diets that should exclude this food (vegan excludes meat, etc.)';
```

### 4. Drift Database Updates

Update `lib/shared/database/app_database.dart`:
- Add `dietaryPreference` column to users table
- Add `allergies` column to users table (as TEXT storing JSON array)
- Add `allergens` column to foods table
- Add `excludedDiets` column to foods table

### 5. Migration Strategy

- **No new migration version** - Stay on v1 as per project guidelines
- Update Drift schema directly
- Add columns to both dev and prod Supabase
- Existing users will have NULL dietary_preference and empty allergies array

---

## Implementation Phases

### Phase 1: Database & Foundation (Day 1-2)

#### 1.1 Database Schema ✅ COMPLETED (Dec 14, 2025)
- [x] Create `dietary_preference_enum` in Supabase (dev + prod)
- [x] Create `allergy_enum` in Supabase (dev + prod)
- [x] Add `dietary_preference` column to users table
- [x] Add `allergies` column to users table
- [x] Add `allergens` column to foods table
- [x] Add `excluded_diets` column to foods table
- [x] Update Drift database schema (`user_profiles.dart`, `foods_table.dart`)
- [x] Run `dart run build_runner build`
- [x] Update database documentation

**Migration file**: `/supabase/migrations/20251214120000_add_dietary_preference_and_allergies.sql`

#### 1.2 Food Data Population (LLM Task) ✅ COMPLETED (Dec 14, 2025)
- [x] Pull all foods from Supabase `foods` table (31 foods)
- [x] Use LLM to analyze each food and determine:
  - Which allergens it contains (dairy, eggs, fish, gluten, peanuts, sesame, shellfish, soy, tree_nuts)
  - Which diets should exclude it (vegetarian, pescatarian, vegan, mediterranean, paleo, keto, low_carb)
- [x] Update `allergens` and `excluded_diets` columns for each food
- [x] Verify data accuracy with spot checks

**Migration file**: `/supabase/migrations/20251214130000_populate_food_allergens_and_diets.sql`

**Summary of populated data:**
- Foods with dairy: Yogurt, Chocolate milk, Protein powder, Protein shake, Protein bar, Energy waffle
- Foods with gluten: Oatmeal, Bagel, Toast, Pretzels, Energy waffle, Fig bar, Energy bar, Protein bar
- Foods with peanuts: Peanut butter, Trail mix
- Foods with tree_nuts: Trail mix
- Foods with soy: Protein bar, Protein shake
- Foods with eggs: Energy waffle
- Vegan-excluded: All dairy products + Energy waffle
- Paleo-excluded: Grains, legumes (peanuts), dairy, processed sugars
- Keto/Low-carb-excluded: High-carb foods (fruits, grains, sugary drinks)

#### 1.3 Domain Models ✅ COMPLETED (Dec 14, 2025)
- [x] Create `DietaryPreference` enum in Dart
- [x] Create `Allergy` enum in Dart
- [x] Update `UserProfile` model with new fields
- [x] Update `Food` model with allergen/diet fields

**Files created/modified:**
- `/lib/features/onboarding/domain/dietary_preference.dart` - NEW enum with dbValue, displayName, fromDbValue, fromDbArray, toDbArray
- `/lib/features/onboarding/domain/allergy.dart` - NEW enum with dbValue, displayName, fromDbValue, fromDbArray, toDbArray
- `/lib/features/auth/domain/user_preferences.dart` - Added dietaryPreference, allergies fields + toJson/fromJson/copyWith
- `/lib/features/nutrition_plan/domain/food.dart` - Added allergens, excludedDiets fields + toJson/fromJson

#### 1.4 Shared Widgets ✅ COMPLETED (Dec 15, 2025)
- [x] Create `OnboardingProgressBar` widget
- [x] Create `OnboardingNavigationFooter` widget
- [x] Create `SelectableCard` widget (checkbox style)
- [x] Create `RadioOptionCard` widget (radio style)
- [x] Create `ToggleCard` widget
- [x] Create `FoodChip` widget
- [x] Create `SegmentedSelector` widget

**Files created:**
- `/lib/features/onboarding/presentation/widgets/onboarding_progress_bar.dart` - 4-segment progress indicator
- `/lib/features/onboarding/presentation/widgets/onboarding_navigation_footer.dart` - Back/Continue/Skip buttons
- `/lib/features/onboarding/presentation/widgets/selectable_card.dart` - Multi-select checkbox cards + grid
- `/lib/features/onboarding/presentation/widgets/radio_option_card.dart` - Single-select radio cards + list
- `/lib/features/onboarding/presentation/widgets/toggle_card.dart` - Boolean toggle cards + rows
- `/lib/features/onboarding/presentation/widgets/food_chip.dart` - Food selection chips + grid + selected section
- `/lib/features/onboarding/presentation/widgets/segmented_selector.dart` - Segmented control selector
- `/lib/features/onboarding/presentation/widgets/onboarding_widgets.dart` - Export file for all widgets

### Phase 2: New Screens (Day 3-5)

#### 2.1 Sports Selection Screen (NEW)
- [ ] Create `sports_selection_screen.dart`
- [ ] Implement multi-select sports logic
- [ ] Add progress bar (segment 2)
- [ ] Add swipe navigation support
- [ ] Connect to controller

#### 2.2 Running Details Screen (NEW)
- [ ] Create `running_details_screen.dart`
- [ ] Water bottle toggle
- [ ] Conditional navigation logic

#### 2.3 Cycling Details Screen (NEW)
- [ ] Create `cycling_details_screen.dart`
- [ ] FTP input field
- [ ] Water bottles segmented selector
- [ ] Aero bottles toggle
- [ ] Bento box toggle

#### 2.4 Swimming Details Screen (NEW)
- [ ] Create `swimming_details_screen.dart`
- [ ] CSS input (minutes:seconds)
- [ ] Wetsuit toggle
- [ ] Swim cap type radio selection

#### 2.5 Dietary Preference Screen (NEW)
- [ ] Create `dietary_preference_screen.dart`
- [ ] Single-select radio options
- [ ] Skip/continue logic (optional)
- [ ] Add progress bar (segment 3)

#### 2.6 Allergies Screen (NEW)
- [ ] Create `allergies_screen.dart`
- [ ] Multi-select checkbox options
- [ ] Skip/continue logic (optional)
- [ ] Add progress bar (segment 3)

#### 2.7 Food Preferences Screen (REDESIGN)
- [ ] Create `onboarding_food_preferences_screen.dart`
- [ ] Chip-based selection UI
- [ ] Search bar (common foods only, no barcode)
- [ ] Selected foods section with X removal
- [ ] Real-time filtering based on diet/allergies
- [ ] Show selected foods in both sections

### Phase 3: Controllers & State (Day 6-7)

#### 3.1 Onboarding Flow Controller
- [ ] Create `OnboardingFlowController` (AsyncNotifier)
- [ ] Track selected sports for conditional navigation
- [ ] Track dietary preference selection
- [ ] Track allergy selections
- [ ] Manage progress bar state
- [ ] Handle back navigation through dynamic flow

#### 3.2 Update Existing Controllers
- [ ] Update `OnboardingController` with new save methods
- [ ] Add `saveDietaryPreference()` method
- [ ] Add `saveAllergies()` method
- [ ] Update `saveFoodPreferences()` for chip model

#### 3.3 Food Filtering Service
- [ ] Create food filtering logic based on dietary preference
- [ ] Create food filtering logic based on allergies
- [ ] Real-time filter updates as user selects diet/allergies

#### 3.4 Repository Updates
- [ ] Update `UserRepository` for new fields
- [ ] Update `FoodRepository` for allergen/diet queries
- [ ] Add sync logic for new fields to Supabase

#### 3.5 Edge Function Update (Backward Compatible)
Update `generate-nutrition-plan` edge function to filter foods by dietary preference and allergies.

**Decision**: Use backward-compatible approach (NOT v2) because:
- Follows existing pattern (how `activity_type` was added)
- No breaking changes to API contract
- Optional parameters default to no filtering
- Single deployment, no coordination needed

**Implementation**:
- [ ] Add optional `dietary_preference` parameter parsing
- [ ] Add optional `allergies` array parameter parsing
- [ ] Update `getFoodsForPhase()` to filter by dietary preference
- [ ] Update `getFoodsForPhase()` to filter by allergens
- [ ] Update SELECT statements to include `allergens` and `excluded_diets` columns
- [ ] Add logging for filtered food counts
- [ ] Test with various diet/allergy combinations
- [ ] Deploy to dev, then prod

**Flutter Service Updates**:
- [ ] Update `LLMNutritionPlanService` to pass `dietary_preference`
- [ ] Update `LLMNutritionPlanService` to pass `allergies` array

### Phase 4: Navigation & Routing (Day 8)

#### 4.1 Router Updates
- [ ] Add routes for all new screens
- [ ] Implement conditional navigation based on selected sports
- [ ] Handle back navigation through dynamic flow
- [ ] Update redirect logic

#### 4.2 Swipe Navigation
- [ ] Implement `PageView` wrapper for swipe support
- [ ] Handle dynamic page count based on selected sports
- [ ] Coordinate swipe with button navigation

### Phase 5: Settings Integration (Day 9)

#### 5.1 New Settings Section
- [ ] Create "Dietary Profile" section in Settings
- [ ] Add dietary preference selector
- [ ] Add allergies selector
- [ ] Link to food preferences screen

#### 5.2 Auto-Dislike Logic
- [ ] Implement logic to auto-dislike foods based on allergies
- [ ] Implement logic to auto-dislike foods based on dietary preference
- [ ] Update food preferences when diet/allergies change

### Phase 6: Polish & Testing (Day 10-14)

#### 6.1 Animations
- [ ] Chip selection animations
- [ ] Progress bar transitions
- [ ] Page swipe physics
- [ ] Button press feedback

#### 6.2 Analytics
- [ ] Add screen view events (matching current tracking level)
- [ ] Add completion events for new screens
- [ ] Track dietary preference selection
- [ ] Track allergy selections

#### 6.3 Content Management
- [ ] Add all UI text to `content_defaults.json`
- [ ] Update ContentService for new screens

#### 6.4 Cleanup
- [ ] Remove old `sport_preferences_screen.dart`
- [ ] Remove GI sensitivity references
- [ ] Update documentation

---

## Testing Plan

### Unit Tests

#### Controllers
- [ ] `OnboardingFlowController` - state management
- [ ] Progress bar segment calculation
- [ ] Conditional navigation logic
- [ ] Food filtering by diet/allergies

#### Services
- [ ] `FoodFilteringService` - allergen exclusion
- [ ] `FoodFilteringService` - diet exclusion
- [ ] Combined filtering (diet + allergies)

#### Repositories
- [ ] `UserRepository` - save/load dietary preference
- [ ] `UserRepository` - save/load allergies
- [ ] `FoodRepository` - query with allergen filters

### Widget Tests

#### New Widgets
- [ ] `OnboardingProgressBar` - correct segment highlighting
- [ ] `SelectableCard` - selection state toggle
- [ ] `RadioOptionCard` - single selection behavior
- [ ] `ToggleCard` - toggle state
- [ ] `FoodChip` - tap to select, X to remove
- [ ] `SegmentedSelector` - segment selection

#### Screens
- [ ] Sports Selection - multi-select behavior
- [ ] Dietary Preference - single-select behavior
- [ ] Allergies - multi-select behavior
- [ ] Food Preferences - chip selection + filtering

### Integration Tests

#### Full Flow Tests
- [ ] Complete onboarding (all sports selected)
- [ ] Complete onboarding (single sport - running only)
- [ ] Complete onboarding (cycling + swimming, no running)
- [ ] Skip dietary preference
- [ ] Skip allergies
- [ ] Food filtering with vegan diet
- [ ] Food filtering with multiple allergies

#### Data Persistence
- [ ] All data saves correctly to Drift
- [ ] All data syncs to Supabase
- [ ] Existing users not affected

#### Navigation Tests
- [ ] Back navigation works correctly
- [ ] Swipe navigation works
- [ ] Conditional screens appear/skip correctly

### Manual Testing Checklist

- [ ] Visual match to Figma designs
- [ ] All touch targets >= 48px
- [ ] Animations feel smooth
- [ ] Keyboard handling for inputs
- [ ] Screen reader accessibility
- [ ] iOS device testing
- [ ] Android device testing
- [ ] Tablet responsive layout

---

## Files to Create

```
lib/features/onboarding/
├── presentation/
│   ├── widgets/
│   │   ├── onboarding_progress_bar.dart          (NEW)
│   │   ├── onboarding_navigation_footer.dart     (NEW)
│   │   ├── selectable_card.dart                  (NEW)
│   │   ├── radio_option_card.dart                (NEW)
│   │   ├── toggle_card.dart                      (NEW)
│   │   ├── food_chip.dart                        (NEW)
│   │   └── segmented_selector.dart               (NEW)
│   ├── screens/
│   │   ├── sports_selection_screen.dart          (NEW)
│   │   ├── running_details_screen.dart           (NEW)
│   │   ├── cycling_details_screen.dart           (NEW)
│   │   ├── swimming_details_screen.dart          (NEW)
│   │   ├── dietary_preference_screen.dart        (NEW)
│   │   ├── allergies_screen.dart                 (NEW)
│   │   └── onboarding_food_preferences_screen.dart (NEW)
│   └── providers/
│       └── onboarding_flow_controller.dart       (NEW)
├── application/
│   └── food_filtering_service.dart               (NEW)
└── domain/
    ├── dietary_preference.dart                   (NEW)
    └── allergy.dart                              (NEW)

lib/features/settings/
└── presentation/
    └── screens/
        └── dietary_profile_screen.dart           (NEW)
```

## Files to Update

```
lib/shared/database/app_database.dart             (UPDATE - new columns)
lib/shared/core/app_router.dart                   (UPDATE - new routes)
lib/features/auth/domain/user_preferences.dart    (UPDATE - new fields)
lib/features/auth/data/user_repository.dart       (UPDATE - new methods)
lib/features/onboarding/presentation/providers/onboarding_controller.dart (UPDATE)
lib/features/onboarding/application/onboarding_service.dart (UPDATE)
assets/config/content_defaults.json               (UPDATE - new UI text)
```

## Files to Remove

```
lib/features/onboarding/presentation/screens/sport_preferences_screen.dart (REMOVE)
```

---

## Content Management Keys

Add to `content_defaults.json`:

```json
{
  "ui_text": {
    "onboarding": {
      "sports_selection": {
        "title": "Which sports do you train for?",
        "description": "We'll customize your nutrition plans for each sport.",
        "running": "Running",
        "cycling": "Cycling",
        "swimming": "Swimming"
      },
      "running_details": {
        "title": "Running details",
        "description": "Help us estimate your hydration needs.",
        "water_bottle": "I run with a water bottle"
      },
      "cycling_details": {
        "title": "Cycling details",
        "ftp_title": "FTP (Functional Threshold Power)",
        "ftp_helper": "Maximum power you can sustain for ~1 hour. Enter 0 if unknown.",
        "ftp_unit": "watts",
        "water_bottles_question": "How many water bottles do you use?",
        "aero_bottles": "I use Aero Bottles",
        "bento_box": "I use a Bento Box for food"
      },
      "swimming_details": {
        "title": "Swimming details",
        "css_title": "CSS (Critical Swim Speed)",
        "css_helper": "Fastest pace per 100 meters you can sustain for 30 minutes. MM:SS format",
        "wetsuit": "I typically wear a wetsuit",
        "swim_cap_title": "Swim Cap Type",
        "swim_cap_none": "None",
        "swim_cap_latex": "Latex",
        "swim_cap_silicone": "Silicone",
        "swim_cap_neoprene": "Neoprene"
      },
      "dietary_preference": {
        "title": "What is your dietary preference?",
        "omnivore": "Omnivore",
        "vegetarian": "Vegetarian",
        "pescatarian": "Pescatarian",
        "vegan": "Vegan",
        "mediterranean": "Mediterranean",
        "paleo": "Paleo",
        "keto": "Keto",
        "low_carb": "Low-Carb"
      },
      "allergies": {
        "title": "Do you have any allergies?",
        "dairy": "Dairy",
        "eggs": "Eggs",
        "fish": "Fish",
        "gluten": "Gluten",
        "peanuts": "Peanuts",
        "sesame": "Sesame",
        "shellfish": "Shellfish",
        "soy": "Soy",
        "tree_nuts": "Tree nuts"
      },
      "food_preferences": {
        "title": "What foods fuel your training?",
        "description": "You can add more later in settings.",
        "search_placeholder": "Search",
        "common_foods_header": "Common foods"
      },
      "navigation": {
        "continue": "Continue",
        "back": "Back",
        "skip": "Skip"
      }
    }
  }
}
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Schema migration issues | Low | High | Test thoroughly in dev before prod |
| Food filtering complexity | Medium | Medium | Start with simple filtering, iterate |
| Existing user data corruption | Low | High | No re-onboarding, null defaults |
| Swipe navigation conflicts | Medium | Low | Fallback to button-only if issues |
| Performance with filtering | Low | Medium | Optimize queries, cache filtered list |

---

## Success Metrics

- [ ] Onboarding completion rate >= current rate
- [ ] Time to complete onboarding <= current time
- [ ] No increase in crash rate
- [ ] All existing tests pass
- [ ] New screens match Figma designs
- [ ] Dietary/allergy data saves correctly

---

## Resolved Questions

1. **Food allergen data**: LLM will populate the `allergens` and `excluded_diets` columns by pulling existing foods from Supabase, analyzing each food, and updating the columns accordingly. This is a one-time data migration task.

2. **Edge function versioning**: Use **backward-compatible updates** to `generate-nutrition-plan` (NOT a v2). Add optional `dietary_preference` and `allergies` parameters that default to no filtering. This follows the existing pattern used for `activity_type` and avoids code duplication, deployment complexity, and breaking changes.

3. **Nutrition plan integration**: The `generate-nutrition-plan` edge function WILL receive dietary preference and allergies parameters for server-side food filtering. This ensures nutrition plans respect user dietary restrictions even if the Flutter app's local filtering is bypassed.

4. **Edge cases**: No warning or auto-correct needed. If a user selects Vegan but manually likes dairy foods, we respect their explicit choice. The filtering only affects which foods are shown by default; user selections override filters.

---

## References

- [Existing Onboarding Docs](/docs/onboarding_revamp/README.md) - Previous implementation plan
- [Design Specifications](/docs/onboarding_revamp/design-specifications.md) - Pixel-perfect specs
- [Production Schema](/docs/prod_schema.txt) - Current database schema
- [FOA Architecture](/docs/technical/foa-architecture.md) - Architecture patterns

---

*This roadmap supersedes the previous `/docs/onboarding_revamp/README.md` for implementation guidance. The old document is retained for reference.*
