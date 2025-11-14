# New Activity Screen Implementation Roadmap
## Unified Multi-Sport Activity Creation Interface

**Status**: 🏗️ In Progress - Phase 0 Complete ✅
**Priority**: P0 - Critical
**Timeline**: ASAP (2-3 days)
**Scope**: Frontend UI consolidation only
**Last Updated**: 2025-11-13 (Phase 0 completed)

---

## Executive Summary

This roadmap documents the implementation of Kyle's unified "New Activity" screen that consolidates three separate sport-specific screens (Running, Cycling, Swimming) into a single tabbed interface. The design matches Kyle's Figma mockups exactly while preserving all existing business logic and maintaining FOA compliance.

### Key Objectives

✅ **Consolidate UI**: Replace 3 separate screens with 1 unified tabbed screen
✅ **Match Design**: Implement Kyle's Figma design with pixel-perfect accuracy
✅ **Preserve State**: Maintain form state when switching between sport tabs
✅ **Reuse Logic**: Leverage existing tested controllers and business logic
✅ **Maintain Quality**: Zero regressions in nutrition plan generation flow

### Design Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Hero Image** | Dynamic per sport | Runner.png → Biker.png → Swimmer.png based on active tab |
| **Tab Pattern** | TabBar/TabBarView | Material Design tabs with sport icons as labels |
| **Date/Time UI** | Display + Edit dialog | Match Figma: side-by-side display with single "Edit" link |
| **Environment Sections** | Collapsible at bottom | Keep for functionality, hide by default to match Figma |
| **Weather Integration** | Auto-fetch + Forecast link | Keep existing auto-fetch, add "Forecast" detail link |
| **Controller Architecture** | Coordinator + existing controllers | Thin coordination layer, reuse tested sport-specific logic |
| **Tab State** | Persistent (keepAlive) | Preserve all form values during tab switching |
| **Migration Strategy** | Immediate replacement | Edit in place, deprecate old screens after launch |
| **Deep Linking** | Not needed | Standard `/new-activity` route only |
| **Rollout** | All sports at once | Single PR with all three tabs |
| **Testing** | Manual only | Fast iteration, leverage existing controller tests |

---

## Current Architecture Analysis

### Existing Screens (TO BE REPLACED)

```
lib/features/nutrition_plan/presentation/screens/
├── distance_pace_gut_entry_screen.dart    (641 lines) - Running
├── cycling_input_screen.dart              (669 lines) - Cycling
└── swimming_input_screen.dart             (719 lines) - Swimming
```

**Total Lines to Consolidate**: ~2,030 lines → Estimated ~800 lines in new unified screen

### Existing Controllers (TO BE REUSED)

```
lib/features/nutrition_plan/presentation/providers/
├── distance_page_gut_entry_controller.dart   (1274 lines) - Main macro generation
├── running_input_controller.dart             (261 lines)  - Running form state
├── cycling_input_controller.dart             (298 lines)  - Cycling form state
└── swimming_input_controller.dart            (275 lines)  - Swimming form state
```

**Status**: ✅ All controllers are FOA-compliant and will be reused as-is

### Key Domain Models

```dart
// Activity model with sport-specific fields
Activity {
  activityType: ActivityType,           // running, cycling, swimming
  distanceMiles: double?,

  // Running-specific
  paceTargetMinutesPerMile: double?,

  // Cycling-specific
  cyclingSpeedMph: double?,
  cyclingTerrain: String?,
  cyclingElevationGainFt: int?,

  // Swimming-specific
  swimmingPacePer100mSeconds: int?,
  swimmingPoolOrOpenWater: String?,
  swimmingWaterTempC: double?,

  // Shared
  intensityTarget: String?,
  timeBeforeMinutes: int?,
  nutritionPlanData: Map<String, dynamic>?,
}

// Pending activity data (during macro generation)
PendingActivityData {
  static running(...) → PendingActivityData
  static cycling(...) → PendingActivityData
  static swimming(...) → PendingActivityData
}
```

---

## Figma Design Specifications

### Visual Hierarchy

```
┌─────────────────────────────────────────┐
│  [< Back]      New Activity             │ ← App Bar
├─────────────────────────────────────────┤
│                                         │
│  [Running] [Biking] [Swimming]          │ ← Tab Selector (62×74px icons)
│     ●                                   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │    [Dynamic Hero Image]         │   │ ← Runner.png / Biker.png / Swimmer.png
│  │    (with pink star overlay)     │   │   (223px height)
│  └─────────────────────────────────┘   │
│                                         │
│  DATE              TIME                 │ ← Display fields (Sansita Bold 20px)
│  Nov 9, 2025      12:00 pm    ✏️ Edit   │   Single edit dialog
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  [Tab Content - Sport-Specific Fields]  │ ← TabBarView with 3 tabs
│                                         │
│  Running Tab:                           │
│    • Distance (plus/minus)              │
│    • Average Pace (plus/minus)          │
│    • Time before Run (plus/minus)       │
│    • Gut Training Level (segmented)     │
│    • Sweat Rate (segmented)             │
│    • Temperature (plus/minus)           │
│    • Humidity (plus/minus)              │
│                                         │
│  Cycling Tab:                           │
│    • Distance (plus/minus)              │
│    • Speed (plus/minus)                 │
│    • Time before Ride (plus/minus)      │
│    • Intensity Target (dropdown)        │
│    • Session Goal (dropdown)            │
│    • Terrain (dropdown)                 │
│    • Elevation Gain (plus/minus)        │
│    • [Environment Section] (collapsible)│
│      - Temperature, Humidity            │
│      - Wind, Sun Exposure               │
│                                         │
│  Swimming Tab:                          │
│    • Pool/Open Water (toggle)           │
│    • Distance (plus/minus)              │
│    • Pace per 100m (plus/minus)         │
│    • Time before Swim (plus/minus)      │
│    • Intensity Target (dropdown)        │
│    • Session Goal (dropdown)            │
│    • Water Temperature (plus/minus)     │
│    • [Environment Section] (collapsible)│
│      - Deck Temperature, Humidity       │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│       [Generate Plan Button]            │ ← Primary button (Orange)
│                                         │
└─────────────────────────────────────────┘
```

