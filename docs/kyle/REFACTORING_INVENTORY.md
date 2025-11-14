# Kyle's Design System - Refactoring Inventory
## Complete Screen & Widget Mapping

**Created:** 2025-11-12
**Last Updated:** 2025-11-12
**Purpose:** Map Figma screenshots to existing codebase screens and widgets for refactoring
**Status:** 🟡 In Progress - P0 Screens Complete (3/51 screens, 6%)

**✅ P0 Milestone Achieved:** Activity Detail, User Profile, Settings screens fully restored with database integration
📖 **See:** [P0 Restoration Complete](./P0_RESTORATION_COMPLETE.md) for detailed completion report

---

## 📋 Table of Contents
1. [Screenshot Analysis](#screenshot-analysis)
2. [Theme System Changes](#theme-system-changes)
3. [Widget Refactoring Inventory](#widget-refactoring-inventory)
4. [Screen Refactoring Inventory](#screen-refactoring-inventory)
5. [New Components to Create](#new-components-to-create)
6. [Implementation Phases](#implementation-phases)

---

## 📸 Screenshot Analysis

### Screens Identified from Figma (14 screenshots)

| # | Screenshot | Screen Name | Light/Dark | Existing File | Status |
|---|-----------|-------------|------------|---------------|---------|
| 1 | 5.17.34 AM | New Activity | Light | `lib/features/nutrition_plan/presentation/screens/distance_pace_gut_entry_screen.dart` | ✅ Found |
| 2 | 5.18.03 AM | New Activity | Dark | Same as #1 | ✅ Found |
| 3 | 5.18.18 AM | Activity Details | Light | `lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart` | ✅ Found |
| 4 | 5.18.50 AM | Activity Details | Dark | Same as #3 | ✅ Found |
| 5 | 5.19.23 AM | Calendar Month | Light | `lib/features/calendar/*` | ✅ Found |
| 6 | 5.19.32 AM | Calendar Month | Dark | Same as #5 | ✅ Found |
| 7 | 5.19.40 AM | Calendar Week | Light | `lib/features/calendar/presentation/widgets/calendar_week_view.dart` | ✅ Found |
| 8 | 5.19.50 AM | Calendar Week | Dark | Same as #7 | ✅ Found |
| 9 | 5.20.04 AM | Adjust Your Macros | Light | `lib/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart` | ✅ Found |
| 10 | 5.20.17 AM | Adjust Your Macros | Dark | Same as #9 | ✅ Found |
| 11 | 5.20.24 AM | Food Preferences | Light | `lib/features/settings/presentation/screens/food_preferences_edit_screen.dart` | ✅ Found |
| 12 | 5.20.31 AM | Food Preferences | Dark | Same as #11 | ✅ Found |
| 13 | 5.20.41 AM | Style Guide | N/A | N/A | ℹ️ Reference only |
| 14 | 5.20.48 AM | Style Guide (cont.) | N/A | N/A | ℹ️ Reference only |

---

## 📱 Complete Screen Inventory (49 Total Screens)

### **All screens must be updated to Kyle's design system**

### 1. **Nutrition Plan** (10 screens) 🔴 CORE FEATURE
| # | File | Priority | Notes |
|---|------|----------|-------|
| 1 | `distance_pace_gut_entry_screen.dart` | 🔴 CRITICAL | Main activity input - has Figma design |
| 2 | `cycling_input_screen.dart` | 🔴 HIGH | Similar to running input |
| 3 | `swimming_input_screen.dart` | 🔴 HIGH | Similar to running input |
| 4 | `activity_detail_screen.dart` | 🔴 CRITICAL | Nutrition display - has Figma design |
| 5 | `adjust_macros_screen.dart` | 🔴 HIGH | Macro table - has Figma design |
| 6 | `current_plan_screen.dart` | 🟡 MEDIUM | Plan overview |
| 7 | `swap_food_screen.dart` | 🟡 MEDIUM | Food swapping UI |
| 8 | `sample_plan_demo.dart` | 🟢 LOW | Demo screen |

### 2. **Calendar & Events** (7 screens) 🔴 CORE FEATURE
| # | File | Priority | Notes |
|---|------|----------|-------|
| 9 | Calendar Month View (widgets) | 🔴 HIGH | Has Figma design |
| 10 | Calendar Week View (widgets) | 🔴 HIGH | Has Figma design |
| 11 | `event_creation_screen.dart` | 🔴 HIGH | Create events |
| 12 | `event_edit_screen.dart` | 🔴 HIGH | Edit events |
| 13 | `event_only_edit_screen.dart` | 🔴 HIGH | Edit event-only |
| 14 | `event_form_screen.dart` | 🔴 HIGH | Event form |
| 15 | `event_detail_screen.dart` | 🔴 HIGH | Event details |
| 16 | `events_list_screen.dart` | 🔴 HIGH | Events list |

### 3. **Activities** (2 screens) 🔴 CORE FEATURE
| # | File | Priority | Notes |
|---|------|----------|-------|
| 17 | `activity_creation_screen.dart` | 🔴 HIGH | Create activity |
| 18 | `activities_list_screen.dart` | 🔴 HIGH | Activity list |

### 4. **Carb Loading** (6 screens) 🟡 FEATURE
| # | File | Priority | Notes |
|---|------|----------|-------|
| 19 | `carb_loading_protocol_selection_screen.dart` | 🟡 MEDIUM | Protocol picker |
| 20 | `carb_loading_food_selection_screen.dart` | 🟡 MEDIUM | Food selection |
| 21 | `create_custom_carb_loading_food_screen.dart` | 🟡 MEDIUM | Custom food |
| 22 | `carb_loading_screen_simple.dart` | 🟡 MEDIUM | Simple view |
| 23 | `carb_loading_day_detail_page.dart` | 🟡 MEDIUM | Day details |
| 24 | `calendar/carb_loading_protocol_selection_screen.dart` | 🟡 MEDIUM | Duplicate? |

### 5. **Settings** (7 screens) 🔴 HIGH PRIORITY
| # | File | Priority | Notes |
|---|------|----------|-------|
| 25 | `settings_screen.dart` | 🔴 HIGH | Main settings - ADD THEME TOGGLE |
| 26 | `settings_menu_screen.dart` | 🔴 HIGH | Settings menu |
| 27 | `food_preferences_edit_screen.dart` | 🔴 HIGH | Has Figma design |
| 28 | `profile_settings_screen.dart` | 🟡 MEDIUM | Profile settings |
| 29 | `sport_settings_screen.dart` | 🟡 MEDIUM | Sport config |
| 30 | `preferences_screen.dart` | 🟡 MEDIUM | General prefs |
| 31 | `help_feedback_screen.dart` | 🟡 MEDIUM | Help & feedback |
| 32 | `debug_screen.dart` | 🟢 LOW | Debug only |

### 6. **Onboarding** (4 screens) 🔴 HIGH PRIORITY
| # | File | Priority | Notes |
|---|------|----------|-------|
| 33 | `welcome_screen.dart` | 🔴 HIGH | First impression |
| 34 | `user_profile_screen.dart` | 🔴 HIGH | User setup |
| 35 | `sport_preferences_screen.dart` | 🔴 HIGH | Sport selection |
| 36 | `food_preferences_screen.dart` | 🔴 HIGH | Food prefs (onboarding) |

### 7. **User Journal** (3 screens) 🟡 FEATURE
| # | File | Priority | Notes |
|---|------|----------|-------|
| 37 | `plan_how_well_screen.dart` | 🟡 MEDIUM | Plan rating |
| 38 | `voice_memo_screen.dart` | 🟡 MEDIUM | Voice notes |
| 39 | `voice_notes_list_screen.dart` | 🟡 MEDIUM | Notes list |

### 8. **Feedback/Survey** (7 screens) 🟡 FEATURE
| # | File | Priority | Notes |
|---|------|----------|-------|
| 40 | `survey_screen.dart` | 🟡 MEDIUM | Main survey |
| 41 | `survey_page_1.dart` | 🟡 MEDIUM | Survey part 1 |
| 42 | `survey_page_2.dart` | 🟡 MEDIUM | Survey part 2 |
| 43 | `survey_page_1_simple.dart` | 🟡 MEDIUM | Simple version |
| 44 | `survey_page_2_simple.dart` | 🟡 MEDIUM | Simple version |
| 45 | `feature_survey_screen.dart` | 🟡 MEDIUM | Feature survey |
| 46 | `feature_survey_success_screen.dart` | 🟡 MEDIUM | Survey success |

### 9. **Other Features** (3 screens) 🟡 MEDIUM
| # | File | Priority | Notes |
|---|------|----------|-------|
| 47 | `barcode_scanner_screen.dart` | 🟡 MEDIUM | Scan barcodes |
| 48 | `add_food_screen.dart` | 🟡 MEDIUM | Add food from scan |
| 49 | `weather_detail_screen.dart` | 🟡 MEDIUM | Weather info |
| 50 | `share_nutrition_plan_screen.dart` | 🟡 MEDIUM | Share plan |
| 51 | `recipes_screen.dart` | 🟢 LOW | Recipes (future) |

---

## 🎨 Theme System Changes

### Current State
**File:** `/lib/theme/app_theme.dart`

**Current Implementation:**
- ❌ **Light mode only** (line 9: "Light mode only - no dark theme support")
- ✅ Uses Material Design 3
- ✅ Has some correct colors (Blackberry `#381633`, Cream `#F8F6EB`)
- ❌ Missing Kyle's exact color palette
- ❌ No dark/light theme switching capability
- ❌ Default is light mode (needs to be dark mode per requirements)

### Required Changes

#### 1. **Add Dark Theme Support** ⭐ HIGH PRIORITY
```dart
// Current (lines 48-74):
static ThemeData get lightTheme { ... }

// Need to add:
static ThemeData get darkTheme {
  // Implement Blackberry background (#381633)
  // Cream text (#F8F6EB)
  // All component themes in dark mode
}

// Add theme mode provider
static ThemeMode defaultTheme = ThemeMode.dark; // DEFAULT TO DARK
```

#### 2. **Update Color Palette with Exact Values** ⭐ HIGH PRIORITY
Replace approximate colors with extracted exact values:

```dart
// EXACT VALUES from Figma extraction:
static const Color blackberry = Color(0xFF381633);      // ✅ Current: 0xFF381633 (CORRECT)
static const Color cream = Color(0xFFF8F6EB);           // ✅ Current: 0xFFF8F6EB (CORRECT)
static const Color orange = Color(0xFFF78B14);          // ❌ Need to add
static const Color electrolyte = Color(0xFF1CF9CF);     // ❌ Need to add (CRITICAL - all icons use this)
static const Color dragonfruit = Color(0xFFDC2597);     // ✅ Current: 0xFFDC2597 (highlight600Alt - CORRECT)
static const Color offCream = Color(0xFFC6C3B2);        // ❌ Need to add (new color for inactive states)

// Current incorrect/missing:
// - No Orange color defined (using wrong coral/pink)
// - No Electrolyte color (CRITICAL - used for all food/activity icons)
// - No Off Cream color
```

#### 3. **Add Theme Switcher in Settings** ⭐ MEDIUM PRIORITY
**File to modify:** `/lib/features/settings/presentation/screens/settings_screen.dart`

Add new setting:
```dart
// Theme Mode Toggle
ListTile(
  title: 'Appearance',
  subtitle: 'Light / Dark / System',
  trailing: SegmentedButton(
    segments: [
      ButtonSegment(value: ThemeMode.light, label: 'Light'),
      ButtonSegment(value: ThemeMode.dark, label: 'Dark'),
      ButtonSegment(value: ThemeMode.system, label: 'System'),
    ],
  ),
)
```

#### 4. **Update Typography with Exact Font Sizes** ⭐ MEDIUM PRIORITY
Current text theme uses approximate sizes. Update with exact extracted values:
- Screen titles: Sansita Bold 17px (not 20pt)
- Button text: Sansita Bold 16px (not 16pt)
- Food names: Compadre Regular 12px
- Input fields: Apercu Mono 14px
- Nutritional values: Apercu Mono 12px
- Labels: Apercu Mono 10px

---

## 🧩 Widget Refactoring Inventory

### Shared Widgets (Global Components)

#### **1. Custom App Bar Back Button** 🔴 MUST REFACTOR
**File:** `/lib/shared/widgets/custom_app_bar_back_button.dart`

**Current State:**
- Generic back button
- May not match Kyle's design

**Kyle's Design (Extracted):**
- Size: 40×40px circular button
- Background: Blackberry `#381633` (light) / Cream `#F8F6EB` (dark) at 10% opacity
- Icon: Left arrow, 20px, contrasting color
- Border Radius: 100px (fully circular)

**Changes Needed:**
- ✅ Update size to exactly 40px
- ✅ Update background color with opacity
- ✅ Update icon size to 20px
- ✅ Ensure fully circular (100px border radius)
- ✅ Support both light and dark themes

**Priority:** 🔴 HIGH (used on every screen)

---

#### **2. Primary Button** 🔴 MUST REFACTOR
**File:** `/lib/shared/widgets/primary_button.dart`

**Current State:**
- Existing primary button implementation
- May not match exact Kyle specs

**Kyle's Design (Exact from Figma):**
```dart
// Specs:
Background: Orange #F78B14
Text: Blackberry #381633, Sansita Bold 16px
Height: Auto (content-based)
Padding: 10px vertical, 16px horizontal
Border Radius: 100px (fully rounded)
Shadow: None (flat design)

// States:
Default: #F78B14
Hover: #F9A042
Pressed: #E57D0C
Disabled: 40% opacity
```

**Changes Needed:**
- ✅ Update colors to exact Orange `#F78B14`
- ✅ Text color Blackberry `#381633`
- ✅ Border radius 100px (fully rounded)
- ✅ Exact padding: 10px vertical, 16px horizontal
- ✅ Remove shadows (flat design)
- ✅ Add hover/pressed states

**Priority:** 🔴 HIGH (used throughout app)

**Screens Using This:**
- New Activity ("Generate Plan")
- Activity Details ("Complete Workout")
- Adjust Macros ("Create Plan")
- Food Preferences ("Save Changes")

---

#### **3. Secondary Button** 🔴 MUST REFACTOR
**File:** `/lib/shared/widgets/secondary_button.dart`

**Current State:**
- Existing secondary button implementation

**Kyle's Design:**
```dart
// Two variants observed:

// Variant 1: Orange Outline
Background: Transparent
Border: 2px solid Orange #F78B14
Text: Blackberry #381633, Sansita Bold 16px
Border Radius: 100px

// Variant 2: Blackberry Outline (for neutral actions)
Background: Transparent
Border: 2px solid Blackberry #381633
Text: Blackberry #381633 (light) / Cream #F8F6EB (dark)
Border Radius: 100px
```

**Changes Needed:**
- ✅ Support two color variants (Orange/Blackberry)
- ✅ Exact border: 2px solid
- ✅ Border radius: 100px
- ✅ Transparent background
- ✅ Dark/light theme support

**Priority:** 🔴 HIGH

**Screens Using This:**
- Adjust Macros ("Edit Macros", "Reset All")

---

#### **4. Plus/Minus Controls** ✅ EXISTS - REFACTOR NEEDED
**File:** `/lib/shared/widgets/increment_decrement_widget.dart`

**Current Implementation:**
- 40px circular buttons with blue border
- Uses Material Icons (add/remove)
- White background with shadows

**Kyle's Design (Exact from Figma):**
```dart
// Specs:
Container: 36×36px (with 8px padding)
Icon: 20×20px
Border: 2px solid Orange #F78B14
Border Radius: 100px (fully circular)
Background: Transparent
Icon Color: Blackberry #381633 (light) / Cream #F8F6EB (dark)

// Layout:
[−] Value Text [+]
Value: Compadre Regular 16px, centered
```

**Changes Needed:**
- ✅ Update size to 36px (from 40px)
- ✅ Update border color to Orange #F78B14
- ✅ Remove shadows and white background
- ✅ Update icon color for dark/light themes
- ✅ Use Font Awesome icons instead of Material Icons

**Priority:** 🔴 HIGH (used in 3+ screens)

---

#### **5. Activity Type Selector** ✅ EXISTS - REFACTOR NEEDED
**File:** `/lib/features/calendar/presentation/widgets/sport_category_selector.dart`

**Current Implementation:**
- Horizontal scrollable chips
- Material Icons
- Different sizing and styling

**Kyle's Design (Exact from Figma):**
```dart
// Specs:
Size: 62px width × 74px height
Border Radius: 15px

// Unselected:
Background: Transparent
Border: 1px solid Blackberry #381633
Icon: 36px, Blackberry #381633
Label: Compadre Regular 12px, Blackberry #381633

// Selected:
Background: Blackberry #381633 (filled)
Border: 2px solid Blackberry #381633
Icon: 36px, Cream #F8F6EB (inverted)
Label: Compadre Regular 12px, Cream #F8F6EB (inverted)
```

**Changes Needed:**
- ✅ Update to fixed 62px × 74px dimensions
- ✅ Update border radius to 15px
- ✅ Implement selected/unselected states
- ✅ Use Font Awesome activity icons
- ✅ Update typography to Compadre Regular 12px

**Priority:** 🔴 HIGH

---

#### **6. Segmented Control** 🟡 NEW COMPONENT
**File to create:** `/lib/shared/widgets/kyle_design/buttons/segmented_control.dart`

**Kyle's Design (Exact from Figma):**
```dart
// Specs:
Width: 74-110px (varies by label)
Height: Auto (content-based)
Border Radius: 15px

// Unselected:
Background: Transparent
Border: 1px solid Blackberry #381633
Text: Sansita Bold 12px, Blackberry #381633

// Selected:
Background: Blackberry #381633 (filled)
Border: 2px solid Blackberry #381633
Text: Sansita Bold 12px, Cream #F8F6EB (inverted)
```

**Currently Used In:**
- New Activity screen (Gut Training Level: LOW/MODERATE/HIGH)
- New Activity screen (Sweat Rate: LOW/MODERATE/HIGH)

**Priority:** 🔴 HIGH

---

#### **7. Food/Activity Icon (Circular)** ✅ EXISTS - REFACTOR NEEDED
**File:** `/lib/shared/widgets/food_icon.dart`

**Current Implementation:**
- Network image loading with fallback
- White background with shadows
- No standard size for activity icons

**Kyle's Design (Exact from Figma):**
```dart
// Specs (SAME for both food and activity icons):
Container: 36×36px (circular)
Background: Electrolyte #1CF9CF ⚠️ CRITICAL COLOR
Icon: ~18px (centered)
Icon Color: Blackberry #381633
Font: Font Awesome Free (using pub.dev package)
```

**⚠️ CRITICAL:** All food and activity icons use Electrolyte `#1CF9CF` background (bright cyan), not the old estimate `#5DE4D3`.

**Changes Needed:**
- ✅ Update background color to Electrolyte #1CF9CF
- ✅ Remove shadows and white background
- ✅ Use Font Awesome icons instead of network images
- ✅ Standardize size to 36px
- ✅ Create separate ActivityIcon component if needed

**Priority:** 🔴 CRITICAL (visual brand element used everywhere)

---

#### **8. Text Input Field** 🟡 REFACTOR EXISTING
**Files:** Multiple input widgets exist

**Kyle's Design (Exact from Figma):**
```dart
// Specs:
Height: 46px
Background: Transparent (Cream #F8F6EB shows through in light mode)
Border: 1px solid Blackberry #381633
Border Radius: 15px
Text: Apercu Mono 14px, Blackberry #381633
Placeholder: Same font and color
Padding: 16px horizontal, 12px vertical
```

**Currently Used In:**
- Food Preferences ("Search Foods")
- Any form inputs throughout the app

**Priority:** 🟡 MEDIUM

---

#### **9. Preference Slider** ✅ EXISTS - MAJOR REFACTOR NEEDED
**File:** `/lib/shared/widgets/food_preference_widget.dart`

**Current Implementation:**
- Three-chip selection (❤️ 🤔 ❌)
- Emoji icons
- Different interaction pattern

**Kyle's Design (Exact from Figma):**
```dart
// Specs:
Track Width: 276px
Track Height: 1px (thin line)
Track Color: Blackberry #381633

// 5 Points:
Point Size: 8×8px circles
Inactive: Blackberry #381633 filled
Active Handle: 16-20px circle, Blackberry #381633 filled

// Labels:
Left: "Avoid" + X icon (FA 15px)
Right: "Love" + Heart icon (FA 20px)
Font: Apercu Mono 10px, Blackberry #381633
```

**Changes Needed:**
- ✅ Complete redesign from chips to slider
- ✅ Implement 5-point discrete system
- ✅ Add track and handle styling
- ✅ Use Font Awesome icons
- ✅ Update labels to "Avoid" to "Love"

**Priority:** 🔴 HIGH (key interaction component)

---

### Shared Widgets - Additional Components

#### **10. Nutrition Section Card** ✅ EXISTS - REFACTOR NEEDED
**File:** `/lib/features/nutrition_plan/presentation/widgets/expandable_food_item.dart`

**Current Implementation:**
- Light blue background (#D6E0FF)
- Expandable with nutrition facts
- Different header structure

**Kyle's Design:**
```dart
// Specs:
Border Radius: 15px
Background: Transparent / subtle fill
Border: 1px solid Blackberry #381633 (subtle)
Padding: 16-24px

// Header:
Title: Compadre Wide 16px uppercase ("BEFORE RUN", "DURING RUN", "AFTER RUN")
Macro Summary: 3 columns (CARBS/PROTEIN/FAT or CARBS/FLUIDS/SODIUM)
  - Values: Apercu Mono 12-14px
  - Format: "97/97g CARBS | 473/444mL FLUIDS"
```

**Changes Needed:**
- ✅ Update background to transparent/subtle fill
- ✅ Add macro summary header
- ✅ Update typography to match Kyle's specs
- ✅ Update border styling

**Priority:** 🔴 HIGH

---

#### **11. Food Item Card (Expandable)** 🟡 NEW COMPONENT
**File to create:** `/lib/shared/widgets/kyle_design/cards/food_item_card.dart`

**Kyle's Design:**
```dart
// Collapsed State:
Height: ~60-80px
Layout: [Icon 36px] [Food Name] [Chevron]
Food Name: Compadre Regular 12px
Icon: Electrolyte #1CF9CF background

// Expanded State:
Additional content:
- Quantity controls (plus/minus)
- Nutritional facts grid (2×2)
  - Values: Apercu Mono 12px
  - Labels: Compadre Regular 7px
- Actions: "Swap Food Item", "Remove Food Item" (Dragonfruit #DC2597)
```

**Currently Used In:**
- Activity Details screen (all food listings)

**Priority:** 🔴 HIGH

---

#### **12. Add Food Button** 🟡 NEW COMPONENT
**File to create:** `/lib/shared/widgets/kyle_design/buttons/add_food_button.dart`

**Kyle's Design:**
```dart
// Specs:
Width: Auto (content-based)
Border Radius: 15px
Border: 2px solid Orange #F78B14
Background: Transparent
Text: Compadre Regular 12px, Blackberry #381633
Icon: Plus icon (FA), Orange #F78B14
Padding: 8-12px
```

**Currently Used In:**
- Activity Details (end of each nutrition section)

**Priority:** 🟡 MEDIUM

---

#### **13. Calendar Day Cell** 🟡 REFACTOR EXISTING
**Files:** `/lib/features/calendar/presentation/widgets/*`

**Kyle's Design:**
```dart
// Month View:
Date Number: Apercu 16px
Today: Circular background (Blackberry light / Cream dark)
Event Indicator: Electrolyte #1CF9CF dot (6px) below number

// Week View:
Selected Day: Larger, emphasized
Date Badge: "Nov 22" format
```

**Currently Used In:**
- Calendar Month view
- Calendar Week view

**Priority:** 🟡 MEDIUM

---

#### **14. Macro Targets Table** ✅ EXISTS - REFACTOR NEEDED
**Files:**
- `/lib/features/nutrition_plan/presentation/widgets/macro_targets_widget.dart`
- `/lib/features/nutrition_plan/presentation/widgets/section_macro_targets_widget.dart`
- `/lib/features/nutrition_plan/presentation/widgets/macro_section_card.dart`

**Current Implementation:**
- Progress bars and chips
- Different layout structure
- No table format

**Kyle's Design:**
```dart
// Specs:
Border: 1px solid Blackberry #381633
Border Radius: 15px
Padding: 16px

// Header:
Title: "Your Nutritional Targets" - Sansita Bold 18px
Info icon: Dragonfruit #DC2597, 20px

// Table:
Columns: PRE | DURING | POST
Rows: CARBS, PROTEIN, FLUIDS, SODIUM
Values: Apercu Mono 16px, Semibold
Labels: Apercu Mono 10px, uppercase
Borders: 1px solid divider
```

**Changes Needed:**
- ✅ Redesign from progress bars to table format
- ✅ Add structured table with borders
- ✅ Update typography to match specs
- ✅ Add info icon and header

**Priority:** 🔴 HIGH

---

#### **15. Large Stat Display** 🟡 NEW COMPONENT
**File to create:** `/lib/shared/widgets/kyle_design/data/large_stat.dart`

**Kyle's Design:**
```dart
// Specs:
Layout: Two columns

// Each stat:
Icon: 32px (clock/flame)
Label: "PACE" or "TOTAL BURN" - Apercu 12px uppercase
Value: "9:00/mi" or "823" - Apercu 48pt Bold
Color: Primary text
```

**Currently Used In:**
- Adjust Macros screen (top section)

**Priority:** 🟡 MEDIUM

---

#### **16. Bottom Navigation Bar** 🟡 REFACTOR EXISTING
**File:** `/lib/shared/widgets/tabs_screen.dart` (likely)

**Kyle's Design:**
```dart
// Specs:
Height: 72px
Background: Blackberry #381633 (dark) / Cream #F8F6EB (light)
Items: 3 circular buttons (48×48px)

// Buttons:
Calendar: Neutral background, calendar icon 24px
Menu: Neutral background, three dots icon 24px
Add: Orange #F78B14 background, plus icon 24px
```

**Currently Used In:**
- Calendar Week view (visible in screenshot)
- Likely other main screens

**Priority:** 🟡 MEDIUM

---

## 📱 Screen Refactoring Inventory

### **Screen 1: New Activity Input** 🔴 COMPLETE REFACTOR NEEDED

**Figma Screenshots:** #1 (Light), #2 (Dark)

**Current File:** ❓ Need to identify (possibly running_input_screen.dart or similar)

**Related Files:**
- `/lib/features/nutrition_plan/presentation/screens/cycling_input_screen.dart`
- `/lib/features/nutrition_plan/presentation/screens/swimming_input_screen.dart`

#### **Components in Screenshot:**
1. ✅ Custom App Bar with Back Button → REFACTOR
2. 🟡 Activity Type Selector (Running/Biking/Swimming) → NEW COMPONENT
3. ✅ Hero Image with geometric overlay → Existing (may need styling update)
4. ✅ Date Display → Existing (check styling)
5. ✅ Time Display → Existing (check styling)
6. 🔴 "Edit" link (Dragonfruit color) → NEW COMPONENT
7. 🟡 Plus/Minus Controls (Distance, Pace, Time before Run, etc.) → NEW COMPONENT
8. 🟡 Segmented Controls (Gut Training, Sweat Rate) → NEW COMPONENT
9. 🔴 "Forecast" link (Dragonfruit color) → NEW COMPONENT
10. ✅ Primary Button ("Generate Plan") → REFACTOR

#### **Layout Differences:**
- Light mode: Cream `#F8F6EB` background
- Dark mode: Blackberry `#381633` background
- All text colors inverted between themes

#### **Questions for User:**
- ❓ Is there a running_input_screen.dart file? Need location.
- ❓ Are cycling/swimming input screens structurally similar to running?

**Priority:** 🔴 CRITICAL (main input screen)

---

### **Screen 2: Activity Detail Screen** 🔴 COMPLETE REFACTOR NEEDED

**Figma Screenshots:** #3 (Light), #4 (Dark)

**Current File:** ✅ `/lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart`

#### **Components in Screenshot:**
1. ✅ Custom App Bar with Back Button → REFACTOR
2. ✅ Hero Image with date/time → Existing (check styling)
3. 🟡 Nutrition Section Cards (3x: Before/During/After Run) → NEW COMPONENT
   - Header with macro summary
   - Food item list with icons
   - Expandable food items with nutritional facts
   - Quantity controls
   - Action buttons (Swap, Remove)
4. 🟡 Add Food Button → NEW COMPONENT
5. ✅ Primary Button ("Complete Workout") → REFACTOR
6. 🟡 Food/Activity Icons (36px circles with Electrolyte background) → NEW COMPONENT

#### **Layout Differences:**
- 3 distinct nutrition sections (Before/During/After)
- Each section has:
  - Macro targets at top
  - List of food items with icons
  - Expandable details
  - Add Food button at bottom
- Bottom has primary CTA button

#### **Current vs. Kyle's Design:**
- Current likely has different card styling
- Icons probably don't match (need Electrolyte background)
- Food item expand/collapse may be different
- Nutritional facts grid format likely different

**Priority:** 🔴 CRITICAL (core feature screen)

---

### **Screen 3: Calendar Month View** 🟡 MODERATE REFACTOR

**Figma Screenshots:** #5 (Light), #6 (Dark)

**Current Files:**
- ✅ `/lib/features/calendar/presentation/widgets/calendar_month_grid.dart`
- Related calendar widgets

#### **Components in Screenshot:**
1. ✅ Month/Year Header ("November 2025")
2. ✅ Tab Toggle ("BY MONTH" / "BY WEEK")
3. ✅ Day Letters Row (S M T W T F S)
4. 🟡 Calendar Grid → REFACTOR EXISTING
   - Date numbers: Apercu 16px
   - Today indicator: Circular background
   - Event dots: Electrolyte `#1CF9CF` 6px dots
5. 🟡 Bottom Navigation (3 circular buttons) → REFACTOR EXISTING

#### **Layout Differences:**
- Very clean, minimal design
- Event indicators are small cyan dots
- Selected day (9) has filled circle background

#### **Current vs. Kyle's Design:**
- Existing calendar likely has different date cell styling
- Event indicators may be different color
- Selected day styling may differ

**Priority:** 🟡 MEDIUM (important but less complex)

---

### **Screen 4: Calendar Week View** 🟡 MODERATE REFACTOR

**Figma Screenshots:** #7 (Light), #8 (Dark)

**Current File:** ✅ `/lib/features/calendar/presentation/widgets/calendar_week_view.dart`

#### **Components in Screenshot:**
1. ✅ Month/Year Header
2. ✅ Tab Toggle ("BY MONTH" / "BY WEEK")
3. 🟡 Week Selector (horizontal date list) → REFACTOR
   - Selected day emphasized
   - Event indicator dots
4. ✅ Section Header ("Today's Activities")
5. 🟡 Activity Card → NEW COMPONENT
   - Icon: 36px circle with Electrolyte background
   - Title: "10 MILE RUN"
   - Details: "18.8 mi • 10:30/mi"
   - Action buttons: Checkmark (Orange outline) and X (Dragonfruit outline)
6. ✅ Section Header ("Upcoming Events")
7. 🟡 Event Card → NEW COMPONENT
   - Icon: 36px circle
   - Title: "KULTURE CITY HALF MARATHON"
   - Details: "13 Days Away!"
   - Date Badge: "Nov 22"
8. 🟡 Bottom Navigation → REFACTOR EXISTING

#### **Layout Differences:**
- Two sections: Today's Activities and Upcoming Events
- Activity cards have action buttons
- Event cards have date badges on right

**Priority:** 🟡 MEDIUM

---

### **Screen 5: Adjust Your Macros** 🔴 MODERATE-HIGH REFACTOR

**Figma Screenshots:** #9 (Light), #10 (Dark)

**Current File:** ✅ `/lib/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart`

#### **Components in Screenshot:**
1. ✅ Custom App Bar with Back Button → REFACTOR
2. ✅ Activity Header ("During this Run" + "18 h • 12Mi")
3. 🟡 Large Stats (2 columns) → NEW COMPONENT
   - PACE: "9:00/mi" with clock icon
   - TOTAL BURN: "823" with flame icon
4. 🟡 Macro Targets Table → NEW COMPONENT
   - Title with info icon
   - 4 rows × 3 columns
   - Values and labels
5. ✅ Secondary Buttons ("Edit Macros", "Reset All") → REFACTOR
6. ✅ Primary Button ("Create Plan") → REFACTOR

#### **Layout Differences:**
- Large stat display at top
- Table with borders and structured layout
- Two secondary buttons side-by-side
- Primary button at bottom

**Priority:** 🔴 HIGH (important screen with complex table)

---

### **Screen 6: Food Preferences** 🟡 MODERATE REFACTOR

**Figma Screenshots:** #11 (Light), #12 (Dark)

**Current File:** ✅ `/lib/features/settings/presentation/screens/food_preferences_edit_screen.dart`
**Shared Content:** `/lib/shared/widgets/food_preferences_content.dart`

#### **Components in Screenshot:**
1. ✅ Custom App Bar with Back Button → REFACTOR
2. 🟡 Search Input → REFACTOR EXISTING
   - Height: 46px
   - Border radius: 15px
   - Icons on right (barcode scan, search)
3. 🟡 Food Preference List Items → NEW COMPONENT
   - Icon: 36px circle with Electrolyte background
   - Food name: Compadre Wide 12px uppercase
   - Preference slider (5 points)
   - X icon (left) and Heart icon (right)
4. 🟡 Preference Slider → NEW COMPONENT
5. ✅ Primary Button ("Save Changes") → REFACTOR

#### **Layout Differences:**
- List of food items with sliders
- Each item has icon, name, slider
- "Avoid" on left, "Love" on right
- Icons use Font Awesome

#### **Current vs. Kyle's Design:**
- Existing slider likely uses Flutter default
- Icons probably don't have Electrolyte background
- Slider needs to be 5-point discrete system

**Priority:** 🟡 MEDIUM (important UX but isolated feature)

---

## 🆕 New Components to Create

### Priority: 🔴 CRITICAL
1. **Food/Activity Icon Component** - Used everywhere, brand visual element
2. **Plus/Minus Controls** - Used in 3+ screens
3. **Activity Type Selector** - Key input component
4. **Segmented Control** - Key input component
5. **Nutrition Section Card** - Core feature component
6. **Food Item Card** - Core feature component
7. **Preference Slider** - Key UX component
8. **Macro Targets Table** - Important data display

### Priority: 🟡 MEDIUM
9. **Add Food Button** - Frequent interaction
10. **Large Stat Display** - Data visualization
11. **Activity Card** (Today's Activities)
12. **Event Card** (Upcoming Events)
13. **Date Picker** (with "Edit" link)
14. **Time Picker** (with "Edit" link)

### Priority: 🟢 LOW (Can defer)
15. **Weather Icon**
16. **Date Badge**
17. **Circular Icon Button** (generic)

---

## 🔄 Implementation Phases

### **Phase 0: Foundation** (Days 1-3) ⭐ START HERE
**Goal:** Set up theme system, dark mode support, and Font Awesome Pro

**Tasks:**
1. ✅ Set up Font Awesome Pro
   - Add `font_awesome_flutter_pro` package to `pubspec.yaml`
   - Configure Font Awesome Pro credentials
   - Test icon rendering
   - Document icon mapping (food icons, activity icons, UI icons)

2. ✅ Update `/lib/theme/app_theme.dart`
   - Add exact color values from Figma:
     - Orange: `#F78B14`
     - Electrolyte: `#1CF9CF` (CRITICAL - used for all icons)
     - Dragonfruit: `#DC2597` (already correct as highlight600Alt)
     - Off Cream: `#C6C3B2` (new color for inactive states)
   - Implement `darkTheme` method (Blackberry background, Cream text)
   - Set default to `ThemeMode.dark`
   - Update all color references

3. ✅ Create theme provider with shared_preferences
   ```dart
   // Theme state provider
   @riverpod
   class ThemeMode extends _$ThemeMode {
     @override
     ThemeMode build() {
       // Load from shared_preferences
       final prefs = ref.read(sharedPreferencesProvider);
       final savedTheme = prefs.getString('theme_mode') ?? 'dark';
       return ThemeMode.values.firstWhere(
         (mode) => mode.name == savedTheme,
         orElse: () => ThemeMode.dark,
       );
     }

     Future<void> setThemeMode(ThemeMode mode) async {
       final prefs = ref.read(sharedPreferencesProvider);
       await prefs.setString('theme_mode', mode.name);
       state = mode;
     }
   }
   ```

4. ✅ Add theme switcher to Settings screen
   - Location: `lib/features/settings/presentation/screens/settings_screen.dart`
   - Add SegmentedButton: Light / Dark / System
   - Persist selection to shared_preferences

5. ✅ Test theme switching works app-wide
   - Test all screens in light mode
   - Test all screens in dark mode
   - Verify colors match Figma designs

**Deliverable:**
- Font Awesome Pro working
- App supports light/dark themes with exact Kyle colors
- Defaults to dark mode
- Theme preference saved locally

---

### **Phase 1: Critical Shared Widgets** (Days 3-7)
**Goal:** Create/refactor most frequently used components

**Priority 🔴 CRITICAL Widgets:**
1. Custom App Bar Back Button (REFACTOR)
2. Primary Button (REFACTOR)
3. Secondary Button (REFACTOR)
4. Plus/Minus Controls (NEW)
5. Activity Type Selector (NEW)
6. Segmented Control (NEW)
7. Food/Activity Icon Component (NEW) ⚠️ MOST IMPORTANT
8. Preference Slider (NEW)

**Deliverable:** 8 core components ready for use in screens

---

### **Phase 2: Card Components** (Days 8-10)
**Goal:** Build complex card layouts

**Components:**
1. Nutrition Section Card (NEW)
2. Food Item Card (NEW)
3. Macro Targets Table (NEW)
4. Large Stat Display (NEW)
5. Activity Card (NEW)
6. Event Card (NEW)
7. Add Food Button (NEW)

**Deliverable:** 7 card/display components ready

---

### **Phase 3: Critical Screens Refactoring** (Days 16-30)
**Goal:** Refactor all 26 critical priority screens

**Week 1 (Days 16-20): Core Nutrition Screens**
1. 🔴 `distance_pace_gut_entry_screen.dart` (New Activity - has Figma design)
2. 🔴 `cycling_input_screen.dart`
3. 🔴 `swimming_input_screen.dart`
4. 🔴 `activity_detail_screen.dart` (has Figma design)
5. 🔴 `adjust_macros_screen.dart` (has Figma design)

**Week 2 (Days 21-25): Calendar & Events**
6. 🔴 Calendar Month View widgets (has Figma design)
7. 🔴 Calendar Week View widgets (has Figma design)
8. 🔴 `event_creation_screen.dart`
9. 🔴 `event_edit_screen.dart`
10. 🔴 `event_only_edit_screen.dart`
11. 🔴 `event_form_screen.dart`

**Week 3 (Days 26-30): Core Features Continued**
12. 🔴 `event_detail_screen.dart`
13. 🔴 `events_list_screen.dart`
14. 🔴 `activity_creation_screen.dart`
15. 🔴 `activities_list_screen.dart`

**Week 4 (Days 31-35): Settings & Onboarding**
16. 🔴 `settings_screen.dart` (includes theme toggle)
17. 🔴 `settings_menu_screen.dart`
18. 🔴 `food_preferences_edit_screen.dart` (has Figma design)
19. 🔴 `welcome_screen.dart` (first impression)
20. 🔴 `user_profile_screen.dart`

**Final Critical Screens (Days 36-40):**
21. 🔴 `sport_preferences_screen.dart`
22. 🔴 `food_preferences_screen.dart` (onboarding version)

**Deliverable:** 26 critical screens fully redesigned with dark/light theme support

---

### **Phase 4: Medium Priority Screens** (Days 41-50)
**Goal:** Refactor all 21 medium priority screens

**Week 1 (Days 41-45): Carb Loading & Settings**
1. 🟡 `current_plan_screen.dart`
2. 🟡 `swap_food_screen.dart`
3. 🟡 All 6 Carb Loading screens
4. 🟡 `profile_settings_screen.dart`
5. 🟡 `sport_settings_screen.dart`

**Week 2 (Days 46-50): Supporting Features**
6. 🟡 `preferences_screen.dart`
7. 🟡 `help_feedback_screen.dart`
8. 🟡 All 3 User Journal screens
9. 🟡 All 7 Feedback/Survey screens
10. 🟡 `barcode_scanner_screen.dart`
11. 🟡 `add_food_screen.dart`
12. 🟡 `weather_detail_screen.dart`
13. 🟡 `share_nutrition_plan_screen.dart`

**Deliverable:** 21 medium priority screens fully redesigned

---

### **Phase 5: Low Priority & Final Screens** (Days 51-55)
**Goal:** Complete remaining screens and polish

**Tasks:**
1. 🟢 `sample_plan_demo.dart`
2. 🟢 `debug_screen.dart`
3. 🟢 `recipes_screen.dart`
4. Cross-screen consistency review
5. Dark/light theme verification on all 51 screens
6. Icon consistency check (all use Electrolyte background)

**Deliverable:** All 51 screens updated

---

### **Phase 6: Testing, QA & Polish** (Days 56-60)
**Goal:** Ensure production quality

**Tasks:**
1. **Comprehensive Testing:**
   - Test all 51 screens in light mode
   - Test all 51 screens in dark mode
   - Test theme switching on every screen
   - Verify all icons use Electrolyte `#1CF9CF`

2. **Accessibility Audit:**
   - Color contrast ratios (WCAG AA)
   - Touch target sizes (minimum 44×44pt)
   - Screen reader support
   - Keyboard navigation (if applicable)

3. **Performance Optimization:**
   - 60fps target on all screens
   - Optimize icon loading
   - Optimize card rendering in long lists
   - Memory profiling

4. **Quality Checks:**
   - Designer review (Kyle approval)
   - Cross-platform testing (iOS + Android)
   - Different device sizes
   - Animation smoothness

5. **Bug Fixes:**
   - Address any issues found in testing
   - Final polish and cleanup

**Deliverable:** Production-ready app with Kyle's design system fully implemented

---

## 📊 Summary Statistics

### Refactoring Scope (UPDATED)
- **Total screens to refactor:** 51 screens (ALL screens in the app)
  - 🔴 Critical priority: 26 screens (core features + onboarding)
  - 🟡 Medium priority: 21 screens (supporting features)
  - 🟢 Low priority: 4 screens (demo/debug)
- **Existing widgets to refactor:** 7 widgets
- **New components to create:** 15 components
- **Theme system changes:** Major (add dark mode, update colors, add Font Awesome Pro)

### Time Estimates (UPDATED for 51 screens)
- **Phase 0 (Foundation):** 3 days (theme + Font Awesome Pro setup)
- **Phase 1 (Critical Widgets):** 7 days (8 core components + tests)
- **Phase 2 (Card Components):** 5 days (7 complex components)
- **Phase 3 (Critical Screens):** 15 days (26 critical screens)
- **Phase 4 (Medium Priority Screens):** 10 days (21 medium screens)
- **Phase 5 (Low Priority + Polish):** 5 days (4 low priority + polish)
- **Phase 6 (Testing & QA):** 5 days (comprehensive testing)
- **Total:** 50 days (10 weeks / 2.5 months)

### Priority Breakdown
- 🔴 **Critical:** 8 components + 2 screens + theme system
- 🟡 **Medium:** 7 components + 4 screens
- 🟢 **Low:** 3 components (can defer)

---

## ✅ Questions Answered

### User Decisions (Lee):

1. **New Activity Screen Location:**
   - ✅ Found: `distance_pace_gut_entry_screen.dart`
   - ✅ Cycling/Swimming have separate input screens but similar structure

2. **Existing Icon System:**
   - ✅ Can use Font Awesome Pro Flutter package
   - ✅ Need to set up FA Pro package

3. **Theme Persistence:**
   - ✅ Use `shared_preferences` (local only, no sync)
   - ✅ No Supabase sync needed

4. **Scope Confirmation:**
   - ✅ **ALL screens** need updating to new style guide (49 total screens identified)
   - ✅ No landscape layouts to worry about
   - ✅ Mobile portrait only

5. **Priorities:**
   - ✅ Timeline is fine (will be extended for 49 screens)
   - ✅ No screens blocking other features

6. **Testing:**
   - ⏳ To be determined during implementation

---

## 📝 Implementation Notes

### Critical Considerations

1. **Electrolyte Color Change** ⚠️
   - Old: `#5DE4D3`
   - New: `#1CF9CF`
   - This is a **major visual change** affecting every icon in the app
   - All food icons, activity icons, event indicators use this color

2. **Dark Mode Default**
   - App must default to dark mode (user requirement)
   - Light mode available but not default
   - System mode should respect OS preference

3. **FOA Compliance**
   - All UI changes in presentation layer only
   - No business logic modifications
   - Controllers access ContentService for text
   - Use `@riverpod` AsyncNotifier pattern

4. **Backwards Compatibility**
   - Old and new components can coexist during migration
   - Gradual rollout by screen
   - Feature flags if needed for AB testing

5. **Performance**
   - Target 60fps on all devices
   - Lazy load icons/images
   - Optimize card rendering for long lists

---

**Next Steps:**
1. Get user answers to outstanding questions
2. Begin Phase 0 (Theme Foundation)
3. Set up component library structure
4. Start building critical widgets

---

**Document Status:** ✅ COMPLETE - Ready for review and user input
