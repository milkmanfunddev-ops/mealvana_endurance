# Final Surge Integration - Implementation Roadmap

**Last Updated**: December 22, 2025
**Status**: Ready for Implementation
**Reference**: [Notes](./notes.md) | [Technical Architecture](./technical-architecture.md)

---

## Executive Summary

This roadmap details the implementation of Final Surge integration for Mealvana Endurance. The integration will:
- Add Final Surge as the **first screen** in onboarding (with TrainingPeaks + Strava as "Coming Soon")
- Import **upcoming workouts** (14 days) for running, cycling, and swimming
- **Auto-detect** user's sports from workout history and pre-populate onboarding
- Generate **nutrition plans** for imported workouts via chunked parallel processing
- Design for **multiple integrations** (extensible architecture)

### Key User Decisions (Finalized December 2025)

| Decision | Choice |
|----------|--------|
| **Update behavior** | Manual sync only (no auto-checking) |
| **Deleted workouts** | Keep in Mealvana if deleted in Final Surge |
| **Walk workouts** | Import as ActivityType.running + IntensityLevel.easy |
| **Missing data** | Apply sensible defaults (see below) |
| **Pace ranges** | Store min/max separately, display midpoint |
| **Swimming units** | Store in meters (industry standard) |
| **Sync triggers** | Manual sync button + initial onboarding |
| **Plan generation** | Immediate chunked parallel (5 concurrent) |
| **Range columns** | Add to schema (pace_min, pace_max) |
| **Workout subtype** | Add field (e.g., "Long Run", "Walk", "Recovery") |
| **Onboarding placement** | First screen (before User Profile) |
| **Settings display** | Show Final Surge athlete info |

### Sensible Defaults for Missing Data

When Final Surge workouts are missing distance/duration/pace:

| Sport | Distance | Duration | Pace |
|-------|----------|----------|------|
| **Running** | 3 miles | 30 min | 10:00/mile |
| **Cycling** | 10 miles | 45 min | 13.3 mph |
| **Swimming** | 1000 meters | 30 min | 180 sec/100m |

---

## Phase 0: API Testing & Validation

### Objective
**CRITICAL**: Thoroughly test Final Surge API before any implementation. Validate data formats, transformations, and edge cases.

### Why Testing First?
- Final Surge API documentation may not match reality
- Data transformation bugs are expensive to fix later
- Establishes confidence in all data flowing into our system
- Discovers edge cases (empty fields, unexpected formats, etc.)

### Tasks

#### 0.1 Create Test Fixtures from Real API Data

```dart
// test/fixtures/final_surge_fixtures.dart

/// Real workout data captured from Final Surge API
/// Used to validate transformations and edge cases

class FinalSurgeFixtures {
  /// Running workout with all fields populated
  static const runningWorkoutComplete = {
    'WorkoutId': 12345,
    'WorkoutDate': '2025-01-15',
    'WorkoutTitle': 'Marathon Tempo',
    'WorkoutTypeName': 'Run',
    'WorkoutIcon': 1,
    'PlannedDistance': 10.0,
    'PlannedDistanceType': 'mi',
    'PlannedTime': 4800, // 80 minutes in SECONDS
    'TargetPace': '8:00',
    'WorkoutDesc': 'Easy warmup, then marathon pace',
    'workout_url': 'https://log.finalsurge.com/workout?id=12345',
  };

  /// Running workout with pace RANGE
  static const runningWorkoutPaceRange = {
    'WorkoutId': 12346,
    'WorkoutDate': '2025-01-16',
    'WorkoutTitle': 'Easy Recovery',
    'WorkoutTypeName': 'Run',
    'PlannedDistance': 5.0,
    'PlannedDistanceType': 'mi',
    'PlannedTime': 2700, // 45 minutes
    'TargetPace': '8:30-9:30', // RANGE format
  };

  /// Walk workout - should map to running/easy
  static const walkWorkout = {
    'WorkoutId': 12347,
    'WorkoutDate': '2025-01-17',
    'WorkoutTitle': 'Active Recovery Walk',
    'WorkoutTypeName': 'Walk',
    'WorkoutIcon': 11, // Walk icon
    'PlannedDistance': 2.0,
    'PlannedDistanceType': 'mi',
    'PlannedTime': 2400, // 40 minutes
  };

  /// Swimming workout with meters
  static const swimmingWorkout = {
    'WorkoutId': 12348,
    'WorkoutDate': '2025-01-18',
    'WorkoutTitle': 'Pool Intervals',
    'WorkoutTypeName': 'Swim',
    'WorkoutIcon': 3,
    'PlannedDistance': 2000.0,
    'PlannedDistanceType': 'm', // meters
    'PlannedTime': 2400, // 40 minutes
  };

  /// Cycling workout
  static const cyclingWorkout = {
    'WorkoutId': 12349,
    'WorkoutDate': '2025-01-19',
    'WorkoutTitle': 'Endurance Ride',
    'WorkoutTypeName': 'Bike',
    'WorkoutIcon': 2,
    'PlannedDistance': 30.0,
    'PlannedDistanceType': 'mi',
    'PlannedTime': 5400, // 90 minutes
  };

  /// Workout with MISSING data - tests defaults
  static const workoutMissingData = {
    'WorkoutId': 12350,
    'WorkoutDate': '2025-01-20',
    'WorkoutTitle': 'Run TBD',
    'WorkoutTypeName': 'Run',
    // Missing: PlannedDistance, PlannedTime, TargetPace
  };

  /// Workout with null/empty fields
  static const workoutNullFields = {
    'WorkoutId': 12351,
    'WorkoutDate': '2025-01-21',
    'WorkoutTitle': null, // null title
    'WorkoutTypeName': 'Run',
    'PlannedDistance': null,
    'PlannedDistanceType': null,
    'PlannedTime': null,
    'TargetPace': '',
  };
}
```

