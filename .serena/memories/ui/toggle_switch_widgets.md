# Toggle/Switch Widgets - Codebase Analysis

## Summary
The Mealvana Endurance app has multiple custom toggle/switch widget options following Kyle's design system. The current "runs with water bottle" implementation varies by context (onboarding vs coach portal).

---

## Current "Runs with Water Bottle" Implementations

### 1. Onboarding (Running Details Screen)
**File**: `/lib/features/onboarding/presentation/screens/running_details_screen.dart`

**Current Widget**: `FigmaToggleCard`
- Simple toggle switch on right side
- Dark mode onboarding design (light purple background)
- Toggle stores as boolean: `_runsWithWaterBottle`
- Internally inverted to `giSensitivity = !_runsWithWaterBottle`
- Label: "I run with a water bottle"

**Code snippet** (lines 282-286):
```dart
FigmaToggleCard(
  label: 'I run with a water bottle',
  value: _runsWithWaterBottle,
  onChanged: (value) => setState(() => _runsWithWaterBottle = value),
)
```

### 2. Coach Portal (Athlete Profile Form)
**File**: `/lib/features/coach_mode/presentation/widgets/portal_athlete_profile_form.dart`

**Current Widget**: Custom inline `_buildSwitchRow()` method (lines 375-400)
- Basic Material Switch.adaptive with orange active color
- Label on left, switch on right
- Part of a form with other fields
- No styling consistency with main app design
- Label: "Runs with Water Bottle"

**Code snippet** (lines 149-152):
```dart
_buildSwitchRow('Runs with Water Bottle', _runsWithWaterBottle,
    (val) {
  setState(() => _runsWithWaterBottle = val);
}),
```

---

## Available Custom Toggle/Switch Widgets

### 1. **ToggleCard** (RECOMMENDED for Coach Portal)
**File**: `/lib/shared/widgets/selection/toggle_card.dart`

**Best For**: Coach portal athlete profile editing
- Full card styling with background and border
- Icon or emoji support on left
- Label + optional description
- Toggle switch on right
- Orange active color (AppColors.orange)
- Disabled state support
- Perfect for inline form fields

**Usage**:
```dart
ToggleCard(
  label: 'Runs with Water Bottle',
  value: _runsWithWaterBottle,
  onChanged: (val) => setState(() => _runsWithWaterBottle = val),
  icon: Icons.water_drop, // Optional
  enabled: true,
)
```

**Styling Details**:
- Background: `AppColors.surfaceLight`
- Border: `AppColors.borderLightSecondary`
- Border radius: `AppRadius.cardRadius`
- Padding: `AppSpacing.md`
- Icon colors: Orange when true, textLightSecondary when false
- Switch: Orange track when active, white thumb, gray when inactive

### 2. **ToggleRow** (LIGHTWEIGHT ALTERNATIVE)
**File**: `/lib/shared/widgets/selection/toggle_card.dart` (lines 128-192)

**Best For**: Compact inline toggles without card styling
- No background card, just a row
- Label + optional description on left
- Switch on right
- Same color scheme as ToggleCard
- Good for within larger forms

**Usage**:
```dart
ToggleRow(
  label: 'Runs with Water Bottle',
  value: _runsWithWaterBottle,
  onChanged: (val) => setState(() => _runsWithWaterBottle = val),
)
```

### 3. **KyleToggleButton** (FOR BINARY CHOICES)
**File**: `/lib/shared/widgets/kyle_design/inputs/indoor_outdoor_toggle.dart` (lines 48-93)

**Best For**: Two-option binary toggles
- Two buttons side by side (not a switch)
- Full-width with flexible layout
- Pill-shaped buttons with borders
- Good for mutually exclusive options
- Used in cycling (Outdoor/Indoor)

**Example Usage**:
```dart
KyleToggleButton(
  label: 'Outdoor',
  isSelected: !isIndoor,
  onTap: () => onChanged(false),
  isDark: isDark,
)
```

### 4. **TwoOptionPillSlider** (ANIMATED SLIDER)
**File**: `/lib/shared/widgets/kyle_design/inputs/two_option_pill_slider.dart`

**Best For**: Mode switching with animation
- Connected pill-shaped control
- Animated thumb slides between options
- Used in DurationPaceToggle
- Sport-aware labeling

**Styling Details**:
- Animated thumb movement (220ms)
- Customizable colors, height (default 46), border
- Font weight bold when selected
- Semantic accessibility support

### 5. **FigmaToggleCard** (CURRENT ONBOARDING)
**File**: `/lib/shared/widgets/selection/figma_toggle_card.dart`

**Best For**: Dark mode onboarding
- Light purple background (rgba(248,246,235,0.08))
- Cyan/electrolyte toggle color when active
- Exact Figma design specifications
- 16px border radius
- Good for dark backgrounds

---

## Styling Comparison

| Widget | Best For | Card Style | Icon Support | Description Support | Animated |
|--------|----------|-----------|--------------|-------------------|----------|
| **ToggleCard** | Coach portal forms | Yes (surfaceLight) | Yes | Yes | No |
| **ToggleRow** | Compact inline | No | No | Yes | No |
| **KyleToggleButton** | Binary choices | Pill buttons | No | No | No |
| **TwoOptionPillSlider** | Mode switching | Pill slider | No | No | Yes |
| **FigmaToggleCard** | Dark onboarding | Yes (dark purple) | No | No | No |

---

## Recommendation for Coach Portal

**Use `ToggleCard`** for consistency because:

1. ✅ Designed for form fields with full card styling
2. ✅ Matches Kyle design system colors (orange active, gray inactive)
3. ✅ Already used elsewhere in app for toggle options
4. ✅ Supports optional icon/emoji for visual clarity
5. ✅ Supports optional description text
6. ✅ Consistent with onboarding philosophy
7. ✅ Reusable pattern - same widget in multiple screens

**Import**:
```dart
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
// or direct
import '../../../../shared/widgets/selection/toggle_card.dart';
```

---

## Color System Reference

- **Active track**: `AppColors.orange`
- **Active thumb**: `Colors.white`
- **Inactive track**: `AppColors.inactive.withValues(alpha: 0.3)`
- **Icon when active**: `AppColors.orange`
- **Icon when inactive**: `AppColors.textLightSecondary`
- **Card background**: `AppColors.surfaceLight`
- **Card border**: `AppColors.borderLightSecondary`

---

## Files to Update for Coach Portal

1. `/lib/features/coach_mode/presentation/widgets/portal_athlete_profile_form.dart`
   - Replace `_buildSwitchRow()` method with `ToggleCard` widget
   - Remove inline custom Switch implementation
   - Add `icon: Icons.water_drop` for visual clarity

2. No other changes needed - ToggleCard handles all styling