### Component Specifications (from Figma)

#### Tab Selector Icons
```dart
// Size: 62px width × 74px height
// Border Radius: 15px
// Unselected: transparent bg, 1px Blackberry border
// Selected: Blackberry bg, 2px Blackberry border

// Icons:
// - Running: Font Awesome runner (20px, centered)
// - Biking: Font Awesome bicycle (20px, centered)
// - Swimming: Font Awesome swimmer (20px, centered)

// Labels:
// - Font: Compadre Regular 8px
// - Color: Cream (selected) / Blackberry (unselected)
// - Text: "Running" / "Biking" / "Swimming"
```

#### Hero Image
```dart
// Container: 355px width × 223px height
// Image: Runner.png / Biker.png / Swimmer.png
// Overlay: Vector.png (pink star pattern) at 12.81% top, 18.13% sides
// Background: Cream (light mode) / Blackberry (dark mode)
```

#### Date/Time Display
```dart
// Layout: Row with two columns + Edit link
// Left: DATE
// - Label: Compadre Regular 10px, uppercase, Blackberry
// - Value: Sansita Bold 20px, "Nov 9, 2025", Blackberry
// Right: TIME
// - Label: Compadre Regular 10px, uppercase, Blackberry
// - Value: Sansita Bold 20px, "12:00 pm", Blackberry
// Edit link:
// - Position: centered between DATE and TIME
// - Icon: Pencil (Font Awesome 15px)
// - Text: "Edit" (Apercu Mono 10px)
// - Color: Dragonfruit (#DC2597)
```

#### Plus/Minus Controls
```dart
// Extracted from Figma (EXACT VALUES):
// Container: 36px × 36px circular
// Border: 2px solid Orange (#F78B14)
// Icon: 20px × 20px (minus or plus)
// Padding: 8px
// Background: Transparent

// Value display between buttons:
// - Font: Compadre Regular 16px
// - Color: Blackberry (#381633)
// - Examples: "12 miles", "9:00 min / Mile"
```

#### Segmented Controls
```dart
// Gut Training & Sweat Rate (EXACT VALUES):
// Width: 74-110px (varies by label)
// Border Radius: 15px
// Unselected: transparent, 1px Blackberry border
// Selected: Blackberry bg, 2px Blackberry border

// Text:
// - Font: Sansita Bold 12px
// - Unselected: Blackberry (#381633)
// - Selected: Cream (#F8F6EB)

// Options:
// - LOW / MODERATE / HIGH
// - Subtext: "0.7 g/kg/h" / "0.8 g/kg/h" (Apercu Mono 10px)
```

#### Section Labels
```dart
// Distance, Average Pace, etc.
// Font: Sansita Bold 17px
// Color: Blackberry (#381633)
// Margin: 16px left, spacing varies
```

#### Generate Plan Button
```dart
// Size: 196px width (auto height with padding)
// Background: Orange (#F78B14)
// Border Radius: 100px (fully rounded)
// Padding: 10px vertical, 16px horizontal
// Text: "Generate Plan" (Sansita Bold 16px, Blackberry)
```

---

## Implementation Plan

### Phase 0: Setup & Preparation ✅ COMPLETED (45 minutes)

**Goal**: Create file structure and stub components

**Status**: ✅ Complete - All files created and verified

#### Tasks Completed

1. ✅ **Created new screen file**
   - File: `lib/features/nutrition_plan/presentation/screens/new_activity_screen.dart`
   - Status: Stub created with basic AppBar and placeholder UI
   - Lines: ~100 lines

2. ✅ **Created coordinator controller**
   - File: `lib/features/nutrition_plan/presentation/providers/new_activity_coordinator.dart`
   - Generated: `new_activity_coordinator.g.dart` (via build_runner)
   - Status: Stub created with state management structure
   - Lines: ~130 lines

3. ✅ **Created shared widgets directory**
   - Directory: `lib/features/nutrition_plan/presentation/widgets/new_activity/`
   - Subdirectory: `new_activity/shared/` (for shared components)

4. ✅ **Created tab content stub files**
   - `running_tab_content.dart` - Running form fields stub
   - `cycling_tab_content.dart` - Cycling form fields stub
   - `swimming_tab_content.dart` - Swimming form fields stub
   - Status: All stubs show placeholder UI with phase progress indicators

5. ✅ **Verified hero images in assets**
   - ✅ `assets/images/Runner.png` - Exists
   - ✅ `assets/images/Biker.png` - Exists
   - ✅ `assets/images/Swimmer.png` - Exists
   - ⏳ `Vector.png` (pink star overlay) - TODO: Extract from Figma in Phase 2

