# Calendar Feature User Flows

## Overview

This document outlines the complete user journeys for the Calendar feature in Mealvana Endurance. Each flow is designed to be intuitive, efficient, and aligned with endurance athletes' training and nutrition planning workflows.

## Core User Personas

### Primary Persona: Sarah, Marathon Runner
- **Background**: Experienced runner training for Boston Marathon
- **Goals**: Optimize race day nutrition, practice carb loading
- **Tech Comfort**: High, uses multiple training apps
- **Pain Points**: Complex nutrition timing, race anxiety about fueling

### Secondary Persona: Mike, Weekend Warrior
- **Background**: Recreational runner, 1-2 runs per week
- **Goals**: Improve energy during longer runs (10+ miles)
- **Tech Comfort**: Medium, prefers simple interfaces
- **Pain Points**: Inconsistent energy levels, doesn't plan nutrition

### Tertiary Persona: Emily, Data-Driven Racer
- **Background**: Competitive age-group runner juggling training with work
- **Goals**: Track adherence, understand what fuels high-quality workouts
- **Tech Comfort**: High, frequently reviews analytics and historical notes
- **Pain Points**: Hard to spot patterns across nutrition plans and completion feedback

## User Flow 1: Creating a Running Activity

### Context
Sarah wants to plan her long run for this Saturday and generate a nutrition plan to practice race fueling.

### Flow Steps

#### 1.1 Access Calendar
**Entry Point**: User opens app → Calendar tab (default landing)

**Screen**: Calendar Week View
- Shows current week (Monday start)
- Today button highlighted
- Empty Saturday slot visible
- Plus (+) button prominent in header

**User Action**: Taps plus (+) button

#### 1.2 Select Activity Type
**Screen**: Activity Type Selector
- Four options: Running, Biking (grayed), Swimming (grayed), Event
- Running pre-selected (most common)
- Clear descriptions under each type

**User Action**: Confirms Running selection or taps "Continue"

#### 1.3 Activity Details Entry
**Screen**: Create Running Activity

