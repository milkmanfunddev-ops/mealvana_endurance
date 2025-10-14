# Calendar Feature Database Implementation Plan

## Overview

This document outlines the database implementation strategy for the Calendar feature in Mealvana Endurance. We are implementing the calendar feature as part of the v1 schema, adding new tables while preserving all existing functionality and data.

## Implementation Strategy

### Current State: v1 Schema
- Existing nutrition planning tables
- Voice notes functionality
- User profiles and preferences
- Food database and user preferences

### Target State: Enhanced v1 Schema
- All existing tables preserved
- New calendar-specific tables added
- Extended existing tables with calendar relationships
- Proper indexing for performance

## Implementation Phases

## Phase 1: Schema Creation (New Tables)

### Implementation: Direct Table Creation

Since we're working with v1 schema, we'll add the calendar tables directly to the existing database schema:

```dart
// In lib/shared/database/app_database.dart
@DriftDatabase(tables: [
  // Existing tables...
  Activities,
  Events, 
  ActivityCompletions,
  CarbLoadingPlans,
  CarbLoadingDays,
])
class AppDatabase extends _$AppDatabase {
  // ... existing implementation
}
```

## Phase 2: Table Extensions

### Implementation: Direct Table Modifications

Since we're working with v1 schema, we'll extend the existing tables directly:

```dart
// In lib/shared/database/tables/user_profiles.dart
@DataClassName('UserProfile')
class UserProfiles extends Table {
  // Existing columns...
  TextColumn get calendarWeekStart => text().withDefault(const Constant('monday'))();
  TimeColumn get defaultActivityTime => time().withDefault(const Constant('07:00:00'))();
  // ... other calendar preference columns
}

// In lib/shared/database/tables/nutrition_plans.dart  
@DataClassName('NutritionPlan')
class NutritionPlans extends Table {
  // Existing columns...
  TextColumn get activityId => text().nullable()();
  TextColumn get planType => text().withDefault(const Constant('standard'))();
  // ... other calendar integration columns
}
```

## Phase 3: Data Initialization

### Implementation: Default Values Setup

Since we're working with v1 schema, we'll set up default values during table creation:

```dart
// In table definitions, use withDefault for existing data compatibility
TextColumn get planType => text().withDefault(const Constant('standard'))();
TextColumn get sportType => text().withDefault(const Constant('running'))();
TextColumn get calendarWeekStart => text().withDefault(const Constant('monday'))();
```

### Data Backfill Script (if needed for existing data)

```dart
// One-time script to backfill existing records
Future<void> backfillExistingData(AppDatabase database) async {
  // Update existing nutrition plans with default values
  await database.customStatement('''
    UPDATE nutrition_plans 
    SET plan_type = 'standard', sport_type = 'running' 
    WHERE plan_type IS NULL OR sport_type IS NULL
  ''');
}
```

## Testing Strategy

### Schema Validation
- Verify all tables are created with proper structure
- Test foreign key relationships
- Validate indexes are properly created
- Test default values and constraints

### Data Integrity Testing
- Test activity creation and retrieval
- Verify nutrition plan relationships
- Test user profile extensions
- Validate carb loading plan functionality

### Performance Testing
- Test calendar query performance
- Verify index effectiveness
- Test with large datasets
- Validate memory usage

## Implementation Execution Plan

### Pre-Implementation Checklist
- [x] Verify current v1 schema structure
- [x] Design new calendar tables
- [x] Create domain models
- [ ] Test new tables in development environment
- [ ] Validate table relationships
- [ ] Test default values and constraints

### Implementation Steps
1. **Add calendar tables** to AppDatabase class
2. **Extend existing tables** with calendar columns
3. **Run build runner** to generate table classes
4. **Create service layer** for calendar operations
5. **Implement controllers** for state management
6. **Build UI components** for calendar views
7. **Test end-to-end functionality**
8. **Performance optimization** and tuning

### Post-Implementation Verification
- [ ] All calendar tables created successfully
- [ ] Existing functionality still works
- [ ] Nutrition plans accessible through calendar
- [ ] Performance metrics within acceptable range
- [ ] Error rates remain stable

## New Tables Summary

### Activities Table
- Central table for all calendar entries
- Supports both workouts and events
- Includes status tracking and metadata
- Properly indexed for date range queries

### Events Table
- Specialized data for race events
- Links to activities via one-to-one relationship
- Includes carb loading configuration
- Supports various race types and distances

### ActivityCompletions Table
- Detailed completion data
- User ratings and feedback
- Weather conditions and performance metrics
- Voice note integration

### CarbLoadingPlans Table
- Multi-day carb loading schedules
- Generated based on event configuration
- Includes adherence tracking
- Supports different plan durations

### CarbLoadingDays Table
- Individual day entries within carb loading plans
- Daily targets and meal distribution
- Progress tracking and completion status
- Links to nutrition plan generation

## Extended Tables Summary

### UserProfiles Extensions
- Calendar preferences (week start, default times)
- Activity defaults and reminders
- Auto-generation preferences

### NutritionPlans Extensions
- Activity relationship for calendar integration
- Plan type classification (standard, carb loading, recovery)
- Sport type placeholder for future multi-sport support

## Index Strategy

### Performance-Critical Indexes
- User ID + scheduled date time for calendar queries
- Activity status for filtering
- Event type for race-specific queries
- Carb loading plan dates for meal planning

### Relationship Indexes
- Activity ID in events table
- Activity ID in nutrition plans table
- Event ID in carb loading plans table
- Plan ID in carb loading days table

## Data Integrity Rules

### Constraints
- Activity status must be valid enum value
- Event type must be supported race distance
- Carb loading days must be within valid range (1, 2, 3, 7)
- Completion ratings must be between 1-5

### Cascade Behaviors
- Activity deletion cascades to related events and completions
- Event deletion cascades to carb loading plans
- User deletion cascades to all user data

## Offline-First Considerations

### Local Storage Priority
- All calendar operations write to local database first
- Background sync handles Supabase synchronization
- Conflict resolution for concurrent edits
- Offline mode with full functionality

### Sync Strategy
- Incremental sync for calendar data
- Conflict detection and resolution
- Fallback to local data when offline
- Sync status indicators in UI

---

This implementation plan ensures the calendar feature integrates seamlessly with the existing v1 schema while maintaining data integrity and performance standards.