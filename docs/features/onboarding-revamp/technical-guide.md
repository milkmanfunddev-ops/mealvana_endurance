# Onboarding Revamp - Technical Implementation Guide

## Overview

This document provides technical implementation details for developers working on the Onboarding Revamp project. It complements the main [README.md](./README.md) with code examples, architecture decisions, and implementation patterns.

## Architecture Patterns

### Feature-Oriented Architecture (FOA) Compliance

All onboarding screens follow Andrea Bizzotto's FOA patterns:

**Layer Structure**:
```
lib/features/onboarding/
├── domain/        # Enums, models (DietaryPreference, Allergy)
├── application/   # Services (OnboardingService)
├── presentation/  # Screens, widgets, controllers
└── data/         # (Not used - data handled by auth feature)
```

**Key Principles**:
1. **Presentation Layer**: UI-only logic (navigation, form validation, animations)
2. **Application Layer**: Business logic (saving preferences, analytics tracking)
3. **Domain Layer**: Pure data models and enums
4. **Data Layer**: Repository pattern (handled by auth feature's UserRepository)

### State Management

All controllers use **Riverpod AsyncNotifier** pattern with code generation:

```dart
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'controller_name.g.dart';

@riverpod
class OnboardingController extends _$OnboardingController {
  OnboardingService get _service => ref.read(onboardingServiceProvider);

  @override
  FutureOr<OnboardingState> build() {
    return OnboardingState.initial();
  }

  Future<void> saveDietaryPreference(DietaryPreference? preference) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final user = await ref.read(authServiceProvider).getCurrentUser();
      if (user == null) throw Exception('No user found');

      await _service.saveDietaryPreference(user.id, preference);

      return state.value!.copyWith(dietaryPreference: preference);
    });
  }
}
```

**Required After Controller Changes**:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Domain Models Deep Dive

### DietaryPreference Enum

**Design Decisions**:
1. **Single-select**: User can only have one dietary preference at a time
2. **Nullable**: `null` means user skipped the preference selection
3. **PostgreSQL enum compatibility**: Uses snake_case for database values

**Implementation**:
```dart
enum DietaryPreference {
  omnivore,
  vegetarian,
  pescatarian,
  vegan,
  mediterranean,
  paleo,
  keto,
  lowCarb;

  // Database value (PostgreSQL enum)
  String get dbValue {
    switch (this) {
      case DietaryPreference.lowCarb:
        return 'low_carb';
      default:
        return name;
    }
  }

  // UI display name
  String get displayName {
    switch (this) {
      case DietaryPreference.lowCarb:
        return 'Low-Carb';
      default:
        return name[0].toUpperCase() + name.substring(1);
    }
  }
}
```

**Array Parsing for Food Model**:
```dart
// Food.excludedDiets uses array parsing
static List<DietaryPreference> fromDbArray(String? value) {
  // Handles PostgreSQL array: {vegan,paleo,keto}
  // Handles JSON array: ["vegan","paleo","keto"]
  // Returns List<DietaryPreference>
}

static String toDbArray(List<DietaryPreference> diets) {
  // Converts to PostgreSQL array: {vegan,paleo,keto}
  if (diets.isEmpty) return '{}';
  return '{${diets.map((d) => d.dbValue).join(',')}}';
}
```

### Allergy Enum

**Design Decisions**:
1. **Multi-select**: User can have multiple allergies
2. **Empty list**: User skipped or has no allergies
3. **PostgreSQL array format**: Stored as `{dairy,gluten,peanuts}`

**Implementation**:
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

  // Database value
  String get dbValue {
    switch (this) {
      case Allergy.treeNuts:
        return 'tree_nuts';
      default:
        return name;
    }
  }

  // UI display name
  String get displayName {
    switch (this) {
      case Allergy.treeNuts:
        return 'Tree nuts';
      default:
        return name[0].toUpperCase() + name.substring(1);
    }
  }
}
```

**Array Parsing**:
```dart
// Parse from database
static List<Allergy> fromDbArray(String? value) {
  if (value == null || value.isEmpty || value == '{}') {
    return [];
  }

  // PostgreSQL format: {dairy,gluten,peanuts}
  if (value.startsWith('{') && value.endsWith('}')) {
    final inner = value.substring(1, value.length - 1);
    final allergyStrings = inner.split(',').map((s) => s.trim()).toList();
    return allergyStrings
        .map((str) => Allergy.fromDbValue(str))
        .whereType<Allergy>()
        .toList();
  }

  return [];
}

