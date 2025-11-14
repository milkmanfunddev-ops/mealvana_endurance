# Component Catalog - Kyle's Design System
## Visual Reference Guide for All UI Components

**Last Updated:** 2025-11-12
**Source:** Kyle's Figma Mockups - ✅ EXACT VALUES via MCP Extraction

---

## Table of Contents
1. [Buttons](#buttons)
2. [Form Inputs](#form-inputs)
3. [Cards](#cards)
4. [Navigation](#navigation)
5. [Lists & Items](#lists--items)
6. [Icons & Badges](#icons--badges)
7. [Data Display](#data-display)
8. [Feedback Components](#feedback-components)

---

## Buttons

### 1. Primary Button (Orange)
**Usage:** Main call-to-action (Generate Plan, Save Changes, Create Plan, Complete Workout)

**Visual Specs:** ✅ **EXACT VALUES**
- **Background:** Orange `#F78B14` ✅ (extracted)
- **Text:** Blackberry `#381633` ✅ (extracted) - Sansita Bold, 16px ✅
- **Height:** Auto (content-based with padding) ✅
- **Padding:** 10px vertical, 16px horizontal ✅ (extracted)
- **Border Radius:** 100px ✅ (fully rounded, extracted)
- **Border:** None
- **Shadow:** None (flat design)

**States:**
- Default: Solid Orange `#F78B14`
- Hover: Lighter orange `#F9A042`
- Pressed: Darker orange `#E57D0C`
- Disabled: Orange at 40% opacity

**Code Extract from Figma:**
```html
<div className="bg-[#f78b14] px-[16px] py-[10px] rounded-[100px]">
  <p className="font-['Sansita:Bold'] text-[16px] text-[#381633]">
    GENERATE PLAN
  </p>
</div>
```

**Screenshot Reference:** Visible in all activity screens at bottom

**Flutter File:** `/lib/shared/widgets/primary_button.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Blue gradient background with shadows
- Different padding and styling

**Changes Needed:**
- ✅ Update background color to Orange #F78B14
- ✅ Remove gradient and shadows
- ✅ Update border radius to 100px
- ✅ Update padding to exact specs

---

### 2. Secondary Button (Outlined)
**Usage:** Alternative actions (Edit Macros, Reset All)

**Visual Specs:**
- **Background:** Transparent
- **Border:** 2px solid (Orange for emphasis, Cream/Blackberry for neutral)
- **Text:** Same color as border - Sansita Bold, 16pt
- **Height:** 56px
- **Border Radius:** 16px

**States:**
- Default: Outlined only
- Hover: Subtle fill (10% opacity of border color)
- Pressed: More opaque fill (20% opacity)
- Active: Full color fill

**Screenshot Reference:** "Edit Macros" and "Reset All" buttons in Adjust Macros screen

**Flutter File:** `/lib/shared/widgets/secondary_button.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Transparent with coral/pink outline
- Different styling

**Changes Needed:**
- ✅ Update border colors to Orange/Blackberry
- ✅ Support two color variants
- ✅ Update border radius to 100px

---

### 3. Tertiary Button (Text Only)
**Usage:** Minor actions (Edit, Remove, Swap Food Item)

**Visual Specs:**
- **Background:** Transparent
- **Text:** Dragonfruit (#E84393) - Apercu, 14pt, Medium
- **Icon:** Optional, 16px, same color as text
- **Padding:** 8px vertical, 16px horizontal

**States:**
- Default: Dragonfruit text
- Hover: Slightly darker
- Pressed: Much darker

**Screenshot Reference:** "Edit" link in Activity Details, "Remove Food Item" in expanded food cards

**Flutter File:** `/lib/shared/widgets/tertiary_button.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Different color scheme
- May need styling updates

**Changes Needed:**
- ✅ Update text color to Dragonfruit #E84393
- ✅ Update font to Apercu 14pt Medium

---

### 4. Icon Button (Circular)
**Usage:** Navigation actions, add food, menu

**Visual Specs:** ✅ **EXACT VALUES**
- **Size:** 48x48px
- **Background:**
  - Primary: Orange `#F78B14` ✅
  - Secondary: Electrolyte `#1CF9CF` ✅
  - Neutral: Blackberry `#381633` (light) / Cream `#F8F6EB` (dark)
- **Icon:** 20-24px ✅, contrasting color (usually Blackberry or Cream)
- **Shape:** Fully circular (border-radius: 100px) ✅

**Variants:**
- **Add Button:** Orange background, plus icon
- **Calendar Button:** Neutral background, calendar icon
- **Menu Button:** Neutral background, three dots icon

**Screenshot Reference:** Bottom of calendar screens (3 circular buttons)

**Flutter File:** `/lib/shared/widgets/circular_icon_button.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Different colors and sizing
- Material Icons

**Changes Needed:**
- ✅ Update colors to Orange/Electrolyte/Neutral variants
- ✅ Update size to 48x48px
- ✅ Use Font Awesome icons

---

### 5. Activity Type Selector
**Usage:** Choose activity type (Running, Biking, Swimming)

**Visual Specs:** ✅ **EXACT VALUES**
- **Size:** 62px width × 74px height ✅ (extracted)
- **Border Radius:** 15px ✅ (extracted)
- **Unselected:**
  - Background: Transparent
  - Border: 1px solid Blackberry `#381633` ✅
  - Icon: 36px ✅, Blackberry `#381633` ✅
  - Label: Compadre Regular 12px ✅, Blackberry `#381633` ✅
- **Selected:**
  - Background: Blackberry `#381633` ✅ (filled)
  - Border: 2px solid Blackberry `#381633` ✅
  - Icon: 36px ✅, Cream `#F8F6EB` ✅ (inverted)
  - Label: Compadre Regular 12px ✅, Cream `#F8F6EB` ✅ (inverted)

**Code Extract from Figma:**
```html
<!-- Selected state -->
<div className="size-[62x74] rounded-[15px] border-2 border-[#381633] bg-[#381633]">
  <img className="size-[36px]" /> <!-- Icon -->
  <p className="font-['Compadre:Regular'] text-[12px] text-[#f8f6eb]">Label</p>
</div>
```

**Screenshot Reference:** Top of "New Activity" screen

**Flutter File:** `/lib/features/calendar/presentation/widgets/sport_category_selector.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Horizontal scrollable chips
- Material Icons
- Different sizing

**Changes Needed:**
- ✅ Update to fixed 62px × 74px dimensions
- ✅ Update border radius to 15px
- ✅ Implement selected/unselected states
- ✅ Use Font Awesome activity icons
- ✅ Update typography to Compadre Regular 12px

---

### 6. Segmented Control (Gut Training, Sweat Rate)
**Usage:** Multi-option selection with 2-3 choices

**Visual Specs:** ✅ **EXACT VALUES**
- **Width:** 74-110px (varies by label) ✅
- **Height:** Auto (content-based with padding) ✅
- **Border Radius:** 15px ✅ (extracted)
- **Unselected:**
  - Background: Transparent
  - Border: 1px solid Blackberry `#381633` ✅
  - Text: Sansita Bold 12px ✅, Blackberry `#381633` ✅
  - Subtext: Apercu Mono 10px (if applicable)
- **Selected:**
  - Background: Blackberry `#381633` ✅ (filled)
  - Border: 2px solid Blackberry `#381633` ✅
  - Text: Sansita Bold 12px ✅, Cream `#F8F6EB` ✅ (inverted)

**Code Extract from Figma:**
```html
<!-- Selected segment -->
<div className="rounded-[15px] border-2 border-[#381633] bg-[#381633] px-[16px] py-[10px]">
  <p className="font-['Sansita:Bold'] text-[12px] text-[#f8f6eb]">HIGH</p>
</div>
```

**Screenshot Reference:** "Gut Training Level" and "Sweat Rate" sections in New Activity screen

**Flutter File:** `/lib/shared/widgets/segmented_control.dart` (NEW COMPONENT)

**Current Implementation:**
- Dropdown for gut training
- Slider for sweat rate
- Different interaction patterns

**Changes Needed:**
- ✅ Create new segmented control component
- ✅ Replace dropdown/slider with segmented buttons
- ✅ Use Sansita Bold 12px text
- ✅ Implement selected/unselected states

---

### 7. Plus/Minus Controls
**Usage:** Increment/decrement numeric values (distance, servings, pace)

**Visual Specs:** ✅ **EXACT VALUES** (fully extracted)
- **Container Size:** 36px × 36px ✅ (with 8px padding)
- **Icon Size:** 20px × 20px ✅
- **Border:** 2px solid Orange `#F78B14` ✅
- **Border Radius:** 100px ✅ (fully circular)
- **Background:** Transparent (Cream shows through in light mode)
- **Icon Color:** Blackberry `#381633` ✅ (light mode) / Cream `#F8F6EB` (dark mode)
- **Padding:** 8px ✅

**Layout Pattern:**
```
[−] 12 miles [+]
```
- Buttons on left/right
- Value centered between them
- Value text: Compadre Regular 16px ✅

**Code Extract from Figma:**
```html
<div className="border border-[#f78b14] border-solid rounded-[100px]">
  <div className="p-[8px]">
    <div className="size-[20px]">
      <img src={minusIcon} />
    </div>
  </div>
</div>
<p className="font-['Compadre:Regular'] text-[16px]">12 miles</p>
<div className="border border-[#f78b14] border-solid rounded-[100px]">
  <div className="p-[8px]">
    <div className="size-[20px]">
      <img src={plusIcon} />
    </div>
  </div>
</div>
```

**Screenshot Reference:** Distance controls in New Activity screen, "Adjust Macros" screen

**Flutter File:** `/lib/shared/widgets/increment_decrement_widget.dart` (REFACTOR EXISTING)

**Current Implementation:**
- 40px circular buttons with blue border
- White background with shadows
- Material Icons

**Changes Needed:**
- ✅ Update size to 36px (from 40px)
- ✅ Update border color to Orange #F78B14
- ✅ Remove background and shadows
- ✅ Use Font Awesome icons
- ✅ Update icon colors for themes

---

## Form Inputs

### 1. Text Input Field
**Usage:** Search foods, enter custom values

**Visual Specs:** ✅ **EXACT VALUES**
- **Height:** 46px ✅ (extracted)
- **Background:** Transparent (Cream `#F8F6EB` shows through in light mode) ✅
- **Border:** 1px solid Blackberry `#381633` ✅
- **Border Radius:** 15px ✅ (extracted)
- **Text:** Apercu Mono 14px ✅, Blackberry `#381633` ✅
- **Placeholder:** Same font and color (e.g., "Search Foods") ✅
- **Padding:** 16px horizontal, 12px vertical ✅

**Code Extract from Figma:**
```html
<div className="border border-[#381633] h-[46px] rounded-[15px] w-[342px]">
  <p className="font-['Apercu:Mono'] text-[14px] text-[#381633] left-[36px] top-[128px]">
    Search Foods
  </p>
</div>
```

**With Icon:**
- Icon on right (search, scan barcode)
- Icon size: 24px
- Icon color: Blackberry (light) / Cream (dark)

**Screenshot Reference:** "Search Foods" in Food Preferences screen

**Flutter File:** `/lib/shared/widgets/text_field.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Different styling and colors
- May need height and border updates

**Changes Needed:**
- ✅ Update height to 46px
- ✅ Update border to 1px solid Blackberry
- ✅ Update border radius to 15px
- ✅ Update typography to Apercu Mono 14px

---

### 2. Plus/Minus Control
**Usage:** Adjust numeric values (distance, pace, temperature, humidity)

**Visual Specs:**
- **Buttons:**
  - Size: 40x40px circular
  - Border: 2px solid Orange
  - Icon: Minus or Plus, Orange color
  - Background: Transparent
- **Value Display:**
  - Font: Apercu, 32pt, Semibold (for large numbers like "12 MILES")
  - Font: Apercu, 20pt, Regular (for smaller values like "9:00 MIN / MILE")
  - Color: Current theme text color
- **Layout:** [- Button] [Value] [+ Button]
- **Spacing:** 24px horizontal between elements

**Screenshot Reference:** Distance, Average Pace, Temperature, Humidity controls in New Activity screen

**Flutter File:** `/lib/shared/widgets/kyle_design/inputs/plus_minus_control.dart`

---

### 3. Slider (Food Preferences)
**Usage:** Rate food preference from "Avoid" to "Love"

**Visual Specs:** ✅ **EXACT VALUES**
- **Track:**
  - Width: 276px ✅ (full width between labels)
  - Height: 1px ✅ (thin line)
  - Color: Blackberry `#381633` ✅
- **Points (5 total):**
  - Size: 8px × 8px ✅ circles
  - Positions: Avoid (left), Center-Left, Center, Center-Right, Love (right) ✅
  - Inactive: 8px filled circles, Blackberry `#381633` ✅
  - Partially Active: 16px circles (larger), lighter shade
  - Active Handle: 16-20px ✅ circle, Blackberry `#381633` ✅ filled
- **Labels:**
  - Left: "Avoid" with X icon (Font Awesome 15px) ✅
  - Right: "Love" with Heart icon (Font Awesome 20px) ✅
  - Font: Apercu Mono 10px ✅, Blackberry `#381633` ✅
  - Position: Below track
- **Icon Colors:**
  - X icon: Blackberry `#381633` ✅
  - Heart icon: Blackberry `#381633` ✅

**Screenshot Reference:** Food Preferences screen with sliders for each food item

**Flutter File:** `/lib/shared/widgets/food_preference_widget.dart` (MAJOR REFACTOR)

**Current Implementation:**
- Three-chip selection (❤️ 🤔 ❌)
- Emoji icons
- Different interaction pattern

**Changes Needed:**
- ✅ Complete redesign from chips to slider
- ✅ Implement 5-point discrete system
- ✅ Add track and handle styling
- ✅ Use Font Awesome icons
- ✅ Update labels to "Avoid" to "Love"

---

### 4. Date Picker
**Usage:** Select activity date

**Visual Specs:**
- **Display Format:** "Nov 9, 2025"
- **Font:** Sansita Bold, 24pt
- **Label:** "DATE" - Apercu, 12pt, uppercase
- **Edit Link:** "Edit" in Dragonfruit with pencil icon

**Interaction:** Tap to open native date picker

**Screenshot Reference:** Date display in New Activity and Activity Details screens

**Flutter File:** `/lib/shared/widgets/date_picker.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Different styling
- May need font and color updates

**Changes Needed:**
- ✅ Update font to Sansita Bold 24pt
- ✅ Update label to "DATE" in Apercu 12pt
- ✅ Add "Edit" link with Dragonfruit color

---

### 5. Time Picker
**Usage:** Select activity time

**Visual Specs:**
- **Display Format:** "12:00 pm"
- **Font:** Sansita Bold, 24pt
- **Label:** "TIME" - Apercu, 12pt, uppercase
- **Edit Link:** "Edit" in Dragonfruit with pencil icon (shared with date)

**Interaction:** Tap to open native time picker

**Screenshot Reference:** Time display in New Activity and Activity Details screens

**Flutter File:** `/lib/shared/widgets/time_picker.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Different styling
- May need font and color updates

**Changes Needed:**
- ✅ Update font to Sansita Bold 24pt
- ✅ Update label to "TIME" in Apercu 12pt
- ✅ Add "Edit" link with Dragonfruit color

---

## Cards

### 1. Activity Hero Card
**Usage:** Display activity with large hero image

**Visual Specs:**
- **Background:** Cream (light) / Blackberry Light (dark)
- **Border Radius:** 12px
- **Padding:** 0 (image fills top portion)
- **Hero Image:**
  - Aspect Ratio: ~16:9 or square
  - Border Radius: 12px top corners only
  - Overlay: Pink geometric pattern (star/burst shape)
- **Content:**
  - Padding: 16px
  - Activity type icon (top of image or below)
  - Date/time in large format (Sansita Bold)

**Screenshot Reference:** Top of Activity Details screen

**Flutter File:** `/lib/shared/widgets/activity_hero_card.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Different styling and layout
- May need overlay and font updates

**Changes Needed:**
- ✅ Update border radius to 12px
- ✅ Add pink geometric pattern overlay
- ✅ Update typography to Sansita Bold

---

### 2. Nutrition Section Card
**Usage:** Display Before/During/After run nutrition

**Visual Specs:**
- **Background:** Transparent with border OR subtle fill
- **Border:** 1px solid Cream (dark) / Light gray (light)
- **Border Radius:** 12px
- **Padding:** 16px
- **Header:**
  - Title: "Before Run" / "During Run" / "After Run" - Sansita Bold, 18pt
  - Macros: "97/97g CARBS | 473/444mL FLUIDS | 97/97g SODIUM"
  - Font: Apercu, 12pt
  - Color: Secondary text color
- **Food List:**
  - See "Food Item (Expandable)" component

**Screenshot Reference:** Activity Details screen with three nutrition cards

**Flutter File:** `/lib/features/nutrition_plan/presentation/widgets/expandable_food_item.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Light blue background (#D6E0FF)
- Different header structure
- No macro summary

**Changes Needed:**
- ✅ Update background to transparent/subtle fill
- ✅ Add macro summary header
- ✅ Update typography to match Kyle's specs
- ✅ Update border styling

---

### 3. Food Item (Expandable)
**Usage:** Display individual food item with expand/collapse

**Visual Specs:**
- **Background:** Transparent
- **Border Bottom:** 1px solid divider color
- **Height:** 56px (collapsed), variable (expanded)
- **Padding:** 12px vertical, 16px horizontal

**Collapsed State:**
- **Icon:** 48px circle, Electrolyte background, food icon (28px)
- **Text:** Food name - Compadre Wide, 16pt
- **Chevron:** Down arrow, 20px

**Expanded State:**
- **Icon:** Same
- **Text:** Food name + descriptor
  - Name: Compadre Wide, 16pt
  - Descriptor: Apercu, 14pt, secondary color
- **Quantity Control:** Plus/minus buttons (smaller, 32px)
- **Nutritional Fact:**
  - Grid: Calories | Carbs | Protein | Fat
  - Values: Apercu, 16pt, Semibold
  - Labels: Apercu, 10pt, uppercase
- **Actions:**
  - "Swap Food Item" - Dragonfruit, with X icon
  - "Remove Food Item" - Dragonfruit, with X icon
- **Chevron:** Up arrow

**Screenshot Reference:** Expanded food item in Activity Details screen

**Flutter File:** `/lib/features/nutrition_plan/presentation/widgets/food_item_card.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Different styling and layout
- May need expand/collapse updates

**Changes Needed:**
- ✅ Update to 36px circular icons with Electrolyte background
- ✅ Update typography to Compadre Wide 16pt
- ✅ Add nutritional fact grid
- ✅ Update action buttons to Dragonfruit color

---

### 4. Calendar Event Dot
**Usage:** Indicate events on calendar dates

**Visual Specs:**
- **Size:** 6px diameter circle
- **Color:** Electrolyte (#5DE4D3)
- **Position:** Below date number in calendar cell
- **Multiple Events:** Show up to 3 dots vertically stacked

**Screenshot Reference:** Calendar Month view with dots under dates

**Flutter File:** `/lib/shared/widgets/kyle_design/calendar/event_dot.dart`

---

### 5. Today's Activities Card
**Usage:** Show activity scheduled for today in week view

**Visual Specs:**
- **Background:** Transparent
- **Border Bottom:** 1px solid divider
- **Height:** 64px
- **Layout:**
  - **Icon:** 48px circle, Electrolyte background, activity icon
  - **Text:**
    - Title: "10 MILE RUN" - Compadre Wide, 16pt
    - Details: "18.8 mi • 10:30/mi" - Apercu, 14pt, secondary
  - **Actions:**
    - Checkmark button (circular, Orange outline)
    - X button (circular, Dragonfruit outline)

**Screenshot Reference:** "Today's Activities" section in Week view

**Flutter File:** `/lib/shared/widgets/kyle_design/cards/todays_activity_card.dart`

---

### 6. Upcoming Event Card
**Usage:** Show future events in week view

**Visual Specs:**
- **Background:** Transparent
- **Border Bottom:** 1px solid divider
- **Height:** 64px
- **Layout:**
  - **Icon:** 48px circle, Electrolyte background, runner icon
  - **Text:**
    - Title: "KULTURE CITY HALF MARATHON" - Compadre Wide, 16pt
    - Details: "13 Days Away!" - Apercu, 14pt, secondary
  - **Date Badge:**
    - Right side: "Nov 22"
    - Font: Apercu, 14pt
    - Color: Secondary text

**Screenshot Reference:** "Upcoming Events" section in Week view

**Flutter File:** `/lib/shared/widgets/kyle_design/cards/upcoming_event_card.dart`

---

### 7. Macro Targets Table
**Usage:** Display nutritional targets in a table

**Visual Specs:**
- **Background:** Transparent with border
- **Border:** 1px solid Cream (dark) / Light gray (light)
- **Border Radius:** 12px
- **Padding:** 16px
- **Header:**
  - Title: "Your Nutritional Targets" - Sansita Bold, 18pt
  - Info icon: Dragonfruit, 20px
- **Table:**
  - Columns: PRE | DURING | POST
  - Rows: CARBS, PROTEIN, FLUIDS, SODIUM
  - Values: Apercu, 16pt, Semibold
  - Labels: Apercu, 10pt, uppercase
  - Borders: 1px solid divider color

**Screenshot Reference:** "Adjust Your Macros" screen

**Flutter File:** `/lib/features/nutrition_plan/presentation/widgets/macro_targets_widget.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Progress bars and chips
- Different layout structure
- No table format

**Changes Needed:**
- ✅ Redesign from progress bars to table format
- ✅ Add structured table with borders
- ✅ Update typography to match specs
- ✅ Add info icon and header

---

## Navigation

### 1. App Bar / Header
**Usage:** Screen title and back navigation

**Visual Specs:**
- **Height:** 56px (iOS), 64px (Android)
- **Background:** Transparent
- **Back Button:**
  - Circular, 40x40px
  - Background: Blackberry (light) / Cream (dark) at 10% opacity
  - Icon: Left arrow, 20px
- **Title:**
  - Font: Sansita Bold, 20pt
  - Position: Left-aligned (after back button)
  - Color: Current theme text color
- **Actions:** Optional right-side buttons

**Screenshot Reference:** Every screen has this header

**Flutter File:** `/lib/shared/widgets/custom_app_bar_back_button.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Different styling and colors
- May need transparency updates

**Changes Needed:**
- ✅ Update background to transparent
- ✅ Update back button styling
- ✅ Update title font to Sansita Bold 20pt

---

### 2. Bottom Navigation Bar
**Usage:** Main app navigation (Week View example)

**Visual Specs:**
- **Height:** 72px
- **Background:** Blackberry (dark) / Cream (light)
- **Items:** 3 buttons (Calendar, Menu, Add)
- **Layout:**
  - Spacing: Evenly distributed
  - Shape: Circular buttons (48x48px)
- **Calendar Button:**
  - Background: Neutral (slight fill)
  - Icon: Calendar/grid, 24px
- **Menu Button:**
  - Background: Neutral (slight fill)
  - Icon: Three horizontal dots, 24px
- **Add Button:**
  - Background: Orange
  - Icon: Plus, 24px, Blackberry color
  - Larger emphasis (primary action)

**Screenshot Reference:** Bottom of Calendar screens

**Flutter File:** `/lib/shared/widgets/bottom_nav_bar.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Different colors and styling
- Material Icons

**Changes Needed:**
- ✅ Update colors to match Kyle's specs
- ✅ Update button sizes to 48x48px
- ✅ Use Font Awesome icons
- ✅ Update Add button to Orange

---

### 3. Tab Selector (Month / Week)
**Usage:** Switch between calendar views

**Visual Specs:**
- **Position:** Below month/year title in calendar
- **Layout:** Two options side by side
- **Options:** "BY MONTH" | "BY WEEK"
- **Unselected:**
  - Font: Apercu, 12pt, uppercase
  - Color: Secondary text
  - No underline
- **Selected:**
  - Font: Apercu, 12pt, uppercase, Semibold
  - Color: Primary text
  - Underline: 2px solid, primary text color

**Screenshot Reference:** Top of calendar views

**Flutter File:** `/lib/shared/widgets/tab_selector.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Different styling and colors
- May need underline updates

**Changes Needed:**
- ✅ Update font to Apercu 12pt uppercase
- ✅ Add underline for selected state
- ✅ Update colors to match themes

---

### 4. Week Selector (Horizontal Dates)
**Usage:** Navigate weeks in week view

**Visual Specs:**
- **Layout:** Horizontal scroll, 7 days visible
- **Date Cell:**
  - Size: 48x48px (minimum)
  - **Unselected:**
    - Background: Transparent
    - Day letter: "M", "T", "W", etc. - Apercu, 12pt
    - Date number: Apercu, 16pt
  - **Selected (Today):**
    - Background: Cream (light) / Blackberry Light (dark)
    - Border Radius: 24px (pill shape)
    - Bold text
  - **Has Event:**
    - Electrolyte dot below date number (6px)

**Screenshot Reference:** Week view with horizontal date selector

**Flutter File:** `/lib/features/calendar/presentation/widgets/week_selector.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Different styling and colors
- May need date cell updates

**Changes Needed:**
- ✅ Update date cell styling
- ✅ Add Electrolyte event dots
- ✅ Update selected day styling

---

## Lists & Items

### 1. Calendar Grid (Month View)
**Usage:** Display month calendar

**Visual Specs:**
- **Grid:** 7 columns (S-M-T-W-T-F-S) × 5-6 rows
- **Header:**
  - Day letters: Apercu, 12pt, uppercase
  - Color: Secondary text
- **Date Cells:**
  - Size: Variable based on screen width
  - Padding: 8px
  - Date number: Apercu, 16pt
  - Today: Circular background (Blackberry in light, Cream in dark)
  - Event indicator: Electrolyte dot (6px) below number
- **Spacing:** Minimal (2-4px between cells)

**Screenshot Reference:** Calendar Month view

**Flutter File:** `/lib/features/calendar/presentation/widgets/calendar_month_grid.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Different styling and colors
- May need event indicator updates

**Changes Needed:**
- ✅ Update date cell styling
- ✅ Update event dots to Electrolyte #1CF9CF
- ✅ Update selected day styling

---

### 2. Section Header
**Usage:** Divide content sections (Today's Activities, Upcoming Events)

**Visual Specs:**
- **Font:** Sansita Bold, 18pt
- **Color:** Primary text color
- **Padding:** 16px top, 8px bottom
- **Background:** Transparent

**Screenshot Reference:** "Today's Activities" and "Upcoming Events" headers in Week view

**Flutter File:** `/lib/shared/widgets/section_header.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Different styling and colors
- May need font updates

**Changes Needed:**
- ✅ Update font to Sansita Bold 18pt
- ✅ Update colors to match themes

---

### 3. Divider
**Usage:** Separate list items

**Visual Specs:**
- **Height:** 1px
- **Color:** Cream (dark) at 10% opacity / Blackberry (light) at 10% opacity
- **Margin:** 0 horizontal (full width)

**Screenshot Reference:** Between food items in nutrition cards

**Flutter File:** Standard Flutter `Divider` widget with theme colors

---

### 4. Food Preferences List Item
**Usage:** Display food with preference slider

**Visual Specs:** ✅ **EXACT VALUES**
- **Height:** Auto (content-based, ~96-120px) ✅
- **Layout:**
  - **Icon:** 36px × 36px ✅ circle, Electrolyte `#1CF9CF` ✅ background, food icon (~18px) ✅
  - **Title:** "BAGELS", "ENERGY CHEWS", etc. - Compadre Wide 12px ✅, Blackberry `#381633` ✅
  - **Slider:** Full width preference slider (276px track width) ✅
  - **Labels:** "Avoid" and "Love" - Apercu Mono 10px ✅, Blackberry `#381633` ✅
- **Spacing:** 16px between items, divider lines (1px Blackberry)

**Screenshot Reference:** Food Preferences screen

**Flutter File:** `/lib/shared/widgets/food_preferences_content.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Different styling and layout
- Uses chips instead of slider

**Changes Needed:**
- ✅ Update to use new preference slider
- ✅ Update icons to 36px with Electrolyte background
- ✅ Update typography to Compadre Wide 12px

---

## Icons & Badges

### 1. Activity Icon (Circular)
**Usage:** Indicate activity type

**Visual Specs:** ✅ **EXACT VALUES**
- **Container:**
  - Size: 36px × 36px ✅ (circular, extracted)
  - Background: Electrolyte `#1CF9CF` ✅ (bright cyan, extracted)
  - Shape: Perfect circle
- **Icon:**
  - Size: ~18px ✅ (centered, ~50% of container)
  - Color: Blackberry `#381633` ✅ (extracted)
  - Style: Solid/Sharp (Font Awesome 7)
- **Icon Types:**
  - Running: Runner icon (fa-running)
  - Cycling: Bicycle icon (fa-bicycle)
  - Swimming: Swimmer icon (fa-swimmer)

**Code Extract from Figma:**
```html
<div className="size-[36px]">
  <img src={imgEllipse1} /> <!-- Electrolyte #1CF9CF background -->
</div>
<div className="font-['Font_Awesome_7_Sharp:Regular'] text-[13px] text-[#381633]">
  <!-- Icon character -->
</div>
```

**Critical:** All activity icons use the updated Electrolyte color `#1CF9CF` (bright cyan), not the old estimate.

**Screenshot Reference:** Activity cards, Today's Activities, Upcoming Events

**Flutter File:** `/lib/shared/widgets/activity_icon.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Network image loading
- Different styling and colors

**Changes Needed:**
- ✅ Update to 36px circles with Electrolyte #1CF9CF background
- ✅ Use Font Awesome activity icons
- ✅ Update icon color to Blackberry #381633

---

### 2. Food Icon (Circular)
**Usage:** Indicate food type

**Visual Specs:** ✅ **EXACT VALUES**
- **Container:**
  - Size: 36px × 36px ✅ (circular, extracted - same as activity icons)
  - Background: Electrolyte `#1CF9CF` ✅ (bright cyan, extracted)
  - Shape: Perfect circle
- **Icon:**
  - Size: ~18px ✅ (centered, ~50% of container)
  - Color: Blackberry `#381633` ✅ (extracted)
  - Style: Solid/Sharp (Font Awesome 7 Sharp Regular) ✅
- **Icon Mapping:**
  - Energy bar: Rectangle/bar (fa-bars or similar)
  - Sports drink: Bottle/cup (fa-bottle-water)
  - Banana: Fruit (fa-apple-whole)
  - Salt packets: Square/packet (fa-square)
  - Water: Cup/droplet (fa-droplet)
  - Gel: Pouch (fa-bag)
  - Electrolyte: Pill/circle (fa-circle)
  - Trail mix: Bowl/dots (fa-bowl-food)

**Code Extract from Figma:**
```html
<div className="size-[36px]">
  <img src={imgEllipse5} /> <!-- Electrolyte #1CF9CF background -->
</div>
<div className="font-['Font_Awesome_7_Sharp:Regular'] text-[13px] text-[#381633]">
  <!-- Food icon character -->
</div>
```

**Critical:** All food icons use the exact same style as activity icons - 36px circles with Electrolyte `#1CF9CF` background.

**Screenshot Reference:** Food items in nutrition cards

**Flutter File:** `/lib/shared/widgets/food_icon.dart` (REFACTOR EXISTING)

**Current Implementation:**
- Network image loading with fallback
- White background with shadows
- Different styling

**Changes Needed:**
- ✅ Update background to Electrolyte #1CF9CF
- ✅ Remove shadows and white background
- ✅ Use Font Awesome food icons
- ✅ Standardize size to 36px

---

### 3. Weather Icon (Optional)
**Usage:** Display weather conditions

**Visual Specs:**
- **Size:** 24-32px
- **Color:** Primary text color or accent
- **Style:** Outlined or filled

**Screenshot Reference:** Temperature section shows icon possibility

**Flutter File:** `/lib/shared/widgets/kyle_design/icons/weather_icon.dart`

---

### 4. Date Badge
**Usage:** Show event date in upcoming events

**Visual Specs:**
- **Background:** Transparent
- **Text:** "Nov 22" - Apercu, 14pt, Semibold
- **Color:** Secondary text color
- **Position:** Right side of card

**Screenshot Reference:** Upcoming Events in Week view

**Flutter File:** Part of upcoming event card component

---

## Data Display

### 1. Large Stat Display
**Usage:** Show pace and total burn in Adjust Macros

**Visual Specs:**
- **Layout:** Two columns
- **Icon:** Clock or flame, 32px
- **Label:** "PACE" or "TOTAL BURN" - Apercu, 12pt, uppercase
- **Value:** "9:00/mi" or "823" - Apercu, 48pt, Bold
- **Color:** Primary text

**Screenshot Reference:** Top of Adjust Your Macros screen

**Flutter File:** `/lib/shared/widgets/kyle_design/data/large_stat.dart`

---

### 2. Inline Macro Display
**Usage:** Show carbs/fluids/sodium at top of nutrition sections

**Visual Specs:**
- **Font:** Apercu, 12pt
- **Format:** "97/97g CARBS | 473/444mL FLUIDS | 97/97g SODIUM"
- **Color:** Secondary text color
- **Separator:** " | " between items

**Screenshot Reference:** Top of each nutrition card in Activity Details

**Flutter File:** `/lib/shared/widgets/kyle_design/data/macro_summary.dart`

---

### 3. Nutritional Fact Grid
**Usage:** Show calories, carbs, protein, fat in expanded food item

**Visual Specs:**
- **Layout:** 4 columns (Calories | Carbs | Protein | Fat)
- **Values:**
  - Font: Apercu, 16pt, Semibold
  - Color: Primary text
- **Labels:**
  - Font: Apercu, 10pt, uppercase
  - Color: Secondary text
- **Spacing:** Equal distribution, 8px between columns

**Screenshot Reference:** Expanded food item in Activity Details

**Flutter File:** `/lib/shared/widgets/kyle_design/data/nutrition_fact_grid.dart`

---

### 4. Activity Duration Badge
**Usage:** Show scheduled activity duration

**Visual Specs:**
- **Text:** "18 h • 12MI" - Apercu, 14pt
- **Color:** Secondary text
- **Format:** Duration • Distance

**Screenshot Reference:** Today's Activities in Week view

**Flutter File:** Part of activity card component

---

## Feedback Components

### 1. Loading Indicator
**Usage:** Show loading state

**Visual Specs:**
- **Style:** Circular progress indicator
- **Color:** Orange (#FF8B3D) or Electrolyte (#5DE4D3)
- **Size:** 32px (normal), 20px (in buttons)

**Flutter File:** Standard Flutter `CircularProgressIndicator` with theme color

---

### 2. Empty State
**Usage:** No activities, no events

**Visual Specs:**
- **Icon:** Large (64px), secondary color
- **Title:** Sansita Bold, 20pt
- **Message:** Apercu, 16pt, secondary text
- **Action:** Primary button (e.g., "Add Activity")

**Flutter File:** `/lib/shared/widgets/kyle_design/feedback/empty_state.dart`

---

### 3. Error State
**Usage:** Show error messages

**Visual Specs:**
- **Icon:** Dragonfruit exclamation or X (48px)
- **Title:** Sansita Bold, 18pt, Dragonfruit
- **Message:** Apercu, 16pt, secondary text
- **Action:** Secondary button (e.g., "Try Again")

**Flutter File:** `/lib/shared/widgets/kyle_design/feedback/error_state.dart`

---

### 4. Success Toast
**Usage:** Confirm action success

**Visual Specs:**
- **Background:** Electrolyte (#5DE4D3)
- **Text:** Apercu, 16pt, Blackberry
- **Icon:** Checkmark, 20px, Blackberry
- **Border Radius:** 8px
- **Padding:** 12px vertical, 16px horizontal
- **Position:** Bottom of screen, above navigation
- **Duration:** 3 seconds

**Flutter File:** `/lib/shared/widgets/kyle_design/feedback/success_toast.dart`

---

## Implementation Priority

### Phase 1 (Week 1) - Foundation
- ✅ Primary Button
- ✅ Secondary Button
- ✅ Tertiary Button
- ✅ Text Input
- ✅ Activity Hero Card
- ✅ App Bar

### Phase 2 (Week 2) - Core Components
- ⏳ Plus/Minus Control
- ⏳ Segmented Control
- ⏳ Food Item Card
- ⏳ Nutrition Section Card
- ⏳ Activity Icon
- ⏳ Food Icon

### Phase 3 (Week 3) - Advanced Components
- ⏳ Preference Slider
- ⏳ Calendar Grid
- ⏳ Week Selector
- ⏳ Macro Targets Table
- ⏳ Large Stat Display

### Phase 4 (Week 4) - Polish
- ⏳ Loading states
- ⏳ Empty states
- ⏳ Error states
- ⏳ Success toasts
- ⏳ Animations

---

**Document Status:** Complete Catalog
**Next Step:** Begin implementation in `/lib/shared/widgets/kyle_design/`
