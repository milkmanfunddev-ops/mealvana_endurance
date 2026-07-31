# Onboarding Revamp - Design Specifications

This document contains detailed design specifications extracted from the Figma designs for pixel-perfect implementation.

---

## Color Reference

### Using Colors in Code

```dart
// DO: Use opacity modifiers
AppColors.electrolyte.withOpacity(0.28)  // Selected background
AppColors.cream.withOpacity(0.08)         // Unselected background

// DON'T: Create new named color constants for every opacity variant
```

### Complete Color Usage Table

| Element | State | Background | Border | Text/Icon |
|---------|-------|------------|--------|-----------|
| **Screen** | - | `#421D48` (blackberry) | - | - |
| **Progress segment** | Active | `#F78B14` (orange) | - | - |
| **Progress segment** | Inactive | cream @ 8% | - | - |
| **Selectable card** | Unselected | cream @ 8% | cream @ 8%, 1px | cream |
| **Selectable card** | Selected | electrolyte @ 28% | electrolyte @ 20%, 1px | cream |
| **Food chip** | Unselected | cream @ 10% | cream @ 8%, 1px | cream |
| **Food chip** | Selected | electrolyte @ 28% | electrolyte @ 40%, 2px | cream |
| **Toggle switch** | Off | gray | - | - |
| **Toggle switch** | On | electrolyte | - | - |
| **Back button** | Normal | orange @ 20% | - | orange |
| **Continue button** | Normal | orange | - | blackberry |
| **Input field** | Normal | cream @ 8% | cream @ 8%, 1px | cream |
| **Search bar** | Normal | cream @ 8% | cream @ 8%, 1px | cream |

---

## Typography

### Font Mapping

| Figma Font | App Font | Usage |
|------------|----------|-------|
| Sansita Bold | Compadre Bold | Headings, button text |
| Inter Regular | Apercu Regular | Body text, descriptions |
| Inter Medium | Apercu Medium | Section headers, option labels |

### Text Styles

```dart
// Screen Title (e.g., "Which sports do you train for?")
TextStyle(
  fontFamily: 'Compadre',
  fontWeight: FontWeight.bold,
  fontSize: 26,
  color: AppColors.orange,
)

// Description Text
TextStyle(
  fontFamily: 'Apercu',
  fontWeight: FontWeight.w400,
  fontSize: 16,
  letterSpacing: 0.192, // 1.2%
  color: AppColors.cream,
)

// Section Header (e.g., "Common foods")
TextStyle(
  fontFamily: 'Apercu',
  fontWeight: FontWeight.w500,
  fontSize: 20,
  letterSpacing: 0.24, // 1.2%
  color: AppColors.cream,
)

// Option Label (e.g., "Running", "I run with a water bottle")
TextStyle(
  fontFamily: 'Apercu',
  fontWeight: FontWeight.w500, // or w400 for toggles
  fontSize: 20,
  letterSpacing: 0.24,
  color: AppColors.cream,
)

// Chip Text
TextStyle(
  fontFamily: 'Apercu',
  fontWeight: FontWeight.w400,
  fontSize: 16,
  letterSpacing: 0.192,
  color: AppColors.cream,
)

// Button Text
TextStyle(
  fontFamily: 'Compadre',
  fontWeight: FontWeight.bold,
  fontSize: 16,
  letterSpacing: 0.192,
  color: AppColors.blackberry, // for continue button
)
```

---

## Spacing System

### Global Spacing

| Element | Value |
|---------|-------|
| Screen horizontal padding | 20px |
| Screen top padding (below progress bar) | 48px |
| Progress bar height | 8px |
| Progress bar segment gap | 8px |
| Section gap (major) | 28-29px |
| Title to description gap | 12px |
| Description to content gap | 12-16px |
| Navigation footer padding | 20px all sides |
| Navigation button gap | 12px |

### Component-Specific Spacing

**Selectable Card / Toggle Card**:
- Padding: 16px (all sides for card), 16px horizontal + 4px vertical (for toggle)
- Border radius: 16px
- Gap between checkbox/toggle and label: 12px
- Gap between cards: 12px

**Food Chip**:
- Height: 40px
- Horizontal padding: 12px
- Border radius: 12px
- Wrap gap: 8px (horizontal and vertical)
- Gap between text and X icon: 8px

**Segmented Selector**:
- Segment padding: 16px
- Border radius: 16px
- Gap between segments: 12px

**Input Field**:
- Padding: 16px
- Border radius: 16px

**Search Bar**:
- Padding: 12px vertical, 16px horizontal
- Border radius: 26px (fully rounded)
- Icon size: 24x24px
- Gap between icon and text: 12px

**Back Button**:
- Size: 48x48px
- Border radius: 28px
- Icon size: 28x28px
- Padding: 12px (centers icon)

**Continue Button**:
- Height: 48px
- Border radius: 28px
- Horizontal padding: 16px
- Vertical padding: 12px

---

## Progress Bar Specifications

