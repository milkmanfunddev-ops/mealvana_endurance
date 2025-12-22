# Final Surge Integration - Technical Architecture

**Last Updated**: December 17, 2025
**Status**: Design Complete - Ready for Implementation
**Related Docs**: [Roadmap](./roadmap.md) | [Notes](./notes.md)

---

## Overview

The Final Surge integration uses a **chunked parallel generation** approach to import workouts and generate nutrition plans efficiently. This document details the technical architecture, data flow, and implementation patterns.

---

## Core Decisions

### Nutrition Plan Generation: Chunked Parallel Processing

**Decision (2025-12-17):** Use Flutter-based chunked parallel generation instead of background processing.

**Rationale:**
- ✅ **Faster:** 15-20 seconds vs 7 minutes with pg_cron
- ✅ **Better UX:** Live progress updates instead of waiting
- ✅ **Simpler:** No distributed system coordination needed
- ✅ **Easier to debug:** All in Flutter code
- ✅ **Rate limit safe:** Max 5 concurrent API calls

**Performance Math:**
```
14 workouts = 3 chunks of 5 + 1 chunk of 4
~5 seconds per chunk (parallel API calls)
Total: 15-20 seconds
```

---

## System Architecture

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         User Onboarding                              │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  1. OAUTH AUTHENTICATION                                            │
│     • User taps "Connect Final Surge"                               │
│     • flutter_web_auth_2 opens secure browser                       │
│     • User authorizes in Final Surge                                │
│     • App receives access token + athlete info                      │
│     • Store in integrations table (Drift + Supabase)                │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  2. WORKOUT IMPORT                                                  │
│     • Fetch upcoming workouts (14 days)                             │
│     • Filter: Running, Cycling, Swimming only                       │
│     • Map to Mealvana activities                                    │
│     • Store in activities table (mark synced_from_provider)         │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  3. CHUNKED PARALLEL NUTRITION PLAN GENERATION                      │
│     • Split activities into chunks of 5                             │
│     • For each chunk:                                               │
│       - Generate 5 plans in parallel via Future.wait()              │
│       - Update progress: "Generating plans... 7/14"                 │
│       - Update calendar as each plan completes                      │
│     • Total time: 15-20 seconds for 14 workouts                     │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  4. SPORT AUTO-DETECTION                                            │
│     • Analyze workout history (count by sport type)                 │
│     • Rule: 2+ workouts = active sport                              │
│     • Pre-populate Sports Selection screen                          │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  5. COMPLETE ONBOARDING                                             │
│     • Show success: "14 workouts imported, 14 plans generated"      │
│     • Continue to next onboarding screen                            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Detailed Component Architecture

### 1. OAuth Flow (flutter_web_auth_2)

**Pattern:** Same as Google/Apple native SDK, but for web OAuth

```dart
// FinalSurgeOAuthService.authenticate()

Future<Integration> authenticate() async {
  // 1. Generate CSRF state token
  final state = _generateSecureState();

  // 2. Build authorization URL
  final authUrl = Uri.https('log.finalsurge.com', '/oauth/authorize', {
    'client-id': _clientId,
    'redirect-uri': 'com.mealvana.endurance://callback',
    'state': state,
  });

  // 3. Open secure browser (ASWebAuthenticationSession/Custom Tabs)
  final result = await FlutterWebAuth2.authenticate(
    url: authUrl.toString(),
    callbackUrlScheme: 'com.mealvana.endurance',
  );

  // 4. Extract auth code from callback
  final code = Uri.parse(result).queryParameters['code'];

  // 5. Exchange code for token
  final tokenResponse = await _apiClient.exchangeCodeForToken(code);

  // 6. Save integration to database
  final integration = Integration(
    userId: _currentUserId,
    provider: 'final_surge',
    accessToken: tokenResponse.accessToken,
    providerAthleteId: tokenResponse.athlete.id,
    providerAthleteName: '${tokenResponse.athlete.firstname} ${tokenResponse.athlete.lastname}',
  );

  await _repository.saveIntegration(integration);

  return integration;
}
```

**No Configuration Required:**
- ❌ No iOS Info.plist changes
- ❌ No Android Manifest changes
- ✅ Package handles callbacks automatically using bundle ID

---

### 2. Workout Import & Sync

**Service:** `FinalSurgeSyncService.syncWorkouts()`

