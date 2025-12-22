# Phase 4: Wiring & Integration - Detailed Checklist

## Overview

This checklist provides step-by-step instructions for completing Phase 4 of the Onboarding Revamp project. Phase 4 focuses on wiring all screens to controllers and ensuring data flows correctly through the entire onboarding process.

**Status**: In Progress
**Priority**: High
**Estimated Effort**: 2-3 days

## Prerequisites

- [ ] Phase 1 (Database & Foundation) complete
- [ ] Phase 2 (New Screens) complete
- [ ] Phase 3 (Shared Widgets) complete
- [ ] Development environment set up with Flutter 3.8+
- [ ] Supabase dev environment accessible

## Task Breakdown

### Task 1: Wire SportsSelectionScreen

**File**: `/lib/features/onboarding/presentation/screens/sports_selection_screen.dart`

**Current State**: Screen has UI but doesn't save selected sports.

**Requirements**:
1. Create local state to track selected sports (List<String>)
2. Implement multi-select logic for Running, Cycling, Swimming cards
3. Add validation (at least one sport must be selected)
4. Save selected sports to controller on Continue button press
5. Navigate to first sport detail screen based on selections

**Implementation**:
```dart
class _SportsSelectionScreenState extends ConsumerState<SportsSelectionScreen> {
  final Set<String> _selectedSports = {};
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // ... existing UI ...

    // Sports cards
    SelectableCard(
      title: 'Running',
      icon: Icons.directions_run,
      isSelected: _selectedSports.contains('running'),
      onTap: () {
        setState(() {
          if (_selectedSports.contains('running')) {
            _selectedSports.remove('running');
          } else {
            _selectedSports.add('running');
          }
        });
      },
    ),

    // ... similar for cycling and swimming ...

    // Continue button
    OnboardingNavigationFooter(
      onContinue: _selectedSports.isEmpty ? null : _handleContinue,
      onBack: () => context.pop(),
      isLoading: _isLoading,
    ),
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);

    try {
      // Determine first sport detail screen
      if (_selectedSports.contains('running')) {
        context.goNamed(
          'onboarding-running-details',
          extra: _selectedSports.toList(),
        );
      } else if (_selectedSports.contains('cycling')) {
        context.goNamed(
          'onboarding-cycling-details',
          extra: _selectedSports.toList(),
        );
      } else if (_selectedSports.contains('swimming')) {
        context.goNamed(
          'onboarding-swimming-details',
          extra: _selectedSports.toList(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
```

**Testing**:
- [ ] Select only Running → navigates to RunningDetailsScreen
- [ ] Select only Cycling → navigates to CyclingDetailsScreen
- [ ] Select only Swimming → navigates to SwimmingDetailsScreen
- [ ] Select multiple sports → navigates to first selected sport
- [ ] Cannot continue with no sports selected

---

### Task 2: Wire RunningDetailsScreen

**File**: `/lib/features/onboarding/presentation/screens/running_details_screen.dart`

**Current State**: Screen has UI but doesn't save water bottle preference.

**Requirements**:
1. Receive selectedSports list from route extra
2. Track water bottle toggle state
3. Save water bottle preference via OnboardingService
4. Navigate to next screen (Cycling, Swimming, or Dietary Preference)

**Implementation**:
```dart
class RunningDetailsScreen extends ConsumerStatefulWidget {
  final List<String> selectedSports;

  const RunningDetailsScreen({required this.selectedSports, super.key});

  @override
  ConsumerState<RunningDetailsScreen> createState() => _RunningDetailsScreenState();
}

class _RunningDetailsScreenState extends ConsumerState<RunningDetailsScreen> {
  bool _runsWithWaterBottle = true; // Default to true
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... existing UI ...

      ToggleCard(
        title: 'Water Bottle',
        description: 'Do you typically run with a water bottle?',
        value: _runsWithWaterBottle,
        onChanged: (value) {
          setState(() {
            _runsWithWaterBottle = value;
          });
        },
      ),

      OnboardingNavigationFooter(
        onContinue: _handleContinue,
        onBack: () => context.pop(),
        isLoading: _isLoading,
      ),
    );
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);

    try {
      // Save running details
      final user = await ref.read(authServiceProvider).getCurrentUser();
      if (user == null) throw Exception('No user found');

      await ref.read(onboardingServiceProvider).saveSportPreferences(
        user.id,
        // Note: runsWithWaterBottle is saved in user profile creation
        // This is just updating it if user changes
      );

      // Navigate to next sport or dietary preference
      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
```