#### 0.2 Data Transformation Tests

```dart
// test/features/integrations/final_surge_transformer_test.dart

import 'package:flutter_test/flutter_test.dart';
import '../fixtures/final_surge_fixtures.dart';

void main() {
  group('FinalSurgeTransformer', () {
    late FinalSurgeTransformer transformer;

    setUp(() {
      transformer = FinalSurgeTransformer();
    });

    group('Time conversion', () {
      test('converts PlannedTime seconds to minutes', () {
        final workout = FinalSurgeFixtures.runningWorkoutComplete;
        final result = transformer.transform(workout);

        // 4800 seconds = 80 minutes
        expect(result.durationMinutes, equals(80));
      });

      test('handles null PlannedTime with default', () {
        final workout = FinalSurgeFixtures.workoutMissingData;
        final result = transformer.transform(workout);

        // Default: 30 minutes for running
        expect(result.durationMinutes, equals(30));
      });
    });

    group('Pace parsing', () {
      test('parses single pace value', () {
        final workout = FinalSurgeFixtures.runningWorkoutComplete;
        final result = transformer.transform(workout);

        expect(result.paceTargetMinutesPerMile, equals(8.0));
        expect(result.paceMinMinutesPerMile, isNull);
        expect(result.paceMaxMinutesPerMile, isNull);
      });

      test('parses pace RANGE correctly', () {
        final workout = FinalSurgeFixtures.runningWorkoutPaceRange;
        final result = transformer.transform(workout);

        // "8:30-9:30" should give us min=8.5, max=9.5
        expect(result.paceMinMinutesPerMile, equals(8.5));
        expect(result.paceMaxMinutesPerMile, equals(9.5));
        // Midpoint for display
        expect(result.paceTargetMinutesPerMile, equals(9.0));
      });

      test('handles empty pace with default', () {
        final workout = FinalSurgeFixtures.workoutNullFields;
        final result = transformer.transform(workout);

        // Default: 10:00/mile for running
        expect(result.paceTargetMinutesPerMile, equals(10.0));
      });
    });

    group('Sport type mapping', () {
      test('maps Run to ActivityType.running', () {
        final workout = FinalSurgeFixtures.runningWorkoutComplete;
        final result = transformer.transform(workout);

        expect(result.activityType, equals(ActivityType.running));
      });

      test('maps Walk to ActivityType.running with easy intensity', () {
        final workout = FinalSurgeFixtures.walkWorkout;
        final result = transformer.transform(workout);

        expect(result.activityType, equals(ActivityType.running));
        expect(result.intensityLevel, equals(IntensityLevel.easy));
        expect(result.workoutSubtype, equals('Walk'));
      });

      test('maps Swim to ActivityType.swimming', () {
        final workout = FinalSurgeFixtures.swimmingWorkout;
        final result = transformer.transform(workout);

        expect(result.activityType, equals(ActivityType.swimming));
      });

      test('maps Bike to ActivityType.cycling', () {
        final workout = FinalSurgeFixtures.cyclingWorkout;
        final result = transformer.transform(workout);

        expect(result.activityType, equals(ActivityType.cycling));
      });
    });

    group('Distance conversion', () {
      test('converts miles to stored value', () {
        final workout = FinalSurgeFixtures.runningWorkoutComplete;
        final result = transformer.transform(workout);

        expect(result.distanceMiles, equals(10.0));
      });

      test('stores swimming distance in meters', () {
        final workout = FinalSurgeFixtures.swimmingWorkout;
        final result = transformer.transform(workout);

        expect(result.distanceMeters, equals(2000.0));
      });

      test('applies default distance when missing', () {
        final workout = FinalSurgeFixtures.workoutMissingData;
        final result = transformer.transform(workout);

        // Default: 3 miles for running
        expect(result.distanceMiles, equals(3.0));
      });
    });

    group('Sensible defaults', () {
      test('applies running defaults for missing data', () {
        final workout = FinalSurgeFixtures.workoutMissingData;
        final result = transformer.transform(workout);

        expect(result.distanceMiles, equals(3.0));
        expect(result.durationMinutes, equals(30));
        expect(result.paceTargetMinutesPerMile, equals(10.0));
      });
    });

    group('Workout ID extraction', () {
      test('extracts workout ID from URL', () {
        final workout = FinalSurgeFixtures.runningWorkoutComplete;
        final id = transformer.extractWorkoutId(workout['workout_url'] as String);

        expect(id, equals('12345'));
      });
    });
  });
}
```

