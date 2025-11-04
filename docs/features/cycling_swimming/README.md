# Cycling & Swimming Feature Expansion

## Overview

This feature expands Mealvana Endurance from a running-focused app to a comprehensive multi-sport nutrition platform supporting **running, cycling, and swimming**. This enables the app to serve triathletes and multi-sport endurance athletes with sport-specific nutrition guidance based on evidence-based sports science.

## Business Justification

### Target Audience Expansion
- **Current**: Runners only
- **New**: Triathletes, cyclists, swimmers, and multi-sport endurance athletes
- **Market Size**: Triathlon participation has grown 300% in the last 20 years with 4M+ participants globally

### Competitive Advantage
- First nutrition app with sport-specific fueling calculations across 3 disciplines
- Evidence-based formulas from ACSM, Sports Medicine research
- Integrated calendar for multi-sport training plans

## Core Requirements

### 1. Multi-Sport Activity Support

**Supported Activity Types:**
- Running (existing, DO NOT MODIFY formulas)
- Cycling (NEW)
- Swimming (NEW)

**Activity Creation:**
- Unified tabbed interface (Running | Cycling | Swimming)
- Sport-specific input screens with appropriate parameters
- Same nutrition plan generation workflow for all sports

### 2. Sport-Specific Input Parameters

#### Running (Existing - No Changes)
- Distance (miles/km)
- Pace (min/mile or min/km)
- Pre-run timing window
- Gut training level
- Environment (temperature, humidity)
- Sweat rate category

#### Cycling (NEW)
**Required Inputs:**
- Distance (miles/km) OR Duration (minutes)
- Average Speed (mph/kph) OR Intensity Target (RPE/FTP zone/HR zone)
- Date & Time

**Additional Inputs:**
- Terrain: flat, rolling, hilly
- Indoor vs Outdoor
- Elevation Gain (feet/meters)
- Session Goal: endurance, tempo, intervals
- Time before ride (pre-fuel window)

**Environmental:**
- Air temperature
- Relative humidity
- Wind conditions
- Solar load (sun exposure)

#### Swimming (NEW)
**Required Inputs:**
- Distance (meters/yards) OR Duration (minutes)
- Pace per 100m (seconds or MM:SS)
- Date & Time

**Additional Inputs:**
- Pool vs Open Water
- Water Temperature (°C/°F)
- Intensity Target (RPE/Zone)
- Session Goal: technique, endurance, sets
- Time before swim (pre-fuel window)

**Environmental (for pool):**
- Air temperature on deck
- Humidity (affects sweat rate even while swimming)

### 3. Unified Edge Function Architecture

**Decision**: Option B - Two unified edge functions with `activity_type` parameter

#### Edge Function: `generate-macros`
**Current:** `generate-running-macros` (rename existing)
**New:** Accepts `activity_type` parameter: `"running"`, `"cycling"`, `"swimming"`

**Responsibilities:**
- Calculate energy expenditure (sport-specific formulas)
- Calculate macro targets (pre/during/post)
- Calculate hydration needs
- Calculate sodium requirements
- Return standardized macro targets JSON

**Sport-Specific Energy Calculations:**
- **Running**: ~1 kcal/kg/km (existing ACSM formula)
- **Cycling**: MET-based from speed/power + air resistance
  - Leisure (~16 km/h): 6 METs
  - Moderate (~24 km/h): 8-10 METs
  - Fast (~30+ km/h): 12-16 METs
- **Swimming**: MET-based from stroke/intensity
  - Moderate freestyle: 8 METs
  - Vigorous freestyle: 10-11 METs
  - Butterfly: 13+ METs

#### Edge Function: `generate-nutrition-plan`
**Current:** `generate-ai-nutrition-plan` (rename existing)
**New:** Accepts `activity_type` parameter

**Responsibilities:**
- Receive macro targets from `generate-macros`
- Select appropriate foods using LP solver
- Consider user food preferences (liked/disliked)
- Post-process for electrolytes and hydration
- Return detailed nutrition plan

**Changes Required:**
- Accept `activity_type` parameter
- Adjust food selection timing (e.g., "On the bike" vs "During run")
- Maintain existing logic for running (backward compatible)