**Testing**:
- [ ] Toggle water bottle on/off
- [ ] Save button enabled
- [ ] Navigates to CyclingDetailsScreen if cycling selected
- [ ] Navigates to SwimmingDetailsScreen if swimming selected (no cycling)
- [ ] Navigates to DietaryPreferenceScreen if only running selected

---

### Task 3: Wire CyclingDetailsScreen

**File**: `/lib/features/onboarding/presentation/screens/cycling_details_screen.dart`

**Current State**: Screen has UI but doesn't save cycling preferences.

**Requirements**:
1. Receive selectedSports list from route extra
2. Track all cycling fields: FTP, bike bottles, aero bottle, bento box, GI sensitivity
3. Save cycling preferences via OnboardingService
4. Navigate to next screen (Swimming or Dietary Preference)

**Implementation**:
```dart
class _CyclingDetailsScreenState extends ConsumerState<CyclingDetailsScreen> {
  final _ftpController = TextEditingController();
  int? _ftpWatts;
  int _bikeBottles = 2; // Default
  bool _hasAeroBottle = false;
  bool _hasBentoBox = false;
  bool _giSensitivity = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... existing UI ...

      // FTP Input
      TextField(
        controller: _ftpController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'FTP (Watts)',
          hintText: 'Enter your Functional Threshold Power',
        ),
        onChanged: (value) {
          setState(() {
            _ftpWatts = int.tryParse(value);
          });
        },
      ),

      // Bike Bottles Selector
      SegmentedSelector<int>(
        options: const [1, 2, 3],
        selectedOption: _bikeBottles,
        onSelectionChanged: (value) {
          setState(() {
            _bikeBottles = value;
          });
        },
        optionBuilder: (value) => Text('$value'),
      ),

      // Aero Bottle Toggle
      ToggleCard(
        title: 'Aero Bottle',
        value: _hasAeroBottle,
        onChanged: (value) {
          setState(() {
            _hasAeroBottle = value;
          });
        },
      ),

      // Bento Box Toggle
      ToggleCard(
        title: 'Bento Box',
        value: _hasBentoBox,
        onChanged: (value) {
          setState(() {
            _hasBentoBox = value;
          });
        },
      ),

      // GI Sensitivity Toggle
      ToggleCard(
        title: 'GI Sensitivity',
        description: 'Do you experience GI issues during rides?',
        value: _giSensitivity,
        onChanged: (value) {
          setState(() {
            _giSensitivity = value;
          });
        },
      ),
    );
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);

    try {
      final user = await ref.read(authServiceProvider).getCurrentUser();
      if (user == null) throw Exception('No user found');

      // Save cycling preferences
      await ref.read(onboardingServiceProvider).saveSportPreferences(
        user.id,
        ftpWatts: _ftpWatts,
        typicalBikeBottles: _bikeBottles,
        hasAeroBottle: _hasAeroBottle,
        hasBentoBox: _hasBentoBox,
        giSensitivity: _giSensitivity,
      );

      // Navigate to next screen
      if (mounted) {
        if (widget.selectedSports.contains('swimming')) {
          context.goNamed(
            'onboarding-swimming-details',
            extra: widget.selectedSports,
          );
        } else {
          context.goNamed('onboarding-dietary-preference');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _ftpController.dispose();
    super.dispose();
  }
}
```

**Testing**:
- [ ] FTP input accepts numbers only
- [ ] Bike bottles selector defaults to 2
- [ ] All toggles work correctly
- [ ] Navigates to SwimmingDetailsScreen if swimming selected
- [ ] Navigates to DietaryPreferenceScreen if no swimming

---

### Task 4: Wire SwimmingDetailsScreen

**File**: `/lib/features/onboarding/presentation/screens/swimming_details_screen.dart`

**Current State**: Screen has UI but doesn't save swimming preferences.

**Requirements**:
1. Receive selectedSports list from route extra
2. Track CSS pace, wetsuit, swim cap type
3. Save swimming preferences via OnboardingService
4. Navigate to Dietary Preference screen