#### 0.3 Live API Integration Tests

```dart
// test/integration/final_surge_api_test.dart

/// These tests hit the REAL Final Surge API
/// Run manually with: flutter test test/integration/final_surge_api_test.dart

@Tags(['integration'])
void main() {
  group('Final Surge Live API', () {
    late FinalSurgeApiClient client;
    late String accessToken;

    setUpAll(() async {
      // Load cached token from previous OAuth
      final tokenFile = File('.final_surge_token.json');
      if (!tokenFile.existsSync()) {
        throw Exception('Run tool/final_surge_api_test.dart auth first');
      }
      final tokenJson = jsonDecode(tokenFile.readAsStringSync());
      accessToken = tokenJson['access_token'];

      client = FinalSurgeApiClient();
    });

    test('fetches upcoming workouts', () async {
      final workouts = await client.getUpcomingWorkouts(
        accessToken,
        numDays: 7,
        numWorkouts: 21,
      );

      logTestHeading('Upcoming Workouts');
      logTestResult('Total workouts', workouts.length);

      expect(workouts, isNotEmpty);
    });

    test('validates workout structure matches expected fields', () async {
      final workouts = await client.getUpcomingWorkouts(
        accessToken,
        numDays: 7,
        numWorkouts: 21,
      );

      if (workouts.isNotEmpty) {
        final workout = workouts.first;

        logTestHeading('Workout Structure Validation');
        logTestInput({
          'WorkoutId': workout.workoutId,
          'WorkoutTypeName': workout.workoutTypeName,
          'PlannedTime type': workout.plannedTime?.runtimeType,
          'PlannedDistance type': workout.plannedDistance?.runtimeType,
          'TargetPace': workout.targetPace,
        });

        // Validate required fields exist
        expect(workout.workoutId, isNotNull);
        expect(workout.workoutDate, isNotNull);
      }
    });

    test('validates time is in SECONDS (not minutes)', () async {
      final workouts = await client.getUpcomingWorkouts(
        accessToken,
        numDays: 7,
        numWorkouts: 21,
      );

      final workoutWithTime = workouts.firstWhere(
        (w) => w.plannedTime != null && w.plannedTime! > 0,
        orElse: () => throw Exception('No workout with time found'),
      );

      logTestHeading('Time Format Validation');
      logTestResult('PlannedTime raw value', workoutWithTime.plannedTime);

      // If PlannedTime > 200, it's likely seconds (30 min = 1800 sec)
      // If PlannedTime < 200, it might be minutes
      logAssertion(
        'PlannedTime appears to be in seconds',
        passed: workoutWithTime.plannedTime! > 200,
        reason: 'Value ${workoutWithTime.plannedTime} should be > 200 for seconds',
      );
    });

    test('validates pace range format', () async {
      final workouts = await client.getUpcomingWorkouts(
        accessToken,
        numDays: 7,
        numWorkouts: 21,
      );

      final pacesFound = workouts
          .where((w) => w.targetPace != null && w.targetPace!.isNotEmpty)
          .map((w) => w.targetPace!)
          .toList();

      logTestHeading('Pace Format Analysis');
      for (final pace in pacesFound.take(5)) {
        final isRange = pace.contains('-');
        logTestResult('Pace', pace, expected: isRange ? 'RANGE' : 'SINGLE');
      }
    });
  });
}
```

#### 0.4 Edge Function Tests

```typescript
// supabase/functions/sync-final-surge/index.test.ts

import { assertEquals, assertExists } from 'std/assert/mod.ts';
import { describe, it } from 'std/testing/bdd.ts';

describe('Final Surge Sync Edge Function', () => {
  describe('Sport mapping', () => {
    it('maps Run to running', () => {
      const result = mapSportType('Run');
      assertEquals(result, 'running');
    });

    it('maps Walk to running (with easy intensity)', () => {
      const result = mapWorkoutToActivity({ WorkoutTypeName: 'Walk' });
      assertEquals(result.activity_type, 'running');
      assertEquals(result.intensity_level, 'easy');
      assertEquals(result.workout_subtype, 'Walk');
    });

    it('maps Bike to cycling', () => {
      const result = mapSportType('Bike');
      assertEquals(result, 'cycling');
    });

    it('maps Swim to swimming', () => {
      const result = mapSportType('Swim');
      assertEquals(result, 'swimming');
    });
  });

  describe('Time conversion', () => {
    it('converts seconds to minutes', () => {
      const result = convertPlannedTime(1800); // 30 min in seconds
      assertEquals(result, 30);
    });

    it('applies running default for null', () => {
      const result = convertPlannedTime(null, 'running');
      assertEquals(result, 30); // default
    });
  });

  describe('Pace parsing', () => {
    it('parses single pace "8:00"', () => {
      const result = parsePace('8:00');
      assertEquals(result.target, 8.0);
      assertEquals(result.min, null);
      assertEquals(result.max, null);
    });

    it('parses range pace "8:30-9:30"', () => {
      const result = parsePace('8:30-9:30');
      assertEquals(result.min, 8.5);
      assertEquals(result.max, 9.5);
      assertEquals(result.target, 9.0); // midpoint
    });

    it('handles empty pace with default', () => {
      const result = parsePace('', 'running');
      assertEquals(result.target, 10.0); // default
    });
  });

  describe('Sensible defaults', () => {
    it('applies running defaults', () => {
      const result = applyDefaults({}, 'running');
      assertEquals(result.distance_miles, 3.0);
      assertEquals(result.duration_minutes, 30);
      assertEquals(result.pace_target, 10.0);
    });

    it('applies cycling defaults', () => {
      const result = applyDefaults({}, 'cycling');
      assertEquals(result.distance_miles, 10.0);
      assertEquals(result.duration_minutes, 45);
    });

    it('applies swimming defaults', () => {
      const result = applyDefaults({}, 'swimming');
      assertEquals(result.distance_meters, 1000.0);
      assertEquals(result.duration_minutes, 30);
    });
  });
});
```