6. ✅ **Verified Kyle design components available**
   - ✅ `KylePrimaryButton` - Found at `lib/shared/widgets/kyle_design/buttons/primary_button.dart`
   - ✅ `KylePlusMinusControl` - Found at `lib/shared/widgets/kyle_design/inputs/plus_minus_control.dart`
   - ✅ `KyleSegmentedControl` - Found at `lib/shared/widgets/kyle_design/buttons/segmented_control.dart`
   - ✅ `KyleActivityIcon` - Found at `lib/shared/widgets/kyle_design/icons/activity_icon.dart`
   - ✅ `SportCategorySelector` - Found at `lib/features/calendar/presentation/widgets/sport_category_selector.dart`

7. ✅ **Ran build_runner**
   - Command: `dart run build_runner build --delete-conflicting-outputs`
   - Generated: `new_activity_coordinator.g.dart`
   - Status: Success - 24 outputs written

8. ✅ **Ran flutter analyze**
   - Errors: 0 critical errors
   - Warnings: 5 info-level deprecation warnings (withOpacity - will fix in Phase 5)
   - Status: ✅ Ready for Phase 1

#### Files Created

```
lib/features/nutrition_plan/presentation/
├── screens/
│   └── new_activity_screen.dart                   (~100 lines) ✅
├── providers/
│   ├── new_activity_coordinator.dart              (~130 lines) ✅
│   └── new_activity_coordinator.g.dart            (generated)  ✅
└── widgets/new_activity/
    ├── running_tab_content.dart                   (~60 lines)  ✅
    ├── cycling_tab_content.dart                   (~60 lines)  ✅
    ├── swimming_tab_content.dart                  (~60 lines)  ✅
    └── shared/                                    (empty dir)  ✅
```

**Total New Lines**: ~410 lines of stub code

#### Next Steps

✅ Phase 0 complete! Ready to proceed to Phase 1: Coordinator Controller Implementation

**Next**: Implement the coordinator controller business logic (macro generation delegation, date/time propagation)

---

### Phase 1: Coordinator Controller (1 hour)

**File**: `lib/features/nutrition_plan/presentation/providers/new_activity_coordinator.dart`

#### Responsibilities

- Manage tab selection state (running/cycling/swimming)
- Coordinate shared state (date/time)
- Delegate to sport-specific controllers
- Handle macro generation trigger
- Manage loading states

#### Implementation

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/material.dart';

part 'new_activity_coordinator.g.dart';

enum SportTab { running, cycling, swimming }

@riverpod
class NewActivityCoordinator extends _$NewActivityCoordinator {
  @override
  NewActivityCoordinatorState build() {
    return NewActivityCoordinatorState(
      selectedTab: SportTab.running,
      selectedDate: DateTime.now(),
      selectedTime: TimeOfDay.now(),
      isGenerating: false,
    );
  }