### Structure

```
┌─────────────────────────────────────────────────────────────────┐
│ [Segment 1] gap [Segment 2] gap [Segment 3] gap [Segment 4]    │
│    flex:1    8px   flex:1    8px   flex:1    8px   flex:1      │
└─────────────────────────────────────────────────────────────────┘
```

### Segment States

Each segment can be:
1. **Complete**: Fully filled with orange
2. **Current**: Active segment (filled with orange)
3. **Incomplete**: Cream @ 8% opacity

### Implementation

```dart
Widget _buildProgressBar(int currentSegment) {
  return Padding(
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        for (int i = 1; i <= 4; i++) ...[
          if (i > 1) const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: i <= currentSegment
                    ? AppColors.orange
                    : AppColors.cream.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
```

### Segment Mapping

| Screen | Segment |
|--------|---------|
| User Profile | 1 |
| Sports Selection | 2 |
| Running Details | 3 |
| Cycling Details | 3 |
| Swimming Details | 3 |
| Stomach Sensitivity | 3 |
| Food Preferences | 4 |

---

## Checkbox/Radio Icons

### Checkbox States

**Unselected**:
- Empty rounded square outline
- Color: cream @ 40% opacity
- Size: 24x24px

**Selected**:
- Filled rounded square with checkmark
- Background: electrolyte
- Checkmark: white/cream
- Size: 24x24px

### Radio States

**Unselected**:
- Empty circle outline
- Color: cream @ 40% opacity
- Size: 24x24px

**Selected**:
- Filled circle with inner dot or checkmark
- Color: electrolyte
- Size: 24x24px

### Implementation Note

Use custom icons or Flutter's built-in icons with appropriate coloring:

```dart
// Unselected checkbox
Icon(
  Icons.check_box_outline_blank_rounded,
  size: 24,
  color: AppColors.cream.withOpacity(0.4),
)

// Selected checkbox
Icon(
  Icons.check_box_rounded,
  size: 24,
  color: AppColors.electrolyte,
)
```

---

## Animation Recommendations

### Chip Selection

```dart
// Scale animation on tap
transform: Matrix4.identity()..scale(isPressed ? 0.95 : 1.0),
// Duration: 150ms

// Color transition when toggling
AnimatedContainer(
  duration: Duration(milliseconds: 200),
  curve: Curves.easeInOut,
  // ...
)
```

### Navigation

```dart
// Page transition (swipe)
PageView(
  physics: const BouncingScrollPhysics(),
  // Smooth swipe with spring physics
)

// Button press
transform: Matrix4.identity()..scale(isPressed ? 0.97 : 1.0),
// Duration: 150ms
```

### Progress Bar

```dart
// Segment fill animation
AnimatedContainer(
  duration: Duration(milliseconds: 300),
  curve: Curves.easeOut,
  // ...
)
```

---

## Screen Layouts

### Common Screen Structure

```dart
Scaffold(
  backgroundColor: AppColors.blackberry,
  body: SafeArea(
    child: Column(
      children: [
        // Progress Bar (fixed at top)
        OnboardingProgressBar(currentSegment: segment),

        // Scrollable Content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 48, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(title, style: titleStyle),
                SizedBox(height: 12),
                // Description
                Text(description, style: descriptionStyle),
                SizedBox(height: 28),
                // Content specific to each screen
                ...contentWidgets,
              ],
            ),
          ),
        ),

        // Navigation Footer (fixed at bottom)
        OnboardingNavigationFooter(
          onBack: showBack ? () => goBack() : null,
          onContinue: () => goNext(),
        ),
      ],
    ),
  ),
)
```

### Food Preferences Layout

```dart
Column(
  children: [
    OnboardingProgressBar(currentSegment: 4),
    Expanded(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 48, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text('What foods fuel your training?', style: titleStyle),
            SizedBox(height: 12),
            // Description
            Text('Add the foods you use...', style: descriptionStyle),
            SizedBox(height: 29),

            // Search Bar
            SearchBar(),
            SizedBox(height: 12),

            // Selected Chips (only if any selected)
            if (selectedFoods.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedFoods.map((food) =>
                  FoodChip(
                    food: food,
                    isSelected: true,
                    onRemove: () => removeFood(food),
                  ),
                ).toList(),
              ),
              SizedBox(height: 29),
            ],

            // Common Foods Section
            Text('Common foods', style: sectionHeaderStyle),
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: commonFoods.map((food) =>
                FoodChip(
                  food: food,
                  isSelected: selectedFoods.contains(food),
                  onTap: () => toggleFood(food),
                ),
              ).toList(),
            ),
          ],
        ),
      ),
    ),
    OnboardingNavigationFooter(
      onBack: () => goBack(),
      onContinue: () => saveFoodsAndContinue(),
    ),
  ],
)
```

---

## Asset Requirements

### Icons Needed