// Convert to database format
static String toDbArray(List<Allergy> allergies) {
  if (allergies.isEmpty) return '{}';
  return '{${allergies.map((a) => a.dbValue).join(',')}}';
}
```

### UserProfile Model Updates

**Database Synchronization Strategy**:

```dart
// toJson() for Supabase sync
Map<String, dynamic> toJson() {
  return {
    // ... existing fields ...

    // SYNCED TO PRODUCTION SUPABASE
    'dietary_preference': dietaryPreference?.dbValue,
    'allergies': Allergy.toDbArray(allergies),
    'cycling_ftp_watts': ftpWatts,
    'swimming_css_seconds_per_100m': cssPacePer100mSeconds,

    // DRIFT-ONLY (NOT synced to production)
    // Note: swipe_hint_shown, gi_sensitivity, typical_bike_bottles,
    // has_aero_bottle, has_bento_box, typical_wetsuit,
    // typical_swim_cap_type are local-only fields
  };
}

// fromJson() for Supabase fetch
factory UserProfile.fromJson(Map<String, dynamic> json) {
  return UserProfile(
    // ... existing fields ...

    // NEW: Dietary and allergy parsing
    dietaryPreference: DietaryPreference.fromDbValue(
      json['dietary_preference'] as String?
    ),
    allergies: Allergy.fromDbArray(json['allergies'] as String?),

    // NEW: Sport preferences (production columns)
    ftpWatts: json['cycling_ftp_watts'] as int?,
    cssPacePer100mSeconds: json['swimming_css_seconds_per_100m'] as int?,

    // Drift-only fields always default to null from Supabase
    giSensitivity: null,
    typicalBikeBottles: null,
    hasAeroBottle: null,
    hasBentoBox: null,
    typicalWetsuit: null,
    typicalSwimCapType: null,
  );
}
```

**Why Some Fields Are Drift-Only**:
- Production Supabase schema doesn't have all cycling/swimming columns yet
- Development environment has full schema
- Future schema migration will sync all fields to production

## Navigation Implementation

### Conditional Sport Detail Screens

**Navigation Logic**:
```dart
// From SportsSelectionScreen
List<String> selectedSports = ['running', 'cycling', 'swimming'];

// Determine first sport detail screen
if (selectedSports.contains('running')) {
  context.goNamed(
    'onboarding-running-details',
    extra: selectedSports,
  );
} else if (selectedSports.contains('cycling')) {
  context.goNamed(
    'onboarding-cycling-details',
    extra: selectedSports,
  );
} else if (selectedSports.contains('swimming')) {
  context.goNamed(
    'onboarding-swimming-details',
    extra: selectedSports,
  );
} else {
  // No sports selected (shouldn't happen)
  context.goNamed('onboarding-dietary-preference');
}
```

**From RunningDetailsScreen**:
```dart
// Save running details, then navigate to next sport or dietary
await controller.saveRunningDetails(runsWithWaterBottle);

if (widget.selectedSports.contains('cycling')) {
  context.goNamed(
    'onboarding-cycling-details',
    extra: widget.selectedSports,
  );
} else if (widget.selectedSports.contains('swimming')) {
  context.goNamed(
    'onboarding-swimming-details',
    extra: widget.selectedSports,
  );
} else {
  context.goNamed('onboarding-dietary-preference');
}
```

**Pattern**: Each sport screen checks `selectedSports` list to determine next destination.

### Passing Data Between Screens

**Route Extra Data Pattern**:
```dart
// Sports Selection → Running Details
context.goNamed(
  'onboarding-running-details',
  extra: ['running', 'cycling', 'swimming'],
);

// Dietary Preference → Allergies
context.goNamed('onboarding-allergies');

// Allergies → Food Preferences V2
context.goNamed(
  'onboarding-food-preferences-v2',
  extra: {
    'dietaryPreference': dietaryPreference,
    'allergies': allergies,
  },
);
```

**GoRouter Configuration**:
```dart
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

## Screen Implementation Patterns

### Standard Screen Structure

All onboarding screens follow this pattern:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/onboarding_progress_bar.dart';
import '../widgets/onboarding_navigation_footer.dart';

class ExampleScreen extends ConsumerStatefulWidget {
  const ExampleScreen({super.key});