### Deliverables
- [ ] Test fixtures created from real API data
- [ ] Data transformation tests passing
- [ ] Live API integration tests passing
- [ ] Edge function tests passing
- [ ] All edge cases documented and handled
- [ ] Time format confirmed (seconds vs minutes)
- [ ] Pace range format confirmed
- [ ] All supported workout types mapped

---

## Phase 1: Database & Schema Setup

### Objective
Create database infrastructure to support Final Surge and future integrations.

### Tasks

#### 1.1 Create `integrations` Table (Drift + Supabase)

```sql
-- supabase/migrations/YYYYMMDDHHMMSS_create_integrations_table.sql

CREATE TABLE integrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL CHECK (provider IN ('final_surge', 'training_peaks', 'strava', 'garmin')),

  -- OAuth tokens (encrypted at rest)
  access_token TEXT NOT NULL,
  refresh_token TEXT,
  token_expires_at TIMESTAMPTZ,

  -- Provider-specific data (displayed in Settings)
  provider_athlete_id TEXT NOT NULL,
  provider_athlete_name TEXT,
  provider_athlete_email TEXT,

  -- Sync metadata
  is_active BOOLEAN DEFAULT true,
  last_sync_at TIMESTAMPTZ,
  last_sync_status TEXT CHECK (last_sync_status IN ('success', 'error', 'pending')),
  last_sync_error TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, provider)
);

-- Indexes
CREATE INDEX idx_integrations_user_provider ON integrations(user_id, provider);
CREATE INDEX idx_integrations_active ON integrations(is_active) WHERE is_active = true;

-- RLS Policies
ALTER TABLE integrations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own integrations"
  ON integrations FOR ALL
  USING (auth.uid() = user_id OR user_id IN (
    SELECT id FROM users WHERE device_id = current_setting('request.headers')::json->>'x-device-id'
  ));
```

#### 1.2 Add Sync & Range Columns to `activities` Table

```sql
-- supabase/migrations/YYYYMMDDHHMMSS_add_activity_sync_columns.sql

-- External sync tracking
ALTER TABLE activities ADD COLUMN IF NOT EXISTS synced_from_provider TEXT;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS provider_workout_id TEXT;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS provider_workout_url TEXT;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ;

-- Workout subtype (e.g., "Long Run", "Walk", "Recovery", "Intervals")
ALTER TABLE activities ADD COLUMN IF NOT EXISTS workout_subtype TEXT;

-- Pace ranges (for workouts with "8:30-9:30" style paces)
ALTER TABLE activities ADD COLUMN IF NOT EXISTS pace_min_minutes_per_mile REAL;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS pace_max_minutes_per_mile REAL;

-- Swimming distance in meters (industry standard)
ALTER TABLE activities ADD COLUMN IF NOT EXISTS distance_meters REAL;

-- Index for finding synced activities
CREATE INDEX IF NOT EXISTS idx_activities_provider_sync
  ON activities(synced_from_provider, provider_workout_id)
  WHERE synced_from_provider IS NOT NULL;
```

#### 1.3 Update Drift Schema

```dart
// lib/shared/database/tables/integrations.dart

@DataClassName('Integration')
class Integrations extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get provider => text()();

  TextColumn get accessToken => text()();
  TextColumn get refreshToken => text().nullable()();
  DateTimeColumn get tokenExpiresAt => dateTime().nullable()();

  TextColumn get providerAthleteId => text()();
  TextColumn get providerAthleteName => text().nullable()();
  TextColumn get providerAthleteEmail => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  TextColumn get lastSyncStatus => text().nullable()();
  TextColumn get lastSyncError => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

```dart
// Update lib/shared/database/tables/activities_table.dart

