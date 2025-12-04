# Onboarding Revamp - Implementation Roadmap

## Overview

This document outlines the complete redesign of the Mealvana Endurance onboarding flow based on Figma designs. The goal is to convert onboarding from a questionnaire-style experience into a supported journey that reduces friction and drop-off rates.

**Figma File**: [Endurance - Figma](https://www.figma.com/design/eA4HqttH0XBdJk0kSfcIWe/Endurance---Figma)

**Key Design Principles**:
- Reduce cognitive load by breaking up complex screens
- Use chip-based selection for faster interaction (Fitts's Law)
- Provide clear progress visibility (Nielsen Norman's "Visibility of System Status")
- Enable swipe navigation between screens
- Use first-person language ("I run with a water bottle") for user agency

---

## Design Decisions Summary

| Decision | Choice |
|----------|--------|
| Progress Bar Segments | 4 segments: Profile → Sports → Sport Details → Food |
| Sport Detail Screens | Conditional separate screens per selected sport |
| Food Preferences Default | All unselected foods = Neutral (willing_to_try) |
| Navigation | Swipe + buttons (back at bottom left, continue at bottom right) |
| Water Bottle Toggle | Moved from Profile to Running Details |
| Stomach Sensitivity | Separate screen after sport details |
| Typography | Keep Compadre (headings) + Apercu (body) |
| Color Opacity | Use `.withOpacity()` modifiers, not new named colors |
| Progress Within Segment | Full segment fill per screen (no partial fills) |
| Auth Flow | Keep auth after food preferences (unchanged) |
| Welcome Screen | Skip for now, focus on core onboarding |

---

## New Onboarding Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        ONBOARDING FLOW                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  [Welcome Screen] - unchanged for now                                │
│         │                                                            │
│         ▼                                                            │
│  ┌──────────────────┐  Segment 1                                    │
│  │  User Profile    │  ████████░░░░░░░░░░░░░░░░░░░░░░               │
│  │  - Gender        │                                                │
│  │  - Birthday      │                                                │
│  │  - Height        │                                                │
│  │  - Weight        │                                                │
│  └────────┬─────────┘                                                │
│           │                                                          │
│           ▼                                                          │
│  ┌──────────────────┐  Segment 2                                    │
│  │ Sports Selection │  ████████████████░░░░░░░░░░░░░░               │
│  │  □ Running       │                                                │
│  │  □ Cycling       │                                                │
│  │  □ Swimming      │                                                │
│  └────────┬─────────┘                                                │
│           │                                                          │
│           ▼ (conditional based on sports selected)                   │
│  ┌──────────────────┐  Segment 3 (fills as screens complete)        │
│  │ Running Details  │  ████████████████████████░░░░░░               │
│  │  - Water bottle  │                                                │
│  └────────┬─────────┘                                                │
│           │ (if cycling selected)                                    │
│           ▼                                                          │
│  ┌──────────────────┐                                                │
│  │ Cycling Details  │  ████████████████████████░░░░░░               │
│  │  - FTP           │                                                │
│  │  - Water bottles │                                                │
│  │  - Aero bottles  │                                                │
│  │  - Bento box     │                                                │
│  └────────┬─────────┘                                                │
│           │ (if swimming selected)                                   │
│           ▼                                                          │
│  ┌──────────────────┐                                                │
│  │ Swimming Details │  ████████████████████████░░░░░░               │
│  │  - CSS           │                                                │
│  │  - Wetsuit       │                                                │
│  │  - Swim cap type │                                                │
│  └────────┬─────────┘                                                │
│           │                                                          │
│           ▼                                                          │
│  ┌──────────────────┐                                                │
│  │Stomach Sensitivity│ ████████████████████████░░░░░░               │
│  │  □ Sensitive      │                                               │
│  └────────┬─────────┘                                                │
│           │                                                          │
│           ▼                                                          │
│  ┌──────────────────┐  Segment 4                                    │
│  │ Food Preferences │  ████████████████████████████████             │
│  │  - Chip selection│                                                │
│  │  - Search bar    │                                                │
│  │  - NO barcode    │                                                │
│  └────────┬─────────┘                                                │
│           │                                                          │
│           ▼                                                          │
│  [Post-Onboarding Auth] - unchanged                                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Color Specifications

### Primary Colors (existing in theme)
| Color | Hex | Usage |
|-------|-----|-------|
| Blackberry | `#421D48` | Background |
| Orange | `#F78B14` | Primary CTA, headers, progress bar active |
| Cream | `#F8F6EB` | Body text, icons |
| Electrolyte | `#1CF9CF` | Selected states (teal) |

### Opacity Modifiers (use `.withOpacity()`)
| Usage | Opacity | Example |
|-------|---------|---------|
| Selected chip/card background | 28% | `AppColors.electrolyte.withOpacity(0.28)` |
| Selected chip/card border | 20-40% | `AppColors.electrolyte.withOpacity(0.2)` |
| Unselected background | 8% | `AppColors.cream.withOpacity(0.08)` |
| Unselected chip background | 10% | `AppColors.cream.withOpacity(0.1)` |
| Back button background | 20% | `AppColors.orange.withOpacity(0.2)` |
| Inactive progress segment | 8% | `AppColors.cream.withOpacity(0.08)` |

---

## Component Specifications

### 1. Progress Bar Widget

**File**: `lib/features/onboarding/presentation/widgets/onboarding_progress_bar.dart`

```dart
/// Onboarding progress bar with 4 segments
///
/// Segment 1: User Profile
/// Segment 2: Sports Selection
/// Segment 3: Sport Details + Stomach Sensitivity
/// Segment 4: Food Preferences
class OnboardingProgressBar extends StatelessWidget {
  final int currentSegment; // 1-4
  final int totalSegments; // Always 4

  // Specifications:
  // - Height: 8px per segment
  // - Border radius: 4px
  // - Gap between segments: 8px
  // - Horizontal padding: 20px
  // - Active color: AppColors.orange
  // - Inactive color: AppColors.cream.withOpacity(0.08)
}
```

### 2. Navigation Footer Widget

**File**: `lib/features/onboarding/presentation/widgets/onboarding_navigation_footer.dart`

```dart
/// Bottom navigation with back button and continue button
///
/// Back Button:
/// - Size: 48x48px
/// - Border radius: 28px (fully rounded)
/// - Background: AppColors.orange.withOpacity(0.2)
/// - Icon: Arrow back, 28x28px, orange color
///
/// Continue Button:
/// - Height: 48px
/// - Flex: 1 (takes remaining width)
/// - Border radius: 28px
/// - Background: AppColors.orange (solid)
/// - Text: Compadre Bold, 16px, Blackberry color
///
/// Gap between buttons: 12px
/// Padding: 20px all sides
class OnboardingNavigationFooter extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback onContinue;
  final String continueText;
  final bool showBackButton;
}
```

### 3. Selectable Card Widget

**File**: `lib/features/onboarding/presentation/widgets/selectable_card.dart`

```dart
/// Card for checkbox-style selection (sports, stomach sensitivity)
///
/// Unselected:
/// - Background: AppColors.cream.withOpacity(0.08)
/// - Border: 1px solid AppColors.cream.withOpacity(0.08)
/// - Border radius: 16px
/// - Icon: Empty checkbox outline
///
/// Selected:
/// - Background: AppColors.electrolyte.withOpacity(0.28)
/// - Border: 1px solid AppColors.electrolyte.withOpacity(0.2)
/// - Border radius: 16px
/// - Icon: Filled checkmark (electrolyte color)
///
/// Padding: 16px
/// Gap between checkbox and label: 12px
/// Label: Apercu Medium, 20px, cream color
class SelectableCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
}
```

### 4. Food Chip Widget

**File**: `lib/features/onboarding/presentation/widgets/food_chip.dart`

```dart
/// Chip for food selection in onboarding
///
/// Unselected (Neutral):
/// - Background: AppColors.cream.withOpacity(0.1)
/// - Border: 1px solid AppColors.cream.withOpacity(0.08)
/// - Border radius: 12px
/// - Height: 40px
/// - No X icon
///
/// Selected (Liked):
/// - Background: AppColors.electrolyte.withOpacity(0.28)
/// - Border: 2px solid AppColors.electrolyte.withOpacity(0.4)
/// - Border radius: 12px
/// - Height: 40px
/// - X icon: 12x12px (for removal)
///
/// Padding: 12px horizontal
/// Text: Apercu Regular, 16px, cream color
class FoodChip extends StatelessWidget {
  final String foodName;
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback? onRemove; // Only shown when liked
}
```

### 5. Toggle Card Widget

**File**: `lib/features/onboarding/presentation/widgets/toggle_card.dart`

```dart
/// Card with label and toggle switch
///
/// Container:
/// - Background: AppColors.cream.withOpacity(0.08)
/// - Border: 1px solid AppColors.cream.withOpacity(0.08)
/// - Border radius: 16px
/// - Padding: 16px horizontal, 4px vertical
///
/// Label: Apercu Regular, 20px, cream color
/// Toggle: 48x48px, electrolyte when on
class ToggleCard extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
}
```

### 6. Segmented Selector Widget

**File**: `lib/features/onboarding/presentation/widgets/segmented_selector.dart`

```dart
/// Horizontal segmented control for single selection
/// Used for: Water bottles count (1, 2, 3+)
///
/// Each segment follows SelectableCard styling
/// Gap between segments: 12px
class SegmentedSelector<T> extends StatelessWidget {
  final List<T> options;
  final T selectedValue;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;
}
```

### 7. Radio Option Card Widget

**File**: `lib/features/onboarding/presentation/widgets/radio_option_card.dart`

```dart
/// Radio button style card for single selection from list
/// Used for: Swim cap type (None, Latex, Silicone, Neoprene)
///
/// Follows SelectableCard styling but with radio icon instead of checkbox
class RadioOptionCard<T> extends StatelessWidget {
  final T value;
  final T groupValue;
  final String label;
  final ValueChanged<T> onChanged;
}
```

---

## Screen Implementation Details

### Screen 1: User Profile (Updated)

**File**: `lib/features/onboarding/presentation/screens/user_profile_screen.dart`

**Changes from current**:
- Add progress bar (segment 1 of 4)
- Add swipe navigation support
- Update navigation footer to new design
- Remove water bottle toggle (moved to Running Details)
- Apply new color scheme to inputs

**Data collected**:
- Gender (Male/Female/Non-binary)
- Birthday
- Height (feet + inches)
- Weight (pounds)

### Screen 2: Sports Selection (New Design)

**File**: `lib/features/onboarding/presentation/screens/sports_selection_screen.dart`

**Replaces**: Current sport_preferences_screen.dart (initial part)

**Design from Figma**: Node 24:147

**Layout**:
```
[Progress Bar - Segment 2]
[Title: "Which sports do you train for?"]
[Description: "We'll customize your nutrition plans for each sport."]
[SelectableCard: Running]
[SelectableCard: Cycling]
[SelectableCard: Swimming]
[Navigation Footer]
```

**Data collected**:
- Set<Sport> selectedSports

**Navigation**:
- Back → User Profile
- Continue → First sport details screen (based on selection order: Running → Cycling → Swimming)

### Screen 3a: Running Details (New Screen)

**File**: `lib/features/onboarding/presentation/screens/running_details_screen.dart`

**Design from Figma**: Node 24:122

**Layout**:
```
[Progress Bar - Segment 3]
[Title: "Running details"]
[Description: "Help us estimate your hydration needs."]
[ToggleCard: "I run with a water bottle"]
[Navigation Footer]
```

**Data collected**:
- bool runsWithWaterBottle

**Navigation**:
- Back → Sports Selection
- Continue → Cycling Details (if selected) OR Swimming Details (if selected) OR Stomach Sensitivity

### Screen 3b: Cycling Details (New Screen)

**File**: `lib/features/onboarding/presentation/screens/cycling_details_screen.dart`

**Design from Figma**: Node 24:183

**Layout**:
```
[Progress Bar - Segment 3]
[Title: "Cycling details"]
[Section: FTP (Functional Threshold Power)]
  [Helper text]
  [Input field with "watts" suffix]
[Section: "How many water bottles do you use?"]
  [SegmentedSelector: 1 | 2 | 3+]
[ToggleCard: "I use Aero Bottles"]
[ToggleCard: "I use a Bento Box for food"]
[Navigation Footer]
```

**Data collected**:
- int? ftpWatts (nullable, 0 = unknown)
- int waterBottlesCount (1, 2, or 3)
- bool usesAeroBottles
- bool usesBentoBox

**Navigation**:
- Back → Running Details (if selected) OR Sports Selection
- Continue → Swimming Details (if selected) OR Stomach Sensitivity

### Screen 3c: Swimming Details (New Screen)

**File**: `lib/features/onboarding/presentation/screens/swimming_details_screen.dart`

**Design from Figma**: Node 24:229

**Layout**:
```
[Progress Bar - Segment 3]
[Title: "Swimming details"]
[Section: CSS (Critical Swim Speed)]
  [Helper text: "Fastest pace per 100 meters you can sustain for 30 minutes. MM:SS format"]
  [Two inputs: minutes : seconds]
[ToggleCard: "I typically wear a wetsuit"]
[Section: "Swim Cap Type"]
  [RadioOptionCard: None]
  [RadioOptionCard: Latex]
  [RadioOptionCard: Silicone]
  [RadioOptionCard: Neoprene]
[Navigation Footer]
```

**Data collected**:
- int? cssMinutes
- int? cssSeconds
- bool wearsWetsuit
- SwimCapType swimCapType (none, latex, silicone, neoprene)

**Navigation**:
- Back → Cycling Details (if selected) OR Running Details (if selected) OR Sports Selection
- Continue → Stomach Sensitivity

### Screen 3d: Stomach Sensitivity (New Screen)

**File**: `lib/features/onboarding/presentation/screens/stomach_sensitivity_screen.dart`

**Design from Figma**: Node 24:302

**Layout**:
```
[Progress Bar - Segment 3]
[Title: "Stomach sensitivity"]
[Description: "Help us recommend easier-to-digest foods"]
[SelectableCard: "I have a sensitive stomach during exercise"]
[Navigation Footer]
```

**Data collected**:
- bool hasSensitiveStomach

**Navigation**:
- Back → Last sport details screen
- Continue → Food Preferences

### Screen 4: Food Preferences (New Design)

**File**: `lib/features/onboarding/presentation/screens/onboarding_food_preferences_screen.dart`

**Design from Figma**: Node 24:337

**Replaces**: Current food_preferences_screen.dart behavior for onboarding only

**Layout**:
```
[Progress Bar - Segment 4]
[Title: "What foods fuel your training?"]
[Description: "Add the foods you use during training and recovery. You can edit these later in settings."]
[Search Bar (no barcode scanner)]
[Selected Foods Section - chips with X buttons]
[Section: "Common foods"]
  [Wrap of FoodChips]
[Navigation Footer]
```

**Key Changes from Current**:
1. **Remove 5-point slider** → Replace with simple tap-to-like chips
2. **Remove barcode scanner** → Only search bar
3. **All foods default to Neutral** → Only show liked chips in selected section
4. **Chip-based UI** → Instead of list with sliders

**Data collected**:
- Set<Food> likedFoods (only liked foods saved, rest remain neutral)

**Navigation**:
- Back → Stomach Sensitivity
- Continue → Post-Onboarding Auth

---

## Implementation Phases

### Phase 1: Foundation (Estimated: 1-2 sessions)

1. **Create shared widgets**:
   - [ ] `OnboardingProgressBar`
   - [ ] `OnboardingNavigationFooter`
   - [ ] `SelectableCard`
   - [ ] `ToggleCard`
   - [ ] `FoodChip`
   - [ ] `SegmentedSelector`
   - [ ] `RadioOptionCard`

2. **Update theme constants**:
   - [ ] Verify color hex values match Figma
   - [ ] Add any missing spacing constants
   - [ ] Document opacity usage patterns

3. **Create PageView wrapper**:
   - [ ] `OnboardingPageView` widget for swipe navigation
   - [ ] Handle dynamic page count based on selected sports

### Phase 2: Screen Implementation (Estimated: 2-3 sessions)

4. **Update User Profile screen**:
   - [ ] Add progress bar
   - [ ] Update navigation footer
   - [ ] Remove water bottle toggle
   - [ ] Apply new styling

5. **Create Sports Selection screen**:
   - [ ] New screen file
   - [ ] Multi-select sports logic
   - [ ] New controller for onboarding flow state

6. **Create sport detail screens**:
   - [ ] Running Details screen
   - [ ] Cycling Details screen
   - [ ] Swimming Details screen
   - [ ] Stomach Sensitivity screen

7. **Create new Food Preferences screen**:
   - [ ] Chip-based selection UI
   - [ ] Search functionality (no barcode)
   - [ ] "Common foods" section
   - [ ] Selected chips display with removal

### Phase 3: Navigation & State (Estimated: 1-2 sessions)

8. **Update routing**:
   - [ ] Add new routes for each screen
   - [ ] Implement conditional navigation based on selected sports
   - [ ] Handle back navigation through dynamic flow

9. **Update controllers**:
   - [ ] Create/update `OnboardingFlowController` for overall state
   - [ ] Track selected sports for conditional screens
   - [ ] Manage progress bar state

10. **Data persistence**:
    - [ ] Update Drift tables if needed for new fields
    - [ ] Ensure all data saves correctly
    - [ ] Handle neutral food preferences (no record = neutral)

### Phase 4: Polish & Testing (Estimated: 1 session)

11. **Animations & interactions**:
    - [ ] Swipe gestures between screens
    - [ ] Chip selection animations
    - [ ] Progress bar transitions

12. **Testing**:
    - [ ] Unit tests for controllers
    - [ ] Widget tests for new components
    - [ ] Integration test for full onboarding flow

13. **Cleanup**:
    - [ ] Remove old sport_preferences_screen.dart
    - [ ] Update old food_preferences_screen.dart (keep for Settings)
    - [ ] Remove unused code

---

## Files to Create

```
lib/features/onboarding/presentation/
├── widgets/
│   ├── onboarding_progress_bar.dart          (NEW)
│   ├── onboarding_navigation_footer.dart     (NEW)
│   ├── selectable_card.dart                  (NEW)
│   ├── toggle_card.dart                      (NEW)
│   ├── food_chip.dart                        (NEW)
│   ├── segmented_selector.dart               (NEW)
│   └── radio_option_card.dart                (NEW)
├── screens/
│   ├── user_profile_screen.dart              (UPDATE)
│   ├── sports_selection_screen.dart          (NEW - replaces sport_preferences_screen.dart)
│   ├── running_details_screen.dart           (NEW)
│   ├── cycling_details_screen.dart           (NEW)
│   ├── swimming_details_screen.dart          (NEW)
│   ├── stomach_sensitivity_screen.dart       (NEW)
│   └── onboarding_food_preferences_screen.dart (NEW - separate from settings version)
└── providers/
    ├── onboarding_controller.dart            (UPDATE)
    └── onboarding_flow_controller.dart       (NEW - manages flow state)
```

## Files to Update

```
lib/shared/core/app_router.dart               (UPDATE - new routes)
lib/theme/kyle_design/app_colors.dart         (VERIFY - hex values)
```

## Files to Eventually Remove

```
lib/features/onboarding/presentation/screens/sport_preferences_screen.dart (REMOVE after migration)
```

---

## Database Considerations

### Current Schema Support
The current schema already supports cycling and swimming fields in the `users` table:
- `ftp_watts`
- `water_bottles_count` (for cycling)
- `uses_aero_bottles`
- `uses_bento_box`
- `css_minutes`, `css_seconds`
- `wears_wetsuit`
- `swim_cap_type`
- `has_sensitive_stomach` (currently `gi_sensitivity`)

### Food Preferences
Current model:
```dart
enum FoodPreference {
  like,
  dislike,
  willingToTry; // This is NEUTRAL
}
```

New behavior for onboarding:
- Tapped chip → `like`
- Not tapped → No preference record (treated as `willingToTry`/neutral)
- Settings screen keeps full like/dislike/neutral functionality

---

## Content Management Integration

All text must come from ContentService. Add these keys to `content_defaults.json`:

```json
{
  "ui_text": {
    "onboarding": {
      "progress": {
        "step_1": "Profile",
        "step_2": "Sports",
        "step_3": "Details",
        "step_4": "Food"
      },
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
      "stomach_sensitivity": {
        "title": "Stomach sensitivity",
        "description": "Help us recommend easier-to-digest foods",
        "sensitive_stomach": "I have a sensitive stomach during exercise"
      },
      "food_preferences": {
        "title": "What foods fuel your training?",
        "description": "Add the foods you use during training and recovery. You can edit these later in settings.",
        "search_placeholder": "Search",
        "common_foods_header": "Common foods"
      },
      "navigation": {
        "continue": "Continue",
        "back": "Back"
      }
    }
  }
}
```

---

## Testing Checklist

### Unit Tests
- [ ] Progress bar calculates correct segment
- [ ] Sports selection state management
- [ ] Conditional screen flow logic
- [ ] Food chip selection/deselection

### Widget Tests
- [ ] Each new widget renders correctly
- [ ] Selection states toggle properly
- [ ] Navigation footer callbacks work

### Integration Tests
- [ ] Complete onboarding flow (all sports selected)
- [ ] Onboarding flow (single sport)
- [ ] Data persists through entire flow
- [ ] Back navigation works correctly
- [ ] Swipe navigation works

### Manual Testing
- [ ] Visual match to Figma designs
- [ ] Animations feel smooth
- [ ] Touch targets adequate size
- [ ] Keyboard handling for inputs
- [ ] Accessibility (screen reader)

---

## Open Questions

1. **Common Foods List**: What foods should appear in the "Common foods" section on the Food Preferences screen? Need to define the default list.

2. **Search Integration**: Should food search still use OpenFoodFacts, or should we limit to predefined foods?

3. **Analytics Events**: What events should we track for the new screens?

4. **A/B Testing**: Should we keep the old flow accessible for comparison testing?

---

## References

- [Figma: Food Preferences Screen](https://www.figma.com/design/eA4HqttH0XBdJk0kSfcIWe/Endurance---Figma?node-id=24-337)
- [Figma: Sports Selection Screen](https://www.figma.com/design/eA4HqttH0XBdJk0kSfcIWe/Endurance---Figma?node-id=24-147)
- [Figma: Running Details Screen](https://www.figma.com/design/eA4HqttH0XBdJk0kSfcIWe/Endurance---Figma?node-id=24-122)
- [Figma: Cycling Details Screen](https://www.figma.com/design/eA4HqttH0XBdJk0kSfcIWe/Endurance---Figma?node-id=24-183)
- [Figma: Swimming Details Screen](https://www.figma.com/design/eA4HqttH0XBdJk0kSfcIWe/Endurance---Figma?node-id=24-229)
- [Figma: Stomach Sensitivity Screen](https://www.figma.com/design/eA4HqttH0XBdJk0kSfcIWe/Endurance---Figma?node-id=24-302)