  // Tab selection
  void selectTab(SportTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  // Shared date/time updates (propagates to all sport controllers)
  void updateDateTime(DateTime date, TimeOfDay time) {
    state = state.copyWith(selectedDate: date, selectedTime: time);

    // Propagate to all sport controllers
    ref.read(runningInputControllerProvider.notifier).updateDateTime(date, time);
    ref.read(cyclingInputControllerProvider.notifier).updateDateTime(date, time);
    ref.read(swimmingInputControllerProvider.notifier).updateDateTime(date, time);
  }

  // Generate macros for active sport
  Future<void> generateMacros() async {
    state = state.copyWith(isGenerating: true);

    try {
      final mainController = ref.read(distancePageGutEntryControllerProvider.notifier);

      switch (state.selectedTab) {
        case SportTab.running:
          await _generateRunningMacros(mainController);
          break;
        case SportTab.cycling:
          await _generateCyclingMacros(mainController);
          break;
        case SportTab.swimming:
          await _generateSwimmingMacros(mainController);
          break;
      }

      state = state.copyWith(isGenerating: false);
    } catch (e) {
      state = state.copyWith(isGenerating: false, errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> _generateRunningMacros(controller) async {
    final runningState = ref.read(runningInputControllerProvider);
    await controller.generateRunningMacros(
      distanceMiles: runningState.distance,
      paceMinutesPerMile: runningState.paceMinutes,
      scheduledDateTime: DateTime(
        runningState.selectedDate.year,
        runningState.selectedDate.month,
        runningState.selectedDate.day,
        runningState.selectedTime.hour,
        runningState.selectedTime.minute,
      ),
      timeBeforeMinutes: runningState.preRunMinutes,
      gutTraining: runningState.gutTraining,
      sweatRate: runningState.sweatRate,
      temperatureC: runningState.temperatureC,
      humidityPercent: runningState.humidityPct,
    );
  }

  Future<void> _generateCyclingMacros(controller) async {
    final cyclingState = ref.read(cyclingInputControllerProvider);
    await controller.generateCyclingMacros(
      distanceMiles: cyclingState.distance,
      speedMph: cyclingState.speedMph,
      scheduledDateTime: DateTime(
        cyclingState.selectedDate.year,
        cyclingState.selectedDate.month,
        cyclingState.selectedDate.day,
        cyclingState.selectedTime.hour,
        cyclingState.selectedTime.minute,
      ),
      timeBeforeMinutes: cyclingState.preRideMinutes,
      intensityTarget: cyclingState.intensityTarget,
      sessionGoal: cyclingState.sessionGoal,
      terrain: cyclingState.terrain,
      elevationGainFt: cyclingState.elevationGainFt,
      temperatureC: cyclingState.temperatureC,
      humidityPercent: cyclingState.humidityPct,
      windCondition: cyclingState.windCondition,
      sunExposure: cyclingState.sunExposure,
    );
  }

  Future<void> _generateSwimmingMacros(controller) async {
    final swimmingState = ref.read(swimmingInputControllerProvider);
    await controller.generateSwimmingMacros(
      distanceMeters: swimmingState.distanceMeters,
      pacePer100mSeconds: swimmingState.pacePer100mSeconds,
      scheduledDateTime: DateTime(
        swimmingState.selectedDate.year,
        swimmingState.selectedDate.month,
        swimmingState.selectedDate.day,
        swimmingState.selectedTime.hour,
        swimmingState.selectedTime.minute,
      ),
      timeBeforeMinutes: swimmingState.preSwimMinutes,
      intensityTarget: swimmingState.intensityTarget,
      sessionGoal: swimmingState.sessionGoal,
      poolOrOpenWater: swimmingState.poolOrOpenWater,
      waterTempC: swimmingState.waterTempC,
      deckTemperature: swimmingState.deckTemperature,
      deckHumidity: swimmingState.deckHumidity,
    );
  }

  // Get hero image for active tab
  String getHeroImagePath() {
    switch (state.selectedTab) {
      case SportTab.running:
        return 'assets/images/Runner.png';
      case SportTab.cycling:
        return 'assets/images/Biker.png';
      case SportTab.swimming:
        return 'assets/images/Swimmer.png';
    }
  }
}

class NewActivityCoordinatorState {
  final SportTab selectedTab;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final bool isGenerating;
  final String? errorMessage;

  NewActivityCoordinatorState({
    required this.selectedTab,
    required this.selectedDate,
    required this.selectedTime,
    required this.isGenerating,
    this.errorMessage,
  });

  NewActivityCoordinatorState copyWith({
    SportTab? selectedTab,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    bool? isGenerating,
    String? errorMessage,
  }) {
    return NewActivityCoordinatorState(
      selectedTab: selectedTab ?? this.selectedTab,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      isGenerating: isGenerating ?? this.isGenerating,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
```

#### Additional Controller Updates

**Add to existing controllers**:
- `runningInputController.updateDateTime(date, time)` method
- `cyclingInputController.updateDateTime(date, time)` method
- `swimmingInputController.updateDateTime(date, time)` method

---

### Phase 2: Tab Content Widgets (2 hours)

**Goal**: Extract sport-specific form sections into reusable tab widgets

#### File Structure

```
lib/features/nutrition_plan/presentation/widgets/new_activity/
├── running_tab_content.dart
├── cycling_tab_content.dart
├── swimming_tab_content.dart
└── shared/
    ├── date_time_display_section.dart
    └── hero_image_section.dart
```

#### Running Tab Content

**File**: `running_tab_content.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RunningTabContent extends ConsumerWidget {
  const RunningTabContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(runningInputControllerProvider);
    final controller = ref.read(runningInputControllerProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // Distance
          _buildSectionLabel('Distance'),
          const SizedBox(height: 8),
          KylePlusMinusControl(
            value: state.distance.toString(),
            onDecrement: () => controller.updateDistance(state.distance - 1.0),
            onIncrement: () => controller.updateDistance(state.distance + 1.0),
            unit: 'miles',
          ),
          const SizedBox(height: 32),

          // Average Pace
          _buildSectionLabel('Average Pace'),
          const SizedBox(height: 8),
          KylePlusMinusControl(
            value: state.paceMinutes.toStringAsFixed(2),
            onDecrement: () => controller.updatePace(state.paceMinutes - 0.25),
            onIncrement: () => controller.updatePace(state.paceMinutes + 0.25),
            unit: 'min / Mile',
          ),
          const SizedBox(height: 32),

          // Time before Run
          _buildSectionLabel('Time before Run'),
          const SizedBox(height: 8),
          KylePlusMinusControl(
            value: _formatTimeBeforeRun(state.preRunMinutes),
            onDecrement: () => controller.updatePreRunMinutes(
              (state.preRunMinutes - 15).clamp(15, 240),
            ),
            onIncrement: () => controller.updatePreRunMinutes(
              (state.preRunMinutes + 15).clamp(15, 240),
            ),
            unit: '',
            showOptimalText: true,
            optimalText: 'Optimal timing: Balanced meal with carbs and protein',
          ),
          const SizedBox(height: 32),

          // Gut Training Level
          _buildSectionLabel('Gut Training Level'),
          const SizedBox(height: 8),
          KyleGutTrainingSegmentedControl(
            selectedLevel: state.gutTraining,
            onChanged: controller.updateGutTraining,
          ),
          const SizedBox(height: 32),

          // Sweat Rate
          _buildSectionLabel('Sweat Rate'),
          const SizedBox(height: 8),
          KyleSweatRateSegmentedControl(
            selectedRate: state.sweatRate,
            onChanged: controller.updateSweatRate,
          ),
          const SizedBox(height: 32),

          // Temperature
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionLabel('Temperature'),
              TextButton.icon(
                onPressed: () {
                  // Navigate to weather detail screen
                  // TODO: Implement forecast navigation
                },
                icon: const Icon(Icons.cloud_outlined, size: 15),
                label: const Text(
                  'Forecast',
                  style: TextStyle(
                    fontFamily: 'Apercu',
                    fontSize: 10,
                    color: Color(0xFFDC2597), // Dragonfruit
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          KylePlusMinusControl(
            value: '${state.temperatureC.toInt()}°C (${_celsiusToFahrenheit(state.temperatureC)}°F)',
            onDecrement: () => controller.updateTemperature(state.temperatureC - 1.0),
            onIncrement: () => controller.updateTemperature(state.temperatureC + 1.0),
            unit: '',
          ),
          const SizedBox(height: 32),

          // Humidity
          _buildSectionLabel('Humidity'),
          const SizedBox(height: 8),
          KylePlusMinusControl(
            value: '${state.humidityPct.toInt()}% HUMIDITY',
            onDecrement: () => controller.updateHumidity(state.humidityPct - 5.0),
            onIncrement: () => controller.updateHumidity(state.humidityPct + 5.0),
            unit: '',
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Sansita',
        fontWeight: FontWeight.w700,
        fontSize: 17,
        color: Color(0xFF381633), // Blackberry
      ),
    );
  }

  String _formatTimeBeforeRun(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes (optimal)';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours hour${hours > 1 ? 's' : ''} (optimal)';
      } else {
        return '$hours:${remainingMinutes.toString().padLeft(2, '0')} hours (optimal)';
      }
    }
  }

  int _celsiusToFahrenheit(double celsius) {
    return ((celsius * 9 / 5) + 32).round();
  }
}
```

#### Cycling & Swimming Tab Content

Similar structure to Running, but with sport-specific fields:

**Cycling**: Distance, Speed, Intensity Target (dropdown), Session Goal (dropdown), Terrain (dropdown), Elevation Gain, [Collapsible Environment Section]

**Swimming**: Pool/Open Water toggle, Distance (meters), Pace per 100m, Intensity Target (dropdown), Session Goal (dropdown), Water Temperature, [Collapsible Deck Conditions]

---

### Phase 3: Main Screen Assembly (2 hours)

**File**: `lib/features/nutrition_plan/presentation/screens/new_activity_screen.dart`

#### Screen Structure

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NewActivityScreen extends ConsumerStatefulWidget {
  const NewActivityScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NewActivityScreen> createState() => _NewActivityScreenState();
}

class _NewActivityScreenState extends ConsumerState<NewActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Sync tab controller with coordinator
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final tab = SportTab.values[_tabController.index];
        ref.read(newActivityCoordinatorProvider.notifier).selectTab(tab);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coordinatorState = ref.watch(newActivityCoordinatorProvider);
    final coordinator = ref.read(newActivityCoordinatorProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6EB), // Cream
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          Column(
            children: [
              // Tab Selector (Sport Icons)
              _buildTabSelector(),

              // Hero Image (dynamic based on selected tab)
              _buildHeroImage(coordinator.getHeroImagePath()),

              // Date/Time Display
              _buildDateTimeDisplay(coordinatorState, coordinator),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    RunningTabContent(),
                    CyclingTabContent(),
                    SwimmingTabContent(),
                  ],
                ),
              ),

              // Generate Plan Button
              _buildGenerateButton(coordinatorState, coordinator),
            ],
          ),

          // Loading Overlay
          if (coordinatorState.isGenerating)
            const LoadingOverlay(message: 'Generating nutrition plan...'),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF381633).withOpacity(0.1),
          ),
          child: const Icon(
            Icons.arrow_back,
            color: Color(0xFF381633),
            size: 20,
          ),
        ),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        'New Activity',
        style: TextStyle(
          fontFamily: 'Sansita',
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: Color(0xFF381633),
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTabIcon(0, 'Running', Icons.directions_run),
          const SizedBox(width: 16),
          _buildTabIcon(1, 'Biking', Icons.directions_bike),
          const SizedBox(width: 16),
          _buildTabIcon(2, 'Swimming', Icons.pool),
        ],
      ),
    );
  }

  Widget _buildTabIcon(int index, String label, IconData icon) {
    final isSelected = _tabController.index == index;

    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: Container(
        width: 62,
        height: 74,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF381633) : Colors.transparent,
          border: Border.all(
            color: const Color(0xFF381633),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 36,
              color: isSelected
                  ? const Color(0xFFF8F6EB) // Cream
                  : const Color(0xFF381633), // Blackberry
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Compadre',
                fontSize: 8,
                color: isSelected
                    ? const Color(0xFFF8F6EB)
                    : const Color(0xFF381633),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage(String imagePath) {
    return SizedBox(
      height: 223,
      width: double.infinity,
      child: Stack(
        children: [
          // Background container
          Container(color: const Color(0xFFF8F6EB)),

          // Hero image (centered)
          Center(
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              width: 355,
            ),
          ),

          // Pink star overlay (if Vector.png is available)
          // Positioned.fill(
          //   child: Image.asset(
          //     'assets/images/Vector.png',
          //     fit: BoxFit.contain,
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildDateTimeDisplay(
    NewActivityCoordinatorState state,
    NewActivityCoordinator coordinator,
  ) {
    return Container(
      height: 95,
      color: const Color(0xFFF8F6EB),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // DATE
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'DATE',
                  style: TextStyle(
                    fontFamily: 'Compadre',
                    fontSize: 10,
                    color: Color(0xFF381633),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(state.selectedDate),
                  style: const TextStyle(
                    fontFamily: 'Sansita',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: Color(0xFF381633),
                  ),
                ),
              ],
            ),
          ),

          // Edit Button
          TextButton.icon(
            onPressed: () => _showDateTimePicker(state, coordinator),
            icon: const Icon(
              Icons.edit,
              size: 15,
              color: Color(0xFFDC2597), // Dragonfruit
            ),
            label: const Text(
              'Edit',
              style: TextStyle(
                fontFamily: 'Apercu',
                fontSize: 10,
                color: Color(0xFFDC2597),
              ),
            ),
          ),

          // TIME
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'TIME',
                  style: TextStyle(
                    fontFamily: 'Compadre',
                    fontSize: 10,
                    color: Color(0xFF381633),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(state.selectedTime),
                  style: const TextStyle(
                    fontFamily: 'Sansita',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: Color(0xFF381633),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton(
    NewActivityCoordinatorState state,
    NewActivityCoordinator coordinator,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: KylePrimaryButton(
        text: 'GENERATE PLAN',
        onPressed: state.isGenerating
            ? null
            : () async {
                try {
                  await coordinator.generateMacros();

                  // Navigate to adjust macros screen on success
                  if (mounted) {
                    context.push('/adjust-macros');
                  }
                } catch (e) {
                  // Show error snackbar
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: const Color(0xFFDC2597),
                      ),
                    );
                  }
                }
              },
        isFullWidth: true,
      ),
    );
  }

  Future<void> _showDateTimePicker(
    NewActivityCoordinatorState state,
    NewActivityCoordinator coordinator,
  ) async {
    // Show date picker
    final date = await showDatePicker(
      context: context,
      initialDate: state.selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;

    // Show time picker
    final time = await showTimePicker(
      context: context,
      initialTime: state.selectedTime,
    );

    if (time == null) return;

    // Update coordinator (propagates to all sport controllers)
    coordinator.updateDateTime(date, time);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'am' : 'pm';
    return '$hour:$minute $period';
  }
}
```

---

### Phase 4: Routing & Navigation Updates (30 minutes)

**File**: `lib/shared/core/app_router.dart`

#### Changes Needed

```dart
// ADD new route
GoRoute(
  path: '/new-activity',
  name: 'newActivity',
  builder: (context, state) => const NewActivityScreen(),
),

// DEPRECATE old routes (keep for backward compatibility temporarily)
GoRoute(
  path: '/distancepacegut',
  redirect: (context, state) => '/new-activity',
),
GoRoute(
  path: '/distance-pace-gut-entry',
  redirect: (context, state) => '/new-activity',
),
```

#### Update Navigation Calls

**Files to Update**:
1. Calendar screens → change `context.push('/distancepacegut')` to `context.push('/new-activity')`
2. Event screens → change navigation to `/new-activity`
3. Any "Create Activity" buttons → point to `/new-activity`

**Search & Replace**:
```bash
# Find all navigation calls to old routes
grep -r "distancepacegut" lib/
grep -r "distance-pace-gut-entry" lib/

# Manual update needed - verify each call site
```

---

### Phase 5: Code Generation & Cleanup (15 minutes)

#### Run Build Runner

```bash
# Generate Riverpod providers
dart run build_runner build --delete-conflicting-outputs

# Should generate:
# - new_activity_coordinator.g.dart
```

#### Verify Imports

Ensure all new files have correct imports:
- `package:flutter_riverpod/flutter_riverpod.dart`
- `package:riverpod_annotation/riverpod_annotation.dart`
- Existing controller providers
- Kyle design components

#### Run Flutter Analyze

```bash
flutter analyze

# Fix any errors or warnings
# Target: Zero warnings/errors
```

---

### Phase 6: Manual Testing (1-2 hours)

#### Testing Checklist

**Tab Switching**:
- [ ] Switch from Running → Cycling → Swimming tabs
- [ ] Verify hero image changes (Runner → Biker → Swimmer)
- [ ] Verify form state persists when switching back
- [ ] Enter values in Running tab, switch to Cycling, switch back to Running
- [ ] Confirm Running values are still there

**Date/Time Editing**:
- [ ] Tap "Edit" link
- [ ] Select new date
- [ ] Select new time
- [ ] Verify display updates correctly
- [ ] Verify date/time propagates to all sport controllers

**Running Tab**:
- [ ] Increment/decrement distance (12 miles default)
- [ ] Increment/decrement pace (9:00 min/mile default)
- [ ] Change time before run (2 hours default)
- [ ] Select gut training level (Low/Moderate/High)
- [ ] Select sweat rate (Low/Moderate/High)
- [ ] Adjust temperature (20°C default)
- [ ] Adjust humidity (60% default)
- [ ] Tap "Forecast" link (should work if weather integration ready)
- [ ] Tap "Generate Plan"
- [ ] Verify macro generation succeeds
- [ ] Verify navigation to Adjust Macros screen

**Cycling Tab**:
- [ ] Increment/decrement distance (25 miles default)
- [ ] Increment/decrement speed (15 mph default)
- [ ] Select intensity target dropdown
- [ ] Select session goal dropdown
- [ ] Select terrain dropdown
- [ ] Increment/decrement elevation gain
- [ ] Expand environment section
- [ ] Adjust temperature, humidity, wind, sun exposure
- [ ] Tap "Generate Plan"
- [ ] Verify macro generation succeeds

**Swimming Tab**:
- [ ] Toggle Pool/Open Water
- [ ] Increment/decrement distance (2000 meters default)
- [ ] Increment/decrement pace per 100m (2:00 default)
- [ ] Select intensity target dropdown
- [ ] Select session goal dropdown
- [ ] Adjust water temperature
- [ ] Expand deck conditions section
- [ ] Adjust deck temperature and humidity
- [ ] Tap "Generate Plan"
- [ ] Verify macro generation succeeds

**Loading States**:
- [ ] Tap "Generate Plan"
- [ ] Verify loading overlay appears
- [ ] Verify UI is disabled during loading
- [ ] Verify loading overlay disappears on success
- [ ] Verify loading overlay disappears on error

**Error Handling**:
- [ ] Test with invalid inputs (if validation exists)
- [ ] Test with network error (disconnect wifi)
- [ ] Verify error SnackBar displays
- [ ] Verify user can retry after error

**Navigation**:
- [ ] Tap back button → should return to previous screen
- [ ] Generate plan → should navigate to Adjust Macros
- [ ] From Adjust Macros, navigate back → should return to calendar (not New Activity)

**Theme Testing**:
- [ ] Test in light mode (Cream background)
- [ ] Test in dark mode (if implemented)
- [ ] Verify colors match Kyle's design tokens

---

## File Changes Summary

### New Files Created

```
lib/features/nutrition_plan/presentation/screens/
└── new_activity_screen.dart                         (~500 lines)

lib/features/nutrition_plan/presentation/providers/
└── new_activity_coordinator.dart                    (~200 lines)
└── new_activity_coordinator.g.dart                  (generated)

lib/features/nutrition_plan/presentation/widgets/new_activity/
├── running_tab_content.dart                         (~200 lines)
├── cycling_tab_content.dart                         (~250 lines)
├── swimming_tab_content.dart                        (~250 lines)
└── shared/
    ├── date_time_display_section.dart               (~100 lines)
    └── hero_image_section.dart                      (~80 lines)
```

**Total New Code**: ~1,580 lines

### Files Modified

```
lib/shared/core/app_router.dart                      (add route + redirects)
lib/features/nutrition_plan/presentation/providers/
├── running_input_controller.dart                    (add updateDateTime method)
├── cycling_input_controller.dart                    (add updateDateTime method)
└── swimming_input_controller.dart                   (add updateDateTime method)

Various navigation call sites:
├── lib/features/calendar/...
├── lib/features/events/...
└── lib/features/activities/...
```

### Files Deprecated (DO NOT DELETE YET)

```
lib/features/nutrition_plan/presentation/screens/
├── distance_pace_gut_entry_screen.dart              (redirect only)
├── cycling_input_screen.dart                        (keep for reference)
└── swimming_input_screen.dart                       (keep for reference)
```

**Deletion Timeline**: After 1 week of successful production usage

---

## Risk Mitigation

### High-Risk Areas

1. **Tab State Persistence**
   - **Risk**: State loss when switching tabs
   - **Mitigation**: Use `@Riverpod(keepAlive: true)` + `IndexedStack` in TabBarView
   - **Testing**: Manual verification of state preservation

2. **Date/Time Propagation**
   - **Risk**: Date/time not syncing to all sport controllers
   - **Mitigation**: Coordinator explicitly calls all three controllers
   - **Testing**: Log date/time in each controller, verify consistency

3. **Macro Generation Flow**
   - **Risk**: Breaking existing nutrition plan generation
   - **Mitigation**: Reuse existing controller methods exactly as-is
   - **Testing**: Generate plans for all three sports, compare with old screens

4. **Navigation Regression**
   - **Risk**: Breaking existing deep links or navigation flows
   - **Mitigation**: Keep old routes as redirects temporarily
   - **Testing**: Test all entry points (calendar, events, home)

### Rollback Plan

If critical issues arise:

1. **Quick Rollback**:
   - Remove redirect from old routes
   - Update navigation calls to point back to old screens
   - New screen remains but unused
   - Time to rollback: <10 minutes

2. **Partial Rollback**:
   - Keep new screen for one sport (Running)
   - Redirect Cycling/Swimming to old screens
   - Iterate on new screen until stable

---

## Success Criteria

### Definition of Done

- ✅ All three sport tabs functional and tested
- ✅ Tab switching preserves form state
- ✅ Hero image changes dynamically per sport
- ✅ Date/time editing works and propagates
- ✅ Macro generation succeeds for all sports
- ✅ Navigation flows work correctly
- ✅ Zero Flutter analyze warnings/errors
- ✅ Visual design matches Figma mockups
- ✅ Old routes redirect to new screen
- ✅ Manual testing checklist 100% complete

### Performance Benchmarks

- First paint: <1 second
- Tab switch animation: 60fps, <300ms
- Date/time picker open: <200ms
- Macro generation time: Same as old screens

### Visual Accuracy

- Hero image aspect ratio: Exact match
- Tab icons size: 62×74px (Figma spec)
- Date/time display: Sansita Bold 20px
- Plus/minus controls: 36×36px with 2px Orange border
- Segmented controls: 15px border radius, Blackberry fill when selected
- Generate button: 196px width, 100px border radius, Orange background

---

## Timeline & Effort Estimate

### Detailed Breakdown

| Phase | Description | Estimated Time | Status |
|-------|-------------|----------------|--------|
| **Phase 0** | Setup & file structure | 45 min | ✅ Complete |
| **Phase 1** | Coordinator controller | 1 hour | 🔄 Next |
| **Phase 2** | Tab content widgets | 2 hours | ⏳ Not started |
| **Phase 3** | Main screen assembly | 2 hours | ⏳ Not started |
| **Phase 4** | Routing updates | 30 min | ⏳ Not started |
| **Phase 5** | Code generation & cleanup | 15 min | ⏳ Not started |
| **Phase 6** | Manual testing | 1-2 hours | ⏳ Not started |
| **Buffer** | Bug fixes & polish | 1 hour | ⏳ Not started |

**Total Estimated Time**: 8-10 hours (~1-1.5 days for experienced developer)

### Critical Path

```
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
  ↓         ↓          ↓          ↓         ↓         ↓         ↓
 30min    1hr        2hr        2hr      30min     15min    1-2hr
```

**Earliest Completion**: 1 business day (with focus)
**Realistic Completion**: 2-3 business days (with other tasks)

---

## Next Steps

### Immediate Actions (Today)

1. **Phase 0**: Create file structure and stub components (30 min)
2. **Phase 1**: Implement coordinator controller (1 hour)
3. **Phase 2**: Build Running tab content (1 hour)

### Tomorrow

4. **Phase 2**: Build Cycling + Swimming tab content (2 hours)
5. **Phase 3**: Assemble main screen (2 hours)
6. **Phase 4-5**: Routing + code generation (45 min)

### Day After

7. **Phase 6**: Comprehensive manual testing (2 hours)
8. **Polish**: Fix any issues discovered (1 hour)
9. **Deploy**: Push to develop branch

---

## Additional Resources

### Figma Design Links

- **New Activity (Light)**: https://www.figma.com/design/4FvaeGejofuETyP5LUIxQK/Kyle-s-Mockups?node-id=1-1571
- **New Activity (Dark)**: https://www.figma.com/design/4FvaeGejofuETyP5LUIxQK/Kyle-s-Mockups?node-id=1-1664

### Code References

- **Existing Controllers**: `/lib/features/nutrition_plan/presentation/providers/`
- **Kyle Design System**: `/lib/shared/widgets/kyle_design/`
- **Design Tokens**: `/docs/kyle/DESIGN_TOKENS.md`
- **Component Catalog**: `/docs/kyle/COMPONENTS_CATALOG.md`

### Related Documentation

- **FOA Architecture**: `/docs/technical/foa-architecture.md`
- **Andrea Bizzotto Patterns**: `/docs/technical/andrea/`
- **Current Activity Research**: This document's research section

---

## Appendix A: Component Mapping

### Kyle Design Components Needed

| Component | File Path | Status |
|-----------|-----------|--------|
| `KylePrimaryButton` | `/lib/shared/widgets/kyle_design/buttons/primary_button.dart` | ✅ Available |
| `KylePlusMinusControl` | `/lib/shared/widgets/kyle_design/inputs/plus_minus_control.dart` | ✅ Available |
| `KyleSegmentedControl` | `/lib/shared/widgets/kyle_design/buttons/segmented_control.dart` | ✅ Available |
| `KyleGutTrainingSegmentedControl` | Custom widget (already exists) | ✅ Available |
| `KyleSweatRateSegmentedControl` | Custom widget (already exists) | ✅ Available |
| `KyleActivityTypeSelectorIcon` | `/lib/shared/widgets/kyle_design/icons/activity_icon.dart` | ✅ Available |
| `LoadingOverlay` | `/lib/shared/widgets/loading_overlay.dart` | ✅ Available |

### Standard Flutter Widgets Used

- `TabController` / `TabBar` / `TabBarView`
- `SingleChildScrollView`
- `showDatePicker` / `showTimePicker`
- `DropdownButton` (for cycling/swimming intensity/session)
- `IconButton` / `TextButton`
- `SnackBar` (for error messages)

---

## Appendix B: FAQs

### Q: Why not merge all three controllers into one?
**A**: The existing controllers are well-tested and sport-specific logic is cleanly separated. A coordinator pattern preserves this separation while adding tab coordination.

### Q: What if I need to add a new sport type in the future?
**A**: Add a new tab, create a new sport-specific controller, add to `SportTab` enum, update coordinator switch statements. Estimated 2-3 hours.

### Q: Can I test this on staging before production?
**A**: Yes, deploy to `develop` branch first, which auto-deploys to staging environment. Test thoroughly before merging to `main`.

### Q: What if weather integration breaks?
**A**: Weather is optional. The screen will work without weather data (users can manually enter temp/humidity). Weather errors are logged but don't block plan generation.

### Q: Do I need to update analytics tracking?
**A**: No. Analytics tracking is in the existing controllers (distance_page_gut_entry_controller), which are reused. Same events fire with same parameters.

---

## Document Metadata

**Created**: 2025-11-13
**Author**: Claude (AI Assistant)
**Reviewed By**: Lee Martin (Pending)
**Status**: Draft → Ready for Implementation
**Version**: 1.0
**Priority**: P0 - Critical
**Estimated Effort**: 8-10 hours (1-1.5 days)

---

**Ready to start implementation?** Begin with Phase 0 and work sequentially through the phases. Reach out if you encounter any blockers or need clarification on any section.

🚀 **Let's build this!**
