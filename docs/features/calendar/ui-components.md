# Calendar Feature UI Components

## Overview

This document provides comprehensive UI specifications for all components in the Calendar feature. The design maintains consistency with Mealvana Endurance's existing design system while introducing calendar-specific patterns optimized for athletic training workflows.

## Design Principles

### Visual Hierarchy
- **Primary Action**: Always clear what the user should do next
- **Information Density**: Show essential info without overwhelming
- **Status Clarity**: Obvious visual distinction between activity states
- **Touch Friendly**: Minimum 44pt touch targets throughout

### Consistency
- **Color System**: Maintain existing brand colors with calendar extensions
- **Typography**: Use established type scale and weights
- **Spacing**: Follow 8pt grid system
- **Animation**: Consistent motion design across interactions

### Accessibility
- **Contrast**: WCAG AA compliance for all text and interactive elements
- **Screen Readers**: Proper semantic markup and ARIA labels
- **Touch Targets**: 44pt minimum for all interactive elements
- **Focus Management**: Clear focus indicators and logical tab order

## Color System Extensions

### Calendar-Specific Colors

```dart
// Calendar color extensions
class CalendarColors {
  // Activity status colors
  static const Color planned = Color(0xFF2196F3);      // Blue
  static const Color inProgress = Color(0xFFFF9800);   // Orange
  static const Color completed = Color(0xFF4CAF50);    // Green
  static const Color skipped = Color(0xFF9E9E9E);      // Gray

  // Activity type colors
  static const Color running = Color(0xFF2196F3);      // Blue
  static const Color biking = Color(0xFFFF5722);       // Red-orange
  static const Color swimming = Color(0xFF00BCD4);     // Cyan
  static const Color event = Color(0xFF9C27B0);        // Purple

  // Carb loading colors
  static const Color carbLoadingPrimary = Color(0xFFFF6B6B);   // Coral
  static const Color carbLoadingSecondary = Color(0xFFFFE0B2); // Light orange

  // Calendar navigation
  static const Color today = Color(0xFFFFC107);        // Amber
  static const Color selectedDay = Color(0xFFE3F2FD);  // Light blue
  static const Color weekendDay = Color(0xFFF5F5F5);   // Light gray
}
```

### Status Indicators

```dart
class StatusIndicators {
  static Widget buildActivityStatus(ActivityStatus status) {
    switch (status) {
      case ActivityStatus.planned:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: CalendarColors.planned,
            shape: BoxShape.circle,
          ),
        );
      case ActivityStatus.completed:
        return Icon(
          Icons.check_circle,
          color: CalendarColors.completed,
          size: 16,
        );
      case ActivityStatus.skipped:
        return Icon(
          Icons.remove_circle_outline,
          color: CalendarColors.skipped,
          size: 16,
        );
      case ActivityStatus.inProgress:
        return CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(CalendarColors.inProgress),
        );
    }
  }
}
```

## Core Components

### 1. Calendar Week View

The main calendar interface showing a 7-day week view with activities.

#### Component Structure

```dart
class CalendarWeekView extends ConsumerWidget {
  final DateTime weekStart;
  final List<Activity> activities;
  final Function(DateTime) onDateSelected;
  final VoidCallback onAddActivity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _CalendarHeader(),
        _WeekDayHeaders(),
        _WeekDayView(),
        _CalendarActions(),
      ],
    );
  }
}
```

#### Visual Specifications

**Calendar Header**:
- Height: 56pt
- Month/Year title: 20pt semibold, primary color
- Today button: 32pt height, secondary action style
- Background: Surface color with subtle shadow

**Week Day Headers**:
- Height: 32pt
- Day labels: 14pt medium weight
- Weekends styled differently (lighter color)
- Responsive to locale (Sunday/Monday start)

**Day Cells**:
- Minimum height: 80pt (expands with content)
- Width: Screen width / 7
- Border: 1pt light gray
- Today: Amber border (2pt)
- Selected: Light blue background

**Activity Items in Day Cells**:
- Height: 24pt minimum
- Corner radius: 4pt
- Left edge color bar: 3pt width, activity type color
- Text: 12pt regular, truncated with ellipsis
- Status indicator: 8pt circle or 12pt icon

#### Interaction Patterns

**Day Selection**:
- Tap: Select day, highlight with background color
- Long press: Quick add activity to that day
- Double tap: Navigate to day detail view

**Activity Interaction**:
- Tap: Open activity detail
- Long press: Context menu (Complete, Edit, Delete)
- Swipe: Reveal quick actions

**Navigation**:
- Swipe left/right: Previous/next week
- Pinch: Future enhancement for month view
- Today button: Animate to current week

### 2. Activity List Item

Displays individual activities within calendar days and other list contexts.

#### Component Structure

