## Epic Overview

**Feature Name:** Carb Loading Calculator & Food Recommender

**Category:** Race Preparation

**Priority:** High (Core feature for race preparation)

**Target Users:** Endurance athletes preparing for races (half-marathon to ultra distances)

## Problem Statement

Endurance athletes need to maximize glycogen stores before races through carb loading, but struggle with:

- Calculating the right amount of carbohydrates based on their body weight and race distance
- Determining the optimal timing and duration for carb loading
- Finding familiar, digestible foods to meet their carb targets without GI distress

## Solution

An intelligent carb loading calculator that provides personalized recommendations based on athlete data and suggests foods from their existing diet history.

## Formulas & Calculations

### 1. Daily Carbohydrate Target

```
Base Formula (following FeatherStone Nutrition methodology):
- 2-3 days before race: 8-10g carbs/kg body weight/day
- 1 day before race: 10-12g carbs/kg body weight/day

Adjustments:
- Race distance factor:
  - Half marathon: 0.8x multiplier
  - Marathon: 1.0x multiplier
  - 50K-100K: 1.1x multiplier
  - 100+ miles: 1.2x multiplier
  
- Training volume factor:
  - Low volume (<30 miles/week): 0.9x
  - Moderate (30-50 miles/week): 1.0x
  - High (>50 miles/week): 1.1x
```

### 2. Carb Loading Duration

```
Duration = Base Duration + Distance Adjustment
- Half marathon: 1-2 days
- Marathon: 2-3 days
- Ultra (50K-100K): 2-3 days
- Ultra (100+ miles): 3-4 days
```

### 3. Meal Distribution

```
Daily carbs distributed across:
- Breakfast: 25-30%
- Mid-morning snack: 10-15%
- Lunch: 25-30%
- Afternoon snack: 10-15%
- Dinner: 20-25%
- Evening snack (if needed): 5-10%
```

## Inputs

### User Profile Data (One-time/Updated as needed)

- **Body weight** (kg/lbs - with unit conversion)
- **Gender** (for refined calculations)
- **Training volume** (average weekly mileage/hours)
- **Dietary restrictions** (allergies, intolerances, preferences)
- **GI sensitivity level** (low/moderate/high)

### Race-Specific Inputs

- **Race date** (calendar picker)
- **Race distance** (dropdown: 5K, 10K, Half Marathon, Marathon, 50K, 50M, 100K, 100M, Custom)
- **Race start time** (for meal timing calculations)
- **Target finish time** (optional - for energy expenditure estimates)
- **Climate conditions** (hot/moderate/cold - affects hydration needs)

### Food Preference Inputs

- **Preferred carb sources** (multi-select from food database)
- **Foods to avoid** during carb loading
- **Fiber tolerance** (low/moderate/high)
- **Maximum meal size comfort** (small/medium/large portions)

## Outputs

### 1. Carb Loading Schedule

```
Example Output:
Race Day: Sunday, October 15, 2025 (Marathon)
Body Weight: 70kg

Thursday (3 days out):
- Daily Target: 560g carbs (8g/kg)
- Breakfast: 140-168g
- Snack: 56-84g
- Lunch: 140-168g
- Snack: 56-84g
- Dinner: 112-140g
- Evening: 28-56g

Friday (2 days out):
- Daily Target: 630g carbs (9g/kg)
[Similar breakdown]

Saturday (1 day out):
- Daily Target: 700g carbs (10g/kg)
[Similar breakdown]
```

### 2. Food Recommendations

```
For each meal/snack:
- Primary options (3-5 familiar foods from user history)
- Portion sizes to meet carb targets
- Preparation notes (e.g., "cook pasta al dente")
- Fiber content warnings
- Hydration reminders
```

### 3. Shopping List

```
Auto-generated based on selected meals:
- Categorized by store section
- Quantities calculated for carb loading period
- Optional: Integration with grocery delivery services
```

### 4. Race Morning Plan

```
- Wake time recommendation
- Breakfast timing and composition
- Last meal cutoff time
- Hydration schedule
```

## Navigation Entry Points

### Primary Access

1. **Home Dashboard**
    - "Prepare for Race" CTA button
    - Upcoming race countdown widget
2. **Race Calendar View**
    - "Plan Carb Loading" button on race events
    - Auto-prompt 1 week before race
3. **Training Plan Integration**
    - Automatic trigger during taper week
    - Push notification: "Time to plan your carb loading"

### Secondary Access

1. **Nutrition Tools Menu**
    - Carb Loading Calculator option
    - Quick access from bottom navigation
2. **Coach Dashboard** (Pro feature)
    - Bulk planning for multiple athletes
    - Template creation and sharing

## Telemetry & Analytics

### User Behavior Metrics

- **Feature Adoption**
    - % of users who use carb loading calculator
    - Average time from race to first use
    - Completion rate of carb loading plans
- **Engagement Metrics**
    - Plan adherence rate (meals logged vs planned)
    - Food recommendation acceptance rate
    - Shopping list usage/exports
    - Return usage for multiple races

### Performance Metrics

- **Calculation Performance**
    - Time to generate plan (<2 seconds target)
    - Food recommendation relevance score
    - API response times for food database queries

### Outcome Metrics

- **Race Performance Correlation**
    - Post-race surveys on energy levels
    - GI distress reports
    - Perceived effectiveness ratings
    - Race result tracking (optional user input)

### Error Tracking

- Failed calculations
- Food database mismatches
- Shopping list generation errors
- Sync failures with training platforms

## User Experience Flows

### First-Time Use

1. Trigger: User adds race to calendar or 1 week before race
2. Welcome screen explaining carb loading benefits
3. Input gathering wizard (3-4 screens max)
4. Plan generation with explanation
5. Food selection and customization
6. Save and export options

### Returning User

1. Quick access from dashboard
2. Pre-filled data from profile
3. Copy previous plans option
4. Adjust for new race specifics
5. Generate and go

## Success Criteria

- 70% of users with upcoming races use the feature
- 80% completion rate for plan generation
- 60% of users log at least 50% of planned meals
- Average rating of 4.5/5 for feature usefulness
- <5% report increased GI issues

## Technical Considerations

- Integration with existing food database
- Sync with training platforms (Strava, Garmin, TrainingPeaks)
- Offline capability for plan viewing
- Export formats: PDF, calendar integration, shopping apps
- Notification system for meal reminders

## Future Enhancements

- AI-powered plan adjustments based on logged adherence
- Integration with continuous glucose monitors
- Restaurant meal suggestions for carb loading
- Group planning for team events
- Carb loading practice runs during training