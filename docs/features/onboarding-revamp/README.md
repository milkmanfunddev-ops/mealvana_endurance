# Onboarding Revamp - Multi-Sport Enhancement Project

## Overview

This document details the comprehensive redesign of the Mealvana Endurance onboarding flow to support multi-sport athletes (runners, cyclists, swimmers) with enhanced personalization including dietary preferences, allergies, and sport-specific configurations.

**Status**: Phase 3 (In Progress - Wiring Phase)
**Started**: December 2025
**Target Completion**: January 2026

## Project Goals

1. **Multi-Sport Support**: Enable users to select multiple sports (Running, Cycling, Swimming) and configure sport-specific details
2. **Enhanced Personalization**: Capture dietary preferences and allergies to filter food recommendations
3. **Improved UX**: Modern, chip-based food selection interface with search functionality
4. **Better Data Model**: Align with expanded database schema supporting multi-sport features

## Architecture Changes

### Domain Models

#### UserProfile Model Updates
**Location**: `/lib/features/auth/domain/user_preferences.dart`

Added fields to support new onboarding requirements:

```dart
class UserProfile {
  // NEW: Dietary preference (single-select)
  final DietaryPreference? dietaryPreference;

  // NEW: Allergies (multi-select)
  final List<Allergy> allergies;

  // NEW: Sport-specific preferences
  final bool? giSensitivity;           // Cycling: GI sensitivity toggle
  final int? ftpWatts;                 // Cycling: Functional Threshold Power
  final int? typicalBikeBottles;       // Cycling: Number of bike bottles
  final bool? hasAeroBottle;           // Cycling: Aero bottle availability
  final bool? hasBentoBox;             // Cycling: Bento box availability
  final int? cssPacePer100mSeconds;    // Swimming: Critical Swim Speed
  final bool? typicalWetsuit;          // Swimming: Wetsuit usage
  final String? typicalSwimCapType;    // Swimming: Swim cap type (silicon/latex/none)

  // EXISTING: Running preferences
  final bool runsWithWaterBottle;      // Running: Water bottle carry
}
```

**Database Synchronization**:
- `dietaryPreference` and `allergies` sync to Supabase production
- Sport-specific cycling/swimming fields are **Drift-only** in production (dev environment has full schema)
- PostgreSQL array format parsing: `fromDbArray()` and `toDbArray()` methods for allergies

#### Food Model Updates
**Location**: `/lib/features/nutrition_plan/domain/food.dart`

Added fields for food filtering:

```dart
class Food {
  // NEW: Allergen tracking (multi-select)
  final List<Allergy> allergens; // e.g., [Allergy.dairy, Allergy.gluten]

  // NEW: Diet exclusions (foods incompatible with certain diets)
  final List<DietaryPreference> excludedDiets; // e.g., [DietaryPreference.vegan]

  // EXISTING: Categories array
  final List<String> categories; // e.g., ['before_run', 'during_run']
}
```

**Food Filtering Logic**:
- Foods containing user allergens are excluded from recommendations
- Foods excluded from user's dietary preference are filtered out
- Categories determine timing suitability (before/during/after)

### New Domain Enums

#### DietaryPreference Enum
**Location**: `/lib/features/onboarding/domain/dietary_preference.dart`

```dart
enum DietaryPreference {
  omnivore,       // No restrictions
  vegetarian,     // No meat/fish
  pescatarian,    // No meat (fish allowed)
  vegan,          // No animal products
  mediterranean,  // Mediterranean diet
  paleo,          // Paleo diet
  keto,           // Ketogenic diet
  lowCarb;        // Low-carb diet
}
```

**Key Features**:
- Single-select (user can only have one dietary preference)
- PostgreSQL enum compatibility with `dbValue` conversion
- UI-friendly `displayName` property
- Array parsing for `excluded_diets` field in Food model

#### Allergy Enum
**Location**: `/lib/features/onboarding/domain/allergy.dart`

```dart
enum Allergy {
  dairy,
  eggs,
  fish,
  gluten,
  peanuts,
  sesame,
  shellfish,
  soy,
  treeNuts;
}
```

**Key Features**:
- Multi-select (users can have multiple allergies)
- PostgreSQL array format: `{dairy,gluten,peanuts}`
- Array parsing: `fromDbArray()` and `toDbArray()` methods
- Snake_case conversion for compound values (`tree_nuts`)