| Icon | Size | Usage |
|------|------|-------|
| Arrow back | 28x28 | Back button |
| Search | 24x24 | Search bar |
| Close/X | 12x12 | Chip removal |
| Checkbox empty | 24x24 | Unselected option |
| Checkbox filled | 24x24 | Selected option |
| Radio empty | 24x24 | Unselected radio |
| Radio filled | 24x24 | Selected radio |
| Toggle on | 48x48 | Toggle switch on |
| Toggle off | 48x48 | Toggle switch off |

### Icon Colors

- Back arrow: `AppColors.orange`
- Search icon: `AppColors.cream`
- Close/X icon: `AppColors.cream`
- Checkbox/Radio empty: `AppColors.cream.withOpacity(0.4)`
- Checkbox/Radio filled: `AppColors.electrolyte`
- Toggle on: `AppColors.electrolyte`
- Toggle off: Gray or `AppColors.cream.withOpacity(0.3)`

---

## Accessibility Notes

### Touch Targets

- Minimum touch target: 48x48px
- All buttons meet this requirement
- Chips at 40px height may need vertical padding for tap area

### Color Contrast

| Combination | Ratio | Status |
|-------------|-------|--------|
| Cream on Blackberry | ~10.5:1 | Pass AAA |
| Orange on Blackberry | ~3.5:1 | Pass AA (large text) |
| Electrolyte on Blackberry | ~6:1 | Pass AA |

### Semantic Labels

```dart
// Checkbox
Semantics(
  label: 'Running, ${isSelected ? 'selected' : 'not selected'}',
  child: SelectableCard(...),
)

// Food chip
Semantics(
  label: '${food.name}, ${isLiked ? 'liked, tap to remove' : 'tap to like'}',
  child: FoodChip(...),
)

// Progress bar
Semantics(
  label: 'Step $currentStep of 4',
  child: OnboardingProgressBar(...),
)
```

---

## Responsive Considerations

### Screen Width Handling

```dart
// Get screen width for responsive calculations
final screenWidth = MediaQuery.of(context).size.width;

// For tablets, consider max width constraint
final contentWidth = screenWidth > 600 ? 600.0 : screenWidth;

Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: contentWidth),
    child: // screen content
  ),
)
```

### Safe Area

Always wrap screens in `SafeArea` to handle notches and home indicators:

```dart
SafeArea(
  child: // screen content
)
```

---

## State Management Patterns

### Onboarding Flow State

```dart
@freezed
class OnboardingFlowState with _$OnboardingFlowState {
  const factory OnboardingFlowState({
    @Default(1) int currentSegment,
    @Default({}) Set<Sport> selectedSports,
    @Default(false) bool runsWithWaterBottle,
    // Cycling details
    int? ftpWatts,
    @Default(2) int waterBottlesCount,
    @Default(false) bool usesAeroBottles,
    @Default(false) bool usesBentoBox,
    // Swimming details
    int? cssMinutes,
    int? cssSeconds,
    @Default(false) bool wearsWetsuit,
    @Default(SwimCapType.none) SwimCapType swimCapType,
    // Stomach
    @Default(false) bool hasSensitiveStomach,
    // Food
    @Default({}) Set<String> likedFoodIds,
  }) = _OnboardingFlowState;
}
```

### Screen Navigation Logic

```dart
String getNextRoute() {
  switch (currentScreen) {
    case OnboardingScreen.profile:
      return '/onboarding/sports-selection';
    case OnboardingScreen.sportsSelection:
      if (selectedSports.contains(Sport.running)) {
        return '/onboarding/running-details';
      } else if (selectedSports.contains(Sport.cycling)) {
        return '/onboarding/cycling-details';
      } else if (selectedSports.contains(Sport.swimming)) {
        return '/onboarding/swimming-details';
      }
      return '/onboarding/stomach-sensitivity';
    case OnboardingScreen.runningDetails:
      if (selectedSports.contains(Sport.cycling)) {
        return '/onboarding/cycling-details';
      } else if (selectedSports.contains(Sport.swimming)) {
        return '/onboarding/swimming-details';
      }
      return '/onboarding/stomach-sensitivity';
    // ... etc
  }
}
```

---

## Testing Specifications

### Visual Regression Tests

Compare screenshots against Figma for:
1. Sports Selection screen
2. Running Details screen
3. Cycling Details screen
4. Swimming Details screen
5. Stomach Sensitivity screen
6. Food Preferences screen

### Interaction Tests

1. **Sports Selection**:
   - Tap each sport → verify selection state
   - Tap selected sport → verify deselection
   - Verify at least one sport required to continue

2. **Food Preferences**:
   - Tap food chip → verify moves to selected section
   - Tap X on selected chip → verify returns to common foods
   - Search → verify results appear
   - Select from search → verify adds to selected

3. **Navigation**:
   - Back button → verify goes to correct previous screen
   - Continue → verify saves data and goes to next screen
   - Swipe → verify page changes (when implemented)

4. **Progress Bar**:
   - Verify correct segment highlighted on each screen
   - Verify animation on segment change