// Add new columns:
TextColumn get syncedFromProvider => text().nullable()();
TextColumn get providerWorkoutId => text().nullable()();
TextColumn get providerWorkoutUrl => text().nullable()();
DateTimeColumn get lastSyncedAt => dateTime().nullable()();

TextColumn get workoutSubtype => text().nullable()();

RealColumn get paceMinMinutesPerMile => real().nullable()();
RealColumn get paceMaxMinutesPerMile => real().nullable()();

RealColumn get distanceMeters => real().nullable()();
```

#### 1.4 Create FOA Directory Structure

```
lib/features/integrations/
├── presentation/
│   ├── widgets/
│   │   ├── integration_card.dart
│   │   ├── final_surge_connect_button.dart
│   │   ├── sync_status_badge.dart
│   │   └── nutrition_plan_progress.dart
│   ├── screens/
│   │   ├── connect_integrations_screen.dart     # Onboarding screen
│   │   └── connected_apps_screen.dart           # Settings screen
│   └── providers/
│       ├── final_surge_controller.dart
│       └── final_surge_controller.g.dart
├── application/
│   ├── final_surge_oauth_service.dart
│   ├── final_surge_sync_service.dart
│   ├── final_surge_transformer.dart             # Data transformation logic
│   └── integration_manager_service.dart
├── domain/
│   ├── integration.dart
│   ├── final_surge_workout.dart
│   ├── final_surge_defaults.dart                # Sensible defaults
│   └── sync_result.dart
└── data/
    ├── integration_repository.dart
    └── final_surge_api_client.dart
```

### Deliverables
- [ ] `integrations` table created in Supabase (dev + prod)
- [ ] Activity sync & range columns added
- [ ] Drift schema updated and code generated
- [ ] FOA directory structure created
- [ ] Domain models defined
- [ ] Drift migration created and tested

---

## Phase 2: OAuth Implementation

### Objective
Enable users to connect their Final Surge account via OAuth 2.0.

### Approach: flutter_web_auth_2

Uses `flutter_web_auth_2` which opens a secure in-app browser (ASWebAuthenticationSession on iOS, Custom Tabs on Android).

### Tasks

#### 2.1 Add flutter_web_auth_2 Dependency

```yaml
# pubspec.yaml
dependencies:
  flutter_web_auth_2: ^3.1.2
```

#### 2.2 FinalSurgeApiClient (Data Layer)

```dart
// lib/features/integrations/data/final_surge_api_client.dart

class FinalSurgeApiClient {
  static const _baseUrl = 'https://log.finalsurge.com';

  Future<FinalSurgeTokenResponse> exchangeCodeForToken(String code) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client-id': _clientId,
        'client-secret': _clientSecret,
        'code': code,
      },
    );
    return FinalSurgeTokenResponse.fromJson(jsonDecode(response.body));
  }

  Future<List<FinalSurgeWorkout>> getUpcomingWorkouts(
    String accessToken, {
    int numDays = 7,
    int numWorkouts = 21,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/API/v1/UpcomingWorkouts')
          .replace(queryParameters: {
        'NumDays': numDays.toString(),
        'NumWorkouts': numWorkouts.toString(),
      }),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final json = jsonDecode(response.body);
    return (json['Workouts'] as List)
        .map((w) => FinalSurgeWorkout.fromJson(w))
        .toList();
  }
}
```

#### 2.3 FinalSurgeOAuthService (Application Layer)

```dart
// lib/features/integrations/application/final_surge_oauth_service.dart

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

class FinalSurgeOAuthService {
  static const _callbackUrlScheme = 'com.mealvana.endurance';

  Future<Integration> authenticate() async {
    // 1. Generate state for CSRF protection
    final state = _generateState();

    // 2. Build OAuth authorization URL
    final authUrl = Uri.https('log.finalsurge.com', '/oauth/authorize', {
      'client-id': _clientId,
      'redirect-uri': '$_callbackUrlScheme://callback',
      'state': state,
    });

    // 3. Launch OAuth flow via flutter_web_auth_2
    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackUrlScheme,
      options: const FlutterWebAuth2Options(preferEphemeral: true),
    );

    // 4. Extract authorization code
    final callbackUri = Uri.parse(result);
    final code = callbackUri.queryParameters['code'];

    if (code == null) {
      throw Exception('No authorization code received from Final Surge');
    }

    // 5. Exchange code for access token
    final tokenResponse = await _apiClient.exchangeCodeForToken(code);

