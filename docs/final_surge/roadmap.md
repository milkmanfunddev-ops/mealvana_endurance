# Final Surge Integration - Implementation Roadmap

**Last Updated**: December 17, 2025
**Status**: Ready for Implementation
**Reference**: [Notes](./notes.md) | [Technical Architecture](./technical-architecture.md)

---

## Executive Summary

This roadmap details the implementation of Final Surge integration for Mealvana Endurance. The integration will:
- Add Final Surge as the **first screen** in onboarding (with TrainingPeaks + Strava as "Coming Soon")
- Import **upcoming workouts** (14 days) for running, cycling, and swimming
- **Auto-detect** user's sports from workout history and pre-populate onboarding
- Generate **nutrition plans** for imported workouts via background processing
- Design for **multiple integrations** (extensible architecture)

### Key User Decisions

| Decision | Choice |
|----------|--------|
| **Workout change detection** | Only check for NEW workouts (not updates) |
| **Sports supported** | Running, Cycling, Swimming |
| **Import range** | 14 days upcoming only |
| **Onboarding placement** | First screen (before User Profile) |
| **Nutrition plan generation** | Chunked parallel generation (5 concurrent) |
| **Conflict resolution** | Keep both entries (don't merge/replace) |
| **Token expiry** | Silent refresh + banner if needed |
| **Premium gating** | Free for testing phase |

---

## Phase 0: Database & Schema Setup

### Objective
Create database infrastructure to support Final Surge and future integrations.

### Tasks

#### 0.1 Create `integrations` Table (Drift + Supabase)

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

  -- Provider-specific data
  provider_athlete_id TEXT NOT NULL,
  provider_athlete_name TEXT,

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

#### 0.2 Add Sync Columns to `activities` Table

```sql
-- supabase/migrations/YYYYMMDDHHMMSS_add_activity_sync_columns.sql

ALTER TABLE activities ADD COLUMN IF NOT EXISTS synced_from_provider TEXT;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS provider_workout_id TEXT;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS provider_workout_url TEXT;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ;

-- Index for finding synced activities
CREATE INDEX idx_activities_provider_sync
  ON activities(synced_from_provider, provider_workout_id)
  WHERE synced_from_provider IS NOT NULL;
```

#### 0.3 Update Drift Schema

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

#### 0.4 Create FOA Directory Structure

```
lib/features/integrations/
├── presentation/
│   ├── widgets/
│   │   ├── integration_card.dart
│   │   ├── final_surge_connect_button.dart
│   │   └── sync_status_badge.dart
│   ├── screens/
│   │   ├── connect_integrations_screen.dart     # New onboarding screen
│   │   └── connected_apps_screen.dart           # Settings screen
│   └── providers/
│       ├── final_surge_controller.dart
│       └── final_surge_controller.g.dart
├── application/
│   ├── final_surge_oauth_service.dart
│   ├── final_surge_sync_service.dart
│   └── integration_manager_service.dart
├── domain/
│   ├── integration.dart
│   ├── final_surge_workout.dart
│   └── sync_result.dart
└── data/
    ├── integration_repository.dart
    └── final_surge_api_client.dart
```

### Deliverables
- [ ] `integrations` table created in Supabase (dev + prod)
- [ ] Activity sync columns added
- [ ] Drift schema updated and code generated
- [ ] FOA directory structure created
- [ ] Domain models defined

---

## Phase 1: OAuth Implementation

### Objective
Enable users to connect their Final Surge account via OAuth 2.0.

### Approach: flutter_web_auth_2

Unlike Google/Apple sign-in which have native SDKs, Final Surge requires web-based OAuth. We'll use `flutter_web_auth_2` which:
- Opens a secure in-app browser (ASWebAuthenticationSession on iOS, Custom Tabs on Android)
- Handles the callback automatically via custom URL scheme
- Returns the auth code without requiring manual deep linking setup
- Same UX pattern as our Google/Apple native flows

### Tasks

#### 1.1 Add flutter_web_auth_2 Dependency

```yaml
# pubspec.yaml
dependencies:
  flutter_web_auth_2: ^3.1.2
```

**Note**: No manual deep linking configuration needed - the package handles callback URLs internally using the app's bundle ID.

#### 1.2 FinalSurgeApiClient (Data Layer)

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

#### 1.3 FinalSurgeOAuthService (Application Layer)

Uses `flutter_web_auth_2` to handle OAuth flow - same pattern as Google/Apple native SDKs but for web OAuth.

```dart
// lib/features/integrations/application/final_surge_oauth_service.dart

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

class FinalSurgeOAuthService {
  static const _clientId = String.fromEnvironment('FINAL_SURGE_CLIENT_ID');
  static const _clientSecret = String.fromEnvironment('FINAL_SURGE_CLIENT_SECRET');

  // Callback URL uses app bundle ID - handled automatically by flutter_web_auth_2
  // iOS: com.mealvana.endurance://callback
  // Android: com.mealvana.endurance://callback
  static const _callbackUrlScheme = 'com.mealvana.endurance';

  Future<Integration> authenticate() async {
    _logger.info('Starting Final Surge OAuth flow', context: 'FINAL_SURGE');

    // 1. Generate state for CSRF protection
    final state = _generateState();

    // 2. Build OAuth authorization URL
    final authUrl = Uri.https('log.finalsurge.com', '/oauth/authorize', {
      'client-id': _clientId,
      'redirect-uri': '$_callbackUrlScheme://callback',
      'state': state,
    });

    // 3. Launch OAuth flow via flutter_web_auth_2
    // Opens secure browser (ASWebAuthenticationSession/Custom Tabs)
    // Returns callback URL with auth code - no manual deep linking needed!
    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackUrlScheme,
      options: const FlutterWebAuth2Options(
        preferEphemeral: true,  // Don't save cookies between sessions
      ),
    );

    // 4. Extract authorization code from callback URL
    final callbackUri = Uri.parse(result);
    final code = callbackUri.queryParameters['code'];
    final returnedState = callbackUri.queryParameters['state'];

    // Verify state to prevent CSRF attacks
    if (returnedState != state) {
      throw Exception('OAuth state mismatch - possible CSRF attack');
    }

    if (code == null) {
      throw Exception('No authorization code received from Final Surge');
    }

    _logger.info('OAuth code received, exchanging for token', context: 'FINAL_SURGE');

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
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repository.saveIntegration(integration);

    _logger.info('Final Surge connected successfully', context: 'FINAL_SURGE', data: {
      'athlete_id': tokenResponse.athlete.id,
      'athlete_name': integration.providerAthleteName,
    });

    return integration;
  }

  String _generateState() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  Future<void> disconnect(String userId) async {
    await _repository.deleteIntegration(userId, 'final_surge');
    _logger.info('Final Surge disconnected', context: 'FINAL_SURGE');
  }
}
```

#### 1.4 IntegrationRepository (Data Layer)

```dart
// lib/features/integrations/data/integration_repository.dart

class IntegrationRepository {
  Future<Integration?> getIntegration(String userId, String provider) async {
    return _db.select(_db.integrations)
        .where((t) => t.userId.equals(userId) & t.provider.equals(provider))
        .getSingleOrNull();
  }

  Future<void> saveIntegration(Integration integration) async {
    await _db.into(_db.integrations).insertOnConflictUpdate(integration);
    await _supabaseClient.from('integrations').upsert(integration.toJson());
  }

  Future<void> deleteIntegration(String userId, String provider) async {
    await (_db.delete(_db.integrations)
        ..where((t) => t.userId.equals(userId) & t.provider.equals(provider)))
        .go();
    await _supabaseClient
        .from('integrations')
        .delete()
        .eq('user_id', userId)
        .eq('provider', provider);
  }
}
```

### Deliverables
- [ ] `flutter_web_auth_2` package added to pubspec.yaml
- [ ] `FinalSurgeApiClient` implemented
- [ ] `FinalSurgeOAuthService` implemented (using flutter_web_auth_2)
- [ ] `IntegrationRepository` implemented
- [ ] OAuth flow tested on iOS + Android
- [ ] Token stored securely in Drift database

---

## Phase 2: Workout Sync

### Objective
Import upcoming workouts (running, cycling, swimming) from Final Surge.

### Tasks

#### 2.1 Update sync-final-surge Edge Function for Multi-Sport

**Current Issue**: Line 332-342 filters to running only. Needs to support all sports.

```typescript
// supabase/functions/sync-final-surge/index.ts

// BEFORE (running only):
const runningWorkouts = (result.workouts || [])
  .filter((w) => w.sport === 'RUNNING')

// AFTER (all sports):
const supportedSports = ['RUNNING', 'CYCLING', 'SWIMMING'];

const allWorkouts = (result.workouts || [])
  .filter((w) => supportedSports.includes(w.sport?.toUpperCase()))
  .map((w) => ({
    ...w,
    sport_type: mapSportType(w.sport),
  }));

function mapSportType(finalSurgeSport: string): string {
  const sportMap: Record<string, string> = {
    'RUNNING': 'running',
    'RUN': 'running',
    'CYCLING': 'cycling',
    'BIKE': 'cycling',
    'SWIMMING': 'swimming',
    'SWIM': 'swimming',
  };
  return sportMap[finalSurgeSport?.toUpperCase()] || 'running';
}
```

#### 2.2 FinalSurgeSyncService (Application Layer)

```dart
// lib/features/integrations/application/final_surge_sync_service.dart

class FinalSurgeSyncService {
  /// Syncs upcoming workouts from Final Surge.
  /// Only imports NEW workouts (does not check for updates).
  Future<SyncResult> syncWorkouts(String userId) async {
    final integration = await _repository.getIntegration(userId, 'final_surge');
    if (integration == null || !integration.isActive) {
      return SyncResult.notConnected();
    }

    try {
      // Fetch workouts for next 14 days (API max)
      final workouts = await _apiClient.getUpcomingWorkouts(
        integration.accessToken,
        numDays: 7,  // API max per request
        numWorkouts: 21,
      );

      // Filter to supported sports
      final supportedWorkouts = workouts.where((w) =>
        ['Run', 'Bike', 'Swim'].contains(w.workoutTypeName)
      ).toList();

      int newWorkouts = 0;
      int skipped = 0;

      for (final workout in supportedWorkouts) {
        final workoutId = _extractWorkoutId(workout.workoutUrl);

        // Check if we already have this workout
        final existingActivity = await _activityRepository
            .findByProviderWorkoutId('final_surge', workoutId);

        if (existingActivity != null) {
          // Already imported - skip (we don't update)
          skipped++;
          continue;
        }

        // Create new activity
        final activity = _mapToActivity(workout, userId);
        await _activityRepository.insert(activity);
        newWorkouts++;

        // Queue nutrition plan generation (background)
        await _queueNutritionPlanGeneration(activity.id);
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
        message: 'Found $newWorkouts new workouts',
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

  String _extractWorkoutId(String? workoutUrl) {
    if (workoutUrl == null) return '';
    final uri = Uri.parse(workoutUrl);
    return uri.queryParameters['id'] ??
           '${uri.queryParameters['s']}_${uri.path}';
  }

  Activity _mapToActivity(FinalSurgeWorkout workout, String userId) {
    return Activity(
      id: const Uuid().v4(),
      userId: userId,
      name: workout.workoutTitle ?? workout.workoutTypeName ?? 'Workout',
      sportType: _mapSportType(workout.workoutTypeName),
      scheduledDate: DateTime.parse(workout.workoutDate),
      distanceKm: _convertToKm(workout.plannedDistance, workout.plannedDistanceType),
      durationMinutes: (workout.plannedTime ?? 0) ~/ 60,
      syncedFromProvider: 'final_surge',
      providerWorkoutId: _extractWorkoutId(workout.workoutUrl),
      providerWorkoutUrl: workout.workoutUrl,
      lastSyncedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  String _mapSportType(String? workoutTypeName) {
    switch (workoutTypeName?.toLowerCase()) {
      case 'run': return 'running';
      case 'bike': return 'cycling';
      case 'swim': return 'swimming';
      default: return 'running';
    }
  }

  double? _convertToKm(double? distance, String? distanceType) {
    if (distance == null) return null;
    if (distanceType == 'mi') return distance * 1.60934;
    if (distanceType == 'km') return distance;
    return distance; // Assume km if not specified
  }
}
```

#### 2.3 New Workout Detection Logic

```dart
/// Checks if a workout is new (not already imported).
/// We only care about NEW workouts - we don't update existing ones.
Future<bool> isNewWorkout(String workoutId) async {
  final existing = await _db.select(_db.activities)
      .where((t) =>
        t.syncedFromProvider.equals('final_surge') &
        t.providerWorkoutId.equals(workoutId)
      )
      .getSingleOrNull();

  return existing == null;
}
```

### Deliverables
- [ ] sync-final-surge edge function updated for multi-sport
- [ ] `FinalSurgeSyncService` implemented
- [ ] Sport type mapping (Run/Bike/Swim to running/cycling/swimming)
- [ ] Distance unit conversion (miles to km)
- [ ] New workout detection working
- [ ] Sync button in UI triggers refresh
- [ ] Synced activities display badge

---

## Phase 3: Onboarding Integration

### Objective
Add Final Surge as the first screen in onboarding flow.

### Tasks

#### 3.1 Create ConnectIntegrationsScreen

```dart
// lib/features/integrations/presentation/screens/connect_integrations_screen.dart

class ConnectIntegrationsScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<ConnectIntegrationsScreen> createState() => _ConnectIntegrationsScreenState();
}

class _ConnectIntegrationsScreenState extends ConsumerState<ConnectIntegrationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),

              // Header
              Text(
                'Connect Your Training',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Import your workouts to get personalized nutrition plans',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Final Surge (Active)
              _IntegrationCard(
                name: 'Final Surge',
                logoAsset: 'assets/images/final_surge_logo.png',
                description: 'Import workouts & detect your sports',
                isActive: true,
                onConnect: _connectFinalSurge,
              ),

              const SizedBox(height: 16),

              // TrainingPeaks (Coming Soon)
              _IntegrationCard(
                name: 'TrainingPeaks',
                logoAsset: 'assets/images/trainingpeaks_logo.png',
                description: 'Coming Soon',
                isActive: false,
                isComingSoon: true,
              ),

              const SizedBox(height: 16),

              // Strava (Coming Soon)
              _IntegrationCard(
                name: 'Strava',
                logoAsset: 'assets/images/strava_logo.png',
                description: 'Coming Soon',
                isActive: false,
                isComingSoon: true,
              ),

              const Spacer(),

              // Skip button
              TextButton(
                onPressed: _skipIntegrations,
                child: Text('Skip - Enter Manually'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connectFinalSurge() async {
    final controller = ref.read(finalSurgeControllerProvider.notifier);

    try {
      await controller.connect();

      // Show summary dialog
      final syncResult = await controller.syncWorkouts();

      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Connected!'),
            content: Text('Found ${syncResult.newWorkouts} workouts for the next 2 weeks'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _proceedToNextScreen();
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _connectFinalSurge,
            ),
          ),
        );
      }
    }
  }

  void _skipIntegrations() {
    context.go('/onboarding/user-profile');
  }

  void _proceedToNextScreen() {
    context.go('/onboarding/user-profile');
  }
}
```

#### 3.2 Integration Card Widget

```dart
class _IntegrationCard extends StatelessWidget {
  final String name;
  final String logoAsset;
  final String description;
  final bool isActive;
  final bool isComingSoon;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isComingSoon ? Colors.grey[100] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComingSoon ? Colors.grey[300]! : AppColors.primary,
          width: isComingSoon ? 1 : 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isActive ? onConnect : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Logo
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(logoAsset, fit: BoxFit.contain),
                ),

                const SizedBox(width: 16),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isComingSoon ? Colors.grey : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: isComingSoon ? Colors.grey : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Action
                if (isActive)
                  Icon(Icons.chevron_right, color: AppColors.primary)
                else if (isComingSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Coming Soon',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

#### 3.3 Sport Detection from Workout History

```dart
// In FinalSurgeSyncService

/// Analyzes workout history and returns detected sports.
/// Sports with 2+ workouts are considered active.
Future<DetectedSports> detectSportsFromWorkouts(String userId) async {
  final integration = await _repository.getIntegration(userId, 'final_surge');
  if (integration == null) return DetectedSports.none();

  final workouts = await _apiClient.getUpcomingWorkouts(
    integration.accessToken,
    numDays: 7,
    numWorkouts: 21,
  );

  final sportCounts = <String, int>{
    'running': 0,
    'cycling': 0,
    'swimming': 0,
  };

  for (final workout in workouts) {
    final sport = _mapSportType(workout.workoutTypeName);
    sportCounts[sport] = (sportCounts[sport] ?? 0) + 1;
  }

  return DetectedSports(
    doesRunning: (sportCounts['running'] ?? 0) >= 2,
    doesCycling: (sportCounts['cycling'] ?? 0) >= 2,
    doesSwimming: (sportCounts['swimming'] ?? 0) >= 2,
    detectedFromFinalSurge: true,
  );
}
```

#### 3.4 Update Sport Preferences Screen

```dart
// In SportPreferencesScreen

@override
FutureOr<SportPreferencesState> build() async {
  // Check if connected to Final Surge
  final integration = await ref.read(integrationRepositoryProvider)
      .getIntegration(_userId, 'final_surge');

  if (integration != null && integration.isActive) {
    // Detect sports from Final Surge
    final detected = await ref.read(finalSurgeSyncServiceProvider)
        .detectSportsFromWorkouts(_userId);

    return SportPreferencesState(
      doesRunning: detected.doesRunning,
      doesCycling: detected.doesCycling,
      doesSwimming: detected.doesSwimming,
      detectedFromFinalSurge: detected.detectedFromFinalSurge,
    );
  }

  // Default state for manual entry
  return SportPreferencesState.initial();
}
```

#### 3.5 Update Onboarding Router

```dart
// Add new route BEFORE user-profile

GoRoute(
  path: 'connect-integrations',
  builder: (context, state) => const ConnectIntegrationsScreen(),
),
```

### Deliverables
- [ ] ConnectIntegrationsScreen created
- [ ] Integration card widgets created
- [ ] Sport detection from workout history implemented
- [ ] Sport Preferences screen pre-populates from Final Surge
- [ ] Onboarding flow updated (integrations as first screen)
- [ ] "Skip" flow still works
- [ ] Success summary dialog shows workout count

---

## Phase 4: Nutrition Plan Generation

### Objective
Generate nutrition plans for imported workouts using chunked parallel processing in Flutter.

### Approach: Chunked Parallel Generation

Instead of background processing with pg_cron + pgmq, we'll use a simpler, faster approach:
- Process nutrition plans immediately after import
- Generate in parallel chunks (5 concurrent API calls at a time)
- Total time: ~15-20 seconds for 14 workouts
- Live progress UI with real-time calendar updates

**Why This Approach:**
- ✅ Simpler - no pg_cron/pgmq infrastructure needed
- ✅ Faster - 15-20 seconds vs 7 minutes with cron
- ✅ Better UX - user sees live progress
- ✅ Easier to debug - all in Flutter code
- ✅ Rate limit safe - max 5 concurrent calls

### Tasks

#### 4.1 Create Progress UI Component

```dart
// lib/features/integrations/presentation/widgets/nutrition_plan_progress.dart

class NutritionPlanProgress extends StatelessWidget {
  final int totalWorkouts;
  final int completedWorkouts;

  @override
  Widget build(BuildContext context) {
    final progress = completedWorkouts / totalWorkouts;

    return Column(
      children: [
        Text(
          'Generating nutrition plans... $completedWorkouts/$totalWorkouts',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 8),
        Text(
          '${(progress * 100).toInt()}% complete',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
```

#### 4.2 Implement Chunked Processing Service

```dart
// In FinalSurgeSyncService

Future<void> generateNutritionPlansInParallel(List<Activity> activities) async {
  const chunkSize = 5; // Process 5 at a time
  final totalWorkouts = activities.length;
  var completedWorkouts = 0;

  // Update progress callback
  void updateProgress() {
    completedWorkouts++;
    _progressController.add(completedWorkouts / totalWorkouts);
  }

  // Process in chunks
  for (var i = 0; i < activities.length; i += chunkSize) {
    final chunk = activities.skip(i).take(chunkSize).toList();

    // Generate plans in parallel for this chunk
    await Future.wait(
      chunk.map((activity) async {
        try {
          await _nutritionPlanService.generatePlan(activity);
          updateProgress();
        } catch (e) {
          _logger.error('Failed to generate plan for activity ${activity.id}',
            error: e);
          updateProgress(); // Still update progress even on error
        }
      }),
    );
  }
}
```

#### 4.3 Update Sync Service to Generate Plans

```dart
// In FinalSurgeSyncService.syncWorkouts()

Future<SyncResult> syncWorkouts(String userId) async {
  // ... existing sync code ...

  // After importing activities, generate nutrition plans
  if (newActivities.isNotEmpty) {
    _logger.info('Generating nutrition plans for ${newActivities.length} workouts');

    await generateNutritionPlansInParallel(newActivities);

    _logger.info('Nutrition plan generation complete');
  }

  return SyncResult(
    success: true,
    newWorkouts: newWorkouts,
    plansGenerated: newActivities.length,
  );
}
```

#### 4.4 Add Progress Stream to Controller

```dart
// In FinalSurgeController

final _progressController = StreamController<double>.broadcast();
Stream<double> get progressStream => _progressController.stream;

Future<void> connect() async {
  state = const AsyncLoading();

  state = await AsyncValue.guard(() async {
    final integration = await _oauthService.authenticate();

    // Trigger sync with progress updates
    final syncResult = await _syncService.syncWorkouts(integration.userId);

    return FinalSurgeState(
      isConnected: true,
      lastSyncAt: DateTime.now(),
      syncStatus: 'success',
      workoutCount: syncResult.newWorkouts,
      plansGenerated: syncResult.plansGenerated,
    );
  });
}
```

#### 4.5 Show Progress Dialog During Generation

```dart
// In ConnectIntegrationsScreen._connectFinalSurge()

Future<void> _connectFinalSurge() async {
  final controller = ref.read(finalSurgeControllerProvider.notifier);

  try {
    await controller.connect();

    // Show progress dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Importing Workouts'),
          content: StreamBuilder<double>(
            stream: controller.progressStream,
            builder: (context, snapshot) {
              final progress = snapshot.data ?? 0.0;
              return NutritionPlanProgress(
                totalWorkouts: controller.totalWorkouts,
                completedWorkouts: (progress * controller.totalWorkouts).round(),
              );
            },
          ),
        ),
      );
    }

    // Wait for completion, then show success
    final syncResult = await controller.syncComplete;

    if (mounted) {
      Navigator.of(context).pop(); // Close progress dialog

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connected!'),
          content: Text(
            'Found ${syncResult.newWorkouts} workouts for the next 2 weeks\n'
            'Generated ${syncResult.plansGenerated} nutrition plans'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _proceedToNextScreen();
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    // Error handling...
  }
}
```

### Deliverables
- [ ] Progress UI component created
- [ ] Chunked parallel processing implemented
- [ ] Progress stream added to controller
- [ ] Progress dialog shown during generation
- [ ] Calendar updates in real-time as plans complete
- [ ] Error handling for failed generations
- [ ] Success dialog shows workout count and plans generated

---

## Phase 5: Settings & Management

### Objective
Allow users to manage their Final Surge connection in Settings.

### Tasks

#### 5.1 Create Connected Apps Screen

```dart
// lib/features/integrations/presentation/screens/connected_apps_screen.dart

class ConnectedAppsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final integrationState = ref.watch(finalSurgeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Connected Apps')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Final Surge
          _ConnectedAppTile(
            name: 'Final Surge',
            logoAsset: 'assets/images/final_surge_logo.png',
            isConnected: integrationState.valueOrNull?.isConnected ?? false,
            lastSyncAt: integrationState.valueOrNull?.lastSyncAt,
            onConnect: () => ref.read(finalSurgeControllerProvider.notifier).connect(),
            onDisconnect: () => _showDisconnectDialog(context, ref),
            onSyncNow: () => ref.read(finalSurgeControllerProvider.notifier).syncNow(),
          ),

          const SizedBox(height: 16),

          // TrainingPeaks (Coming Soon)
          _ConnectedAppTile(
            name: 'TrainingPeaks',
            logoAsset: 'assets/images/trainingpeaks_logo.png',
            isComingSoon: true,
          ),

          const SizedBox(height: 16),

          // Strava (Coming Soon)
          _ConnectedAppTile(
            name: 'Strava',
            logoAsset: 'assets/images/strava_logo.png',
            isComingSoon: true,
          ),
        ],
      ),
    );
  }

  Future<void> _showDisconnectDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Final Surge?'),
        content: const Text('Your imported workouts will remain, but automatic syncing will stop.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(finalSurgeControllerProvider.notifier).disconnect();
    }
  }
}
```

#### 5.2 Add to Settings Screen

```dart
// In SettingsScreen, add new section