**Implementation**:
```dart
class _SwimmingDetailsScreenState extends ConsumerState<SwimmingDetailsScreen> {
  final _cssMinutesController = TextEditingController();
  final _cssSecondsController = TextEditingController();
  int? _cssPacePer100mSeconds;
  bool _typicalWetsuit = false;
  String _typicalSwimCapType = 'silicone'; // Default
  bool _isLoading = false;

  void _updateCssPace() {
    final minutes = int.tryParse(_cssMinutesController.text) ?? 0;
    final seconds = int.tryParse(_cssSecondsController.text) ?? 0;
    setState(() {
      _cssPacePer100mSeconds = (minutes * 60) + seconds;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... existing UI ...

      // CSS Pace Input
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _cssMinutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutes',
              ),
              onChanged: (_) => _updateCssPace(),
            ),
          ),
          const Text(':'),
          Expanded(
            child: TextField(
              controller: _cssSecondsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Seconds',
              ),
              onChanged: (_) => _updateCssPace(),
            ),
          ),
        ],
      ),

      // Wetsuit Toggle
      ToggleCard(
        title: 'Wetsuit',
        description: 'Do you typically swim in a wetsuit?',
        value: _typicalWetsuit,
        onChanged: (value) {
          setState(() {
            _typicalWetsuit = value;
          });
        },
      ),

      // Swim Cap Type
      Column(
        children: [
          RadioOptionCard(
            title: 'Silicone Cap',
            isSelected: _typicalSwimCapType == 'silicone',
            onTap: () {
              setState(() {
                _typicalSwimCapType = 'silicone';
              });
            },
          ),
          RadioOptionCard(
            title: 'Latex Cap',
            isSelected: _typicalSwimCapType == 'latex',
            onTap: () {
              setState(() {
                _typicalSwimCapType = 'latex';
              });
            },
          ),
          RadioOptionCard(
            title: 'No Cap',
            isSelected: _typicalSwimCapType == 'none',
            onTap: () {
              setState(() {
                _typicalSwimCapType = 'none';
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);

    try {
      final user = await ref.read(authServiceProvider).getCurrentUser();
      if (user == null) throw Exception('No user found');

      // Save swimming preferences
      await ref.read(onboardingServiceProvider).saveSportPreferences(
        user.id,
        cssPacePer100mSeconds: _cssPacePer100mSeconds,
        typicalWetsuit: _typicalWetsuit,
        typicalSwimCapType: _typicalSwimCapType,
      );

      // Navigate to dietary preference
      if (mounted) {
        context.goNamed('onboarding-dietary-preference');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _cssMinutesController.dispose();
    _cssSecondsController.dispose();
    super.dispose();
  }
}
```

**Testing**:
- [ ] CSS pace input accepts MM:SS format
- [ ] Wetsuit toggle works
- [ ] Swim cap radio selection works
- [ ] Navigates to DietaryPreferenceScreen

---

### Task 5: Wire DietaryPreferenceScreen

**File**: `/lib/features/onboarding/presentation/screens/dietary_preference_screen.dart`

**Current State**: Screen has UI but doesn't save dietary preference.

**Requirements**:
1. Track selected dietary preference (nullable)
2. Save preference via OnboardingService
3. Handle Skip button (sets preference to null)
4. Navigate to Allergies screen

**Implementation**:
```dart
class _DietaryPreferenceScreenState extends ConsumerState<DietaryPreferenceScreen> {
  DietaryPreference? _selectedPreference;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... existing UI ...

      // Dietary preference cards
      Column(
        children: DietaryPreference.values.map((diet) {
          return SelectableCard(
            title: diet.displayName,
            isSelected: _selectedPreference == diet,
            onTap: () {
              setState(() {
                _selectedPreference = diet;
              });
            },
          );
        }).toList(),
      ),

      OnboardingNavigationFooter(
        onContinue: _handleContinue,
        onBack: () => context.pop(),
        showSkip: true,
        onSkip: _handleSkip,
        isLoading: _isLoading,
      ),
    );
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);

    try {
      final user = await ref.read(authServiceProvider).getCurrentUser();
      if (user == null) throw Exception('No user found');

      // Save dietary preference
      await ref.read(onboardingServiceProvider)
          .saveDietaryPreference(user.id, _selectedPreference);

      // Navigate to allergies
      if (mounted) {
        context.goNamed('onboarding-allergies');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preference: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleSkip() {
    // Skip without saving (preference remains null)
    context.goNamed('onboarding-allergies');
  }
}
```