## New Onboarding Flow

### Flow Diagram

```
Welcome Screen
    ↓
User Profile Screen (age, gender, height, weight)
    ↓
Sports Selection Screen (multi-select: Running, Cycling, Swimming)
    ↓
[Conditional] Running Details Screen (water bottle toggle)
    ↓ (if Cycling selected)
[Conditional] Cycling Details Screen (FTP, bottles, aero bottle, bento box)
    ↓ (if Swimming selected)
[Conditional] Swimming Details Screen (CSS pace, wetsuit, swim cap)
    ↓
Dietary Preference Screen (single-select with skip option)
    ↓
Allergies Screen (multi-select with skip option)
    ↓
Food Preferences V2 Screen (chip-based selection with search)
    ↓
Onboarding Complete → Main App
```

### Route Configuration

**Location**: `/lib/shared/core/app_router.dart`

New routes added (lines 121-180):

```dart
// Sports Selection
GoRoute(
  path: '/onboarding/sports-selection',
  name: 'onboarding-sports-selection',
  builder: (context, state) => const SportsSelectionScreen(),
),

// Running Details (conditional)
GoRoute(
  path: '/onboarding/running-details',
  name: 'onboarding-running-details',
  builder: (context, state) {
    final extra = state.extra as List<String>? ?? ['running'];
    return RunningDetailsScreen(selectedSports: extra);
  },
),

// Cycling Details (conditional)
GoRoute(
  path: '/onboarding/cycling-details',
  name: 'onboarding-cycling-details',
  builder: (context, state) {
    final extra = state.extra as List<String>? ?? ['cycling'];
    return CyclingDetailsScreen(selectedSports: extra);
  },
),

// Swimming Details (conditional)
GoRoute(
  path: '/onboarding/swimming-details',
  name: 'onboarding-swimming-details',
  builder: (context, state) {
    final extra = state.extra as List<String>? ?? ['swimming'];
    return SwimmingDetailsScreen(selectedSports: extra);
  },
),

// Dietary Preference
GoRoute(
  path: '/onboarding/dietary-preference',
  name: 'onboarding-dietary-preference',
  builder: (context, state) => const DietaryPreferenceScreen(),
),

// Allergies
GoRoute(
  path: '/onboarding/allergies',
  name: 'onboarding-allergies',
  builder: (context, state) => const AllergiesScreen(),
),

// Food Preferences V2 (chip-based)
GoRoute(
  path: '/onboarding/food-preferences-v2',
  name: 'onboarding-food-preferences-v2',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>?;
    return FoodPreferencesV2Screen(
      dietaryPreference: extra?['dietaryPreference'] as DietaryPreference?,
      allergies: (extra?['allergies'] as List<dynamic>?)
              ?.whereType<Allergy>()
              .toList() ??
          const [],
    );
  },
),
```

## Implementation Details

### Phase 1: Database & Foundation (COMPLETE)

#### 1.1 Domain Model Updates
- ✅ Added `dietaryPreference` and `allergies` fields to UserProfile
- ✅ Added `allergens` and `excludedDiets` fields to Food model
- ✅ Created DietaryPreference enum with 8 diet types
- ✅ Created Allergy enum with 9 common allergens
- ✅ Implemented PostgreSQL array parsing for both enums

**Files Modified**:
- `/lib/features/auth/domain/user_preferences.dart`
- `/lib/features/nutrition_plan/domain/food.dart`

**Files Created**:
- `/lib/features/onboarding/domain/dietary_preference.dart`
- `/lib/features/onboarding/domain/allergy.dart`

#### 1.2 Service Layer Updates
- ✅ Added `updateDietaryPreference()` to AuthService
- ✅ Added `updateAllergies()` to AuthService
- ✅ Added `saveDietaryPreference()` to OnboardingService
- ✅ Added `saveAllergies()` to OnboardingService
- ✅ Added analytics tracking for dietary preferences and allergies

**Files Modified**:
- `/lib/features/auth/application/auth_service.dart`
- `/lib/features/onboarding/application/onboarding_service.dart`

### Phase 2: New Screens (COMPLETE)

#### 2.1 Sports Selection Screen
**Location**: `/lib/features/onboarding/presentation/screens/sports_selection_screen.dart`