    // 6. Create and store integration
    final integration = Integration(
      id: const Uuid().v4(),
      userId: _currentUserId,
      provider: 'final_surge',
      accessToken: tokenResponse.accessToken,
      providerAthleteId: tokenResponse.athlete.id,
      providerAthleteName: '${tokenResponse.athlete.firstname} ${tokenResponse.athlete.lastname}',
      providerAthleteEmail: tokenResponse.athlete.email,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repository.saveIntegration(integration);
    return integration;
  }
}
```

### Deliverables
- [ ] `flutter_web_auth_2` package added
- [ ] `FinalSurgeApiClient` implemented
- [ ] `FinalSurgeOAuthService` implemented
- [ ] `IntegrationRepository` implemented
- [ ] OAuth flow tested on iOS + Android
- [ ] Token stored securely in Drift database

---

## Phase 3: Workout Sync & Data Transformation

### Objective
Import upcoming workouts with proper data transformation and sensible defaults.

### Key Decision: Manual Sync Only

For MVP, sync is **MANUAL ONLY**:
- User clicks "Sync Now" button
- Initial sync during onboarding
- No automatic background checking

### Tasks

#### 3.1 Create FinalSurgeDefaults

```dart
// lib/features/integrations/domain/final_surge_defaults.dart

class FinalSurgeDefaults {
  // Running defaults
  static const double runningDistanceMiles = 3.0;
  static const int runningDurationMinutes = 30;
  static const double runningPaceMinPerMile = 10.0;

  // Cycling defaults
  static const double cyclingDistanceMiles = 10.0;
  static const int cyclingDurationMinutes = 45;
  static const double cyclingSpeedMph = 13.3;

  // Swimming defaults (in meters - industry standard)
  static const double swimmingDistanceMeters = 1000.0;
  static const int swimmingDurationMinutes = 30;
  static const int swimmingPacePer100mSeconds = 180; // 3 min per 100m
}
```

#### 3.2 Create FinalSurgeTransformer

```dart
// lib/features/integrations/application/final_surge_transformer.dart

