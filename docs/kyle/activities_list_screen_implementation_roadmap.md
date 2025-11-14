# Activities List Screen - Implementation Roadmap
## Kyle's Design System Integration

**Created:** 2025-11-13
**Status:** Ready for Implementation
**Priority:** P0 - Critical Path
**Figma Sources:**
- Dark Mode: https://www.figma.com/design/4FvaeGejofuETyP5LUIxQK/Kyle-s-Mockups?node-id=1-2207
- Light Mode: https://www.figma.com/design/4FvaeGejofuETyP5LUIxQK/Kyle-s-Mockups?node-id=1-2157
- Month View (Dark): https://www.figma.com/design/4FvaeGejofuETyP5LUIxQK/Kyle-s-Mockups?node-id=1-1850
- Month View (Light): https://www.figma.com/design/4FvaeGejofuETyP5LUIxQK/Kyle-s-Mockups?node-id=1-1782

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Design Analysis](#design-analysis)
3. [Current State Analysis](#current-state-analysis)
4. [Widget Inventory](#widget-inventory)
5. [Implementation Phases](#implementation-phases)
6. [Technical Specifications](#technical-specifications)
7. [Testing Strategy](#testing-strategy)

---

## Executive Summary

### Goals
Transform the Activities List screen to match Kyle's design system exactly, including:
- Replace bottom navigation bar with floating action buttons
- Implement week/month calendar toggle
- Add action buttons (check/X) to activity cards
- Integrate "Today's Activities" and "Upcoming Events" sections
- Apply Kyle's design tokens (colors, typography, spacing)

### Scope
- **Primary File:** `lib/features/activities/presentation/screens/activities_list_screen.dart`
- **Navigation:** `lib/shared/widgets/tabs_screen.dart`
- **Widgets:** Calendar components, activity cards, floating buttons
- **Features:** Activities + Events + Calendar integration

### Timeline Estimate
- **Phase 1** (Navigation): 2-3 hours
- **Phase 2** (Calendar Integration): 3-4 hours
- **Phase 3** (Activity Cards): 2-3 hours
- **Phase 4** (Sections & Layout): 2-3 hours
- **Phase 5** (Testing & Polish): 2-3 hours
- **Total:** 11-16 hours (2 days)

---

## Design Analysis

### Screen Structure (Kyle's Design)

```
┌─────────────────────────────────────┐
│  November 2025                      │ ← Title (Sansita Bold 17px, centered)
│  [BY MONTH]  BY WEEK                │ ← Toggle (underlined = selected)
├─────────────────────────────────────┤
│  S   M   T   W   T   F   S          │ ← Week view days
│  9  10  11  12  13  14  15          │   (Selected has Cream bg, rounded)
│  ●   ●       ●           ●          │ ← Cyan dots = activities scheduled
├─────────────────────────────────────┤
│  Today's Activities                 │ ← Section header (Sansita Bold 17px)
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐  │
│  │ ● 10 MILE RUN         ✓  ✕   │  │ ← Activity card with check/X
│  │   10.0 mi • 10:30/mi          │  │
│  └───────────────────────────────┘  │
├─────────────────────────────────────┤
│  Upcoming Events                    │ ← Section header (Sansita Bold 17px)
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐  │
│  │ ● KULTURE CITY HALF MARATHON  │  │ ← Event card (no check/X)
│  │   12 Days Away!      Nov 22   │  │
│  └───────────────────────────────┘  │
│                                     │
│  (Empty space)                      │
│                                     │
├─────────────────────────────────────┤
│        ⚪📅  ⚪...  🟠➕           │ ← Floating action buttons
└─────────────────────────────────────┘
```

### Key Visual Elements

#### 1. Header Section
- **Title:** "November 2025" (Sansita Bold, 17px, centered)
- **Toggle:** "BY MONTH" / "BY WEEK" (Compadre Regular, 8px)
  - Selected state: underline (1px solid line, 40px wide)
  - Positioned below month title

#### 2. Calendar Week View
**Layout:**
- 7 columns (S M T W T F S)
- Day abbreviations: Apercu Mono, 12px
- Day numbers: Compadre Regular, 18px
- Selected day: Cream (#F8F6EB) background, 40px × 60px rounded rectangle (15px radius)
- Activity indicators: Cyan dots (#1CF9CF), 6px diameter, centered below day number

**Spacing:**
- Days evenly distributed across screen width
- 8px between day abbreviation and number
- 6px between day number and indicator dot
- 1px divider line below week view

#### 3. Today's Activities Section
**Header:**
- Text: "Today's Activities" (Sansita Bold, 17px)
- Color: Cream (dark mode) / Blackberry (light mode)
- Margin: 16px left, 16px top

**Activity Cards:**
- Background: Transparent (no card background)
- Layout: Horizontal row
- Components:
  - **Icon:** 36px cyan circle with sport icon (left)
  - **Title:** "10 MILE RUN" (Compadre Regular, 12px, all caps)
  - **Details:** "10.0 mi • 10:30/mi" (Apercu Mono, 8px)
  - **Check button:** 26px circle, transparent with Cream border (right)
  - **X button:** 26px circle, transparent with Cream border (right)
- Spacing: 8px between icon and text, 8px between check/X buttons

#### 4. Upcoming Events Section
**Header:**
- Text: "Upcoming Events" (Sansita Bold, 17px)
- Same styling as Today's Activities header

**Event Cards:**
- Same layout as activity cards
- **NO check/X buttons** (events are not completable)
- Components:
  - **Icon:** 36px cyan circle with event icon (left)
  - **Title:** "KULTURE CITY HALF MARATHON" (Compadre Regular, 12px, all caps)
  - **Details:** "12 Days Away!" (Apercu Mono, 8px, left side)
  - **Date:** "Nov 22" (Apercu Mono, 8px top / Compadre Regular, 14px bottom, right side)

#### 5. Floating Action Buttons (Bottom Navigation Replacement)
**Container:**
- Position: Fixed bottom, centered horizontally
- Background: Pill-shaped container
- Border: 1px solid Cream (dark) or Blackberry (light)
- Border radius: 25px (fully rounded pill)
- Padding: Buttons inside container

**Buttons:**
1. **Calendar Button (Left):**
   - Icon: Calendar grid icon (Font Awesome calendar)
   - Size: 42px × 42px
   - Background: Blackberry circle (dark mode) / Cream circle (light mode)
   - Icon color: Cream (dark mode) / Blackberry (light mode)
   - Action: Toggle between week/month calendar views

2. **Menu Button (Center):**
   - Icon: Three dots (Font Awesome ellipsis)
   - Size: 42px × 42px
   - Background: Transparent
   - Icon color: Cream (dark mode) / Blackberry (light mode)
   - Action: Navigate to Settings screen

3. **Plus Button (Right):**
   - Icon: Plus sign (Font Awesome plus)
   - Size: 42px × 42px
   - Background: Orange (#F78B14)
   - Icon color: Cream or Blackberry
   - Action: Create new activity

**Spacing:**
- 8px gap between buttons inside container
- Container positioned 16px from bottom
- Container positioned centered horizontally

#### 6. Empty States
**No Upcoming Events:**
- Gray calendar icon (large, centered)
- Text: "NO UPCOMING EVENTS" (Compadre Wide, gray)
- Subtext: "Tap to add a race event" (Apercu, smaller, gray)

**No Activities:**
- Gray calendar icon (large, centered)
- Text: "No activities scheduled" (Compadre Wide, gray)
- Date: "2025-11-12" (Apercu, smaller, gray)

### Color Specifications (Kyle's Design Tokens)

#### Dark Mode (Primary)
- **Background:** Blackberry (#381633)
- **Text:** Cream (#F8F6EB)
- **Selected Day Background:** Cream (#F8F6EB)
- **Selected Day Text:** Blackberry (#381633)
- **Activity Dot:** Electrolyte (#1CF9CF)
- **Divider:** Cream with 20% opacity
- **Button Borders:** Cream (#F8F6EB)
- **Orange Accent:** #F78B14

#### Light Mode
- **Background:** Cream (#F8F6EB)
- **Text:** Blackberry (#381633)
- **Selected Day Background:** Blackberry (#381633)
- **Selected Day Text:** Cream (#F8F6EB)
- **Activity Dot:** Electrolyte (#1CF9CF)
- **Divider:** Blackberry with 20% opacity
- **Button Borders:** Blackberry (#381633)
- **Orange Accent:** #F78B14

---

## Current State Analysis

### Existing Files

#### `lib/shared/widgets/tabs_screen.dart`
**Current Implementation:**
- Bottom navigation bar with 3 tabs (Activities, Survey, Settings)
- Material Design style (white container, rounded corners)
- Uses `IndexedStack` to maintain state
- Icons: `Icons.list_alt`, `Icons.assignment`, `Icons.settings`

**What Changes:**
- ❌ **REMOVE:** Entire bottom navigation bar
- ✅ **KEEP:** Tab switching logic (IndexedStack approach)
- ✅ **ADD:** Floating action buttons (Kyle's design)

#### `lib/features/activities/presentation/screens/activities_list_screen.dart`
**Current Implementation:**
- Uses `CalendarDatePicker` widget (custom calendar)
- Shows "Upcoming Event" widget
- Lists activities for selected date
- `FloatingActionButton.extended` for "New Activity"
- Empty state: calendar icon + "No activities scheduled" text

**What Changes:**
- ✅ **KEEP:** Overall structure (SafeArea > Column > Calendar > List)
- ✅ **REFACTOR:** Calendar widget to support week/month toggle
- ✅ **ADD:** "Today's Activities" and "Upcoming Events" section headers
- ✅ **REFACTOR:** Activity cards to add check/X buttons
- ❌ **REMOVE:** FloatingActionButton (replaced by bottom buttons)

#### `lib/features/activities/presentation/widgets/activity_card.dart`
**Current Implementation:**
- Shows activity icon, title, date/time, status indicator
- Supports swipe-to-delete
- Has `_confirmDelete` and `_handleDelete` methods
- Status indicator shows completion state

**What Changes:**
- ✅ **KEEP:** Core layout (icon, title, details)
- ✅ **KEEP:** Swipe-to-delete functionality
- ✅ **ADD:** Check button (mark complete)
- ✅ **ADD:** X button (delete)
- ✅ **REFACTOR:** Visual styling to match Kyle's design (remove card background, adjust spacing)

#### `lib/features/events/presentation/widgets/upcoming_event_widget.dart`
**Current Implementation:**
- Shows single upcoming event
- Format: event name + countdown ("12 Days Away!")

**What Changes:**
- ✅ **KEEP:** Core functionality
- ✅ **REFACTOR:** Visual styling to match activity cards
- ✅ **ENSURE:** NO check/X buttons on event cards

### Existing Kyle Design Widgets

Located in `lib/shared/widgets/kyle_design/`:

**Buttons:**
- ✅ `primary_button.dart` - Can use for Orange plus button
- ✅ `secondary_button.dart` - May need for other buttons
- ✅ `tertiary_button.dart` - Not needed for this screen
- ✅ `segmented_control.dart` - **USE for BY MONTH / BY WEEK toggle**
- ❌ Circular icon button - **NEED TO CREATE** for calendar/menu/plus buttons

**Cards:**
- ✅ `base_card.dart` - May use as base
- ❌ Activity card with actions - **NEED TO CREATE/REFACTOR**
- ❌ Event card - **NEED TO CREATE/REFACTOR**

**Icons:**
- ✅ `activity_icon.dart` - **USE** for activity/event icons
- ✅ `food_icon.dart` - Not needed for this screen

**Inputs:**
- ❌ Calendar toggle - Part of segmented control or custom widget

---

## Widget Inventory

### Widgets to CREATE (New)

#### 1. `FloatingActionButtonsBar` (lib/shared/widgets/kyle_design/navigation/floating_action_buttons_bar.dart)
**Purpose:** Bottom navigation replacement with Kyle's floating button design

**Specifications:**
```dart
class FloatingActionButtonsBar extends StatelessWidget {
  final VoidCallback onCalendarTap;
  final VoidCallback onMenuTap;
  final VoidCallback onAddTap;

  // Pill-shaped container with 3 circular buttons
  // Border: 1px solid, theme-aware
  // Border radius: 25px (fully rounded)
  // Positioned: 16px from bottom, centered
}
```

**Components:**
- Pill container (91px width × 43px height)
- Calendar button (42px circle, left)
- Menu button (42px circle, center)
- Plus button (42px circle, right, orange background)

#### 2. `CircularActionButton` (lib/shared/widgets/kyle_design/buttons/circular_action_button.dart)
**Purpose:** Individual circular buttons for floating bar

**Specifications:**
```dart
class CircularActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor; // Defaults to transparent
  final Color? iconColor; // Theme-aware
  final double size; // Default: 42px

  // Circular container with icon
  // Size: 42px × 42px
  // Background: theme-aware or custom
  // Icon: 20px
}
```

#### 3. `ActivityActionButtons` (lib/features/activities/presentation/widgets/activity_action_buttons.dart)
**Purpose:** Check and X buttons for activity cards

**Specifications:**
```dart
class ActivityActionButtons extends StatelessWidget {
  final VoidCallback onCheckTap;
  final VoidCallback onDeleteTap;
  final bool isCompleted; // Show filled check if true

  // Two 26px circular buttons side by side
  // 8px gap between buttons
  // Border: 1px solid Cream/Blackberry
  // Icons: checkmark and X (Font Awesome)
}
```

#### 4. `CalendarViewToggle` (lib/features/calendar/presentation/widgets/calendar_view_toggle.dart)
**Purpose:** BY MONTH / BY WEEK toggle above calendar

**Specifications:**
```dart
class CalendarViewToggle extends StatelessWidget {
  final CalendarViewMode selectedMode; // enum: month, week
  final ValueChanged<CalendarViewMode> onModeChanged;

  // Two text buttons side by side
  // Selected: underline (1px solid, 40px wide)
  // Font: Compadre Regular, 8px
  // Spacing: centered, 20px apart
}

enum CalendarViewMode { month, week }
```

#### 5. `SectionHeaderText` (lib/shared/widgets/kyle_design/typography/section_header_text.dart)
**Purpose:** Reusable section headers ("Today's Activities", "Upcoming Events")

**Specifications:**
```dart
class SectionHeaderText extends StatelessWidget {
  final String text;

  // Sansita Bold, 17px
  // Theme-aware color (Cream/Blackberry)
  // Padding: 16px left, 16px top
}
```

#### 6. `TodaysActivityCard` (lib/features/activities/presentation/widgets/todays_activity_card.dart)
**Purpose:** Activity card styled for "Today's Activities" section

**Specifications:**
```dart
class TodaysActivityCard extends StatelessWidget {
  final Activity activity;
  final VoidCallback onCheckTap;
  final VoidCallback onDeleteTap;
  final VoidCallback onTap;

  // Horizontal layout:
  // - 36px cyan icon circle (left)
  // - Title + details (center, expanded)
  // - Check/X buttons (right)
  //
  // Background: Transparent
  // Supports swipe-to-delete
}
```

#### 7. `UpcomingEventCard` (lib/features/events/presentation/widgets/upcoming_event_card.dart)
**Purpose:** Event card for "Upcoming Events" section (refactor existing)

**Specifications:**
```dart
class UpcomingEventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  // Horizontal layout:
  // - 36px cyan icon circle (left)
  // - Title + countdown (center, expanded)
  // - Date (right, top: small text, bottom: large number)
  //
  // Background: Transparent
  // NO check/X buttons
}
```

#### 8. `CalendarWeekViewKyle` (lib/features/calendar/presentation/widgets/calendar_week_view_kyle.dart)
**Purpose:** Week calendar view matching Kyle's design exactly

**Specifications:**
```dart
class CalendarWeekViewKyle extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final Map<DateTime, bool> datesWithActivities; // For cyan dots

  // 7 columns (S M T W T F S)
  // Day abbreviations: Apercu Mono, 12px
  // Day numbers: Compadre Regular, 18px
  // Selected: Cream bg (dark) / Blackberry bg (light), 40×60px, 15px radius
  // Activity dots: 6px cyan circles
  // 1px divider line below
}
```

#### 9. `CalendarMonthViewKyle` (lib/features/calendar/presentation/widgets/calendar_month_view_kyle.dart)
**Purpose:** Month calendar view matching Kyle's design

**Specifications:**
```dart
class CalendarMonthViewKyle extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final Map<DateTime, bool> datesWithActivities; // For cyan dots

  // Full month grid (7 columns × ~5 rows)
  // Day numbers only (no abbreviations in cells)
  // Selected: circle with highlight
  // Activity dots: 6px cyan circles below day numbers
  // S M T W T F S header row
}
```

### Widgets to REFACTOR (Existing)

#### 1. `tabs_screen.dart`
**Changes:**
- Remove traditional bottom navigation bar
- Add `FloatingActionButtonsBar` widget at bottom
- Keep IndexedStack for tab switching
- Calendar button: toggles calendar view mode (state management)
- Menu button: navigates to Settings screen
- Plus button: navigates to Activity Creation screen

#### 2. `activities_list_screen.dart`
**Changes:**
- Add state for calendar view mode (week/month)
- Replace `CalendarDatePicker` with conditional rendering:
  - `CalendarWeekViewKyle` (default)
  - `CalendarMonthViewKyle` (when toggled)
- Add `CalendarViewToggle` above calendar
- Add "Today's Activities" section header
- Add "Upcoming Events" section header
- Replace `ActivityCard` with `TodaysActivityCard`
- Replace `UpcomingEventWidget` with `UpcomingEventCard`
- Remove FloatingActionButton (now in tabs_screen)

#### 3. `activity_card.dart`
**Changes:**
- Simplify to remove card background (transparent)
- Adjust spacing to match Kyle's design (more compact)
- Add `ActivityActionButtons` widget
- Keep swipe-to-delete functionality
- Update icon size to 36px
- Update typography: Compadre Regular 12px (title), Apercu Mono 8px (details)

#### 4. `upcoming_event_widget.dart`
**Changes:**
- Create new `UpcomingEventCard` widget (similar structure to activity card)
- Remove check/X buttons (events are not completable)
- Add date display on right side (Nov 22 format)
- Match visual styling to activity cards

### Widgets to REUSE (No Changes)

#### 1. `activity_icon.dart` (lib/shared/widgets/kyle_design/icons/activity_icon.dart)
- Already 36px cyan circle with icon
- Perfect for activity/event cards
- Use as-is

#### 2. `segmented_control.dart` (lib/shared/widgets/kyle_design/buttons/segmented_control.dart)
- Could potentially use for BY MONTH / BY WEEK toggle
- May need slight styling adjustments (underline instead of border)
- Evaluate: might be easier to create custom `CalendarViewToggle` widget

---

## Implementation Phases

### Phase 1: Navigation Refactoring (2-3 hours)

**Objective:** Replace bottom navigation bar with Kyle's floating buttons

**Tasks:**

#### 1.1 Create `CircularActionButton` Widget
**File:** `lib/shared/widgets/kyle_design/buttons/circular_action_button.dart`

```dart
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class CircularActionButton extends StatelessWidget {
  const CircularActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 42.0,
    this.iconSize = 20.0,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBg = backgroundColor ?? Colors.transparent;
    final defaultIconColor = iconColor ??
      (isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: defaultBg,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon),
        iconSize: iconSize,
        color: defaultIconColor,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
```

**Testing:**
- [ ] Renders correct size (42px × 42px)
- [ ] Icon color is theme-aware
- [ ] Background color can be customized
- [ ] OnPressed callback fires correctly
- [ ] Works in both light and dark modes

#### 1.2 Create `FloatingActionButtonsBar` Widget
**File:** `lib/shared/widgets/kyle_design/navigation/floating_action_buttons_bar.dart`

```dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../theme/app_theme.dart';
import '../buttons/circular_action_button.dart';

class FloatingActionButtonsBar extends StatelessWidget {
  const FloatingActionButtonsBar({
    super.key,
    required this.onCalendarTap,
    required this.onMenuTap,
    required this.onAddTap,
  });

  final VoidCallback onCalendarTap;
  final VoidCallback onMenuTap;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          height: 43,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularActionButton(
                icon: FontAwesomeIcons.calendar,
                onPressed: onCalendarTap,
                backgroundColor: isDark
                  ? AppTheme.kyleBlackberry
                  : AppTheme.kyleCream,
              ),
              const SizedBox(width: 8),
              CircularActionButton(
                icon: FontAwesomeIcons.ellipsis,
                onPressed: onMenuTap,
              ),
              const SizedBox(width: 8),
              CircularActionButton(
                icon: FontAwesomeIcons.plus,
                onPressed: onAddTap,
                backgroundColor: AppTheme.kyleOrange,
                iconColor: AppTheme.kyleCream,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Testing:**
- [ ] Container positioned 16px from bottom
- [ ] Container centered horizontally
- [ ] Pills shape (border radius 25px)
- [ ] 1px border with correct color
- [ ] Three buttons render correctly
- [ ] 8px spacing between buttons
- [ ] Callbacks fire correctly

#### 1.3 Update `tabs_screen.dart`
**File:** `lib/shared/widgets/tabs_screen.dart`

**Changes:**
```dart
// Remove bottom navigation bar section
// Add state for calendar view mode (if needed here)

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppTheme.baseCream,
    body: Stack(
      children: [
        IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        FloatingActionButtonsBar(
          onCalendarTap: () {
            // TODO: Toggle calendar view (will implement in Phase 2)
            // For now, just log or do nothing
          },
          onMenuTap: () {
            setState(() {
              _currentIndex = 2; // Navigate to Settings
            });
          },
          onAddTap: () {
            // Navigate to Activity Creation
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ActivityCreationScreen(
                  selectedDate: DateTime.now(),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}
```

**Testing:**
- [ ] Bottom navigation bar removed
- [ ] Floating buttons appear at bottom
- [ ] Menu button navigates to Settings
- [ ] Plus button navigates to Activity Creation
- [ ] Calendar button logs tap (functionality in Phase 2)

**Acceptance Criteria:**
- ✅ Traditional bottom nav bar is completely removed
- ✅ Floating action buttons bar renders at bottom
- ✅ Menu button switches to Settings tab
- ✅ Plus button navigates to Activity Creation screen
- ✅ Visual matches Kyle's design (pill shape, spacing, colors)

---

### Phase 2: Calendar Integration (3-4 hours)

**Objective:** Add week/month toggle and integrate calendar views

**Tasks:**

#### 2.1 Create `CalendarViewToggle` Widget
**File:** `lib/features/calendar/presentation/widgets/calendar_view_toggle.dart`

```dart
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

enum CalendarViewMode { month, week }

class CalendarViewToggle extends StatelessWidget {
  const CalendarViewToggle({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  final CalendarViewMode selectedMode;
  final ValueChanged<CalendarViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildToggleOption(
          context,
          'BY MONTH',
          CalendarViewMode.month,
          textColor,
        ),
        const SizedBox(width: 20),
        _buildToggleOption(
          context,
          'BY WEEK',
          CalendarViewMode.week,
          textColor,
        ),
      ],
    );
  }

  Widget _buildToggleOption(
    BuildContext context,
    String label,
    CalendarViewMode mode,
    Color textColor,
  ) {
    final isSelected = selectedMode == mode;

    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Compadre',
              fontSize: 8,
              color: textColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          if (isSelected)
            Container(
              height: 1,
              width: 40,
              color: textColor,
            ),
        ],
      ),
    );
  }
}
```

**Testing:**
- [ ] Renders two options (BY MONTH, BY WEEK)
- [ ] Selected option shows underline
- [ ] Font: Compadre Regular, 8px
- [ ] Underline: 1px solid, 40px wide
- [ ] Tap changes selection
- [ ] Callback fires with correct mode

#### 2.2 Create `CalendarWeekViewKyle` Widget
**File:** `lib/features/calendar/presentation/widgets/calendar_week_view_kyle.dart`

```dart
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class CalendarWeekViewKyle extends StatelessWidget {
  const CalendarWeekViewKyle({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.datesWithActivities = const {},
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final Map<DateTime, bool> datesWithActivities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate week start (Sunday)
    final weekStart = _getWeekStart(selectedDate);
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Column(
      children: [
        // Month/Year title
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            _formatMonthYear(selectedDate),
            style: const TextStyle(
              fontFamily: 'Sansita',
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Day abbreviations row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: weekDays.map((date) {
            return Expanded(
              child: Text(
                _getDayAbbreviation(date.weekday % 7),
                style: TextStyle(
                  fontFamily: 'Apercu',
                  fontSize: 12,
                  color: isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 8),

        // Day numbers row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: weekDays.map((date) {
            final isSelected = _isSameDay(date, selectedDate);
            final hasActivity = datesWithActivities[_dateKey(date)] ?? false;

            return Expanded(
              child: GestureDetector(
                onTap: () => onDateSelected(date),
                child: Container(
                  height: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontFamily: 'Compadre',
                          fontSize: 18,
                          color: isSelected
                              ? (isDark ? AppTheme.kyleBlackberry : AppTheme.kyleCream)
                              : (isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (hasActivity)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppTheme.kyleElectrolyte,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Divider line
        Container(
          height: 1,
          color: (isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry)
              .withOpacity(0.2),
        ),
      ],
    );
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  String _getDayAbbreviation(int weekday) {
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return days[weekday];
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _dateKey(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
```

**Testing:**
- [ ] Renders 7 days (Sunday to Saturday)
- [ ] Shows month/year title (Sansita Bold 17px)
- [ ] Day abbreviations: Apercu Mono 12px
- [ ] Day numbers: Compadre Regular 18px
- [ ] Selected day has correct background color
- [ ] Activity dots appear for dates with activities
- [ ] Tap changes selected date
- [ ] Divider line renders below

#### 2.3 Create `CalendarMonthViewKyle` Widget
**File:** `lib/features/calendar/presentation/widgets/calendar_month_view_kyle.dart`

```dart
// Similar structure to CalendarWeekViewKyle
// But shows full month grid (7 columns × 5-6 rows)
// Refer to month_light.png and month_dark.png screenshots
```

**Testing:**
- [ ] Renders full month grid
- [ ] Shows all days of month + overflow from prev/next month
- [ ] Selected day highlighted
- [ ] Activity dots on dates with activities
- [ ] Tap changes selected date

#### 2.4 Update `activities_list_screen.dart` for Calendar Toggle
**File:** `lib/features/activities/presentation/screens/activities_list_screen.dart`

**Changes:**
```dart
class _ActivitiesListScreenState extends ConsumerState<ActivitiesListScreen> {
  DateTime _selectedDate = DateTime.now();
  CalendarViewMode _calendarMode = CalendarViewMode.week; // ADD THIS

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      body: SafeArea(
        child: Column(
          children: [
            // ADD: Calendar View Toggle
            CalendarViewToggle(
              selectedMode: _calendarMode,
              onModeChanged: (mode) {
                setState(() {
                  _calendarMode = mode;
                });
              },
            ),

            // REPLACE: Conditional calendar rendering
            if (_calendarMode == CalendarViewMode.week)
              CalendarWeekViewKyle(
                selectedDate: _selectedDate,
                onDateSelected: (date) {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                datesWithActivities: _buildActivityMap(activitiesState),
              )
            else
              CalendarMonthViewKyle(
                selectedDate: _selectedDate,
                onDateSelected: (date) {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                datesWithActivities: _buildActivityMap(activitiesState),
              ),

            Expanded(
              child: _buildContent(activitiesState, upcomingEvent, carbLoadingState),
            ),
          ],
        ),
      ),
    );
  }

  Map<DateTime, bool> _buildActivityMap(AsyncValue activitiesState) {
    // Build map of dates with activities for cyan dots
    return activitiesState.maybeWhen(
      data: (activities) {
        final map = <DateTime, bool>{};
        for (final activity in activities) {
          final date = DateTime(
            activity.scheduledDateTime.year,
            activity.scheduledDateTime.month,
            activity.scheduledDateTime.day,
          );
          map[date] = true;
        }
        return map;
      },
      orElse: () => {},
    );
  }
}
```

**Testing:**
- [ ] Calendar toggle appears above calendar
- [ ] BY WEEK shows week view
- [ ] BY MONTH shows month view
- [ ] Selected date persists when switching views
- [ ] Activity dots show correctly in both views

#### 2.5 Connect Calendar Toggle to FloatingActionButtonsBar
**File:** `lib/shared/widgets/tabs_screen.dart`

**Changes:**
```dart
// Need to communicate calendar toggle to ActivitiesListScreen
// Options:
// 1. Use Riverpod state provider
// 2. Pass callback through navigation
// 3. Use GlobalKey to access child state (not recommended)

// RECOMMENDED: Create Riverpod state provider
// lib/features/calendar/presentation/providers/calendar_view_provider.dart

@riverpod
class CalendarViewNotifier extends _$CalendarViewNotifier {
  @override
  CalendarViewMode build() => CalendarViewMode.week;

  void toggleView() {
    state = state == CalendarViewMode.week
      ? CalendarViewMode.month
      : CalendarViewMode.week;
  }

  void setView(CalendarViewMode mode) {
    state = mode;
  }
}

// Then in tabs_screen.dart:
FloatingActionButtonsBar(
  onCalendarTap: () {
    ref.read(calendarViewNotifierProvider.notifier).toggleView();
  },
  // ...
)

// And in activities_list_screen.dart:
final calendarMode = ref.watch(calendarViewNotifierProvider);
```

**Testing:**
- [ ] Calendar button toggles between week/month
- [ ] State persists across tab switches
- [ ] Visual feedback shows current mode

**Acceptance Criteria:**
- ✅ BY MONTH / BY WEEK toggle renders correctly
- ✅ Week view shows 7 days with selection and activity dots
- ✅ Month view shows full month grid
- ✅ Calendar button in floating bar toggles view
- ✅ Selected date persists across view changes
- ✅ Activity dots show on dates with scheduled activities

---

### Phase 3: Activity Cards Refactoring (2-3 hours)

**Objective:** Update activity cards to match Kyle's design with check/X buttons

**Tasks:**

#### 3.1 Create `ActivityActionButtons` Widget
**File:** `lib/features/activities/presentation/widgets/activity_action_buttons.dart`

```dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../theme/app_theme.dart';

class ActivityActionButtons extends StatelessWidget {
  const ActivityActionButtons({
    super.key,
    required this.onCheckTap,
    required this.onDeleteTap,
    this.isCompleted = false,
  });

  final VoidCallback onCheckTap;
  final VoidCallback onDeleteTap;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildButton(
          icon: FontAwesomeIcons.check,
          onTap: onCheckTap,
          borderColor: borderColor,
          isFilled: isCompleted,
        ),
        const SizedBox(width: 8),
        _buildButton(
          icon: FontAwesomeIcons.xmark,
          onTap: onDeleteTap,
          borderColor: borderColor,
          isFilled: false,
        ),
      ],
    );
  }

  Widget _buildButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color borderColor,
    required bool isFilled,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: isFilled ? borderColor : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 10,
          color: isFilled
              ? (borderColor == AppTheme.kyleCream
                  ? AppTheme.kyleBlackberry
                  : AppTheme.kyleCream)
              : borderColor,
        ),
      ),
    );
  }
}
```

**Testing:**
- [ ] Two 26px circular buttons render
- [ ] 8px gap between buttons
- [ ] Check button shows filled when completed
- [ ] X button always transparent
- [ ] Border color theme-aware
- [ ] Tap callbacks fire correctly

#### 3.2 Refactor `activity_card.dart`
**File:** `lib/features/activities/presentation/widgets/activity_card.dart`

**Changes:**
```dart
// Current structure:
// - Card container with background
// - Icon, title, details in a row
// - Status indicator
// - Swipe to delete

// New structure:
// - NO card background (transparent)
// - Icon (36px cyan circle), title/details, action buttons
// - Keep swipe to delete
// - More compact spacing

@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return Dismissible(
    key: Key(activity.id),
    direction: DismissDirection.endToStart,
    onDismissed: (_) => _handleDelete(context, ref),
    confirmDismiss: (_) => _confirmDelete(context),
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 16),
      color: AppTheme.kyleDragonfruit,
      child: const Icon(Icons.delete, color: Colors.white),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          // Activity Icon (36px cyan circle)
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppTheme.kyleElectrolyte,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getActivityIcon(activity.activityType),
              size: 18,
              color: AppTheme.kyleBlackberry,
            ),
          ),

          const SizedBox(width: 12),

          // Title and Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatActivityTitle(activity),
                  style: TextStyle(
                    fontFamily: 'Compadre',
                    fontSize: 12,
                    color: isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatActivityDetails(activity),
                  style: TextStyle(
                    fontFamily: 'Apercu',
                    fontSize: 8,
                    color: isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Action Buttons
          ActivityActionButtons(
            onCheckTap: () => _handleComplete(context, ref),
            onDeleteTap: () async {
              if (await _confirmDelete(context) == true) {
                _handleDelete(context, ref);
              }
            },
            isCompleted: activity.isCompleted ?? false,
          ),
        ],
      ),
    ),
  );
}

Future<void> _handleComplete(BuildContext context, WidgetRef ref) async {
  // Toggle completion status
  final updatedActivity = activity.copyWith(
    isCompleted: !(activity.isCompleted ?? false),
  );

  // Update via controller
  await ref.read(activitiesControllerProvider.notifier)
    .updateActivity(updatedActivity);
}
```

**Testing:**
- [ ] Card has NO background (transparent)
- [ ] Icon is 36px cyan circle
- [ ] Title: Compadre Regular 12px
- [ ] Details: Apercu Mono 8px
- [ ] Check/X buttons appear on right
- [ ] Swipe to delete still works
- [ ] Check button marks as complete
- [ ] X button shows confirmation dialog

#### 3.3 Create `SectionHeaderText` Widget
**File:** `lib/shared/widgets/kyle_design/typography/section_header_text.dart`

```dart
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class SectionHeaderText extends StatelessWidget {
  const SectionHeaderText({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Sansita',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry,
        ),
      ),
    );
  }
}
```

**Testing:**
- [ ] Renders text with correct font
- [ ] Padding: 16px left, 16px top, 8px bottom
- [ ] Color theme-aware
- [ ] Sansita Bold 17px

**Acceptance Criteria:**
- ✅ Activity cards have transparent background
- ✅ 36px cyan icon circles
- ✅ Typography matches Kyle's design (Compadre 12px, Apercu 8px)
- ✅ Check and X buttons appear and function correctly
- ✅ Check button toggles completion status
- ✅ X button shows confirmation and deletes
- ✅ Swipe to delete still works

---

### Phase 4: Sections & Layout (2-3 hours)

**Objective:** Add "Today's Activities" and "Upcoming Events" sections

**Tasks:**

#### 4.1 Refactor `upcoming_event_widget.dart`
**File:** `lib/features/events/presentation/widgets/upcoming_event_widget.dart`

**Current:** Simple widget showing event name + countdown

**New:** Create `UpcomingEventCard` matching activity card styling

```dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/event.dart';

class UpcomingEventCard extends StatelessWidget {
  const UpcomingEventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  final Event event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            // Event Icon (36px cyan circle)
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppTheme.kyleElectrolyte,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                FontAwesomeIcons.personRunning,
                size: 18,
                color: AppTheme.kyleBlackberry,
              ),
            ),

            const SizedBox(width: 12),

            // Title and Countdown
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Compadre',
                      fontSize: 12,
                      color: isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCountdown(event.date),
                    style: TextStyle(
                      fontFamily: 'Apercu',
                      fontSize: 8,
                      color: isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Date Display (right side)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatMonthShort(event.date),
                  style: TextStyle(
                    fontFamily: 'Apercu',
                    fontSize: 8,
                    color: isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry,
                  ),
                ),
                Text(
                  '${event.date.day}',
                  style: TextStyle(
                    fontFamily: 'Compadre',
                    fontSize: 14,
                    color: isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCountdown(DateTime eventDate) {
    final now = DateTime.now();
    final difference = eventDate.difference(now).inDays;

    if (difference == 0) return 'Today!';
    if (difference == 1) return 'Tomorrow!';
    return '$difference Days Away!';
  }

  String _formatMonthShort(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[date.month - 1];
  }
}
```

**Testing:**
- [ ] Renders event name in uppercase
- [ ] Shows countdown ("12 Days Away!")
- [ ] Shows date on right (Nov 22)
- [ ] NO check/X buttons
- [ ] Matches activity card styling
- [ ] Tap callback fires (navigate to event detail)

#### 4.2 Update `activities_list_screen.dart` with Sections
**File:** `lib/features/activities/presentation/screens/activities_list_screen.dart`

**Changes:**
```dart
Widget _buildContent(
  AsyncValue activitiesState,
  AsyncValue upcomingEvent,
  AsyncValue<List<dynamic>> carbLoadingState,
) {
  return activitiesState.when(
    data: (activities) {
      // Filter activities for today
      final todaysActivities = activities.where((activity) {
        return _isSameDay(activity.scheduledDateTime, DateTime.now());
      }).toList();

      return RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activitiesControllerProvider);
          ref.invalidate(nextUpcomingEventProvider);
        },
        child: CustomScrollView(
          slivers: [
            // "Today's Activities" Section
            if (todaysActivities.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeaderText(text: "Today's Activities"),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return ActivityCard(activity: todaysActivities[index]);
                  },
                  childCount: todaysActivities.length,
                ),
              ),
            ],

            // "Upcoming Events" Section
            SliverToBoxAdapter(
              child: SectionHeaderText(text: "Upcoming Events"),
            ),
            SliverToBoxAdapter(
              child: upcomingEvent.when(
                data: (event) {
                  if (event == null) {
                    return _buildNoEventsCard();
                  }
                  return UpcomingEventCard(
                    event: event,
                    onTap: () {
                      // Navigate to event detail
                    },
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // Empty state if no activities and no events
            if (todaysActivities.isEmpty && upcomingEvent.value == null)
              SliverFillRemaining(
                child: _buildEmptyState(),
              ),
          ],
        ),
      );
    },
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, stack) => _buildErrorState(error),
  );
}

Widget _buildNoEventsCard() {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: (isDark ? AppTheme.kyleBlackberry : AppTheme.kyleCream)
          .withOpacity(0.5),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      children: [
        Icon(
          Icons.calendar_month,
          size: 48,
          color: (isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry)
              .withOpacity(0.5),
        ),
        const SizedBox(height: 12),
        Text(
          'NO UPCOMING EVENTS',
          style: TextStyle(
            fontFamily: 'Compadre',
            fontSize: 14,
            color: (isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry)
                .withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap to add a race event',
          style: TextStyle(
            fontFamily: 'Apercu',
            fontSize: 12,
            color: (isDark ? AppTheme.kyleCream : AppTheme.kyleBlackberry)
                .withOpacity(0.5),
          ),
        ),
      ],
    ),
  );
}
```

**Testing:**
- [ ] "Today's Activities" header appears
- [ ] Today's activities listed below header
- [ ] "Upcoming Events" header appears
- [ ] Event card shows below header
- [ ] Empty event card shows if no events
- [ ] Empty state shows if nothing scheduled

**Acceptance Criteria:**
- ✅ "Today's Activities" section with header
- ✅ "Upcoming Events" section with header
- ✅ Activity cards render in Today's section
- ✅ Event card renders in Upcoming section
- ✅ No event card matches Kyle's design
- ✅ Empty states match Kyle's design

---

### Phase 5: Testing & Polish (2-3 hours)

**Objective:** Test all functionality and polish visuals

**Tasks:**

#### 5.1 Visual Verification
- [ ] Compare with Kyle's screenshots (dark mode)
- [ ] Compare with Kyle's screenshots (light mode)
- [ ] Verify all colors match design tokens
- [ ] Verify all typography matches (Sansita, Compadre, Apercu)
- [ ] Verify all spacing matches (8pt grid)
- [ ] Verify all border radius values (15px cards, 100px buttons)
- [ ] Verify icon sizes (36px circles, 20px icons)

#### 5.2 Functional Testing
- [ ] Bottom floating buttons:
  - [ ] Calendar button toggles week/month view
  - [ ] Menu button navigates to Settings
  - [ ] Plus button navigates to Activity Creation
- [ ] Calendar views:
  - [ ] Week view shows 7 days
  - [ ] Month view shows full month
  - [ ] Selected date highlighted
  - [ ] Activity dots show on correct dates
  - [ ] Date selection works
- [ ] Activity cards:
  - [ ] Check button marks complete
  - [ ] X button shows confirmation and deletes
  - [ ] Swipe to delete works
  - [ ] Tap card navigates to detail
- [ ] Event cards:
  - [ ] NO check/X buttons
  - [ ] Shows countdown
  - [ ] Shows date
  - [ ] Tap navigates to event detail
- [ ] Sections:
  - [ ] "Today's Activities" shows today's items
  - [ ] "Upcoming Events" shows next event
  - [ ] Empty states show correctly

#### 5.3 Edge Cases
- [ ] No activities scheduled (empty state)
- [ ] No events scheduled (no events card)
- [ ] Many activities (scrolling works)
- [ ] Past activities (should not show in Today's)
- [ ] Future activities (should not show in Today's)
- [ ] Completed activities (check button filled)
- [ ] Very long activity names (text truncation)
- [ ] Very long event names (text truncation)

#### 5.4 Theme Testing
- [ ] Light mode: all colors correct
- [ ] Dark mode: all colors correct
- [ ] Theme switching: no visual glitches
- [ ] System theme: respects OS setting

#### 5.5 Device Testing
- [ ] iPhone SE (small screen)
- [ ] iPhone 14 Pro (medium screen)
- [ ] iPhone 14 Pro Max (large screen)
- [ ] iPad (tablet layout)
- [ ] Android phone (Material differences)

#### 5.6 Performance Testing
- [ ] Smooth scrolling with 50+ activities
- [ ] Calendar animations smooth
- [ ] No jank when toggling views
- [ ] No memory leaks

#### 5.7 Code Quality
- [ ] Run `flutter analyze` (no errors)
- [ ] All widgets properly documented
- [ ] No hardcoded strings (use content service if needed)
- [ ] Proper error handling
- [ ] Proper null safety

**Acceptance Criteria:**
- ✅ Visual match with Kyle's design: 95%+ accuracy
- ✅ All functional requirements met
- ✅ No analyzer errors or warnings
- ✅ Works on iOS and Android
- ✅ Smooth performance (60fps)
- ✅ No regressions in existing functionality

---

## Technical Specifications

### Design Tokens Reference

#### Colors
```dart
// lib/theme/app_theme.dart

static const kyleBlackberry = Color(0xFF381633); // Dark bg
static const kyleCream = Color(0xFFF8F6EB);      // Light bg
static const kyleOrange = Color(0xFFF78B14);     // Primary action
static const kyleElectrolyte = Color(0xFF1CF9CF); // Icons/accents
static const kyleDragonfruit = Color(0xFFDC2597); // Warnings
static const kyleOffCream = Color(0xFFC6C3B2);    // Inactive
```

#### Typography
```dart
// Font families
static const sansitaBold = 'Sansita';      // Weight: 700
static const compadreRegular = 'Compadre'; // Weight: 400
static const apercuMono = 'Apercu';        // Weight: 400

// Text styles
static const screenTitle = TextStyle(
  fontFamily: sansitaBold,
  fontSize: 17,
  fontWeight: FontWeight.w700,
);

static const activityTitle = TextStyle(
  fontFamily: compadreRegular,
  fontSize: 12,
  fontWeight: FontWeight.w400,
);

static const activityDetails = TextStyle(
  fontFamily: apercuMono,
  fontSize: 8,
  fontWeight: FontWeight.w400,
);

static const calendarDayAbbrev = TextStyle(
  fontFamily: apercuMono,
  fontSize: 12,
  fontWeight: FontWeight.w400,
);

static const calendarDayNumber = TextStyle(
  fontFamily: compadreRegular,
  fontSize: 18,
  fontWeight: FontWeight.w400,
);

static const toggleLabel = TextStyle(
  fontFamily: compadreRegular,
  fontSize: 8,
  fontWeight: FontWeight.w400,
);
```

#### Spacing
```dart
static const double spacing4 = 4.0;
static const double spacing8 = 8.0;
static const double spacing12 = 12.0;
static const double spacing16 = 16.0;
static const double spacing20 = 20.0;
static const double spacing24 = 24.0;
```

#### Sizes
```dart
static const double iconCircleSize = 36.0;
static const double iconSize = 18.0;
static const double actionButtonSize = 26.0;
static const double floatingButtonSize = 42.0;
static const double calendarDayHeight = 60.0;
static const double activityDotSize = 6.0;
```

#### Border Radius
```dart
static const double cardRadius = 15.0;
static const double buttonRadius = 100.0; // Fully rounded
static const double pillRadius = 25.0;
```

### State Management

#### Calendar View State
```dart
// lib/features/calendar/presentation/providers/calendar_view_provider.dart

@riverpod
class CalendarViewNotifier extends _$CalendarViewNotifier {
  @override
  CalendarViewMode build() => CalendarViewMode.week;

  void toggleView() {
    state = state == CalendarViewMode.week
      ? CalendarViewMode.month
      : CalendarViewMode.week;
  }

  void setView(CalendarViewMode mode) {
    state = mode;
  }
}
```

### Navigation Flow

```
TabsScreen (Root)
├── FloatingActionButtonsBar
│   ├── Calendar Button → Toggle calendarViewProvider
│   ├── Menu Button → Set tab index to 2 (Settings)
│   └── Plus Button → Navigate to ActivityCreationScreen
│
├── IndexedStack
│   ├── [0] ActivitiesListScreen
│   │   ├── CalendarViewToggle (BY MONTH / BY WEEK)
│   │   ├── CalendarWeekViewKyle OR CalendarMonthViewKyle
│   │   ├── "Today's Activities" section
│   │   │   └── ActivityCard (with check/X buttons)
│   │   └── "Upcoming Events" section
│   │       └── UpcomingEventCard (no check/X buttons)
│   │
│   ├── [1] FeatureSurveyScreen
│   └── [2] SettingsScreen
```

### File Structure

```
lib/
├── features/
│   ├── activities/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── activities_list_screen.dart (REFACTOR)
│   │       └── widgets/
│   │           ├── activity_card.dart (REFACTOR)
│   │           ├── activity_action_buttons.dart (NEW)
│   │           └── todays_activity_card.dart (OPTIONAL)
│   │
│   ├── calendar/
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── calendar_view_provider.dart (NEW)
│   │       └── widgets/
│   │           ├── calendar_view_toggle.dart (NEW)
│   │           ├── calendar_week_view_kyle.dart (NEW)
│   │           └── calendar_month_view_kyle.dart (NEW)
│   │
│   └── events/
│       └── presentation/
│           └── widgets/
│               ├── upcoming_event_widget.dart (REFACTOR)
│               └── upcoming_event_card.dart (NEW)
│
└── shared/
    └── widgets/
        ├── tabs_screen.dart (REFACTOR)
        │
        └── kyle_design/
            ├── buttons/
            │   └── circular_action_button.dart (NEW)
            │
            ├── navigation/
            │   └── floating_action_buttons_bar.dart (NEW)
            │
            └── typography/
                └── section_header_text.dart (NEW)
```

---

## Testing Strategy

### Unit Tests

#### Widget Tests
```dart
// test/features/calendar/widgets/calendar_view_toggle_test.dart
test('CalendarViewToggle shows underline for selected mode', () {
  // Test that underline appears under selected option
});

test('CalendarViewToggle calls callback on tap', () {
  // Test that onModeChanged is called with correct mode
});

// test/shared/widgets/kyle_design/buttons/circular_action_button_test.dart
test('CircularActionButton renders with correct size', () {
  // Test that button is 42x42px
});

test('CircularActionButton uses theme-aware colors', () {
  // Test light and dark mode colors
});

// test/features/activities/widgets/activity_action_buttons_test.dart
test('ActivityActionButtons shows filled check when completed', () {
  // Test completed state
});

test('ActivityActionButtons calls correct callbacks', () {
  // Test onCheckTap and onDeleteTap
});
```

#### Provider Tests
```dart
// test/features/calendar/providers/calendar_view_provider_test.dart
test('CalendarViewNotifier toggles between week and month', () {
  // Test toggle functionality
});

test('CalendarViewNotifier sets specific view', () {
  // Test setView method
});
```

### Integration Tests

```dart
// integration_test/activities_list_screen_test.dart
testWidgets('Full activities list flow', (tester) async {
  // 1. Launch app
  // 2. Verify week view is default
  // 3. Tap BY MONTH toggle
  // 4. Verify month view shows
  // 5. Select a date
  // 6. Verify activities for that date show
  // 7. Tap check button on activity
  // 8. Verify activity marked complete
  // 9. Tap X button on activity
  // 10. Verify confirmation dialog
  // 11. Confirm delete
  // 12. Verify activity removed
  // 13. Tap calendar button in floating bar
  // 14. Verify view toggles
  // 15. Tap plus button
  // 16. Verify navigation to creation screen
  // 17. Tap menu button
  // 18. Verify navigation to settings
});
```

### Visual Regression Tests

Use Flutter's golden tests to compare screenshots:

```dart
// test/golden/activities_list_screen_golden_test.dart
testWidgets('ActivitiesListScreen matches golden (dark mode)', (tester) async {
  await tester.pumpWidget(/* ... */);
  await expectLater(
    find.byType(ActivitiesListScreen),
    matchesGoldenFile('activities_list_dark.png'),
  );
});

testWidgets('ActivitiesListScreen matches golden (light mode)', (tester) async {
  await tester.pumpWidget(/* ... */);
  await expectLater(
    find.byType(ActivitiesListScreen),
    matchesGoldenFile('activities_list_light.png'),
  );
});
```

### Manual Testing Checklist

#### Visual Testing
- [ ] Screenshot comparison with Kyle's Figma designs
- [ ] All colors match exactly (use color picker)
- [ ] All fonts match (Sansita, Compadre, Apercu)
- [ ] All spacing matches (use ruler tool)
- [ ] All border radius correct (15px, 100px, 25px)
- [ ] All icon sizes correct (36px, 26px, 20px)
- [ ] Activity dots are 6px cyan circles

#### Interaction Testing
- [ ] Calendar toggle switches views
- [ ] Date selection highlights correctly
- [ ] Activity dots show on correct dates
- [ ] Check button marks activity complete
- [ ] X button deletes activity (with confirmation)
- [ ] Swipe to delete works
- [ ] Floating calendar button toggles view
- [ ] Floating menu button navigates to settings
- [ ] Floating plus button creates activity
- [ ] Event card tap navigates to event detail
- [ ] Activity card tap navigates to activity detail

#### Theme Testing
- [ ] Light mode colors correct
- [ ] Dark mode colors correct
- [ ] Theme toggle works
- [ ] System theme respected
- [ ] No visual glitches when switching

#### Responsive Testing
- [ ] Small screens (iPhone SE): layout doesn't break
- [ ] Medium screens (iPhone 14 Pro): optimal layout
- [ ] Large screens (iPhone 14 Pro Max): no wasted space
- [ ] Tablets (iPad): consider larger layout
- [ ] Landscape mode: graceful handling

---

## Success Metrics

### Visual Accuracy
- ✅ 95%+ match with Kyle's Figma designs
- ✅ All design tokens correctly implemented
- ✅ No hardcoded colors or sizes
- ✅ Theme system fully functional

### Functional Completeness
- ✅ All user interactions work as designed
- ✅ No regressions in existing features
- ✅ Calendar toggle functional
- ✅ Activity completion functional
- ✅ Activity deletion functional
- ✅ Navigation functional

### Code Quality
- ✅ No analyzer warnings or errors
- ✅ Proper widget composition (small, reusable)
- ✅ Proper state management (Riverpod patterns)
- ✅ Proper error handling
- ✅ Proper null safety
- ✅ Adequate test coverage (60%+ for new code)

### Performance
- ✅ 60fps scrolling
- ✅ No jank or stuttering
- ✅ Fast calendar view switching (<100ms)
- ✅ Fast date selection (<50ms)
- ✅ No memory leaks

### User Experience
- ✅ Intuitive interactions
- ✅ Clear visual feedback
- ✅ Proper confirmation dialogs
- ✅ Helpful empty states
- ✅ Smooth animations

---

## Rollout Plan

### Phase 1: Development (Days 1-2)
- Implement all features per phases above
- Unit tests for all new widgets
- Integration tests for critical paths

### Phase 2: Internal Testing (Day 3)
- QA testing on multiple devices
- Visual regression testing
- Performance profiling
- Bug fixes

### Phase 3: Beta Release (Day 4)
- Deploy to TestFlight/Internal Testing
- Gather feedback from beta testers
- Monitor crash reports
- Fix critical issues

### Phase 4: Production Release (Day 5)
- Deploy to App Store / Play Store
- Monitor user feedback
- Quick hotfix capability ready
- Document any learnings

---

## Rollback Plan

### If Critical Issues Found

**Option 1: Quick Fix**
- If issue is minor and fixable in <2 hours
- Deploy hotfix immediately
- Test and release

**Option 2: Feature Flag**
- Add feature flag for new Activities List
- Toggle off in production
- Fix issue in development
- Toggle back on when ready

**Option 3: Revert**
- If major issue, revert entire changes
- Restore previous tabs_screen implementation
- Restore previous activities_list_screen implementation
- Release reverted version
- Fix issues thoroughly before retry

---

## Dependencies

### Flutter Packages
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.0
  font_awesome_flutter: ^10.6.0
  # ... existing dependencies
```

### Fonts
Ensure these are in `pubspec.yaml`:
```yaml
fonts:
  - family: Sansita
    fonts:
      - asset: assets/fonts/Sansita/Sansita-Bold.ttf
        weight: 700

  - family: Compadre
    fonts:
      - asset: assets/fonts/Compadre/Compadre-Regular.ttf
        weight: 400

  - family: Apercu
    fonts:
      - asset: assets/fonts/Apercu/Apercu-Regular.ttf
        weight: 400
      - asset: assets/fonts/Apercu/Apercu-Medium.ttf
        weight: 500
```

### Icons
Font Awesome package provides all needed icons:
- `FontAwesomeIcons.calendar` (calendar button)
- `FontAwesomeIcons.ellipsis` (menu button)
- `FontAwesomeIcons.plus` (add button)
- `FontAwesomeIcons.check` (complete button)
- `FontAwesomeIcons.xmark` (delete button)
- `FontAwesomeIcons.personRunning` (activity/event icon)

---

## Appendix

### Kyle's Design Screenshots Reference

1. **activities_list_dark.png** - Dark mode activities list (week view)
2. **activities_list_light.png** - Light mode activities list (week view)
3. **month_dark.png** - Dark mode calendar month view
4. **month_light.png** - Light mode calendar month view
5. **current_list.png** - Current implementation (for comparison)

### Figma Links

- Dark Week View: [node-id=1-2207](https://www.figma.com/design/4FvaeGejofuETyP5LUIxQK/Kyle-s-Mockups?node-id=1-2207)
- Light Week View: [node-id=1-2157](https://www.figma.com/design/4FvaeGejofuETyP5LUIxQK/Kyle-s-Mockups?node-id=1-2157)
- Dark Month View: [node-id=1-1850](https://www.figma.com/design/4FvaeGejofuETyP5LUIxQK/Kyle-s-Mockups?node-id=1-1850)
- Light Month View: [node-id=1-1782](https://www.figma.com/design/4FvaeGejofuETyP5LUIxQK/Kyle-s-Mockups?node-id=1-1782)

### Related Documentation

- [Kyle's Design System README](./README.md)
- [Design Tokens](./DESIGN_TOKENS.md)
- [Components Catalog](./COMPONENTS_CATALOG.md)
- [Implementation Guide](./IMPLEMENTATION_GUIDE.md)
- [P0 Restoration Complete](./P0_RESTORATION_COMPLETE.md)

---

**Document Status:** ✅ Ready for Implementation
**Created:** 2025-11-13
**Owner:** Development Team
**Reviewer:** Kyle (Designer)