**Features**:
- Multi-select cards for Running, Cycling, Swimming
- Requires at least one sport selected
- Passes selected sports to subsequent screens via route `extra`
- Uses `SelectableCard` widget for consistent UI

**Navigation Logic**:
```dart
// Example navigation with selected sports
context.goNamed(
  'onboarding-running-details',
  extra: selectedSports, // ['running', 'cycling']
);
```

#### 2.2 Running Details Screen
**Location**: `/lib/features/onboarding/presentation/screens/running_details_screen.dart`

**Fields**:
- Water bottle toggle (boolean)
- Displays selected sports for context

**Widget Used**: `ToggleCard`

#### 2.3 Cycling Details Screen
**Location**: `/lib/features/onboarding/presentation/screens/cycling_details_screen.dart`

**Fields**:
1. FTP (Functional Threshold Power) in watts - numeric input
2. Number of bike bottles - segmented selector (1, 2, 3)
3. Aero bottle - toggle
4. Bento box - toggle

**Widgets Used**: `SegmentedSelector`, `ToggleCard`

#### 2.4 Swimming Details Screen
**Location**: `/lib/features/onboarding/presentation/screens/swimming_details_screen.dart`

**Fields**:
1. CSS pace (Critical Swim Speed) in MM:SS per 100m - time input
2. Wetsuit usage - toggle
3. Swim cap type - radio selector (Silicon, Latex, None)

**Widgets Used**: `RadioOptionCard`, `ToggleCard`

#### 2.5 Dietary Preference Screen
**Location**: `/lib/features/onboarding/presentation/screens/dietary_preference_screen.dart`

**Features**:
- Single-select cards for 8 dietary preferences
- Skip button (sets preference to null)
- Uses SelectableCard widget with radio selection pattern

**Dietary Options**:
- Omnivore
- Vegetarian
- Pescatarian
- Vegan
- Mediterranean
- Paleo
- Keto
- Low-Carb

#### 2.6 Allergies Screen
**Location**: `/lib/features/onboarding/presentation/screens/allergies_screen.dart`

**Features**:
- Multi-select cards for 9 common allergens
- Skip button (sets allergies to empty list)
- Uses SelectableCard widget with checkbox pattern

**Allergen Options**:
- Dairy
- Eggs
- Fish
- Gluten
- Peanuts
- Sesame
- Shellfish
- Soy
- Tree nuts

#### 2.7 Food Preferences V2 Screen
**Location**: `/lib/features/onboarding/presentation/screens/food_preferences_v2_screen.dart`

**Features**:
- Chip-based food selection interface
- Search functionality to filter foods
- Pre-filtered by dietary preference and allergies
- Three preference levels: Love, Willing to Try, Avoid
- Uses `FoodChip` widget for individual food items

**Food Filtering**:
```dart
// Foods are filtered based on:
1. Excluded diets: Remove foods incompatible with user's dietary preference
2. Allergens: Remove foods containing user's allergens
3. Search query: Filter by food name
```

### Phase 3: Shared Widgets (COMPLETE)

#### 3.1 Onboarding Progress Bar
**Location**: `/lib/features/onboarding/presentation/widgets/onboarding_progress_bar.dart`

**Features**:
- Linear progress indicator with step count
- Displays current step / total steps
- Consistent styling across all onboarding screens

#### 3.2 Onboarding Navigation Footer
**Location**: `/lib/features/onboarding/presentation/widgets/onboarding_navigation_footer.dart`

**Features**:
- Standardized footer with Back and Continue buttons
- Optional Skip button
- Handles loading states
- Consistent spacing and padding

#### 3.3 Selectable Card
**Location**: `/lib/features/onboarding/presentation/widgets/selectable_card.dart`

**Features**:
- Reusable card component for single/multi-select options
- Checkbox or radio indicator support
- Hover states and animations
- Title, subtitle, and icon support

#### 3.4 Radio Option Card
**Location**: `/lib/features/onboarding/presentation/widgets/radio_option_card.dart`

**Features**:
- Specialized card for radio button selections
- Used in swim cap type selection
- Single selection pattern

#### 3.5 Toggle Card
**Location**: `/lib/features/onboarding/presentation/widgets/toggle_card.dart`

**Features**:
- Card with integrated toggle switch
- Used for yes/no options (water bottle, wetsuit, etc.)
- Title, subtitle, and description support