ListTile(
  leading: const Icon(Icons.apps),
  title: const Text('Connected Apps'),
  subtitle: Text(_getConnectedAppsSubtitle()),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push('/settings/connected-apps'),
),
```

#### 5.3 Sync Status Badge on Activities

```dart
// Widget to show on synced activities

class SyncedFromBadge extends StatelessWidget {
  final String provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.electrolyte.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync, size: 12, color: AppColors.electrolyte),
          const SizedBox(width: 4),
          Text(
            _formatProviderName(provider),
            style: TextStyle(
              fontSize: 11,
              color: AppColors.electrolyte,
            ),
          ),
        ],
      ),
    );
  }

  String _formatProviderName(String provider) {
    switch (provider) {
      case 'final_surge': return 'Final Surge';
      case 'training_peaks': return 'TrainingPeaks';
      default: return provider;
    }
  }
}
```

### Deliverables
- [ ] Connected Apps screen created
- [ ] Settings screen links to Connected Apps
- [ ] Disconnect functionality working
- [ ] Manual "Sync Now" button
- [ ] Last sync time displayed
- [ ] Synced activities show badge

---

## Phase 6: Polish & Testing

### Objective
Ensure production-ready quality with comprehensive error handling and testing.

### Tasks

#### 6.1 Error Handling

```dart
// Comprehensive error handling in controller