```dart
Future<SyncResult> syncWorkouts(String userId) async {
  // Get integration
  final integration = await _repository.getIntegration(userId, 'final_surge');

  // Fetch upcoming workouts (14 days)
  final workouts = await _apiClient.getUpcomingWorkouts(
    integration.accessToken,
    numDays: 7,
    numWorkouts: 21,
  );

  // Filter to supported sports
  final supportedWorkouts = workouts.where((w) =>
    ['Run', 'Bike', 'Swim'].contains(w.workoutTypeName)
  ).toList();

  // Import new workouts
  final newActivities = <Activity>[];
  for (final workout in supportedWorkouts) {
    // Check if already imported
    final existingActivity = await _activityRepository
        .findByProviderWorkoutId('final_surge', workout.id);

    if (existingActivity != null) continue; // Skip duplicates

    // Create activity
    final activity = _mapToActivity(workout, userId);
    await _activityRepository.insert(activity);
    newActivities.add(activity);
  }

  // Generate nutrition plans (chunked parallel)
  if (newActivities.isNotEmpty) {
    await _generateNutritionPlansInParallel(newActivities);
  }

  return SyncResult(
    success: true,
    newWorkouts: newActivities.length,
    plansGenerated: newActivities.length,
  );
}
```

**Deduplication Strategy:**
- Use `provider_workout_id` as unique identifier
- Check local database before creating activity
- Server-side constraint: `UNIQUE(user_id, provider_workout_id)`

---

### 3. Chunked Parallel Nutrition Plan Generation

**The Core Innovation:**

```dart
Future<void> _generateNutritionPlansInParallel(List<Activity> activities) async {
  const chunkSize = 5; // Rate limit: max 5 concurrent
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
          _logger.error('Failed to generate plan for ${activity.id}', error: e);
          updateProgress(); // Still update progress on error
        }
      }),
    );
  }

  _logger.info('Generated $completedWorkouts nutrition plans');
}
```

**Why 5 Concurrent?**
- Balances speed vs rate limits
- Avoids overwhelming AI API
- Still fast: 5 seconds per chunk
- Safe for mobile network conditions

**Progress Updates:**
```dart
// Controller exposes stream
final _progressController = StreamController<double>.broadcast();
Stream<double> get progressStream => _progressController.stream;

// UI subscribes to updates
StreamBuilder<double>(
  stream: controller.progressStream,
  builder: (context, snapshot) {
    final progress = snapshot.data ?? 0.0;
    return LinearProgressIndicator(value: progress);
  },
)
```

---

### 4. Sport Auto-Detection

**Algorithm:**

```dart
Future<DetectedSports> detectSportsFromWorkouts(List<FinalSurgeWorkout> workouts) async {
  final sportCounts = <String, int>{
    'running': 0,
    'cycling': 0,
    'swimming': 0,
  };

  // Count workouts by sport type
  for (final workout in workouts) {
    final sport = _mapSportType(workout.workoutTypeName);
    sportCounts[sport] = (sportCounts[sport] ?? 0) + 1;
  }

  // Rule: 2+ workouts = active sport
  return DetectedSports(
    doesRunning: (sportCounts['running'] ?? 0) >= 2,
    doesCycling: (sportCounts['cycling'] ?? 0) >= 2,
    doesSwimming: (sportCounts['swimming'] ?? 0) >= 2,
    detectedFromFinalSurge: true,
  );
}
```

**Usage in Onboarding:**
```dart
// In SportPreferencesScreen.build()

if (integration != null && integration.isActive) {
  final detected = await _finalSurgeService.detectSportsFromWorkouts(userId);

  return SportPreferencesState(
    doesRunning: detected.doesRunning,
    doesCycling: detected.doesCycling,
    doesSwimming: detected.doesSwimming,
    detectedFromFinalSurge: true, // Show badge
  );
}
```

---

## Data Models

### Integration Model

```dart
@DataClassName('Integration')
class Integrations extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get provider => text()(); // 'final_surge'

  // OAuth tokens
  TextColumn get accessToken => text()();
  TextColumn get refreshToken => text().nullable()();
  DateTimeColumn get tokenExpiresAt => dateTime().nullable()();

  // Provider data
  TextColumn get providerAthleteId => text()();
  TextColumn get providerAthleteName => text().nullable()();

  // Sync metadata
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

### Activity Sync Tracking

**New columns on activities table:**

```dart
// Sync tracking
TextColumn get syncedFromProvider => text().nullable()(); // 'final_surge'
TextColumn get providerWorkoutId => text().nullable()(); // Unique ID
TextColumn get providerWorkoutUrl => text().nullable()(); // Deep link
BoolColumn get userModified => boolean().withDefault(const Constant(false))();
DateTimeColumn get lastSyncedAt => dateTime().nullable()();
```

**Why not a separate junction table?**
- Simpler queries (no extra join)
- Most activities won't be synced (column is nullable)
- Aligns with existing schema design patterns

---

## UI Components

### Progress Dialog

**Component:** `NutritionPlanProgressDialog`

```dart
class NutritionPlanProgressDialog extends StatelessWidget {
  final int totalWorkouts;
  final int completedWorkouts;