#### 3.6 Food Chip
**Location**: `/lib/features/onboarding/presentation/widgets/food_chip.dart`

**Features**:
- Chip widget for food selection
- Three states: Love, Willing to Try, Avoid
- Color-coded visual feedback
- Tap to cycle through states

#### 3.7 Segmented Selector
**Location**: `/lib/features/onboarding/presentation/widgets/segmented_selector.dart`

**Features**:
- iOS-style segmented control
- Used for bike bottle count (1, 2, 3)
- Smooth animations between selections

### Phase 4: Wiring & Integration (IN PROGRESS)

#### 4.1 Controller Updates
**Status**: Partially Complete

**Remaining Tasks**:
1. Wire up SportsSelectionScreen to call controller save methods
2. Wire up RunningDetailsScreen to save water bottle preference
3. Wire up CyclingDetailsScreen to save cycling preferences
4. Wire up SwimmingDetailsScreen to save swimming preferences
5. Wire up DietaryPreferenceScreen to call `saveDietaryPreference()`
6. Wire up AllergiesScreen to call `saveAllergies()`
7. Wire up FoodPreferencesV2Screen to call `saveFoodPreferences()`

**Navigation Flow**:
Each screen must:
- Save its data to the controller
- Determine the next screen based on selected sports
- Navigate with appropriate `extra` data

#### 4.2 Entry Point Navigation
**Status**: Not Started

**Task**: Update UserProfileScreen to navigate to new sports selection flow instead of old sport preferences screen.

**Current Behavior**:
```dart
// User completes profile → goes to old sport_preferences_screen
context.goNamed('onboarding-sport-preferences');
```

**Target Behavior**:
```dart
// User completes profile → goes to new sports_selection_screen
context.goNamed('onboarding-sports-selection');
```

#### 4.3 Settings Integration
**Status**: Not Started

**Task**: Add dietary preference and allergy editing in settings screens.

**Screens to Update**:
- `/lib/features/settings/presentation/screens/preferences_screen.dart`
- New screen: `/lib/features/settings/presentation/screens/dietary_settings_screen.dart`

#### 4.4 Edge Function Updates
**Status**: Not Started

**Tasks**:
1. Update `save-food-preferences` edge function to handle dietary preferences and allergies
2. Update `generate-ai-nutrition-plan` edge function to respect dietary preferences and allergens
3. Update `run-plan` edge function to filter foods by dietary preference and allergens

**Edge Function Locations**:
- `/supabase/functions/save-food-preferences/index.ts`
- `/supabase/functions/generate-ai-nutrition-plan/index.ts`
- `/supabase/functions/run-plan/index.ts`

## Testing Strategy

### Manual Testing Checklist

#### Flow Testing
- [ ] Complete onboarding flow with only Running selected
- [ ] Complete onboarding flow with only Cycling selected
- [ ] Complete onboarding flow with only Swimming selected
- [ ] Complete onboarding flow with all three sports selected
- [ ] Skip dietary preference and allergies
- [ ] Select dietary preference without allergies
- [ ] Select allergies without dietary preference
- [ ] Select both dietary preference and allergies

#### Data Persistence Testing
- [ ] Verify UserProfile saves all sport-specific fields to Drift
- [ ] Verify dietary preference syncs to Supabase
- [ ] Verify allergies sync to Supabase
- [ ] Verify food preferences respect dietary filter
- [ ] Verify food preferences respect allergen filter

#### Navigation Testing
- [ ] Back button works correctly on each screen
- [ ] Skip button works on dietary preference screen
- [ ] Skip button works on allergies screen
- [ ] Progress bar shows correct step count
- [ ] Selected sports are passed correctly between screens

### Automated Testing

**Location**: `/test/features/onboarding/`

**Test Categories**:
1. **Enum Parsing Tests**: Verify PostgreSQL array format parsing for DietaryPreference and Allergy
2. **Service Tests**: Verify OnboardingService methods save data correctly
3. **Food Filtering Tests**: Verify foods are filtered by dietary preference and allergens
4. **Navigation Tests**: Verify conditional navigation based on selected sports

## Known Issues & Limitations

### Production Schema Limitations

**Issue**: Production Supabase schema missing cycling/swimming columns in `users` table.

