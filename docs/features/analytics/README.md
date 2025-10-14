# Analytics Tracking Implementation

This document defines the exact events and properties tracked in Mealvana Endurance to satisfy all metrics requirements defined in `mixpanel_metrics.md`.

## Events Tracked

### 1. User Lifecycle Events

#### `user_registered`
Fired when a new user completes profile creation.
- **Properties:**
  - `device_id` (string): Unique device identifier
  - `timestamp` (ISO-8601): Registration timestamp
  - `registration_source` (string): "onboarding"

#### `app_opened`
Fired every time the app is opened.
- **Properties:**
  - `device_id` (string): Unique device identifier
  - `session_id` (string): Unique session identifier
  - `timestamp` (ISO-8601): Open timestamp

### 2. Plan Creation & Saving Events

#### `plan_generation_started`
Fired when user initiates plan creation (taps generate or enters plan flow).
- **Properties:**
  - `device_id` (string): Unique device identifier
  - `plan_id` (UUID): Unique plan identifier (generated at this point)
  - `timestamp` (ISO-8601): Start timestamp
  - `distance_miles` (number): Run distance
  - `pace_minutes_per_mile` (number): Run pace
  - `gut_training_level` (string): "low" | "moderate" | "high"

#### `plan_saved`
Fired when user saves a nutrition plan.
- **Properties:**
  - `device_id` (string): Unique device identifier
  - `plan_id` (UUID): Unique plan identifier
  - `timestamp` (ISO-8601): Save timestamp
  - `time_since_generation_started` (number): Seconds from plan_generation_started
  - `is_first_plan` (boolean): True if this is user's first saved plan
  - `total_plans_saved` (number): Total count of plans saved by this user

### 3. Plan Modification Events

#### `macros_edited`
Fired when user edits macro targets.
- **Properties:**
  - `device_id` (string): Unique device identifier
  - `plan_id` (UUID): Plan identifier
  - `timestamp` (ISO-8601): Edit timestamp
  - `macro_type` (string): "carbs" | "protein" | "fat" | "sodium" | "fluids" | "all"
  - `old_value` (number): Previous value
  - `new_value` (number): New value

#### `macro_info_viewed`
Fired when user clicks info button to view macro calculation details.
- **Properties:**
  - `device_id` (string): Unique device identifier
  - `plan_id` (UUID): Plan identifier
  - `timestamp` (ISO-8601): View timestamp
  - `macro_type` (string): Which macro info was viewed

#### `plan_item_deleted`
Fired when user deletes an item from plan.
- **Properties:**
  - `device_id` (string): Unique device identifier
  - `plan_id` (UUID): Plan identifier
  - `timestamp` (ISO-8601): Delete timestamp
  - `item_name` (string): Name of deleted item
  - `phase` (string): "before_run" | "during_run" | "after_run"

#### `plan_item_swapped`
Fired when user swaps one food for another.
- **Properties:**
  - `device_id` (string): Unique device identifier
  - `plan_id` (UUID): Plan identifier
  - `timestamp` (ISO-8601): Swap timestamp
  - `old_item_name` (string): Item being replaced
  - `new_item_name` (string): Replacement item
  - `phase` (string): "before_run" | "during_run" | "after_run"

#### `plan_item_added`
Fired when user adds a new item to plan.
- **Properties:**
  - `device_id` (string): Unique device identifier
  - `plan_id` (UUID): Plan identifier
  - `timestamp` (ISO-8601): Add timestamp
  - `item_name` (string): Name of added item
  - `phase` (string): "before_run" | "during_run" | "after_run"

### 4. Reminder Events

#### `reminder_set`
Fired when user schedules a reminder.
- **Properties:**
  - `device_id` (string): Unique device identifier
  - `plan_id` (UUID): Plan identifier
  - `timestamp` (ISO-8601): When reminder was set
  - `reminder_time` (ISO-8601): Scheduled reminder time

#### `reminder_scheduled`
Fired when a reminder notification is scheduled to fire (proxy for delivery).
- **Properties:**
  - `device_id` (string): Unique device identifier
  - `plan_id` (UUID): Plan identifier
  - `timestamp` (ISO-8601): When the reminder is scheduled to fire
  - `scheduled_at` (ISO-8601): When the scheduling action occurred

#### `reminder_clicked`
Fired when user taps on a reminder notification.
- **Properties:**
  - `device_id` (string): Unique device identifier
  - `plan_id` (UUID): Plan identifier
  - `timestamp` (ISO-8601): Click timestamp

## How This Fulfills the Metrics Requirements

### Core KPIs

1. **Weekly Active Users (WAU)**
   - Calculated from `app_opened` events with distinct `device_id` in 7-day window
   - Provides any app activity metric

2. **Weekly New Users**
   - Calculated from `user_registered` events with distinct `device_id` in 7-day window
   - First-time users identified by `user_registered` event

3. **Activation (% new users who save plan in first 24h)**
   - Filter `user_registered` events
   - Join with `plan_saved` events where `is_first_plan = true`
   - Calculate time difference using timestamps
   - Percentage = (users with plan_saved within 24h) / (total user_registered)
   - **Time-to-first-plan**: Direct calculation from `time_since_generation_started` in first `plan_saved`