```dart
class ActivityListItem extends StatelessWidget {
  final Activity activity;
  final bool showDate;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _ActivityTypeIcon(),
        title: _ActivityTitle(),
        subtitle: _ActivityDetails(),
        trailing: _ActivityStatus(),
        onTap: onTap,
      ),
    );
  }
}
```

#### Visual Specifications

**Card Container**:
- Corner radius: 8pt
- Elevation: 2dp
- Margin: 8pt horizontal, 4pt vertical
- Background: Surface color

**Activity Type Icon** (Leading):
- Size: 32pt circle
- Background: Activity type color (20% opacity)
- Icon: 20pt, activity type color
- Running: `Icons.directions_run`
- Biking: `Icons.directions_bike`
- Swimming: `Icons.pool`
- Event: `Icons.event`

**Title Section**:
- Activity name: 16pt semibold
- Distance/Duration: 14pt regular, secondary color
- Truncate long titles with ellipsis

**Subtitle Section**:
- Date/Time: 14pt regular (if showDate)
- Pace/Intensity: 12pt regular, tertiary color
- Location: 12pt regular (for events)

**Status Indicator** (Trailing):
- Planned: Blue dot (8pt)
- Completed: Green checkmark (20pt)
- Skipped: Gray dash (16pt)
- In Progress: Orange spinner (16pt)

#### State Variations

**Planned Activity**:
- Full color saturation
- All text black/primary colors
- Call-to-action styling if due today

**Completed Activity**:
- Slightly muted colors (80% opacity)
- Green accent elements
- Completion time in subtitle

**Skipped Activity**:
- Grayed out (60% opacity)
- Strike-through on title
- Skip reason in subtitle if available

**Past Due Activity**:
- Orange accent color
- "Overdue" badge
- Prominent completion CTA

### 3. Activity Detail Screen

Renamed from "Current Plan Screen" - shows activity information and associated nutrition plan.

#### Component Structure

```dart
class ActivityDetailScreen extends ConsumerWidget {
  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: _ActivityDetailAppBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _ActivitySummaryCard(),
            SizedBox(height: 16),
            _NutritionPlanCard(),
            SizedBox(height: 16),
            _ActivityActionsCard(),
          ],
        ),
      ),
    );
  }
}
```

#### Visual Specifications

**App Bar**:
- Title: Activity name (truncated if long)
- Subtitle: Date and time
- Actions: Edit (if future), Share, More menu
- Background: Surface color

**Activity Summary Card**:
- Corner radius: 12pt
- Padding: 16pt
- Background: Activity type color (10% opacity)
- Border: 1pt activity type color (20% opacity)

**Summary Card Content**:
```
[Activity Icon] Activity Name
Distance: 18 miles | Duration: 2:30:00
Pace Target: 8:20/mile | Intensity: Moderate
Scheduled: Saturday, Dec 14 at 6:00 AM
Status: [Status Indicator] Planned
```

**Nutrition Plan Card**:
- Standard card styling (8pt radius, 2dp elevation)
- Header: "Nutrition Plan" with generation timestamp
- Content: Existing nutrition plan layout
- Footer: Edit/Regenerate buttons (if applicable)

**Activity Actions Card**:
- Prominent primary action based on status:
  - Planned: "Mark Complete" (full-width primary button)
  - Completed: "View Completion" (outline button)
  - Skipped: "Reschedule" (secondary button)
- Secondary actions in horizontal row:
  - Edit, Duplicate, Delete

#### Interactive Elements

**Mark Complete Button**:
- Height: 48pt
- Full width minus 32pt margins
- Primary color background
- White text, 16pt semibold
- Subtle press animation

**Edit Functionality**:
- Available for future activities only
- Past activities show "View Only" state
- Changes save automatically with undo option

**Status Updates**:
- Real-time updates from other screens
- Optimistic UI with rollback on error
- Success animations for completed actions

### 4. Create Activity Screen

New screen for creating activities, replacing distance/pace/gut entry screen functionality.

#### Component Structure

```dart
class CreateActivityScreen extends ConsumerWidget {
  final DateTime? preselectedDate;
  final ActivityType? preselectedType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: _CreateActivityAppBar(),
      body: Form(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              _ActivityTypeSelector(),
              SizedBox(height: 24),
              _ActivityDetailsForm(),
              SizedBox(height: 24),
              _AdvancedOptions(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _CreateActivityActions(),
    );
  }
}
```

#### Visual Specifications

**Activity Type Selector**:
- Horizontal scrollable row
- Each type: 80pt width, 64pt height card
- Selected: Primary color border (2pt)
- Unselected: Light gray border (1pt)
- Icon: 24pt activity type icon
- Label: 12pt medium below icon
- Biking/Swimming cards show a subdued style with an "Under Construction" badge and are disabled until future phases