### 4. Database Schema Updates (v1 - No Migration)

**Approach**: Add nullable sport-specific columns to existing v1 schema

#### `activities` Table Changes

```sql
-- Existing columns (no changes)
id TEXT PRIMARY KEY,
user_id TEXT NOT NULL,
activity_type TEXT NOT NULL, -- ALREADY supports 'running', 'cycling', 'swimming'
title TEXT NOT NULL,
scheduled_date_time TIMESTAMP NOT NULL,
status TEXT DEFAULT 'planned',
distance_miles REAL,
duration_minutes INTEGER,
pace_target_minutes_per_mile REAL,
intensity_level TEXT,

-- NEW: Cycling-specific columns (nullable)
cycling_speed_mph REAL,
cycling_terrain TEXT, -- 'flat', 'rolling', 'hilly'
cycling_indoor_outdoor TEXT, -- 'indoor', 'outdoor'
cycling_elevation_gain_ft INTEGER,
cycling_session_goal TEXT, -- 'endurance', 'tempo', 'intervals'

-- NEW: Swimming-specific columns (nullable)
swimming_pace_per_100m_seconds INTEGER,
swimming_pool_or_open_water TEXT, -- 'pool', 'open_water'
swimming_water_temp_c REAL,

-- NEW: Shared intensity target
intensity_target TEXT, -- 'zone_1', 'zone_2', 'zone_3', 'zone_4', 'zone_5', 'rpe_3', 'rpe_5', 'rpe_7'

-- NEW: Pre-activity timing (moved from run-specific to shared)
time_before_minutes INTEGER, -- Replaces run-specific pre_run_timing

-- Existing metadata columns (no changes)
completed_at TIMESTAMP,
completion_rating INTEGER,
completion_notes TEXT,
actual_distance_miles REAL,
actual_duration_minutes INTEGER,
notes TEXT,
created_at TIMESTAMP NOT NULL,
updated_at TIMESTAMP NOT NULL,
deleted_at TIMESTAMP
```

**Constraint Updates:**
```sql
CHECK (cycling_terrain IS NULL OR cycling_terrain IN ('flat', 'rolling', 'hilly')),
CHECK (cycling_indoor_outdoor IS NULL OR cycling_indoor_outdoor IN ('indoor', 'outdoor')),
CHECK (cycling_session_goal IS NULL OR cycling_session_goal IN ('endurance', 'tempo', 'intervals')),
CHECK (swimming_pool_or_open_water IS NULL OR swimming_pool_or_open_water IN ('pool', 'open_water'))
```

#### `foods` Table Changes (Sport-Specific Suitability)

**Problem**: Different sports can consume different foods during activity:
- **Running**: Only gels, chews, drinks (high GI distress risk)
- **Cycling**: Can tolerate solid foods (bars, bananas, sandwiches, rice cakes)
- **Swimming**: Very limited - only gels/drinks at feed stops

**Solution**: Add `suitable_for_activities` JSONB column

```sql
-- Add to foods table
ALTER TABLE foods ADD COLUMN suitable_for_activities JSONB DEFAULT '["running", "cycling", "swimming"]'::jsonb;

-- Add to user_foods table
ALTER TABLE user_foods ADD COLUMN suitable_for_activities JSONB DEFAULT '["running", "cycling", "swimming"]'::jsonb;
```