**Form Fields** (in order):
1. **Title**: "Long Run" (smart default based on distance)
2. **Date & Time**: Saturday, 7:00 AM (user's default)
3. **Distance**: Slider + text input, miles
4. **Pace Target**: Optional, minutes per mile
5. **Intensity**: Easy/Moderate/Hard (affects nutrition)

**Smart Defaults**:
- Title auto-updates based on distance ("Long Run", "Easy Run", "Tempo Run")
- Date defaults to user's preferred training day
- Time defaults to user's preferred training time

**User Actions**:
- Adjusts distance to 18 miles
- Changes time to 6:00 AM
- Selects "Moderate" intensity
- Taps "Create Activity"

#### 1.4 Nutrition Plan Generation
**Screen**: Activity Creation Loading
- Progress indicator: "Generating nutrition plan..."
- Takes 2-5 seconds with AI system
- Fallback to algorithm if AI unavailable

**Background Process**:
- Activity created in local database
- Nutrition plan service called with activity parameters
- Plan optimized for distance, pace, user preferences
- Plan linked to activity in database

#### 1.5 Activity Created Confirmation
**Screen**: Calendar Week View (updated)
- New activity appears in Saturday slot
- Shows title, time, distance
- Nutrition plan icon indicates plan ready
- Success feedback: "Activity created with nutrition plan"

**User Action**: Taps on created activity to review

#### 1.6 Activity Detail View
**Screen**: Activity Detail (renamed from Current Plan)
- Activity summary at top
- Nutrition plan details below
- Edit button (for future activities only)
- Mark Complete button (if day of activity)

**Success Metrics**:
- Time to complete: <2 minutes
- User satisfaction: 4.5+ stars
- Plan generation success: >95%

### Error Handling

**Network Issues**:
- Activity saves locally immediately
- Nutrition plan generates when connection restored
- User informed: "Activity saved, nutrition plan generating..."

**Validation Errors**:
- Date in past: "Activities must be scheduled for future dates"
- Distance invalid: "Please enter a distance between 1-100 miles"
- Form incomplete: Clear field-level error messages

**System Errors**:
- AI generation fails: Fall back to algorithmic plan seamlessly
- Database error: Show retry option with explanation
- Critical error: Graceful degradation with support contact

## User Flow 2: Creating a Race Event

### Context
Sarah is training for Boston Marathon and wants to plan the entire race experience including carb loading.

### Flow Steps

#### 2.1 Event Creation Access
**Entry Point**: Calendar → Plus (+) → Event

**Screen**: Event Type Selector
- Marathon highlighted (most common)
- Half-Marathon, 10K, 5K, Ultra options
- Custom option for other distances
- Each option shows typical carb loading recommendations

**User Action**: Selects "Marathon"

#### 2.2 Event Details Entry
**Screen**: Create Marathon Event

**Form Sections**:

**Basic Information**:
- Event Name: "Boston Marathon" (auto-complete from database)
- Date: April 21, 2025 (date picker)
- Start Time: 10:00 AM
- Location: Boston, MA (auto-complete)

**Goals & Targets**:
- Goal Time: 3:30:00 (time picker)
- Target Pace: 8:02 per mile (auto-calculated)
- Expected Weather: Cool/Moderate/Hot

**Race Logistics**:
- Registration URL: Optional
- Bib Number: Optional
- Wave Start: Optional

**User Actions**:
- Fills in event details
- Sets goal time of 3:30:00
- Selects "Cool" weather
- Taps "Continue"

#### 2.3 Carb Loading Configuration
**Screen**: Carb Loading Setup

**Carb Loading Options**:
- No Carb Loading (for experienced athletes who don't need it)
- 1-Day Plan (minimal carb loading)
- 3-Day Plan (standard recommendation)
- 7-Day Plan (maximum glycogen storage)

**Plan Preview** (for 3-day selection):
- Shows dates: April 18, 19, 20
- Daily carb targets based on user weight
- Estimated grocery cost
- Complexity level indicator

**User Action**: Selects "3-Day Plan" and taps "Create Event"

#### 2.4 Event and Plan Generation
**Screen**: Event Creation Loading
- "Creating race event..."
- "Generating race day nutrition plan..."
- "Setting up carb loading schedule..."

**Background Process**:
- Event created with all details
- Race-specific nutrition plan generated
- Carb loading plan created for 3 days
- Calendar entries created for each carb loading day

#### 2.5 Event Created Confirmation
**Screen**: Calendar Week View
- Race event appears on April 21 with special styling
- Carb loading activities appear April 18-20
- All linked with visual indicators
- Success message: "Marathon event created with 3-day carb loading plan"

**User Action**: Taps on race day to review plan

#### 2.6 Race Day Plan Review
**Screen**: Event Detail View
- Race information summary
- Detailed nutrition plan for race day
- Pre-race meal recommendations
- During-race fueling strategy
- Post-race recovery plan

**Navigation Options**:
- View carb loading plan
- Edit event details (up to 1 week before)
- Duplicate event (for future races)

### Success Metrics
- Event creation completion: >90%
- Carb loading adoption: >60% for marathon events
- Plan satisfaction: 4.3+ stars

## User Flow 3: Daily Calendar Navigation

### Context
Mike opens the app to see what training he has planned for the week and check if he completed yesterday's run.

### Flow Steps

#### 3.1 Calendar Landing
**Entry Point**: App startup → Calendar (default)

**Screen**: Calendar Week View
- Current week displayed (Monday start)
- Today highlighted with distinct styling
- Activities shown in each day slot
- Quick visual indicators for completion status

**Visual Elements**:
- Completed activities: Green checkmark
- Planned activities: Blue dot
- Skipped activities: Gray dash
- Today: Yellow highlight border

#### 3.2 Week Navigation
**User Actions Available**:
- Swipe left/right to change weeks
- Tap Today button to return to current week
- Tap month/year header for month overview

**Navigation Example**:
- User swipes right to see next week
- Sees planned long run on Saturday
- Swipes left twice to see last week
- Reviews completed activities

#### 3.3 Day Interaction
**Tap on Day**:
- Shows detailed day view with all activities
- Allows adding new activities to specific day
- Shows hourly breakdown if multiple activities

**Tap on Activity**:
- Opens Activity Detail view
- Shows nutrition plan if generated
- Allows completion if activity is today/past due

#### 3.4 Quick Actions
**Available from Calendar**:
- Long press activity: Context menu (Complete, Edit, Delete)
- Tap completion status: Quick status change
- Swipe activity: Reveal quick actions

**Context Menu Options**:
- Mark Complete
- Mark Skipped
- Edit Activity
- Delete Activity
- Duplicate for Next Week

### Error Handling
- Loading issues: Show cached data with refresh option
- Sync conflicts: Prioritize local changes, background sync
- Performance issues: Lazy load activities outside current view

## User Flow 4: Completing a Workout

### Context
Sarah just finished her 18-mile long run and wants to log completion with feedback about how the nutrition plan worked.

### Flow Steps

#### 4.1 Completion Trigger
**Entry Points**:
1. **Post-Activity Notification**: "How did your Long Run go?" (2 hours after scheduled time)
2. **App Open Check**: Automatic detection of past-due planned activities
3. **Manual Completion**: User taps "Mark Complete" on activity

**Screen**: Activity Completion Detection
- Shows activity details: "Long Run - 18 miles"
- Scheduled time vs. current time
- "Ready to log your workout?" prompt

**User Action**: Taps "Log Workout"

#### 4.2 Performance Entry
**Screen**: Workout Performance

**Actual Performance Fields**:
- Distance: 18.0 miles (pre-filled from plan)
- Duration: 2:45:30 (time picker)
- Average Pace: 9:12/mile (auto-calculated)
- Effort Level: Easy/Moderate/Hard/Very Hard

**Optional Fields**:
- Max Heart Rate: 165 bpm
- Weather: Sunny, 45°F (auto-detect location)
- Route Notes: Text field

**User Actions**:
- Confirms distance (matches plan)
- Enters actual duration
- Selects "Moderate" effort
- Taps "Continue"

#### 4.3 Nutrition Feedback
**Screen**: Nutrition Plan Rating

**Primary Question**: "How well did your nutrition plan work?"

**Rating Scale** (5 emojis):
- 😞 Poor - caused problems
- 😬 Below expectations
- 😐 Okay - no issues but not great
- 😊 Good - worked well
- 😄 Excellent - felt great

**Secondary Questions** (optional):
- Energy levels throughout run
- Stomach/digestive issues (yes/no)
- What worked best?
- What would you change?

**User Action**: Selects 😊 (Good) and taps "Continue"

#### 4.4 Voice Notes (Optional)
**Screen**: Workout Notes

**Interface**:
- Large text input field (soft limit 500 chars)
- `Record Voice Note` button that routes to the existing voice note recorder
- Status text showing whether a voice note is already attached
- Skip option prominent

**Voice Note Flow (reused)**:
1. User taps `Record Voice Note`.
2. App launches the existing voice note modal (already used elsewhere in the product).
3. User records audio and saves; the modal returns a `voice_note_id`.
4. Activity completion screen reflects the attached recording and allows playback or removal via the legacy UI components.

**User Actions**:
- Taps `Record Voice Note`.
- Records quick audio summary using the familiar voice note interface.
- Confirms the note is attached, optionally adds a short text reflection.
- Taps `Save Notes`.

#### 4.5 Completion Confirmation
**Screen**: Workout Logged Successfully

**Summary Display**:
- Activity marked as completed
- Performance summary
- Nutrition rating recorded
- Notes saved
- Celebration micro-animation

**Next Steps Suggested**:
- View your workout history
- Plan your next run
- Share with training partner
- Set up recovery nutrition

**User Action**: Returns to calendar to see completed activity

### Success Metrics
- Completion rate: >70% of planned activities logged
- Rating completion: >80% of logged activities include nutrition feedback
- Voice notes usage: >40% of completions include notes
- Time to complete flow: <3 minutes average

## User Flow 5: Managing Carb Loading Plans

### Context
Sarah is 3 days out from Boston Marathon and needs to track her carb loading progress and make adjustments.

### Flow Steps

#### 5.1 Carb Loading Day View
**Entry Point**: Calendar → Tap on carb loading activity

**Screen**: Carb Loading Day Detail
- Day 1 of 3-day plan header
- Current date and carb target: "Thursday: 560g carbs"
- Progress bar: 180g / 560g (32% complete)
- Meal breakdown with checkboxes
- "Add Food" button prominent

**Meal Breakdown**:
- ✅ Breakfast: 140g / 140g target
- ⬜ Morning Snack: 0g / 84g target
- ⬜ Lunch: 40g / 140g target (in progress)
- ⬜ Afternoon Snack: 0g / 84g target
- ⬜ Dinner: 0g / 112g target
- ⬜ Evening: 0g / 56g target

#### 5.2 Adding Carb Loading Foods
**User Action**: Taps "Add Food" for lunch

**Screen**: Carb Loading Food Selection
- Search bar at top
- "Recommended for carb loading" section
- Food categories: Grains, Fruits, Energy, Drinks
- Each food shows carbs per serving
- Quick add buttons for common portions

**Food Recommendations** (personalized):
- White rice: 45g carbs per cup
- Banana: 27g carbs per medium
- Pasta: 43g carbs per cup
- Sports drink: 14g carbs per 8oz

**User Actions**:
- Searches for "pasta"
- Selects "Penne pasta, cooked"
- Chooses "1.5 cups" portion
- Sees "65g carbs" added to lunch
- Taps "Add to Plan"

#### 5.3 Progress Tracking
**Screen**: Updated Carb Loading Day
- Progress bar updated: 245g / 560g (44% complete)
- Lunch section shows: 105g / 140g target (25% to go)
- Green checkmark appears as goals are met
- Encouragement message: "Great progress! You're on track."

**Smart Notifications**:
- Reminder 2 hours before each meal
- Progress check-ins at end of day
- Adjustment suggestions if behind target

#### 5.4 Plan Adjustment
**User Scenario**: Sarah realizes she's getting too full and needs to adjust remaining meals

**User Action**: Taps "Adjust Plan" button

**Screen**: Carb Loading Plan Adjustment
- Shows remaining meals and current targets
- Suggests redistributing remaining carbs
- Option to extend plan by adding meals
- Warning about minimum carb targets

**Adjustment Options**:
- Reduce dinner target from 112g to 90g
- Add bedtime snack: 22g target
- Suggest liquid carbs for easier consumption
- Reschedule some carbs to tomorrow

**User Action**: Accepts suggestion to add bedtime snack

#### 5.5 Multi-Day Overview
**Entry Point**: Carb loading activity → "View Full Plan"

**Screen**: 3-Day Carb Loading Overview
- Timeline view of all 3 days
- Daily targets and progress
- Color coding: Green (complete), Yellow (in progress), Gray (upcoming)
- Total carb accumulation graph

**Day Progress**:
- Day 1 (Thu): 512g / 560g (91% - nearly complete)
- Day 2 (Fri): 0g / 630g (upcoming)
- Day 3 (Sat): 0g / 700g (race day prep)

**Navigation**:
- Tap any day to drill into details
- Shopping list for remaining days
- Progress sharing options

### Success Metrics
- Plan adherence: >80% of daily carb targets met
- Completion rate: >90% of users complete carb loading when started
- Adjustment usage: <20% of users need plan modifications
- User satisfaction: 4.2+ stars for carb loading experience

## User Flow 6: App Startup and Pending Activities

### Context
Mike opens the app Monday morning after missing his planned Sunday run. The app should help him catch up and plan for the week.

### Flow Steps

#### 6.1 App Launch Detection
**Background Process**:
- App checks for past-due planned activities
- Identifies Sunday run marked as "planned" but past scheduled time
- Determines appropriate action based on user preferences

**Decision Logic**:
- If <24 hours late: Offer to complete or reschedule
- If >24 hours late: Suggest marking as skipped or rescheduling
- If nutrition feedback pending: Prioritize completion flow

#### 6.2 Pending Activity Prompt
**Screen**: Activity Check-in
- "Good morning! How did your Sunday run go?"
- Activity summary: "Easy Run - 8 miles, Sunday 8:00 AM"
- Three action buttons with clear outcomes

**Action Options**:
1. **"I Completed It"**: Opens completion flow
2. **"I Skipped It"**: Marks as skipped, asks for reason
3. **"Reschedule"**: Move to new date/time

**User Action**: Selects "I Skipped It"

#### 6.3 Skip Reason Capture
**Screen**: Activity Skip
- "No problem! Why did you skip the run?"
- Reason options:
  - Weather conditions
  - Injury/not feeling well
  - Schedule conflict
  - Lack of motivation
  - Other (text input)

**Purpose**: Helps app learn patterns and provide better recommendations

**User Action**: Selects "Schedule conflict" and taps "Continue"

#### 6.4 Week Planning Suggestion
**Screen**: Week Ahead
- Calendar view showing current week
- Suggestion: "Want to reschedule your 8-mile run for later this week?"
- Shows available time slots based on user's typical patterns
- Option to modify distance/intensity for make-up run

**Smart Suggestions**:
- Tuesday evening (user's alternate day)
- Reduce to 6 miles (accommodating missed training)
- Keep same intensity and nutrition plan structure

**User Action**: Accepts Tuesday evening suggestion

#### 6.5 Updated Calendar
**Screen**: Calendar Week View
- Sunday run marked as "Skipped" with reason
- Tuesday run added with adjusted parameters
- Nutrition plan automatically generated for new activity
- Success message: "Week updated! Tuesday run scheduled with nutrition plan."

### Success Metrics
- Pending activity resolution: >85% of past-due activities addressed
- Rescheduling adoption: >60% of skipped activities rescheduled
- User retention: No drop in engagement after missed activities

## Cross-Flow Considerations

### State Management
- All flows maintain consistent state across app lifecycle
- Background sync ensures data integrity
- Offline capability for all core functions
- Optimistic UI updates with rollback capability

### Performance Requirements
- Calendar week load: <500ms
- Activity creation: <3 seconds end-to-end
- Plan generation: <5 seconds (AI) or <1 second (algorithm)
- Smooth 60fps animations throughout

### Accessibility
- Screen reader support for all interactive elements
- High contrast mode compatibility
- Touch targets minimum 44pt
- Keyboard navigation support

### Error Recovery
- Network failures handled gracefully
- Data loss prevention through local persistence
- Clear error messages with actionable next steps
- Support contact integration for complex issues

### Analytics and Learning
- User journey tracking for optimization
- A/B testing capability for flow improvements
- Performance monitoring and alerting
- User feedback integration for continuous improvement

---

These user flows represent the core interactions that transform Mealvana Endurance from a tab-based nutrition app into a comprehensive calendar-driven training and nutrition platform. Each flow is designed to be efficient, intuitive, and aligned with real-world athletic training patterns.