**Current Workaround**:
- Drift local database has full schema with all sport-specific fields
- Supabase sync only syncs `cycling_ftp_watts` and `swimming_css_seconds_per_100m`
- Other sport fields are Drift-only and don't sync to production

**Future Fix**: Deploy schema migration to production to add missing columns

### Old vs New Onboarding Flows

**Issue**: Two parallel onboarding flows exist in the codebase.

**Old Flow**:
- `/onboarding/profile` → `/onboarding/sport-preferences` → `/onboarding/food-preferences`

**New Flow**:
- `/onboarding/profile` → `/onboarding/sports-selection` → (conditional sport screens) → `/onboarding/dietary-preference` → `/onboarding/allergies` → `/onboarding/food-preferences-v2`

**Resolution Plan**:
1. Complete Phase 4 (wiring)
2. Update UserProfileScreen to use new flow
3. Deprecate old screens: `sport_preferences_screen.dart`, `food_preferences_screen.dart`
4. Remove old routes after full migration

## File Structure

```
lib/features/onboarding/
├── domain/
│   ├── dietary_preference.dart      # NEW: Dietary preference enum
│   └── allergy.dart                 # NEW: Allergy enum
├── application/
│   └── onboarding_service.dart      # UPDATED: Added dietary/allergy methods
└── presentation/
    ├── screens/
    │   ├── sports_selection_screen.dart       # NEW: Multi-sport selection
    │   ├── running_details_screen.dart        # NEW: Water bottle toggle
    │   ├── cycling_details_screen.dart        # NEW: FTP, bottles, aero, bento
    │   ├── swimming_details_screen.dart       # NEW: CSS, wetsuit, cap
    │   ├── dietary_preference_screen.dart     # NEW: Single-select diet
    │   ├── allergies_screen.dart              # NEW: Multi-select allergies
    │   ├── food_preferences_v2_screen.dart    # NEW: Chip-based food selection
    │   ├── user_profile_screen.dart           # EXISTING: Entry point
    │   ├── sport_preferences_screen.dart      # OLD: To be deprecated
    │   └── food_preferences_screen.dart       # OLD: To be deprecated
    └── widgets/
        ├── onboarding_progress_bar.dart       # NEW: Progress indicator
        ├── onboarding_navigation_footer.dart  # NEW: Consistent footer
        ├── selectable_card.dart               # NEW: Single/multi-select cards
        ├── radio_option_card.dart             # NEW: Radio selection
        ├── toggle_card.dart                   # NEW: Yes/no toggles
        ├── food_chip.dart                     # NEW: Food preference chips
        └── segmented_selector.dart            # NEW: iOS-style selector
```

## Next Steps

### Immediate (Phase 4)
1. Wire all screens to call controller save methods
2. Update UserProfileScreen navigation to use new sports-selection flow
3. Test complete end-to-end onboarding flow
4. Fix any data persistence issues

### Near-Term
1. Add dietary preference and allergy editing in settings
2. Update edge functions to filter by dietary preference and allergens
3. Add automated tests for new onboarding flow
4. Remove old onboarding screens after validation

### Future Enhancements
1. Add more dietary preference options (if needed)
2. Add food recommendation AI based on dietary preferences
3. Improve food search with fuzzy matching
4. Add onboarding flow analytics tracking
5. A/B test chip-based vs slider-based food preferences

## Resources

### Related Documentation
- [Database Schema v1](/database_schemas/v1/) - Complete schema with all tables
- [FOA Architecture](/docs/technical/foa-architecture.md) - Feature-oriented architecture patterns
- [Food Preferences System](/docs/business_logic/food-preferences-system-overview.md) - Three-tier preference model
- [Old Onboarding Roadmap](/docs/features/onboarding/roadmap.md) - Previous enhancement plans (barcode scanning)

### Code Locations
- **Domain Models**: `/lib/features/auth/domain/user_preferences.dart`
- **Services**: `/lib/features/onboarding/application/onboarding_service.dart`
- **Router**: `/lib/shared/core/app_router.dart`
- **Screens**: `/lib/features/onboarding/presentation/screens/`
- **Widgets**: `/lib/features/onboarding/presentation/widgets/`

---

**Last Updated**: December 15, 2025
**Phase**: 3 - Wiring & Integration (In Progress)
**Author**: AI Assistant (Claude Sonnet 4.5)
**Next Review**: After Phase 4 completion