  @override
  Widget build(BuildContext context) {
    final progress = completedWorkouts / totalWorkouts;

    return AlertDialog(
      title: const Text('Importing Workouts'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Usage:**
```dart
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => StreamBuilder<double>(
    stream: controller.progressStream,
    builder: (context, snapshot) {
      final progress = snapshot.data ?? 0.0;
      return NutritionPlanProgressDialog(
        totalWorkouts: controller.totalWorkouts,
        completedWorkouts: (progress * controller.totalWorkouts).round(),
      );
    },
  ),
);
```

### Connected Apps Screen

**Location:** Settings → Connected Apps

```dart
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
          _buildConnectionCard(
            name: 'Final Surge',
            logoAsset: 'assets/images/final_surge_logo.png',
            isConnected: integrationState.valueOrNull?.isConnected ?? false,
            athleteName: integrationState.valueOrNull?.athleteName,
            lastSyncAt: integrationState.valueOrNull?.lastSyncAt,
            onConnect: () => ref.read(finalSurgeControllerProvider.notifier).connect(),
            onDisconnect: () => _showDisconnectDialog(context, ref),
            onSyncNow: () => ref.read(finalSurgeControllerProvider.notifier).syncNow(),
          ),

          const SizedBox(height: 16),

          // Coming Soon: TrainingPeaks
          _buildComingSoonCard(
            name: 'TrainingPeaks',
            logoAsset: 'assets/images/trainingpeaks_logo.png',
          ),

          const SizedBox(height: 16),

          // Coming Soon: Strava
          _buildComingSoonCard(
            name: 'Strava',
            logoAsset: 'assets/images/strava_logo.png',
          ),
        ],
      ),
    );
  }
}
```

---

## Error Handling

### Comprehensive Error Strategy

```dart
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

**UI Error Display:**
```dart
AsyncValue.when(
  data: (data) => SuccessWidget(data),
  loading: () => LoadingWidget(),
  error: (error, stack) => ErrorWidget(
    message: error.toString(),
    onRetry: () => ref.refresh(finalSurgeControllerProvider),
  ),
)
```

---

## Performance Considerations

### API Call Optimization

**Deduplication:**
- Check local database before creating activities
- Use `provider_workout_id` as unique identifier
- Server-side constraint prevents duplicates

**Rate Limiting:**
- Max 5 concurrent API calls (chunking)
- Exponential backoff on errors
- ETag caching for repeat requests

**Memory Management:**
- Process in chunks (don't load all plans at once)
- Stream progress updates (don't batch)
- Dispose controllers when done

---

## Security

### Token Storage

**Encrypted at Rest:**
```dart
// Drift database with encryption
final db = AppDatabase(
  NativeDatabase.memory(
    encrypted: true,
    encryptionKey: await _getEncryptionKey(),
  ),
);
```

**Token Rotation:**
- Monitor token expiry (if Final Surge provides it)
- Silent refresh when possible
- Prompt user to reconnect if refresh fails

**Never Log Tokens:**
```dart
_logger.info('Final Surge connected', data: {
  'athlete_id': integration.providerAthleteId, // OK
  'athlete_name': integration.providerAthleteName, // OK
  // 'access_token': integration.accessToken, // NEVER LOG THIS
});
```

---

## Testing Strategy

### Unit Tests

```dart
test('chunks activities correctly', () {
  final activities = List.generate(14, (i) => Activity(id: '$i'));
  final chunks = _chunkActivities(activities, chunkSize: 5);

  expect(chunks.length, 3); // 5 + 5 + 4
  expect(chunks[0].length, 5);
  expect(chunks[1].length, 5);
  expect(chunks[2].length, 4);
});

test('detects sports from workouts', () {
  final workouts = [
    FinalSurgeWorkout(workoutTypeName: 'Run'),
    FinalSurgeWorkout(workoutTypeName: 'Run'),
    FinalSurgeWorkout(workoutTypeName: 'Bike'),
  ];

  final detected = detectSportsFromWorkouts(workouts);

  expect(detected.doesRunning, true); // 2+ runs
  expect(detected.doesCycling, false); // Only 1 bike
});
```

### Integration Tests

```dart
testWidgets('OAuth flow completes successfully', (tester) async {
  // Mock FlutterWebAuth2
  final mockAuth = MockFlutterWebAuth2();
  when(mockAuth.authenticate(any, any)).thenAnswer((_) async =>
    'com.mealvana.endurance://callback?code=test-code&state=test-state'
  );

  // Trigger connect
  await tester.tap(find.text('Connect Final Surge'));
  await tester.pumpAndSettle();

  // Verify integration saved
  final integration = await getIntegration();
  expect(integration?.provider, 'final_surge');
});

testWidgets('Progress updates during plan generation', (tester) async {
  // Setup: Import 14 workouts
  await tester.tap(find.text('Connect Final Surge'));
  await tester.pumpAndSettle();

  // Wait for progress dialog
  expect(find.text('Generating nutrition plans...'), findsOneWidget);

  // Verify progress updates
  expect(find.text('0/14'), findsOneWidget);
  await tester.pump(Duration(seconds: 5));
  expect(find.text('5/14'), findsOneWidget);
  await tester.pump(Duration(seconds: 5));
  expect(find.text('10/14'), findsOneWidget);
});
```

### Edge Function Tests

```typescript
// supabase/functions/sync-final-surge/index.test.ts

Deno.test('imports running workouts', async () => {
  const result = await syncFinalSurge({
    workouts: [{ sport: 'RUNNING', distance: 10 }]
  });

  assertEquals(result.sport_type, 'running');
  assertEquals(result.distance_km, 16.09); // 10 miles
});

Deno.test('imports cycling workouts', async () => {
  const result = await syncFinalSurge({
    workouts: [{ sport: 'CYCLING', distance: 50 }]
  });

  assertEquals(result.sport_type, 'cycling');
});

Deno.test('only imports new workouts', async () => {
  // First sync
  const result1 = await syncFinalSurge({ workouts: [{ id: '123' }] });
  assertEquals(result1.newWorkouts, 1);

  // Second sync with same workout
  const result2 = await syncFinalSurge({ workouts: [{ id: '123' }] });
  assertEquals(result2.newWorkouts, 0);
  assertEquals(result2.skipped, 1);
});
```

---

## Monitoring & Analytics

### Key Metrics

```dart
// Track in RudderStack → Mixpanel

// Connection metrics
_analytics.track('final_surge_connected', properties: {
  'athlete_id': integration.providerAthleteId,
  'workouts_imported': syncResult.newWorkouts,
  'time_to_connect_ms': connectionTime.inMilliseconds,
});

// Sync metrics
_analytics.track('final_surge_sync_complete', properties: {
  'new_workouts': syncResult.newWorkouts,
  'skipped_workouts': syncResult.skipped,
  'plans_generated': syncResult.plansGenerated,
  'sync_duration_ms': syncDuration.inMilliseconds,
  'chunk_size': 5,
});

// Error metrics
_analytics.track('final_surge_error', properties: {
  'error_type': error.runtimeType.toString(),
  'error_message': error.toString(),
  'context': 'connection', // or 'sync', 'oauth'
});
```

### Success Criteria

| Metric | Target |
|--------|--------|
| OAuth completion rate | >80% |
| Sync success rate | >95% |
| Error rate | <1% |
| Avg sync time (14 workouts) | <20 seconds |
| User retention (7-day) | >80% for connected users |

---

## Future Enhancements

### Phase 2 Features

1. **Structured Workout Parsing**
   - Parse `json_fs_v1` format
   - Extract interval details
   - Adjust nutrition for intensity

2. **Historical Import**
   - Import past workouts (30/60/90 days)
   - Premium feature
   - Batch processing

3. **Webhook Support**
   - Real-time workout updates
   - Contact Final Surge for webhook API
   - Replace polling with push notifications

4. **Two-Way Sync**
   - Push nutrition data back to Final Surge
   - Explore ProfileInfo API for plan links
   - Display in Final Surge calendar

---

## References

- [Final Surge API Documentation](./Final-Surge-Partner-API-Uploads.pdf)
- [Implementation Roadmap](./roadmap.md)
- [Comprehensive Notes](./notes.md)
- [FOA Architecture](../technical/foa-architecture.md)
- [flutter_web_auth_2 Package](https://pub.dev/packages/flutter_web_auth_2)

---

*This document will be updated as implementation progresses and new learnings emerge.*