**Form Layout**:
- Title input: 48pt height, 16pt text
- Date/Time picker: Custom component, 48pt height
- Distance slider: Custom component with text input
- Pace input: Optional, 48pt height
- Intensity selector: Chip group

**Distance Slider Component**:
```
Distance: 18.0 miles
[====●====================]
1mi    18mi                 100mi
```

**Intensity Chips**:
- Chip height: 32pt
- Horizontal spacing: 8pt
- Selected: Primary color background
- Unselected: Outline style

**Bottom Actions**:
- Cancel button: Text button, left aligned
- Create button: Primary button, right aligned
- Floating above bottom safe area

#### Form Validation

**Real-time Validation**:
- Title: Required, max 50 characters
- Date: Future dates only (except events)
- Distance: 0.1 - 100 miles for running
- Time: Valid 24-hour format

**Error States**:
- Red underline on invalid fields
- Error message below field (12pt, error color)
- Create button disabled until form valid

**Smart Defaults**:
- Title: Auto-generate based on distance/type
- Date: Next occurrence of user's preferred day
- Time: User's default activity time
- Distance: Based on recent activity patterns

### 5. Activity Completion Screen

Interface for marking activities complete with performance data and feedback.

#### Component Structure

```dart
class ActivityCompletionScreen extends ConsumerWidget {
  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: _CompletionAppBar(),
      body: PageView(
        children: [
          _PerformanceDataPage(),
          _NutritionFeedbackPage(),
          _NotesPage(),
        ],
      ),
      bottomNavigationBar: _CompletionNavigation(),
    );
  }
}
```

#### Page 1: Performance Data

**Layout**:
- Activity summary at top (non-editable)
- Performance input form
- Large, touch-friendly input fields

**Duration Input**:
- Time picker with hours:minutes:seconds
- Large, tappable segments
- Default to planned duration

**Distance Confirmation**:
- Pre-filled with planned distance
- Allow adjustment for actual distance
- Visual comparison with planned

**Effort Rating**:
- 5-star system with emoji faces
- Large touch targets (48pt each)
- Descriptive labels below

#### Page 2: Nutrition Feedback

**Primary Rating**:
- Large emoji scale (5 options, 64pt each)
- Question: "How well did your nutrition plan work?"
- Required before proceeding

**Secondary Questions** (Optional):
- Energy levels: 5-point scale
- Digestive issues: Yes/No toggle
- Favorite fuel: Text input with suggestions

#### Page 3: Notes

**Voice Notes Integration**:
- `Record Voice Note` button styled as primary action (48pt height)
- Tapping launches the existing voice note modal (no bespoke recorder UI on this screen)
- Status text/chip indicates when a recording is attached, with quick access to play or remove via legacy components

**Text Input**:
- Large text area (minimum 120pt height)
- Placeholder: "How did your workout go? Any notes?"
- Character counter (soft limit 500)

**Navigation**:
- Page indicators at bottom
- Swipe or tap to navigate
- Back/Next buttons
- Save button on final page

### 6. Event Creation Screen

Specialized screen for creating race events with carb loading options.

#### Component Structure

```dart
class CreateEventScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stepper(
        currentStep: _currentStep,
        onStepTapped: _onStepTapped,
        steps: [
          _EventTypeStep(),
          _EventDetailsStep(),
          _CarbLoadingStep(),
          _ConfirmationStep(),
        ],
      ),
    );
  }
}
```

#### Step 1: Event Type Selection

**Layout**:
- Grid of event type cards (2 columns)
- Each card: 120pt height, event type color
- Popular types first (Marathon, Half-Marathon)
- Custom option at bottom

**Event Type Cards**:
```
┌─────────────────┐
│   🏃‍♀️ Marathon    │
│   26.2 miles     │
│   3-7 day carb   │
└─────────────────┘
```

#### Step 2: Event Details

**Form Layout**:
- Event name: Auto-complete from race database
- Date: Calendar picker
- Location: Auto-complete with map integration
- Start time: Time picker
- Goal time: Duration picker

**Goal Time Component**:
- Hours:Minutes format
- Suggested times based on user history
- Pace calculation in real-time

#### Step 3: Carb Loading Configuration

**Carb Loading Options**:
- Visual cards showing plan durations
- Each card shows daily carb targets
- Estimated preparation complexity
- Cost estimates (optional)

**Plan Preview**:
```
3-Day Carb Loading Plan
├── Thursday: 560g carbs
├── Friday: 630g carbs
└── Saturday: 700g carbs
Race Day: Sunday
```

#### Step 4: Confirmation

**Summary View**:
- Event details summary
- Race day nutrition plan preview
- Carb loading schedule overview
- Calendar integration preview

**Action Buttons**:
- Create Event: Primary button, full width
- Back to Edit: Text button
- Save as Template: Secondary button