Future<void> connect() async {
  state = const AsyncLoading();

  state = await AsyncValue.guard(() async {
    try {
      final integration = await _oauthService.authenticate();
      final syncResult = await _syncService.syncWorkouts(integration.userId);

      return FinalSurgeState(
        isConnected: true,
        lastSyncAt: DateTime.now(),
        syncStatus: 'success',
        workoutCount: syncResult.newWorkouts,
      );
    } on SocketException {
      throw IntegrationException('No internet connection');
    } on FormatException {
      throw IntegrationException('Invalid response from Final Surge');
    } on TimeoutException {
      throw IntegrationException('Connection timed out');
    } catch (e) {
      throw IntegrationException('Connection failed: ${e.toString()}');
    }
  });
}
```

#### 6.2 Token Refresh Handling

```dart
// Silent token refresh with banner fallback

Future<void> _refreshTokenIfNeeded() async {
  final integration = await _repository.getIntegration(_userId, 'final_surge');

  if (integration == null) return;

  // Check if token is expired or expiring soon
  if (integration.tokenExpiresAt != null &&
      integration.tokenExpiresAt!.isBefore(DateTime.now().add(Duration(hours: 1)))) {

    try {
      // Try silent refresh (Final Surge may not require this)
      await _oauthService.refreshToken(integration);
    } catch (e) {
      // Show banner to user
      _showReconnectBanner();
    }
  }
}
```

#### 6.3 Integration Tests

**Edge Function Tests** (`supabase/functions/sync-final-surge/index.test.ts`):

```typescript
Deno.test('multi-sport filtering - running', async () => {
  const result = await syncFinalSurge({ sport: 'RUNNING' });
  assertEquals(result.sport_type, 'running');
});