4. **Successful Fueling Plans per WAU**
   - Numerator: Count `plan_saved` events per week
   - Denominator: Distinct `device_id` from `app_opened` events per week
   - Ratio provides plans per active user

5. **D1/D7/D28 Retention**
   - Cohort users by `user_registered` date
   - Check for `plan_saved` events at D1, D7, D28 intervals
   - Uses `plan_saved` as the retention action

6. **Conversion (plan_saved → reminder_set → reminder_clicked)**
   - Funnel analysis using `plan_id` to connect:
     1. `plan_saved` event
     2. `reminder_set` event with same `plan_id`
     3. `reminder_clicked` event with same `plan_id`
   - Conversion rates calculated at each step

### Hypothesis Testing Metrics

1. **H0: Users want better control of macro levels**
   - **Metric**: % of unique users who edited macros
   - **Calculation**: Distinct `device_id` with `macros_edited` event / Total distinct `device_id` with `plan_saved`

2. **H0: Users want to view macro calculation info**
   - **Metric**: % of unique users who clicked info button
   - **Calculation**: Distinct `device_id` with `macro_info_viewed` event / Total distinct `device_id` with `plan_saved`

3. **H0: Users want to fine-tune plans**
   - **Metric**: % of users who deleted items
   - **Calculation**: Distinct `device_id` with `plan_item_deleted` / Total distinct `device_id` with `plan_saved`
   - **Metric**: % of users who swapped items
   - **Calculation**: Distinct `device_id` with `plan_item_swapped` / Total distinct `device_id` with `plan_saved`
   - **Metric**: % of users who added items
   - **Calculation**: Distinct `device_id` with `plan_item_added` / Total distinct `device_id` with `plan_saved`

4. **H0: Reminders increase retention**
   - **Metric**: Weekly retention of users with reminders
   - **Calculation**:
     - Cohort A: Users with `reminder_set` events
     - Cohort B: Users without `reminder_set` events
     - Compare weekly `app_opened` or `plan_saved` rates between cohorts
   - **Metric**: % of reminders clicked
   - **Calculation**: Count of `reminder_clicked` / Count of `reminder_scheduled`

## Implementation Notes

1. **Plan ID Threading**: Every plan gets a unique `plan_id` at `plan_generation_started` that threads through all subsequent plan-related events.

2. **User Identification**: `device_id` is consistently used across all events to identify unique users.

3. **Timestamp Consistency**: All events include ISO-8601 timestamps for time-based calculations.

4. **First Plan Detection**: The `is_first_plan` boolean helps identify activation metrics without complex queries.

5. **Session Tracking**: `session_id` in `app_opened` helps distinguish between multiple app sessions.

## Mixpanel Configuration

These events enable Mixpanel to:
- Create funnels using `plan_id` for conversion tracking
- Build cohorts based on `user_registered` timestamps
- Calculate retention using `device_id` and time-based queries
- Compute percentages using distinct user counts
- Track time-to-event metrics using timestamp differences

## Implementation Status

### ✅ Implemented Events
All events listed above have been implemented in the codebase as of October 2024.

### 📍 Implementation Locations

**Event Definitions:**
- `/lib/shared/services/analytics/analytics_events.dart` - All event tracking methods

**Event Triggers:**
- `user_registered`: `/lib/features/onboarding/application/onboarding_service.dart`
- `app_opened`: `/lib/features/app_startup/application/app_startup_service.dart`
- `plan_generation_started`: `/lib/features/nutrition_plan/presentation/providers/distance_page_gut_entry_controller.dart`
- `plan_saved`: `/lib/features/nutrition_plan/presentation/providers/nutrition_plan_controller.dart`
- `plan_item_swapped`: `/lib/features/nutrition_plan/presentation/providers/nutrition_plan_controller.dart`
- `plan_item_added`: `/lib/features/nutrition_plan/presentation/providers/nutrition_plan_controller.dart`
- `plan_item_deleted`: `/lib/features/nutrition_plan/presentation/providers/nutrition_plan_controller.dart`
- `macros_edited`: `/lib/features/nutrition_plan/presentation/providers/distance_page_gut_entry_controller.dart`
- `macro_info_viewed`: `/lib/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart`
- `reminder_set`, `reminder_scheduled`, `reminder_clicked`: `/lib/shared/services/notification_service.dart`

### 🔧 Technical Notes

1. **Reminder Delivery Limitation**: Due to iOS/Android OS constraints, we use `reminder_scheduled` as a proxy for delivery since the app cannot reliably detect when notifications are shown to users.

2. **Device ID**: The app uses device-specific identifiers (iOS: identifierForVendor, Android: Android ID) for user tracking since there are no traditional user accounts.

3. **Plan ID Generation**: UUIDs are generated using the `uuid` package at the moment plan generation starts.

4. **Time Tracking**: The `time_since_generation_started` in `plan_saved` currently uses a placeholder value (0) and should be enhanced to track actual elapsed time.