  @override
  ConsumerState<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends ConsumerState<ExampleScreen> {
  // Local UI state
  bool _isLoading = false;
  String? _selectedOption;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Title'),
      ),
      body: Column(
        children: [
          // Progress bar
          OnboardingProgressBar(
            currentStep: 3,
            totalSteps: 7,
          ),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Screen content here
                ],
              ),
            ),
          ),

          // Navigation footer
          OnboardingNavigationFooter(
            onBack: () => context.pop(),
            onContinue: _handleContinue,
            isLoading: _isLoading,
            showSkip: true,
            onSkip: _handleSkip,
          ),
        ],
      ),
    );
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);

    try {
      // Save data via controller
      await ref.read(onboardingControllerProvider.notifier)
          .saveData(_selectedOption);

      // Navigate to next screen
      if (mounted) {
        context.goNamed('next-screen');
      }
    } catch (e) {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleSkip() {
    // Navigate without saving
    context.goNamed('next-screen');
  }
}
```

### Widget Reusability

**SelectableCard - Multi-Select Example**:
```dart
Column(
  children: Allergy.values.map((allergy) {
    final isSelected = _selectedAllergies.contains(allergy);

    return SelectableCard(
      title: allergy.displayName,
      isSelected: isSelected,
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedAllergies.remove(allergy);
          } else {
            _selectedAllergies.add(allergy);
          }
        });
      },
    );
  }).toList(),
)
```

**SelectableCard - Single-Select Example**:
```dart
Column(
  children: DietaryPreference.values.map((diet) {
    final isSelected = _selectedDiet == diet;

    return SelectableCard(
      title: diet.displayName,
      isSelected: isSelected,
      onTap: () {
        setState(() {
          _selectedDiet = diet;
        });
      },
    );
  }).toList(),
)
```

**ToggleCard Example**:
```dart
ToggleCard(
  title: 'Water Bottle',
  description: 'Do you run with a water bottle?',
  value: _runsWithWaterBottle,
  onChanged: (value) {
    setState(() {
      _runsWithWaterBottle = value;
    });
  },
)
```

**SegmentedSelector Example**:
```dart
SegmentedSelector<int>(
  options: const [1, 2, 3],
  selectedOption: _bikeBottles,
  onSelectionChanged: (value) {
    setState(() {
      _bikeBottles = value;
    });
  },
  optionBuilder: (value) => Text('$value'),
)
```

## Service Layer Implementation

### OnboardingService Methods

**saveDietaryPreference**:
```dart
Future<void> saveDietaryPreference(
  String userId,
  DietaryPreference? dietaryPreference,
) async {
  // Call AuthService to update user profile
  await _authService.updateDietaryPreference(userId, dietaryPreference);

  // Track analytics
  await _analytics.track('dietary_preference_saved', properties: {
    'preference': dietaryPreference?.name ?? 'none',
    'skipped': dietaryPreference == null,
  });
}
```

**saveAllergies**:
```dart
Future<void> saveAllergies(
  String userId,
  List<Allergy> allergies,
) async {
  // Call AuthService to update user profile
  await _authService.updateAllergies(userId, allergies);

  // Track analytics
  await _analytics.track('allergies_saved', properties: {
    'allergies': allergies.map((a) => a.name).toList(),
    'count': allergies.length,
    'skipped': allergies.isEmpty,
  });
}
```

**saveSportPreferences**:
```dart
Future<void> saveSportPreferences(
  String userId, {
  bool? giSensitivity,
  int? ftpWatts,
  int? typicalBikeBottles,
  bool? hasAeroBottle,
  bool? hasBentoBox,
  int? cssPacePer100mSeconds,
  bool? typicalWetsuit,
  String? typicalSwimCapType,
}) async {
  // Update user profile with sport-specific fields
  await _authService.updateSportPreferences(
    userId,
    giSensitivity: giSensitivity,
    ftpWatts: ftpWatts,
    typicalBikeBottles: typicalBikeBottles,
    hasAeroBottle: hasAeroBottle,
    hasBentoBox: hasBentoBox,
    cssPacePer100mSeconds: cssPacePer100mSeconds,
    typicalWetsuit: typicalWetsuit,
    typicalSwimCapType: typicalSwimCapType,
  );

  // Track analytics
  await _analytics.track('sport_preferences_saved', properties: {
    'gi_sensitivity': giSensitivity,
    'has_cycling': ftpWatts != null,
    'has_swimming': cssPacePer100mSeconds != null,
  });
}
```

### AuthService Updates

**updateDietaryPreference**:
```dart
Future<void> updateDietaryPreference(
  String userId,
  DietaryPreference? dietaryPreference,
) async {
  final user = await getCurrentUser();
  if (user == null) throw Exception('User not found');

  final updatedUser = user.copyWith(
    dietaryPreference: dietaryPreference,
    updatedAt: DateTime.now(),
  );

  // Save to Drift
  await _userRepository.updateUser(updatedUser);

  // Sync to Supabase
  await _syncUserToSupabase(updatedUser);
}
```

**updateAllergies**:
```dart
Future<void> updateAllergies(
  String userId,
  List<Allergy> allergies,
) async {
  final user = await getCurrentUser();
  if (user == null) throw Exception('User not found');

  final updatedUser = user.copyWith(
    allergies: allergies,
    updatedAt: DateTime.now(),
  );

  // Save to Drift
  await _userRepository.updateUser(updatedUser);

  // Sync to Supabase
  await _syncUserToSupabase(updatedUser);
}
```

## Food Filtering Implementation

### Filter Logic in FoodPreferencesV2Screen

```dart
List<Food> _filterFoods(
  List<Food> allFoods,
  DietaryPreference? dietaryPreference,
  List<Allergy> allergies,
  String searchQuery,
) {
  return allFoods.where((food) {
    // 1. Filter by dietary preference
    if (dietaryPreference != null &&
        food.excludedDiets.contains(dietaryPreference)) {
      return false;
    }

    // 2. Filter by allergens
    if (allergies.isNotEmpty) {
      for (final allergy in allergies) {
        if (food.allergens.contains(allergy)) {
          return false;
        }
      }
    }

    // 3. Filter by search query
    if (searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      return food.name.toLowerCase().contains(lowerQuery) ||
             food.displayName?.toLowerCase().contains(lowerQuery) == true;
    }

    return true;
  }).toList();
}
```

### Food Model Examples

**Example 1: Dairy-Free Vegan Protein Bar**:
```dart
Food(
  id: 'protein-bar-vegan',
  name: 'Vegan Protein Bar',
  categories: ['before_run', 'after_run'],
  allergens: [Allergy.soy, Allergy.treeNuts],
  excludedDiets: [DietaryPreference.paleo, DietaryPreference.keto],
  // ... other fields
)
```

**Example 2: Greek Yogurt**:
```dart
Food(
  id: 'greek-yogurt',
  name: 'Greek Yogurt',
  categories: ['before_run', 'after_run'],
  allergens: [Allergy.dairy],
  excludedDiets: [
    DietaryPreference.vegan,
    DietaryPreference.vegetarian,
    DietaryPreference.paleo,
  ],
  // ... other fields
)
```

## Testing Guidelines

### Unit Tests for Enum Parsing

```dart
// Test: dietary_preference_test.dart
void main() {
  group('DietaryPreference fromDbArray', () {
    test('parses PostgreSQL array format', () {
      final result = DietaryPreference.fromDbArray('{vegan,paleo,keto}');
      expect(result, [
        DietaryPreference.vegan,
        DietaryPreference.paleo,
        DietaryPreference.keto,
      ]);
    });

    test('handles empty array', () {
      expect(DietaryPreference.fromDbArray('{}'), []);
      expect(DietaryPreference.fromDbArray(null), []);
      expect(DietaryPreference.fromDbArray(''), []);
    });

    test('handles snake_case values', () {
      final result = DietaryPreference.fromDbArray('{low_carb}');
      expect(result, [DietaryPreference.lowCarb]);
    });
  });

  group('DietaryPreference toDbArray', () {
    test('converts to PostgreSQL array format', () {
      final result = DietaryPreference.toDbArray([
        DietaryPreference.vegan,
        DietaryPreference.keto,
      ]);
      expect(result, '{vegan,keto}');
    });

    test('handles empty list', () {
      expect(DietaryPreference.toDbArray([]), '{}');
    });
  });
}
```

### Integration Tests for Food Filtering

```dart
// Test: food_filtering_test.dart
void main() {
  group('Food filtering', () {
    late List<Food> testFoods;

    setUp(() {
      testFoods = [
        Food(
          id: '1',
          name: 'Chicken Breast',
          allergens: [],
          excludedDiets: [DietaryPreference.vegan, DietaryPreference.vegetarian],
        ),
        Food(
          id: '2',
          name: 'Almond Butter',
          allergens: [Allergy.treeNuts],
          excludedDiets: [],
        ),
        Food(
          id: '3',
          name: 'Greek Yogurt',
          allergens: [Allergy.dairy],
          excludedDiets: [DietaryPreference.vegan],
        ),
      ];
    });

    test('filters by dietary preference', () {
      final result = filterFoodsByDiet(
        testFoods,
        DietaryPreference.vegan,
      );
      expect(result.length, 1);
      expect(result.first.name, 'Almond Butter');
    });

    test('filters by allergens', () {
      final result = filterFoodsByAllergens(
        testFoods,
        [Allergy.treeNuts, Allergy.dairy],
      );
      expect(result.length, 1);
      expect(result.first.name, 'Chicken Breast');
    });
  });
}
```

## Common Issues & Solutions

### Issue 1: PostgreSQL Array Format Parsing

**Problem**: PostgreSQL returns arrays in `{a,b,c}` format, not JSON arrays.

**Solution**: Use `fromDbArray()` static methods on enums:
```dart
// UserProfile.fromJson()
allergies: Allergy.fromDbArray(json['allergies'] as String?)