Deno.test('multi-sport filtering - cycling', async () => {
  const result = await syncFinalSurge({ sport: 'CYCLING' });
  assertEquals(result.sport_type, 'cycling');
});

Deno.test('multi-sport filtering - swimming', async () => {
  const result = await syncFinalSurge({ sport: 'SWIMMING' });
  assertEquals(result.sport_type, 'swimming');
});

Deno.test('only detects new workouts', async () => {
  // First sync
  const result1 = await syncFinalSurge({ workouts: [{ id: '123' }] });
  assertEquals(result1.newWorkouts, 1);

  // Second sync with same workout
  const result2 = await syncFinalSurge({ workouts: [{ id: '123' }] });
  assertEquals(result2.newWorkouts, 0);
  assertEquals(result2.skipped, 1);
});
```

**Flutter Tests**:

```dart
testWidgets('OAuth flow completes successfully', (tester) async {
  // Test OAuth flow end-to-end
});

testWidgets('Sync button triggers refresh', (tester) async {
  // Test manual sync
});

testWidgets('Synced activities show badge', (tester) async {
  // Test badge display
});

testWidgets('Disconnect clears connection', (tester) async {
  // Test disconnect functionality
});
```

### Deliverables
- [ ] Comprehensive error handling implemented
- [ ] Token refresh with fallback banner
- [ ] Edge function tests passing
- [ ] Flutter integration tests passing
- [ ] All edge cases handled
- [ ] Security audit complete (no token logging)

---

## Success Metrics

| Metric | Target |
|--------|--------|
| OAuth completion rate | >80% of users who start OAuth |
| Sync success rate | >95% |
| Error rate | <1% |
| User retention (7-day) | >80% for connected users |
| Workout import accuracy | 100% of supported sports |

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Final Surge API changes | Version-lock API calls, monitor for breaking changes |
| Token expiry unknown | Implement proactive refresh, reconnect banner fallback |
| Rate limiting | Conservative sync intervals, ETag caching |
| Multi-device conflicts | Server-side deduplication by `provider_workout_id` |
| OAuth user cancellation | Graceful error + retry + skip options |

---

## References

- [Final Surge Integration Notes](./notes.md) - Comprehensive research and decisions
- [Final Surge Partner API PDF](./Final-Surge-Partner-API-Uploads.pdf) - Official API documentation
- [Test Script](../../tool/final_surge_api_test.dart) - Working OAuth implementation
- [FOA Architecture](../technical/foa-architecture.md) - Flutter architecture patterns
- [Supabase Background Processing](../database/supabase/README.md) - pg_cron + pgmq setup

---

*This roadmap is a living document. Update as implementation progresses.*