### 7. Carb Loading Components

#### Carb Loading Day Card

```dart
class CarbLoadingDayCard extends StatelessWidget {
  final CarbLoadingDay day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _DayHeader(),
            SizedBox(height: 12),
            _ProgressIndicator(),
            SizedBox(height: 16),
            _MealBreakdown(),
          ],
        ),
      ),
    );
  }
}
```

**Day Header**:
- Day name and date: 18pt semibold
- Carb target: 16pt regular, secondary color
- Day number indicator: "Day 1 of 3"

**Progress Indicator**:
- Horizontal progress bar with segments
- Current progress: Primary color
- Remaining: Light gray
- Target markers for each meal

**Meal Breakdown**:
- 6 meal slots (Breakfast through Evening)
- Each meal: Target vs. actual carbs
- Checkmark when meal target met
- Add button for incomplete meals

#### Carb Loading Progress Bar

```dart
class CarbLoadingProgressBar extends StatelessWidget {
  final double currentCarbs;
  final double targetCarbs;
  final List<double> mealTargets;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      child: CustomPaint(
        painter: CarbProgressPainter(
          currentCarbs: currentCarbs,
          targetCarbs: targetCarbs,
          mealTargets: mealTargets,
        ),
      ),
    );
  }
}
```

**Visual Design**:
- Height: 24pt
- Background: Light gray rounded rectangle
- Progress: Primary color with rounded edges
- Meal segments: Vertical dividers
- Labels: Small text above/below bar

## Responsive Design

### Screen Size Adaptations

**Small Screens** (< 375pt width):
- Calendar: Single day view option
- Activity cards: Simplified layout
- Forms: Single column only
- Typography: Reduced by 2pt

**Large Screens** (> 768pt width):
- Calendar: Month view option
- Activity cards: Enhanced information
- Forms: Two-column layout where appropriate
- Side panels for detail views

**Tablet Landscape**:
- Calendar + detail view side-by-side
- Enhanced navigation options
- Larger touch targets
- Additional context information

### Orientation Changes

**Portrait to Landscape**:
- Calendar: Maintain week view
- Forms: Optimize for horizontal space
- Navigation: Consider horizontal tabs
- Content: Reflow without losing context

## Animation Specifications

### Micro-interactions

**Activity Status Changes**:
- Duration: 300ms
- Easing: Ease-out
- Effect: Scale up completion checkmark

**Calendar Navigation**:
- Duration: 250ms
- Easing: Ease-in-out
- Effect: Slide left/right with fade

**Form Validation**:
- Duration: 200ms
- Easing: Ease-out
- Effect: Shake animation for errors

### Page Transitions

**Screen Navigation**:
- Duration: 300ms
- Style: Slide from right (iOS), Material motion (Android)
- Maintain element continuity where possible

**Modal Presentations**:
- Duration: 250ms
- Style: Slide up from bottom
- Include backdrop fade

### Loading States

**Activity Creation**:
- Skeleton loading for 2-3 seconds
- Progress indicator for plan generation
- Success animation on completion

**Data Sync**:
- Subtle progress indicator in header
- Pull-to-refresh interaction
- Success/error feedback

## Accessibility Specifications

### Screen Reader Support

**Calendar Navigation**:
- Proper heading structure (H1-H6)
- Date announcements with context
- Activity count per day

**Activity Items**:
- Semantic markup for status
- Clear action descriptions
- Progress information for carb loading

### Focus Management

**Keyboard Navigation**:
- Logical tab order through calendar
- Skip links for complex layouts
- Clear focus indicators (2pt outline)

**Focus Trap**:
- Modal dialogs contain focus
- Escape key returns to trigger
- Initial focus on primary action

### Color Accessibility

**Contrast Ratios**:
- Text on background: 4.5:1 minimum
- Interactive elements: 3:1 minimum
- Status indicators: Don't rely on color alone

**High Contrast Mode**:
- Increased border weights
- Additional visual indicators
- Simplified color palette

## Implementation Notes

### Performance Considerations

**Calendar Rendering**:
- Virtualize activity lists for large datasets
- Lazy load activity details
- Efficient date calculations

**Image Assets**:
- Vector icons for scalability
- Optimize for different screen densities
- Use system icons where appropriate

### Platform Differences

**iOS Specific**:
- Native date/time pickers
- iOS-style navigation patterns
- SF Symbols where appropriate

**Android Specific**:
- Material Design components
- Android-style navigation
- Material icons throughout

### Development Workflow

**Component Library**:
- Storybook for component development
- Design system documentation
- Automated visual regression testing

**Design Handoff**:
- Figma design system integration
- Automated spacing/color validation
- Component prop documentation

---

These UI components provide a comprehensive foundation for implementing the Calendar feature while maintaining design consistency and user experience excellence throughout Mealvana Endurance.