// NOT this:
allergies: (json['allergies'] as List?)
    ?.map((e) => Allergy.fromDbValue(e))
    .toList() ?? []
```

### Issue 2: Null vs Empty List for Allergies

**Problem**: Skipping allergies should result in empty list, not null.

**Solution**: Always use empty list as default:
```dart
final List<Allergy> allergies;

// In constructor
UserProfile({
  this.allergies = const [],  // NOT null
});

// In copyWith
allergies: allergies ?? this.allergies,  // Use existing if null passed
```

### Issue 3: Navigation State Loss

**Problem**: Selected sports list is lost when navigating between screens.

**Solution**: Always pass via route `extra`:
```dart
// From Sports Selection
context.goNamed('onboarding-running-details', extra: selectedSports);

// In Running Details
class RunningDetailsScreen extends ConsumerWidget {
  final List<String> selectedSports;

  const RunningDetailsScreen({required this.selectedSports});

  // Use selectedSports to determine next navigation
}
```

### Issue 4: Drift-Only Fields Not Syncing

**Problem**: Sport-specific fields like `hasAeroBottle` don't sync to Supabase.

**Expected Behavior**: This is intentional until production schema migration.

**Workaround**:
- Store locally in Drift
- Only sync `ftpWatts` and `cssPacePer100mSeconds` to production
- Full sync will work after schema migration

## Performance Considerations

### Food List Rendering

**Problem**: Rendering 100+ food chips can be slow.

**Solution**: Use ListView.builder with lazy loading:
```dart
ListView.builder(
  itemCount: filteredFoods.length,
  itemBuilder: (context, index) {
    final food = filteredFoods[index];
    return FoodChip(
      food: food,
      preference: foodPreferences[food.id],
      onPreferenceChanged: (preference) {
        setState(() {
          foodPreferences[food.id] = preference;
        });
      },
    );
  },
)
```

### Search Debouncing

**Problem**: Filtering on every keystroke is inefficient.

**Solution**: Use debouncing with Timer:
```dart
Timer? _debounce;