**Testing**:
- [ ] Can select any dietary preference
- [ ] Continue button saves selection
- [ ] Skip button navigates without saving
- [ ] Navigates to AllergiesScreen

---

### Task 6: Wire AllergiesScreen

**File**: `/lib/features/onboarding/presentation/screens/allergies_screen.dart`

**Current State**: Screen has UI but doesn't save allergies.

**Requirements**:
1. Track selected allergies (multi-select)
2. Save allergies via OnboardingService
3. Handle Skip button (sets allergies to empty list)
4. Navigate to Food Preferences V2 screen with dietary preference and allergies

**Implementation**:
```dart
class _AllergiesScreenState extends ConsumerState<AllergiesScreen> {
  final Set<Allergy> _selectedAllergies = {};
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... existing UI ...

      // Allergy cards
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
      ),

      OnboardingNavigationFooter(
        onContinue: _handleContinue,
        onBack: () => context.pop(),
        showSkip: true,
        onSkip: _handleSkip,
        isLoading: _isLoading,
      ),
    );
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);

    try {
      final user = await ref.read(authServiceProvider).getCurrentUser();
      if (user == null) throw Exception('No user found');

      // Save allergies
      await ref.read(onboardingServiceProvider)
          .saveAllergies(user.id, _selectedAllergies.toList());

      // Get dietary preference from user profile
      final dietaryPreference = user.dietaryPreference;

      // Navigate to food preferences with context
      if (mounted) {
        context.goNamed(
          'onboarding-food-preferences-v2',
          extra: {
            'dietaryPreference': dietaryPreference,
            'allergies': _selectedAllergies.toList(),
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving allergies: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleSkip() async {
    // Get user for dietary preference
    final user = await ref.read(authServiceProvider).getCurrentUser();
    final dietaryPreference = user?.dietaryPreference;

    // Navigate without saving allergies
    if (mounted) {
      context.goNamed(
        'onboarding-food-preferences-v2',
        extra: {
          'dietaryPreference': dietaryPreference,
          'allergies': <Allergy>[],
        },
      );
    }
  }
}
```

**Testing**:
- [ ] Can select multiple allergies
- [ ] Can deselect allergies
- [ ] Continue button saves selections
- [ ] Skip button navigates with empty list
- [ ] Passes dietary preference and allergies to FoodPreferencesV2Screen

---

### Task 7: Wire FoodPreferencesV2Screen

**File**: `/lib/features/onboarding/presentation/screens/food_preferences_v2_screen.dart`

**Current State**: Screen has UI but doesn't save food preferences or filter foods.

**Requirements**:
1. Receive dietary preference and allergies from route extra
2. Filter foods by dietary preference and allergens
3. Track food preferences (Love, Willing to Try, Avoid)
4. Save food preferences via OnboardingService
5. Navigate to Onboarding Complete (redirects to main app)

**Implementation**:
```dart
class FoodPreferencesV2Screen extends ConsumerStatefulWidget {
  final DietaryPreference? dietaryPreference;
  final List<Allergy> allergies;

  const FoodPreferencesV2Screen({
    this.dietaryPreference,
    this.allergies = const [],
    super.key,
  });

  @override
  ConsumerState<FoodPreferencesV2Screen> createState() =>
      _FoodPreferencesV2ScreenState();
}

class _FoodPreferencesV2ScreenState extends ConsumerState<FoodPreferencesV2Screen> {
  final Map<String, FoodPreference> _foodPreferences = {};
  String _searchQuery = '';
  bool _isLoading = false;

  List<Food> _filterFoods(List<Food> allFoods) {
    return allFoods.where((food) {
      // Filter by dietary preference
      if (widget.dietaryPreference != null &&
          food.excludedDiets.contains(widget.dietaryPreference)) {
        return false;
      }

      // Filter by allergens
      for (final allergy in widget.allergies) {
        if (food.allergens.contains(allergy)) {
          return false;
        }
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final lowerQuery = _searchQuery.toLowerCase();
        return food.name.toLowerCase().contains(lowerQuery) ||
               food.displayName?.toLowerCase().contains(lowerQuery) == true;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final allFoods = ref.watch(foodsProvider); // Assuming you have this provider

    return Scaffold(
      // ... existing UI ...

      // Search field
      TextField(
        decoration: const InputDecoration(
          labelText: 'Search foods',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),

      // Food chips
      allFoods.when(
        data: (foods) {
          final filteredFoods = _filterFoods(foods);

          return ListView.builder(
            itemCount: filteredFoods.length,
            itemBuilder: (context, index) {
              final food = filteredFoods[index];
              final preference = _foodPreferences[food.id] ??
                  FoodPreference.willingToTry;

              return FoodChip(
                food: food,
                preference: preference,
                onPreferenceChanged: (newPreference) {
                  setState(() {
                    _foodPreferences[food.id] = newPreference;
                  });
                },
              );
            },
          );
        },
        loading: () => const CircularProgressIndicator(),
        error: (error, stack) => Text('Error: $error'),
      ),

      OnboardingNavigationFooter(
        onContinue: _handleContinue,
        onBack: () => context.pop(),
        isLoading: _isLoading,
      ),
    );
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);

    try {
      final user = await ref.read(authServiceProvider).getCurrentUser();
      if (user == null) throw Exception('No user found');

      // Save food preferences
      await ref.read(onboardingServiceProvider)
          .saveFoodPreferences(user.id, _foodPreferences);

      // Mark onboarding as complete
      await ref.read(authServiceProvider).completeOnboarding(user.id);

      // Navigate to complete (redirects to main app)
      if (mounted) {
        context.goNamed('onboarding-complete');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
```