class FinalSurgeTransformer {
  /// Transforms a Final Surge workout to a Mealvana Activity
  Activity transform(Map<String, dynamic> workout, String userId) {
    final sportType = _mapSportType(workout['WorkoutTypeName']);
    final isWalk = workout['WorkoutTypeName']?.toLowerCase() == 'walk';

    return Activity(
      id: const Uuid().v4(),
      userId: userId,
      name: workout['WorkoutTitle'] ?? workout['WorkoutTypeName'] ?? 'Workout',
      activityType: sportType,
      intensityLevel: isWalk ? IntensityLevel.easy : _inferIntensity(workout),
      workoutSubtype: isWalk ? 'Walk' : workout['WorkoutDesc'],
      scheduledDate: DateTime.parse(workout['WorkoutDate']),

      // Distance
      distanceMiles: sportType != ActivityType.swimming
          ? _getDistanceMiles(workout, sportType)
          : null,
      distanceMeters: sportType == ActivityType.swimming
          ? _getDistanceMeters(workout)
          : null,

      // Duration (PlannedTime is in SECONDS, convert to minutes)
      durationMinutes: _getDurationMinutes(workout, sportType),

      // Pace (handle ranges)
      ...(_parsePace(workout['TargetPace'], sportType)),

      // Sync metadata
      syncedFromProvider: 'final_surge',
      providerWorkoutId: _extractWorkoutId(workout['workout_url']),
      providerWorkoutUrl: workout['workout_url'],
      lastSyncedAt: DateTime.now(),

      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  ActivityType _mapSportType(String? workoutTypeName) {
    switch (workoutTypeName?.toLowerCase()) {
      case 'run':
      case 'walk': // Walk maps to running with easy intensity
        return ActivityType.running;
      case 'bike':
        return ActivityType.cycling;
      case 'swim':
        return ActivityType.swimming;
      default:
        return ActivityType.running;
    }
  }

  int _getDurationMinutes(Map<String, dynamic> workout, ActivityType sport) {
    final plannedTimeSeconds = workout['PlannedTime'] as int?;
    if (plannedTimeSeconds != null && plannedTimeSeconds > 0) {
      return plannedTimeSeconds ~/ 60; // Convert seconds to minutes
    }

    // Apply sensible defaults
    switch (sport) {
      case ActivityType.running:
        return FinalSurgeDefaults.runningDurationMinutes;
      case ActivityType.cycling:
        return FinalSurgeDefaults.cyclingDurationMinutes;
      case ActivityType.swimming:
        return FinalSurgeDefaults.swimmingDurationMinutes;
    }
  }

  Map<String, double?> _parsePace(String? targetPace, ActivityType sport) {
    if (targetPace == null || targetPace.isEmpty) {
      // Return default pace
      return {
        'paceTargetMinutesPerMile': sport == ActivityType.running
            ? FinalSurgeDefaults.runningPaceMinPerMile
            : null,
        'paceMinMinutesPerMile': null,
        'paceMaxMinutesPerMile': null,
      };
    }

    // Check for range format "8:30-9:30"
    if (targetPace.contains('-')) {
      final parts = targetPace.split('-');
      final minPace = _parsePaceString(parts[0]);
      final maxPace = _parsePaceString(parts[1]);
      final midpoint = (minPace + maxPace) / 2;

      return {
        'paceTargetMinutesPerMile': midpoint,
        'paceMinMinutesPerMile': minPace,
        'paceMaxMinutesPerMile': maxPace,
      };
    }

    // Single pace value
    return {
      'paceTargetMinutesPerMile': _parsePaceString(targetPace),
      'paceMinMinutesPerMile': null,
      'paceMaxMinutesPerMile': null,
    };
  }

  double _parsePaceString(String pace) {
    // Parse "8:30" to 8.5
    final parts = pace.trim().split(':');
    final minutes = int.parse(parts[0]);
    final seconds = parts.length > 1 ? int.parse(parts[1]) : 0;
    return minutes + (seconds / 60);
  }
}
```

#### 3.3 FinalSurgeSyncService

```dart
// lib/features/integrations/application/final_surge_sync_service.dart

class FinalSurgeSyncService {
  /// Syncs upcoming workouts from Final Surge.
  /// MANUAL SYNC ONLY - called when user taps "Sync Now"
  /// Does NOT update existing workouts - only imports NEW ones
  Future<SyncResult> syncWorkouts(String userId) async {
    final integration = await _repository.getIntegration(userId, 'final_surge');
    if (integration == null || !integration.isActive) {
      return SyncResult.notConnected();
    }

    try {
      // Fetch workouts for next 7-14 days
      final workouts = await _apiClient.getUpcomingWorkouts(
        integration.accessToken,
        numDays: 7,
        numWorkouts: 21,
      );

      // Filter to supported sports
      final supportedWorkouts = workouts.where((w) =>
        ['Run', 'Walk', 'Bike', 'Swim'].contains(w.workoutTypeName)
      ).toList();

      int newWorkouts = 0;
      int skipped = 0;
      final newActivities = <Activity>[];

      for (final workout in supportedWorkouts) {
        final workoutId = _extractWorkoutId(workout.workoutUrl);

        // Check if already imported (we don't update existing)
        final exists = await _activityRepository
            .findByProviderWorkoutId('final_surge', workoutId);

        if (exists != null) {
          skipped++;
          continue;
        }

        // Transform and save
        final activity = _transformer.transform(workout.toJson(), userId);
        await _activityRepository.insert(activity);
        newActivities.add(activity);
        newWorkouts++;
      }

      // Update sync metadata
      await _repository.updateSyncStatus(
        userId: userId,
        provider: 'final_surge',
        status: 'success',
        syncedAt: DateTime.now(),
      );

      return SyncResult(
        success: true,
        newWorkouts: newWorkouts,
        skipped: skipped,
        activities: newActivities,
      );
    } catch (e) {
      await _repository.updateSyncStatus(
        userId: userId,
        provider: 'final_surge',
        status: 'error',
        error: e.toString(),
      );
      return SyncResult.error(e.toString());
    }
  }
}
```

### Deliverables
- [ ] `FinalSurgeDefaults` class created
- [ ] `FinalSurgeTransformer` implemented with all mappings
- [ ] `FinalSurgeSyncService` implemented
- [ ] Walk workouts map to running/easy
- [ ] Pace ranges stored correctly
- [ ] Swimming distances in meters
- [ ] Sensible defaults applied
- [ ] Only NEW workouts imported (no updates)

---

## Phase 4: Onboarding Integration

### Objective
Add Final Surge as the **FIRST** screen in onboarding flow.

### Tasks

#### 4.1 Create ConnectIntegrationsScreen

First screen in onboarding - before user profile.

```dart
// lib/features/integrations/presentation/screens/connect_integrations_screen.dart

class ConnectIntegrationsScreen extends ConsumerStatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Text('Connect Your Training'),
            Text('Import your workouts to get personalized nutrition plans'),

            // Final Surge (Active)
            IntegrationCard(
              name: 'Final Surge',
              logoAsset: 'assets/images/final_surge_logo.png',
              description: 'Import workouts & detect your sports',
              isActive: true,
              onConnect: _connectFinalSurge,
            ),

            // TrainingPeaks (Coming Soon)
            IntegrationCard(
              name: 'TrainingPeaks',
              isComingSoon: true,
            ),

            // Strava (Coming Soon)
            IntegrationCard(
              name: 'Strava',
              isComingSoon: true,
            ),

            // Skip button
            TextButton(
              onPressed: () => context.go('/onboarding/user-profile'),
              child: Text('Skip - Enter Manually'),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### 4.2 Update Onboarding Router

```dart
// In app_router.dart - add as FIRST onboarding screen

GoRoute(
  path: '/onboarding',
  redirect: (context, state) => '/onboarding/connect-integrations',
),
GoRoute(
  path: '/onboarding/connect-integrations',  // NEW FIRST SCREEN
  builder: (context, state) => const ConnectIntegrationsScreen(),
),
GoRoute(
  path: '/onboarding/user-profile',
  builder: (context, state) => const UserProfileScreen(),
),
// ... rest of onboarding
```

### Deliverables
- [ ] ConnectIntegrationsScreen created
- [ ] Onboarding flow updated (integrations first)
- [ ] "Skip" flow works correctly
- [ ] Sport detection pre-populates onboarding

---

## Phase 5: Nutrition Plan Generation

### Objective
Generate nutrition plans immediately using chunked parallel processing.

### Approach: Chunked Parallel Generation

- Process 5 API calls concurrently
- Total time: ~15-20 seconds for 14 workouts
- Live progress UI
- Better UX than background jobs

### Tasks

#### 5.1 Implement Chunked Processing

```dart
// In FinalSurgeSyncService

Future<void> generateNutritionPlansInParallel(List<Activity> activities) async {
  const chunkSize = 5;

  for (var i = 0; i < activities.length; i += chunkSize) {
    final chunk = activities.skip(i).take(chunkSize).toList();

    await Future.wait(
      chunk.map((activity) async {
        try {
          await _nutritionPlanService.generatePlan(activity);
          _progressController.add((i + chunk.indexOf(activity) + 1) / activities.length);
        } catch (e) {
          _logger.error('Failed to generate plan for ${activity.id}', error: e);
        }
      }),
    );
  }
}
```

#### 5.2 Progress UI

```dart
class NutritionPlanProgress extends StatelessWidget {
  final int totalWorkouts;
  final int completedWorkouts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Generating nutrition plans... $completedWorkouts/$totalWorkouts'),
        LinearProgressIndicator(value: completedWorkouts / totalWorkouts),
      ],
    );
  }
}
```

### Deliverables
- [ ] Chunked parallel processing implemented
- [ ] Progress UI shows real-time updates
- [ ] Error handling for failed generations
- [ ] Plans generate immediately after sync

---

## Phase 6: Settings & Management

### Objective
Allow users to manage Final Surge in Settings and display athlete info.

### Tasks

#### 6.1 Connected Apps Screen

Shows:
- Final Surge athlete name + email
- Last sync time
- Sync Now button
- Disconnect button

```dart
class ConnectedAppsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(finalSurgeControllerProvider);
    final integration = state.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text('Connected Apps')),
      body: ListView(
        children: [
          if (integration?.isConnected == true) ...[
            // Athlete info section
            ListTile(
              title: Text(integration!.providerAthleteName ?? 'Unknown'),
              subtitle: Text(integration.providerAthleteEmail ?? ''),
              leading: Icon(Icons.person),
            ),
            ListTile(
              title: Text('Last Synced'),
              subtitle: Text(integration.lastSyncAt?.toString() ?? 'Never'),
            ),
            // Actions
            ElevatedButton(
              onPressed: () => ref.read(finalSurgeControllerProvider.notifier).syncNow(),
              child: Text('Sync Now'),
            ),
            TextButton(
              onPressed: () => _showDisconnectDialog(context, ref),
              child: Text('Disconnect', style: TextStyle(color: Colors.red)),
            ),
          ] else ...[
            // Not connected - show connect button
            ElevatedButton(
              onPressed: () => ref.read(finalSurgeControllerProvider.notifier).connect(),
              child: Text('Connect Final Surge'),
            ),
          ],
        ],
      ),
    );
  }
}
```

#### 6.2 Synced Activity Badge

```dart
class SyncedFromBadge extends StatelessWidget {
  final String provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.electrolyte.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync, size: 12),
          SizedBox(width: 4),
          Text('Final Surge', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
```

### Deliverables
- [ ] Connected Apps screen created
- [ ] Athlete info displayed (name, email)
- [ ] Last sync time shown
- [ ] Manual "Sync Now" works
- [ ] Disconnect functionality works
- [ ] Synced activities show badge
- [ ] Settings menu links to Connected Apps

---

## Phase 7: Polish & Testing

### Objective
Production-ready quality with comprehensive testing.

### Tasks

- [ ] Comprehensive error handling
- [ ] Token refresh with reconnect banner
- [ ] All edge function tests passing
- [ ] All Flutter integration tests passing
- [ ] Security audit (no token logging)
- [ ] Performance testing (sync + generation times)

---

## Success Metrics

| Metric | Target |
|--------|--------|
| OAuth completion rate | >80% |
| Sync success rate | >95% |
| Plan generation success | >90% |
| Time to generate 14 plans | <25 seconds |

---

## Timeline Summary

| Phase | Description | Dependency |
|-------|-------------|------------|
| **Phase 0** | API Testing & Validation | None |
| **Phase 1** | Database Schema Setup | Phase 0 |
| **Phase 2** | OAuth Implementation | Phase 1 |
| **Phase 3** | Workout Sync & Transform | Phase 2 |
| **Phase 4** | Onboarding Integration | Phase 3 |
| **Phase 5** | Nutrition Plan Generation | Phase 4 |
| **Phase 6** | Settings & Management | Phase 5 |
| **Phase 7** | Polish & Testing | Phase 6 |

---

## References

- [Final Surge Integration Notes](./notes.md) - API documentation and research
- [Final Surge Partner API PDF](./Final-Surge-Partner-API-Uploads.pdf) - Official docs
- [Test Script](../../tool/final_surge_api_test.dart) - Working OAuth implementation
- [FOA Architecture](../technical/foa-architecture.md) - Flutter patterns

---

*This roadmap reflects all finalized decisions from December 2025 planning sessions.*