void _onSearchChanged(String query) {
  if (_debounce?.isActive ?? false) _debounce!.cancel();

  _debounce = Timer(const Duration(milliseconds: 300), () {
    setState(() {
      _searchQuery = query;
    });
  });
}

@override
void dispose() {
  _debounce?.cancel();
  super.dispose();
}
```

## Migration Notes

### From Old to New Onboarding Flow

**Old Flow**:
1. UserProfileScreen
2. SportPreferencesScreen (single-select radio buttons)
3. FoodPreferencesScreen (slider-based)

**New Flow**:
1. UserProfileScreen (unchanged)
2. SportsSelectionScreen (multi-select cards)
3. Conditional sport detail screens
4. DietaryPreferenceScreen
5. AllergiesScreen
6. FoodPreferencesV2Screen (chip-based)

**Migration Steps**:
1. Complete Phase 4 wiring
2. Update UserProfileScreen navigation:
   ```dart
   // OLD:
   context.goNamed('onboarding-sport-preferences');

   // NEW:
   context.goNamed('onboarding-sports-selection');
   ```
3. Test complete flow
4. Deprecate old screens (keep for reference)
5. Remove old routes after validation

### Database Schema Alignment

**Current State**:
- Drift: Full schema with all sport fields
- Supabase Dev: Full schema with all sport fields
- Supabase Production: Missing some sport fields

**Target State**:
- All environments have identical schema
- All fields sync bidirectionally

**Migration Plan**:
1. Create schema migration SQL for production
2. Test migration on staging environment
3. Deploy to production during low-traffic window
4. Update `UserProfile.toJson()` to sync all fields
5. Verify data integrity

---

**Last Updated**: December 15, 2025
**Companion Document**: [README.md](./README.md)
**Author**: AI Assistant (Claude Sonnet 4.5)