**Testing**:
- [ ] Foods are filtered by dietary preference
- [ ] Foods are filtered by allergens
- [ ] Search functionality works
- [ ] Food chips cycle through Love/Willing/Avoid
- [ ] Continue saves all preferences
- [ ] Navigates to main app after completion

---

### Task 8: Update UserProfileScreen Navigation

**File**: `/lib/features/onboarding/presentation/screens/user_profile_screen.dart`

**Current State**: Navigates to old sport preferences screen.

**Requirements**:
1. Change navigation target from old flow to new flow
2. Ensure user profile is saved before navigation

**Implementation**:
```dart
Future<void> _handleContinue() async {
  // ... existing validation and save logic ...

  // OLD:
  // context.goNamed('onboarding-sport-preferences');

  // NEW:
  if (mounted) {
    context.goNamed('onboarding-sports-selection');
  }
}
```

**Testing**:
- [ ] User profile saves correctly
- [ ] Navigates to SportsSelectionScreen (not old SportPreferencesScreen)

---

## Code Generation

After making changes to any controllers, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Testing Checklist

### End-to-End Flow Testing

- [ ] Complete flow: Running only
  - User Profile → Sports Selection (Running) → Running Details → Dietary → Allergies → Food Prefs → Main App

- [ ] Complete flow: Cycling only
  - User Profile → Sports Selection (Cycling) → Cycling Details → Dietary → Allergies → Food Prefs → Main App

- [ ] Complete flow: Swimming only
  - User Profile → Sports Selection (Swimming) → Swimming Details → Dietary → Allergies → Food Prefs → Main App

- [ ] Complete flow: All sports
  - User Profile → Sports Selection (All) → Running → Cycling → Swimming → Dietary → Allergies → Food Prefs → Main App

- [ ] Skip flow
  - Complete with all Skip buttons pressed

### Data Persistence Testing

- [ ] All sport preferences save to Drift
- [ ] Dietary preference saves to Drift and Supabase
- [ ] Allergies save to Drift and Supabase
- [ ] Food preferences save to Drift and Supabase
- [ ] Onboarding completion flag is set

### Navigation Testing

- [ ] Back button works on all screens
- [ ] Selected sports are passed correctly
- [ ] Progress bar shows correct steps
- [ ] App redirects to main screen after completion

## Completion Criteria

Phase 4 is complete when:

1. All 8 tasks above are checked off
2. All end-to-end flow tests pass
3. All data persistence tests pass
4. All navigation tests pass
5. No console errors or warnings
6. Code follows FOA patterns
7. Analytics tracking confirmed working

## Next Phase

After Phase 4 completion:

1. Settings Integration (add dietary/allergy editing in settings)
2. Edge Function Updates (filter foods by diet/allergens in nutrition plan)
3. Deprecate Old Screens (remove old onboarding flow)
4. Add Automated Tests (integration tests for onboarding flow)

---

**Last Updated**: December 15, 2025
**Related Documents**:
- [README.md](./README.md)
- [technical-guide.md](./technical-guide.md)