**Benefits**:
- ✅ Realistic nutrition plans (cyclists get solid foods, swimmers don't get bananas during swim)
- ✅ Sport-appropriate recommendations
- ✅ Easy to query: `WHERE suitable_for_activities @> '["cycling"]'`
- ✅ Flexible for future sports (triathlon, duathlon, etc.)
- ✅ Default to all sports (backward compatible)

**Example Food Suitability:**
```sql
-- Energy gel: Universal (easy to consume in all sports)
UPDATE foods SET suitable_for_activities = '["running", "cycling", "swimming"]'::jsonb
WHERE name = 'Energy Gel';

-- Banana: Running and cycling only (impractical during swimming)
UPDATE foods SET suitable_for_activities = '["running", "cycling"]'::jsonb
WHERE name = 'Banana';

-- PB&J Sandwich: Cycling only (too heavy for running, impossible during swimming)
UPDATE foods SET suitable_for_activities = '["cycling"]'::jsonb
WHERE name = 'PB&J Sandwich';

-- Rice cake: Cycling specific (popular with cyclists, too dry for running)
UPDATE foods SET suitable_for_activities = '["cycling"]'::jsonb
WHERE name = 'Rice Cake';

-- Sports drink: Universal
UPDATE foods SET suitable_for_activities = '["running", "cycling", "swimming"]'::jsonb
WHERE name = 'Sports Drink';
```

**Query Example in Edge Function:**
```typescript
// Filter foods by activity type
const { data: foods } = await supabase
  .from('foods')
  .select('*')
  .eq('category', 'during_run')
  .contains('suitable_for_activities', [activityType]); // ← NEW FILTER
```

#### `users` Table Changes (Onboarding Data)

```sql
-- Existing fields (no changes)
id TEXT PRIMARY KEY,
device_id TEXT NOT NULL UNIQUE,
weight_kg REAL,
height_cm REAL,
age INTEGER,
gender TEXT,
gut_training_level TEXT,
sweat_rate_category TEXT,
sweat_sodium_concentration TEXT,

-- NEW: Cycling-specific preferences
ftp_watts INTEGER, -- Functional Threshold Power
typical_bike_bottles INTEGER DEFAULT 2, -- Carrying capacity
has_aero_bottle BOOLEAN DEFAULT false,
has_bento_box BOOLEAN DEFAULT false,

-- NEW: Swimming-specific preferences
css_pace_per_100m_seconds INTEGER, -- Critical Swim Speed
typical_wetsuit BOOLEAN DEFAULT false,
typical_swim_cap_type TEXT, -- 'none', 'latex', 'silicone', 'neoprene'

-- NEW: Shared preferences
gi_sensitivity BOOLEAN DEFAULT false, -- GI sensitivity flag

-- Existing metadata (no changes)
created_at TIMESTAMP NOT NULL,
updated_at TIMESTAMP NOT NULL
```

### 5. Onboarding Updates

**New Onboarding Screens/Sections:**

#### Screen: "Sport Preferences" (NEW)
"Which sports do you do?"
- [ ] Running
- [ ] Cycling
- [ ] Swimming

**If Cycling Selected → Cycling Details:**
- **FTP (Functional Threshold Power)**
  - Input: Number (watts)
  - Help text: "Your FTP is the maximum power you can sustain for ~1 hour. If you don't know, you can enter 0 and we'll estimate based on your rides."
  - Default: 0 (will estimate)

- **Bike Carrying Capacity**
  - "How many water bottles can you carry?"
    - 1 bottle
    - 2 bottles (default)
    - 3+ bottles
  - "Do you have an aero bottle?" Yes/No
  - "Do you have a bento box for food?" Yes/No

**If Swimming Selected → Swimming Details:**
- **CSS (Critical Swim Speed)**
  - Input: Pace per 100m (MM:SS format)
  - Help text: "Your CSS is the fastest pace you can sustain for 30 minutes of continuous swimming. If you don't know, you can enter 0 and we'll estimate based on your swims."
  - Example: "2:00 means 2 minutes per 100 meters"
  - Default: 0 (will estimate)

- **Typical Swimming Conditions**
  - "Do you typically wear a wetsuit?" Yes/No
  - "What swim cap do you usually wear?"
    - None / Latex / Silicone / Neoprene

#### Screen: "Gut Training" (Updated)
- Existing gut training question (keep as-is)
- NEW: "Do you have a sensitive stomach during exercise?" Yes/No
  - Help text: "This helps us recommend foods that are easier to digest"

### 6. Settings Screen Updates

**New Section: "Sport Settings"**

Subsections:
- Running Settings (existing preferences)
- Cycling Settings (NEW)
  - FTP (watts)
  - Bike carrying capacity
  - Aero bottle: Yes/No
  - Bento box: Yes/No
- Swimming Settings (NEW)
  - CSS (pace per 100m)
  - Typical wetsuit: Yes/No
  - Typical swim cap type

### 7. UI/UX Requirements

#### Activity Creation Screen (Updated)
**File:** `lib/features/calendar/presentation/screens/activity_creation_screen.dart`

**Current State:**
- 3 tabs: Running | Biking | Swimming
- Only Running tab is implemented (goes to `DistancePaceGutEntryScreen`)
- Biking and Swimming show "Under Construction" placeholders

**New State:**
- Running tab: Keep existing workflow (NO CHANGES)
- Cycling tab: New `CyclingInputScreen` (create new)
- Swimming tab: New `SwimmingInputScreen` (create new)

#### Cycling Input Screen (NEW)
**File:** `lib/features/nutrition_plan/presentation/screens/cycling_input_screen.dart`

**UI Components:**
- Hero image (cycling-themed)
- Date & Time selectors
- Distance input with increment/decrement (miles)
- Average Speed input with increment/decrement (mph)
  - Display calculated duration below: "Duration: ~83 min"
- Intensity Target dropdown:
  - Zone 1 - Recovery
  - Zone 2 - Endurance
  - Zone 3 - Tempo
  - Zone 4 - Threshold
  - Zone 5 - VO2 Max
- Session Goal dropdown:
  - Endurance
  - Tempo
  - Intervals
- Terrain & Aero Load dropdown:
  - Flat - Indoor
  - Flat - Outdoor
  - Rolling - Outdoor
  - Hilly - Outdoor
- Elevation Gain input (feet)
- Pre-Ride Timing selector (same as running: 30min, 1hr, 2hr, 3hr, 4hr)
- Environment section (collapsible):
  - Temperature slider (°C or °F)
  - Humidity slider (%)
  - Wind: Still / Breezy / Windy
  - Sun: Full Sun / Mixed / Shade
- Primary button: "Generate Nutrition Plan"

#### Swimming Input Screen (NEW)
**File:** `lib/features/nutrition_plan/presentation/screens/swimming_input_screen.dart`

**UI Components:**
- Hero image (swimming-themed)
- Date & Time selectors
- Pool / Open Water toggle
- Distance input (meters or yards)
- Pace per 100m input (MM:SS format)
  - Display calculated duration below: "Duration: ~40 min"
- Intensity Target dropdown:
  - Zone 1 - Easy
  - Zone 2 - Moderate
  - Zone 3 - Hard
  - Zone 4 - Very Hard
- Session Goal dropdown:
  - Technique
  - Endurance
  - Sets
- Water Temperature input (°C or °F)
- Pre-Swim Timing selector
- Environment section (for pool swims):
  - Deck temperature
  - Deck humidity
- Primary button: "Generate Nutrition Plan"

#### Nutrition Plan Display (Updated for Sport-Agnostic)
**Files:**
- `lib/features/nutrition_plan/presentation/screens/nutrition_plan_screen.dart`
- `lib/features/nutrition_plan/presentation/screens/macro_targets_screen.dart`

**Changes Required:**
- All text comes from ContentService with `{activity_type}` placeholder
- Examples:
  - Running: "Before Your Run" → "2-3 hours before"
  - Cycling: "Before Your Ride" → "2-3 hours before"
  - Swimming: "Before Your Swim" → "2-3 hours before"

  - Running: "During Your Run" → "Throughout run"
  - Cycling: "On The Bike" → "Throughout ride"
  - Swimming: "During Your Swim" → "At feed stops (if applicable)"

  - Running: "After Your Run" → "Within 30 minutes"
  - Cycling: "Post-Ride Recovery" → "Within 30 minutes"
  - Swimming: "Post-Swim Recovery" → "Within 30 minutes"

**ContentService Keys:**
```json
{
  "nutrition_plan": {
    "before_running_title": "Before Your Run",
    "before_cycling_title": "Before Your Ride",
    "before_swimming_title": "Before Your Swim",
    "during_running_title": "During Your Run",
    "during_cycling_title": "On The Bike",
    "during_swimming_title": "During Your Swim",
    "after_running_title": "After Your Run",
    "after_cycling_title": "Post-Ride Recovery",
    "after_swimming_title": "Post-Swim Recovery"
  }
}
```

### 8. Content Management System Updates

**New Content Keys Required:**

```json
{
  "onboarding": {
    "sport_preferences_title": "Which sports do you do?",
    "ftp_label": "FTP (Functional Threshold Power)",
    "ftp_help": "Your FTP is the maximum power you can sustain for ~1 hour. If you don't know, enter 0 and we'll estimate.",
    "css_label": "CSS (Critical Swim Speed)",
    "css_help": "Your CSS is the fastest pace you can sustain for 30 minutes of continuous swimming. Format: MM:SS per 100m. Example: 2:00 means 2 minutes per 100 meters.",
    "bike_bottles_label": "How many water bottles can you carry?",
    "wetsuit_label": "Do you typically wear a wetsuit?",
    "swim_cap_label": "What swim cap do you usually wear?",
    "gi_sensitivity_label": "Do you have a sensitive stomach during exercise?",
    "gi_sensitivity_help": "This helps us recommend foods that are easier to digest"
  },
  "activity_input": {
    "cycling_title": "Plan Your Ride",
    "swimming_title": "Plan Your Swim",
    "average_speed_label": "Average Speed",
    "pace_per_100m_label": "Pace per 100m",
    "intensity_target_label": "Intensity Target",
    "session_goal_label": "Session Goal",
    "terrain_label": "Terrain & Aero Load",
    "elevation_gain_label": "Elevation Gain",
    "pool_open_water_label": "Pool or Open Water",
    "water_temperature_label": "Water Temperature"
  }
}
```

### 9. FOA Architecture Compliance

**All new code MUST follow Andrea Bizzotto's FOA patterns:**

#### Controllers (Application Layer)
- `CyclingInputController` - Handles cycling input logic
- `SwimmingInputController` - Handles swimming input logic
- `ActivityCreationController` - Orchestrates activity creation across sports
- All controllers extend `AsyncNotifier<T>` with `@riverpod` annotation

#### Services (Application Layer)
- `CyclingNutritionService` - Business logic for cycling nutrition calculations
- `SwimmingNutritionService` - Business logic for swimming nutrition calculations
- `MultiSportCalendarService` - Handles multi-sport calendar operations

#### Repositories (Data Layer)
- `ActivityRepository` (existing) - Update to handle new sport-specific fields
- `UserPreferencesRepository` (existing) - Update to handle FTP, CSS, etc.

#### Models (Domain Layer)
- `CyclingParameters` - Domain model for cycling activity inputs
- `SwimmingParameters` - Domain model for swimming activity inputs
- `SportSpecificMacros` - Domain model for sport-specific macro targets

**Critical Rules:**
- ❌ NO business logic in UI screens
- ❌ NO API calls from UI screens
- ❌ NO underscore methods with business logic in UI
- ✅ ALL API calls in controllers
- ✅ ALL data transformations in services
- ✅ ALL calculations in edge functions or services

### 10. Testing Requirements

**Edge Function Tests (Priority: HIGH)**

Create new test files:
- `supabase/functions/generate-macros/test/cycling.test.ts`
- `supabase/functions/generate-macros/test/swimming.test.ts`
- `supabase/functions/generate-nutrition-plan/test/cycling.test.ts`
- `supabase/functions/generate-nutrition-plan/test/swimming.test.ts`

**Integration Tests:**
- Test macro generation for cycling activities
- Test macro generation for swimming activities
- Test nutrition plan generation for all 3 sports
- Test activity type switching (running → cycling → swimming)

**Backward Compatibility:**
- DO NOT modify existing running tests
- Existing running functionality must continue to work exactly as before

**Test Coverage Goals:**
- Edge functions: 80%+ coverage for new cycling/swimming code
- Critical paths: 100% coverage for energy expenditure formulas

### 11. Deployment Strategy

**Development Environment:**
1. Create new edge functions in **dev** Supabase first
2. Test with dev database
3. Verify all formulas against research

**Production Deployment:**
- NO feature flags required
- Full release to all users immediately
- Update App Store description to highlight multi-sport support

**Rollout Plan:**
1. Deploy updated schema to dev database
2. Deploy new edge functions to dev
3. Test end-to-end in dev environment
4. Deploy to production (database + edge functions + app)
5. Submit app update to Apple App Store / Google Play

### 12. Success Metrics

**User Adoption:**
- % of users creating cycling activities
- % of users creating swimming activities
- % of users creating all 3 activity types (triathletes)

**Technical Metrics:**
- Edge function success rate for cycling/swimming
- Average response time for new sports
- Error rate for sport-specific calculations

**Feedback Loop:**
- In-app feedback form asking: "How accurate was your nutrition plan?"
- Track completion ratings by sport type
- Monitor food preference patterns by sport

## Out of Scope (Phase 2)

- Brick workouts (cycling → running transitions)
- Multi-sport events (triathlons) as single activity
- Auto-import from Strava/Garmin for cycling/swimming data
- Power meter integration for real-time FTP detection
- Swim stroke analysis integration
- Weather API integration for auto-fill environment data

## Technical Risks & Mitigations

### Risk 1: Formula Accuracy
**Risk**: Cycling and swimming energy expenditure formulas may not match real-world results
**Mitigation**:
- Start with conservative estimates
- Collect user feedback via completion ratings
- Iterate formulas based on data

### Risk 2: UI Complexity
**Risk**: Too many input fields may overwhelm users
**Mitigation**:
- Make advanced fields collapsible (environment section)
- Provide sensible defaults based on onboarding data
- Show helpful tooltips and examples

### Risk 3: Edge Function Complexity
**Risk**: Unified edge functions become too complex with if/else branches
**Mitigation**:
- Use strategy pattern to separate sport-specific logic
- Comprehensive unit tests for each sport
- Clear code comments and documentation

### Risk 4: Database Performance
**Risk**: Additional columns may slow down queries
**Mitigation**:
- Nullable columns don't add significant overhead
- Existing indexes on `user_id`, `activity_type`, `scheduled_date_time` remain effective
- Monitor query performance in production

## Timeline Estimate

**Phase 1: Documentation & Planning** (Complete)
- Requirements gathering ✅
- Formula research ✅
- Architecture decisions ✅

**Phase 2: Backend (Edge Functions)** (2-3 weeks)
- Refactor existing edge functions for multi-sport
- Implement cycling energy formulas
- Implement swimming energy formulas
- Write comprehensive tests

**Phase 3: Database & Models** (1 week)
- Update schema with new columns
- Create migration scripts for dev/prod
- Update Drift models
- Update domain models

**Phase 4: Frontend (UI Screens)** (2-3 weeks)
- Implement `CyclingInputScreen`
- Implement `SwimmingInputScreen`
- Update onboarding flow
- Update settings screen
- Make nutrition plan display sport-agnostic

**Phase 5: Testing & QA** (1-2 weeks)
- End-to-end testing
- Manual QA on dev devices
- Performance testing
- User acceptance testing

**Phase 6: Deployment** (1 week)
- Deploy to production
- App store submission
- Marketing materials update

**Total Estimated Timeline: 7-10 weeks**

## Documentation Structure

This feature is documented across multiple files:

- **README.md** (this file) - Overview and requirements
- **roadmap.md** - Detailed implementation steps with priority order
- **formulas.md** - Evidence-based sports science formulas for each sport
- **edge-functions.md** - Technical specification for unified edge functions
- **database-schema.md** - Complete schema changes and migration strategy

## References

- ChatGPT Deep Research: `docs/features/cycling_swimming/chatgpt_deep_research.md`
- ChatGPT Conversation 1: `docs/features/cycling_swimming/chatgpt_convo_1.md`
- UI Screenshots: `docs/features/cycling_swimming/screenshot_*.png`
- ACSM Guidelines for Exercise Testing and Prescription (10th Edition)
- Sports Medicine - Open (2024) - Marathon Nutrition Guidelines
- Nutrients (2023) - Food-First Approach for Endurance Athletes

---

**Document Version:** 1.0
**Last Updated:** 2025-10-15
**Status:** APPROVED - Ready for Implementation
