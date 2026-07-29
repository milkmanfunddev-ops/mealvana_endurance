# Final Surge Integration - Comprehensive Notes

**Last Updated**: December 5, 2025
**Project Status**: Implementation Planning - User Decisions Finalized
**Owner**: TBD
**Related Integration**: [TrainingPeaks](/Users/leemartin/development/mealvana_endurance/docs/integration/training_peaks/README.md) (parallel integration)

---

## 0. User Decisions (Finalized)

### Integration Flow Decisions
| Decision | Choice | Notes |
|----------|--------|-------|
| **First screen options** | Final Surge active, TrainingPeaks + Strava "Coming Soon" | Show all three with visual distinction |
| **OAuth approach** | Same as Google/Apple sign-in | Use system browser, follow existing pattern |
| **After OAuth success** | Show brief summary | "Found 12 workouts for the next 2 weeks" |
| **Sport detection** | Pre-populate, keep all screens | Don't skip screens, just pre-fill |
| **Import time range** | 14 days upcoming only | API only supports future workouts |
| **Synced workout display** | Small badge/icon | Subtle visual indicator |
| **Conflict resolution** | Keep both entries | Don't merge or replace existing workouts |
| **Workout changes in FS** | Auto-delete in Mealvana | Regenerate nutrition plan |
| **Nutrition plan generation** | Chunked parallel generation | 5 concurrent API calls, 15-20 seconds total |
| **Settings location** | New "Connected Apps" section | Dedicated section in Settings |
| **OAuth errors** | Error + retry + skip option | Both options available |
| **Token expiry** | Silent refresh + banner if needed | Graceful degradation |
| **Architecture** | Multi-integration design | Stub TrainingPeaks + Strava |
| **Premium gating** | Free for testing, premium later | Start free for testing |
| **Scope** | Full MVP for next release | Everything included |
| **Testing** | Add edge function integration tests | Use testing agent |

### Critical Fixes Required
1. **sync-final-surge edge function**: Remove running-only filter (line 332), support RUNNING + CYCLING + SWIMMING
2. **Production schema**: ✅ Verified - All multi-sport columns exist

---

## 1. Executive Summary

### Project Overview
The Final Surge integration enables Mealvana Endurance to connect with Final Surge, a popular training platform for endurance athletes. This integration will allow athletes to sync their training calendar with Mealvana to automatically generate nutrition plans based on upcoming workouts.

### Current State

**What Exists:**
- ✅ Final Surge Partner API credentials (Client ID + Secret)
- ✅ OAuth 2.0 documentation from Final Surge
- ✅ Working test script (`tool/final_surge_api_test.dart`) that successfully:
  - Completes OAuth flow
  - Fetches athlete profile info
  - Retrieves upcoming workouts
  - Stores tokens locally
- ✅ API endpoint documentation (PDF)
- ✅ Test credentials stored in test script (not production-ready)

**What's Needed:**
- ❌ Database schema for integration storage (no `integrations` table exists)
- ❌ Flutter services and repositories (following FOA pattern)
- ❌ UI/UX for onboarding flow
- ❌ Production-ready OAuth implementation
- ❌ Background sync service
- ❌ Premium feature gating (if applicable)
- ❌ Multi-device sync strategy
- ❌ Activity import mapping (Final Surge → Mealvana activities)

### Strategic Value

**Primary Benefits:**
1. **Onboarding Acceleration**: Pre-fill user profile and upcoming races from Final Surge
2. **Automatic Activity Creation**: Import scheduled workouts as Mealvana activities
3. **Sport Type Detection**: Infer primary sport (running/cycling/swimming) from workout history
4. **Reduced Manual Entry**: Athletes don't need to manually enter workout details
5. **Competitive Advantage**: Final Surge is popular but has less competition than TrainingPeaks

**Target User Segments:**
- Marathon runners using Final Surge training plans
- Triathletes coordinating multi-sport training
- Coaches using Final Surge for athlete management
- Budget-conscious athletes (Final Surge is more affordable than TrainingPeaks)

---

## 2. Final Surge API Capabilities

### OAuth 2.0 Flow

**Authorization Endpoint:**
```
GET https://log.finalsurge.com/oauth/authorize
```

**Required Parameters:**
- `client-id`: Your Application's Client ID
- `redirect-uri`: Callback URL (localhost/127.0.0.1 whitelisted)
- `state`: Security token returned in redirect

**Token Exchange:**
```
POST https://log.finalsurge.com/oauth/token
Content-Type: application/x-www-form-urlencoded

client-id=YOUR_CLIENT_ID
client-secret=YOUR_CLIENT_SECRET
code=AUTHORIZATION_CODE
```

**Token Response:**
```json
{
  "access_token": "bfe2fbd7-8862-4d85-9839-3ed70abcef11",
  "athlete": {
    "id": "16238aab-bd1d-4a89-9b17-50f33630a007",
    "firstname": "Brian",
    "lastname": "Roberds"
  },
  "error": null
}
```

**Key Differences from TrainingPeaks:**
- ✅ Simpler OAuth flow (no PKCE required)
- ✅ Athlete info returned in token exchange (no separate profile call needed)
- ❌ No explicit refresh token (access tokens appear long-lived)
- ❌ No token expiration time specified in docs
- ✅ Localhost whitelisted by default (easier testing)

### Available API Endpoints

#### 1. GET /API/v1/ProfileInfo
**Purpose**: Read/write app-specific data storage (not athlete profile)

**Authorization**: User Authorized (Bearer token)

**Response:**
```json
{
  "uniqueid": "<your_app_unique_id>",
  "profile": "<custom_profile_json>",
  "Success": true,
  "ErrorNumber": null,
  "ErrorDescription": null
}
```

**Use Case for Mealvana:**
- Store Mealvana `user_id` or `device_id` as `uniqueid`
- Store sync metadata (last_sync_date, preferences) as `profile` JSON
- Max lengths: uniqueid (200 chars), profile (3000 chars)

#### 2. POST /API/v1/ProfileInfo
**Purpose**: Save app-specific data to Final Surge

**Parameters:**
- `uniqueid` (string, max 200): Your unique identifier for this user
- `profile` (string, max 3000): Additional profile information

**Use Case for Mealvana:**
- Link Final Surge athlete to Mealvana user account
- Store sync preferences and metadata

#### 3. GET /API/v1/UpcomingWorkouts
**Purpose**: Fetch scheduled workouts (next 14 days max)

**Authorization**: User Authorized (Bearer token)

**Parameters (optional):**
- `NumDays` (int, 1-7): Number of days to fetch (default 5, includes current day)
- `NumWorkouts` (int, 1-21): Number of workouts to return (default 5)

**Response Fields (all nullable except WorkoutDate, WorkoutCompleted, WorkoutTypeName, WorkoutIcon):**
```json
{
  "Success": true,
  "Workouts": [
    {
      "WorkoutURL": "https://log.finalsurge.com/WorkoutDetails?s=...",
      "WorkoutDate": "2019-01-24T00:00:00",
      "WorkoutTime": "17:00:00",
      "WorkoutCode": "TRLTP",
      "WorkoutTitle": "Tempo Run",
      "WorkoutDescription": "10-15 minute Warm-Up + Tempo Run...",
      "WorkoutTypeName": "Run",
      "WorkoutSubTypeName": "Tempo Run",
      "WorkoutCompleted": false,
      "WorkoutIcon": 1,
      "PlannedTime": 1800,
      "PlannedDistance": 25.5,
      "PlannedDistanceType": "mi",
      "PlannedPace": "5:40-5:55",
      "PlannedPaceType": "min/mi",
      "HasStructuredWorkout": true,
      "StructuredWorkoutURLs": {
        "fit": "url_to_fit_file",
        "json_garmin_v1": "url_to_garmin_json",
        "json_fs_v1": "url_to_fs_json",
        "mrc": "url_to_mrc_file",
        "zwo": "url_to_zwift_file"
      }
    }
  ]
}
```

**WorkoutIcon Values:**
1. Run
2. Bike
3. Swim
4. Cross Training
5. Strength Training
6. Rest Day
7. Recovery
8. Other
9. Transition
10. Custom
11. Walk

**Mealvana-Relevant Fields:**
- `WorkoutDate` → Activity date for nutrition timing
- `WorkoutTypeName` → Sport type (Run, Bike, Swim)
- `PlannedDistance` → Distance for macro calculations
- `PlannedTime` → Duration for calorie estimates (in seconds)
- `WorkoutSubTypeName` → Intensity hint (Long Run, Tempo, Intervals)
- `HasStructuredWorkout` → Indicates detailed workout structure available
- `WorkoutDescription` → Coach notes that may contain nutrition guidance

#### 4. POST /API/v1/uploads
**Purpose**: Upload FIT/TCX files (workout data)

**Authorization**: User Authorized (Bearer token)

**Use Case for Mealvana:**
- ❌ Not needed for MVP (we're pulling workouts, not pushing them)
- 🔮 Future: Upload nutrition data as custom workout files

#### 5. POST /API/v1/LoginToken
**Purpose**: Generate auto-login token for Final Surge Beta System

**Authorization**: User Authorized (Bearer token)

**Response:**
```json
{
  "Success": true,
  "Token": "<token>",
  "ErrorNumber": null,
  "ErrorDescription": null
}
```

**Token Expiration**: 10 seconds

**Use Case for Mealvana:**
- Deep link users to Final Surge web interface
- "View in Final Surge" feature
- Seamless web integration

#### 6. Structured Workout Data (json_fs_v1)
**Purpose**: Detailed workout structure (intervals, ramps, repeats)

**Available via**: `StructuredWorkoutURLs.json_fs_v1` from UpcomingWorkouts

**Workout Object Structure:**
- `workoutId`: Required
- `workoutName`: Required
- `sport`: Required (RUNNING, CYCLING, SWIMMING)
- `steps`: Array of WorkoutStep/WorkoutRampStep/WorkoutRepeatStep

**Use Case for Mealvana:**
- Parse structured workouts for precise intensity estimation
- Calculate calorie burn from intervals vs steady-state
- Adjust nutrition based on workout structure (high-intensity intervals need more carbs)

### Rate Limits and Constraints

**From Documentation:**
- ❌ No explicit rate limits documented
- ✅ Upcoming workouts limited to 14 days in future
- ✅ Max 21 workouts per request
- ✅ Max 7 days per request

**Best Practices:**
- Implement exponential backoff on errors
- Cache workout data locally (Drift database)
- Only sync when needed (on app open, manual refresh, webhook trigger)
- Respect 14-day window limitation

### Error Handling

**Invalid Token Response:**
```json
{
  "Success": false,
  "ErrorNumber": 401,
  "ErrorDescription": "Access Forbidden"
}
```

**Error Scenarios:**
1. **401 Unauthorized**: Token expired or invalid → Re-authenticate
2. **403 Forbidden**: Insufficient permissions → Show error to user
3. **404 Not Found**: Invalid endpoint → Log error, contact support
4. **500 Server Error**: Final Surge issues → Retry with backoff

---

## 3. Existing Implementation

### Test Script: `tool/final_surge_api_test.dart`

**Location**: `/Users/leemartin/development/mealvana_endurance/tool/final_surge_api_test.dart`

**Capabilities:**
- ✅ OAuth flow with local HTTP server (port 8888)
- ✅ Token caching to `.final_surge_token.json`
- ✅ Athlete info extraction from token response
- ✅ Fetch and display upcoming workouts
- ✅ Profile info GET/POST support
- ✅ Pretty-printed JSON responses

**Commands:**
```bash
# Start OAuth flow
dart run tool/final_surge_api_test.dart auth

# Test API with cached token
dart run tool/final_surge_api_test.dart test

# Fetch upcoming workouts
dart run tool/final_surge_api_test.dart workouts

# Show cached athlete info
dart run tool/final_surge_api_test.dart athlete

# Get profile info (app storage)
dart run tool/final_surge_api_test.dart profile
```

**Test Credentials (Hardcoded in Script):**
```dart
const String clientId = 'BD5D0C2B-7507-405B-8A3F-DB161288E6FC';
const String clientSecret = r'65kj$#deujXLk3h?mpkm*V94X$dkb2$u78H35-Sc#$es#^C2e5^pMat3*2QAe7+$';
const String redirectUri = 'http://127.0.0.1:8888/callback';
```

**What Works:**
- OAuth flow successfully authorizes and gets access token
- Token includes athlete `id`, `firstname`, `lastname`
- Workouts API returns structured data with all fields
- Identifies useful fields for Mealvana (distance, pace, sport type)

**Limitations:**
- ❌ Not production-ready (credentials hardcoded)
- ❌ No secure token storage
- ❌ No error handling for network failures
- ❌ No token refresh mechanism
- ❌ Desktop-only (local HTTP server)

### Environment Configuration

**Required Environment Variables (for production):**
```bash
# .env files (NOT in version control)
FINAL_SURGE_CLIENT_ID=BD5D0C2B-7507-405B-8A3F-DB161288E6FC
FINAL_SURGE_CLIENT_SECRET=65kj$#deujXLk3h?mpkm*V94X$dkb2$u78H35-Sc#$es#^C2e5^pMat3*2QAe7+$
FINAL_SURGE_REDIRECT_URI=<production_deep_link_url>
```

**Mobile Redirect URI Strategy:**
- iOS: `mealvana://finalsurge/callback`
- Android: `mealvana://finalsurge/callback`
- Configure in Final Surge partner portal
- Use `uni_links` or `app_links` Flutter package for deep linking

### No Edge Functions Yet

**Observation**: Unlike TrainingPeaks integration research, there's no existing edge function for Final Surge sync.

**Implications:**
- Need to create `supabase/functions/sync-final-surge/index.ts`
- Can model after TrainingPeaks edge function structure
- OR implement sync entirely client-side (simpler for OAuth)

**Recommendation**: Start with client-side sync, move to edge functions if needed for:
- Background sync (webhooks)
- Token refresh automation
- Multi-device coordination

---

## 4. Industry Best Practices

### OAuth Patterns from Competitor Apps

**Strava Pattern (Gold Standard):**
1. **Connection Screen**: Clear value prop before OAuth redirect
2. **Scope Transparency**: Show exactly what data will be accessed
3. **One-Tap Connect**: Single button to start OAuth flow
4. **Post-Auth Confirmation**: Show what data was synced
5. **Disconnect Option**: Easy way to revoke access

**TrainingPeaks Pattern:**
1. **Calendar Preview**: Show upcoming events before asking to connect
2. **Premium Badge**: Indicate if integration requires premium
3. **Two-Way Sync Toggle**: Let users choose sync direction
4. **Conflict Resolution**: Ask user when data conflicts occur

**Garmin Connect Pattern:**
1. **Activity Type Selection**: Ask which sports to sync
2. **Historical Data Import**: Offer to import past workouts
3. **Automatic Sync Toggle**: Enable/disable background sync
4. **Sync Status Indicator**: Show last sync time

### Onboarding Flow Recommendations

**Best Practice: Integrate OAuth Early in Onboarding**

**Optimal Placement**: First screen after app install (before manual data entry)

**Flow:**
```
1. Welcome Screen
   └─> "Connect Your Training" (Final Surge + TrainingPeaks options)
       ├─> [Connect Final Surge] → OAuth Flow
       │   └─> Success → Pre-fill profile & activities
       │       └─> "Confirm Your Profile" (editable pre-filled data)
       │           └─> "Select Upcoming Race" (from imported events)
       │               └─> Complete onboarding
       │
       └─> [Skip for Now] → Manual Onboarding
           └─> Traditional data entry flow
```

**Why First Screen:**
- ✅ Reduces onboarding friction (no manual typing)
- ✅ Demonstrates immediate value (auto-populated data)
- ✅ Increases completion rates (fewer steps)
- ✅ Builds trust (shows Mealvana integrates with their tools)
- ✅ Captures primary sport automatically (from workout history)

**Alternative: Pre-Onboarding**
```
App Install → "Quick Start" Choice:
├─> "I use Final Surge" → OAuth → Pre-filled Onboarding
├─> "I use TrainingPeaks" → OAuth → Pre-filled Onboarding
└─> "Manual Setup" → Traditional Onboarding
```

### Token Storage Best Practices

**Security Requirements:**
1. **Encrypt at Rest**: Use `flutter_secure_storage` or Drift encryption
2. **Never Log Tokens**: Redact from logs and Sentry
3. **Secure Transmission**: HTTPS only
4. **Token Rotation**: Refresh tokens periodically even if not expired
5. **Revocation**: Clear tokens on logout/uninstall

**Storage Options:**

**Option A: Drift Database (Recommended)**
```dart
// Encrypted table in Drift
class IntegrationTokens extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get provider => text()(); // 'final_surge'
  TextColumn get accessToken => text()(); // Encrypted
  TextColumn get refreshToken => text().nullable()(); // Encrypted
  DateTimeColumn get expiresAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
```

**Option B: flutter_secure_storage**
```dart
// Simple key-value storage
final storage = FlutterSecureStorage();
await storage.write(
  key: 'final_surge_token_${userId}',
  value: encryptedToken,
);
```

**Recommendation**: Use Drift for consistency with rest of app architecture.

### Background Sync Strategy

**Sync Triggers:**
1. **App Open**: Check for new workouts on startup
2. **Manual Refresh**: Pull-to-refresh on activities screen
3. **Scheduled Background**: Daily sync at 6 AM user local time
4. **Webhook Push**: Real-time when Final Surge workout changes (future)

**Sync Algorithm:**
```
1. Check last_sync_at timestamp in database
2. If last_sync > 1 hour ago, skip (prevent excessive API calls)
3. Fetch upcoming workouts (NumDays=7)
4. For each workout:
   a. Check if workout already exists (by WorkoutDate + WorkoutTitle)
   b. If exists, update details (in case workout was modified)
   c. If new, create activity in Mealvana
   d. Mark as synced_from_final_surge = true
5. Update last_sync_at timestamp
6. Show notification: "3 new workouts synced from Final Surge"
```

**Conflict Resolution:**
- User modified synced activity in Mealvana → Keep Mealvana version, mark as user_modified
- Final Surge workout deleted → Mark as archived in Mealvana (don't delete)
- Duplicate workouts → Prefer Final Surge version (source of truth)

**Performance Optimization:**
- Batch insert activities (use Drift transactions)
- Cache workout icons locally
- Lazy-load structured workout data (only fetch when user opens activity)
- Debounce sync requests (prevent rapid successive syncs)

---

## 5. Architecture Decisions

### Integrations Table Design

**Proposed Schema (Drift + Supabase):**

```sql
-- Supabase table (synced to Drift)
CREATE TABLE integrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL CHECK (provider IN ('final_surge', 'training_peaks', 'strava', 'garmin')),

  -- OAuth tokens (encrypted in Drift)
  access_token TEXT NOT NULL,
  refresh_token TEXT,
  token_expires_at TIMESTAMPTZ,

  -- Provider-specific athlete data
  provider_athlete_id TEXT NOT NULL, -- Final Surge athlete.id
  provider_athlete_name TEXT, -- "FirstName LastName"
  provider_profile_data JSONB, -- Full athlete profile

  -- Sync metadata
  is_active BOOLEAN DEFAULT true,
  last_sync_at TIMESTAMPTZ,
  last_sync_status TEXT CHECK (last_sync_status IN ('success', 'error', 'pending')),
  last_sync_error TEXT,
  sync_settings JSONB DEFAULT '{}', -- User preferences

  -- Tracking
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, provider) -- One integration per provider per user
);

-- Indexes
CREATE INDEX idx_integrations_user_provider ON integrations(user_id, provider);
CREATE INDEX idx_integrations_active ON integrations(is_active);
CREATE INDEX idx_integrations_last_sync ON integrations(last_sync_at);

-- RLS Policies
ALTER TABLE integrations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own integrations"
  ON integrations FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own integrations"
  ON integrations FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own integrations"
  ON integrations FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own integrations"
  ON integrations FOR DELETE
  USING (auth.uid() = user_id);
```

**Drift Table:**
```dart
@DataClassName('Integration')
class Integrations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get provider => text()(); // 'final_surge', 'training_peaks'

  // Encrypted columns
  TextColumn get accessToken => text()();
  TextColumn get refreshToken => text().nullable()();
  DateTimeColumn get tokenExpiresAt => dateTime().nullable()();

  // Provider data
  TextColumn get providerAthleteId => text()();
  TextColumn get providerAthleteName => text().nullable()();
  TextColumn get providerProfileData => text().map(JsonConverter()).nullable()();

  // Sync metadata
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  TextColumn get lastSyncStatus => text().nullable()(); // 'success', 'error', 'pending'
  TextColumn get lastSyncError => text().nullable()();
  TextColumn get syncSettings => text().map(JsonConverter()).withDefault(const Constant('{}'))();

  // Timestamps
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
```

**Sync Settings JSONB Structure:**
```json
{
  "auto_sync_enabled": true,
  "sync_interval_hours": 24,
  "import_past_workouts": false,
  "sync_sport_types": ["Run", "Bike", "Swim"],
  "create_activities_automatically": true,
  "notify_on_new_workouts": true
}
```

### Activity Sync Tracking

**Option A: Add columns to existing `activities` table**
```sql
ALTER TABLE activities ADD COLUMN synced_from_provider TEXT;
ALTER TABLE activities ADD COLUMN provider_workout_id TEXT;
ALTER TABLE activities ADD COLUMN provider_workout_url TEXT;
ALTER TABLE activities ADD COLUMN user_modified BOOLEAN DEFAULT false;
```

**Option B: Create separate `synced_activities` junction table**
```sql
CREATE TABLE synced_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  integration_id UUID NOT NULL REFERENCES integrations(id) ON DELETE CASCADE,
  provider_workout_id TEXT NOT NULL,
  provider_workout_url TEXT,
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  last_updated_at TIMESTAMPTZ,
  user_modified BOOLEAN DEFAULT false,
  UNIQUE(activity_id, integration_id)
);
```

**Recommendation**: **Option A** (simpler, fewer joins, aligns with existing schema design)

**Updated Activities Schema:**
```dart
@DataClassName('Activity')
class Activities extends Table {
  // ... existing columns ...

  // Integration tracking (new columns)
  TextColumn get syncedFromProvider => text().nullable()(); // 'final_surge', 'training_peaks'
  TextColumn get providerWorkoutId => text().nullable()(); // Final Surge WorkoutDate+WorkoutTitle hash
  TextColumn get providerWorkoutUrl => text().nullable()(); // Deep link to Final Surge workout
  BoolColumn get userModified => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}
```

### Background Sync Approach

**Option A: Workmanager (Recommended for MVP)**
```dart
// Setup in main.dart
Workmanager().registerPeriodicTask(
  "final-surge-sync",
  "syncFinalSurgeWorkouts",
  frequency: Duration(hours: 24),
  constraints: Constraints(
    networkType: NetworkType.connected,
  ),
);

// Handler
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == "syncFinalSurgeWorkouts") {
      final service = FinalSurgeSyncService();
      await service.syncWorkouts();
      return true;
    }
    return false;
  });
}
```

**Option B: Supabase Edge Function + Cron (Future Enhancement)**
```typescript
// supabase/functions/sync-final-surge/index.ts
Deno.serve(async (req) => {
  // Fetch all active Final Surge integrations
  const integrations = await supabase
    .from('integrations')
    .select('*')
    .eq('provider', 'final_surge')
    .eq('is_active', true);

  for (const integration of integrations) {
    await syncUserWorkouts(integration);
  }
});

// Triggered by Supabase cron: "0 6 * * *" (6 AM daily)
```

**Recommendation**: Start with **Option A** (simpler, works offline), migrate to **Option B** for advanced features (webhooks, multi-device coordination).

### Premium Feature Gating

**Question**: Should Final Surge integration be a premium feature?

**Considerations:**

**Free Tier:**
- ✅ Increases user acquisition (remove friction)
- ✅ Competitive advantage over apps that paywall integrations
- ✅ Final Surge API is free (no cost to Mealvana)
- ✅ Aligns with "offline-first" philosophy (doesn't require server)

**Premium Tier:**
- ✅ Justifies subscription value
- ✅ Limits server load (fewer sync requests)
- ✅ Encourages upgrades ("Unlock Final Surge sync")

**Hybrid Approach (Recommended):**
1. **Free**: Manual one-time import (via OAuth, then disconnect)
2. **Premium**: Auto-sync, background sync, real-time updates

**Implementation:**
```dart
// Check premium status before auto-sync
if (user.isPremium || user.premiumExpiresAt > DateTime.now()) {
  await syncService.enableAutoSync();
} else {
  // Show upgrade prompt
  showPremiumUpgradeDialog(
    feature: 'Automatic Final Surge Sync',
    description: 'Keep your workouts in sync automatically',
  );
}
```

---

## 6. Onboarding Integration Plan

### Screen Placement: First Screen (Recommended)

**New Welcome Screen (replaces or precedes existing onboarding):**

```
┌─────────────────────────────────────┐
│                                     │
│   🏃 Welcome to Mealvana Endurance │
│                                     │
│   Personalized nutrition for        │
│   endurance athletes                │
│                                     │
│   ┌───────────────────────────┐   │
│   │  Connect Your Training     │   │
│   │                            │   │
│   │  [Final Surge Logo]        │   │
│   │  Connect Final Surge       │   │
│   │  Import workouts & profile │   │
│   │                            │   │
│   └───────────────────────────┘   │
│                                     │
│   ┌───────────────────────────┐   │
│   │  [TrainingPeaks Logo]      │   │
│   │  Connect TrainingPeaks     │   │
│   │  Import events & metrics   │   │
│   └───────────────────────────┘   │
│                                     │
│   ─── OR ───                       │
│                                     │
│   [Skip - Enter Manually]          │
│                                     │
└─────────────────────────────────────┘
```

**User Flow:**

1. **User Taps "Connect Final Surge"**
   ```
   → Show loading: "Connecting to Final Surge..."
   → Open OAuth flow (in-app browser or system browser)
   → User authorizes in Final Surge
   → Redirect back to Mealvana
   → Show success: "Connected! Importing your data..."
   ```

2. **Data Pre-fill Process**
   ```
   ┌─────────────────────────────────────┐
   │  Importing from Final Surge...      │
   │                                     │
   │  ✅ Profile information             │
   │  ✅ 12 upcoming workouts            │
   │  ⏳ Analyzing training history...   │
   │                                     │
   └─────────────────────────────────────┘
   ```

3. **Confirm Your Profile Screen** (editable pre-filled data)
   ```
   ┌─────────────────────────────────────┐
   │  Confirm Your Profile               │
   │                                     │
   │  Name: Brian Roberds ✏️             │
   │  Primary Sport: Running 🏃          │
   │  (detected from workout history)    │
   │                                     │
   │  Weight: [empty] ← needs input     │
   │  Height: [empty] ← needs input     │
   │  Birthday: [empty] ← needs input   │
   │                                     │
   │  [Continue]                         │
   └─────────────────────────────────────┘
   ```

4. **Select Upcoming Race** (from imported events)
   ```
   ┌─────────────────────────────────────┐
   │  Select Your Next Race              │
   │                                     │
   │  📍 Boston Marathon                 │
   │     April 21, 2025 • 26.2 miles    │
   │     [Select This Race]              │
   │                                     │
   │  📍 Weekly Long Run                 │
   │     Dec 8, 2024 • 15 miles         │
   │     [Select This Workout]           │
   │                                     │
   │  ─── OR ───                        │
   │  [Enter Race Manually]              │
   └─────────────────────────────────────┘
   ```

5. **Complete Onboarding**
   ```
   → Generate nutrition plan for selected race
   → Show plan
   → Onboarding complete
   ```

### Data Pre-fill Opportunities

**From OAuth Token Response:**
- `athlete.id` → Store as `provider_athlete_id`
- `athlete.firstname` + `athlete.lastname` → Pre-fill user name (optional)

**From UpcomingWorkouts API:**
- `WorkoutTypeName` → Detect primary sport
  - Count frequency: Run (10), Bike (3), Swim (2) → Primary sport = Running
  - Map to Mealvana sport types (currently run-focused, future: cycling/swimming)
- `WorkoutDate` + `PlannedDistance` → Find "race" workouts
  - Heuristic: Distance > 13.1 miles = likely race
  - `WorkoutSubTypeName` contains "Race" or "Marathon" or "Event"
  - First long-distance workout in future = candidate race
- `PlannedDistance` + `PlannedDistanceType` → Pre-fill activity distance
- `PlannedTime` → Pre-fill estimated duration (convert seconds to HH:MM:SS)
- `WorkoutDescription` → Parse for pace goals, intensity hints

**Sport Inference Logic:**
```dart
Map<String, int> sportCounts = {
  'Run': 0,
  'Bike': 0,
  'Swim': 0,
};

for (var workout in upcomingWorkouts) {
  final sportType = workout.workoutTypeName;
  if (sportCounts.containsKey(sportType)) {
    sportCounts[sportType]++;
  }
}

// Find most common sport
final primarySport = sportCounts.entries
    .reduce((a, b) => a.value > b.value ? a : b)
    .key;

// Map to Mealvana sport_type
final mealvanaSport = {
  'Run': 'running',
  'Bike': 'cycling',
  'Swim': 'swimming',
}[primarySport] ?? 'running'; // Default to running
```

### Skip/Manual Flow

**If user taps "Skip - Enter Manually":**
```
→ Go to existing onboarding flow
→ At end of onboarding, show:
   "Want to connect Final Surge later?"
   [Yes, Remind Me] [No, Thanks]

→ If "Remind Me", show banner on home screen:
   "Connect Final Surge to auto-import workouts"
   [Connect Now] [Dismiss]
```

---

## 7. Technical Requirements

### Database Schema Changes Needed

**1. Create `integrations` table** (Drift + Supabase)
```sql
-- See Section 5: Architecture Decisions for full schema
```

**2. Add columns to `activities` table** (Drift + Supabase)
```sql
ALTER TABLE activities ADD COLUMN synced_from_provider TEXT;
ALTER TABLE activities ADD COLUMN provider_workout_id TEXT;
ALTER TABLE activities ADD COLUMN provider_workout_url TEXT;
ALTER TABLE activities ADD COLUMN user_modified BOOLEAN DEFAULT false;
ALTER TABLE activities ADD COLUMN last_synced_at TIMESTAMPTZ;
```

**3. Create indices for performance**
```sql
CREATE INDEX idx_activities_provider_workout ON activities(synced_from_provider, provider_workout_id);
CREATE INDEX idx_activities_last_synced ON activities(last_synced_at);
```

**4. Add migration scripts**
```dart
// Drift migration
MigrationStrategy(
  onUpgrade: (m, from, to) async {
    if (from < 2) {
      await m.addColumn(activities, activities.syncedFromProvider);
      await m.addColumn(activities, activities.providerWorkoutId);
      await m.addColumn(activities, activities.providerWorkoutUrl);
      await m.addColumn(activities, activities.userModified);
      await m.addColumn(activities, activities.lastSyncedAt);

      await m.createTable(integrations);
    }
  },
);
```

**5. Supabase migration SQL**
```sql
-- Create in: supabase/migrations/YYYYMMDDHHMMSS_add_final_surge_integration.sql
-- See Section 5 for full SQL
```

### New Flutter Services/Repositories (FOA Pattern)

**Directory Structure:**
```
lib/features/integrations/
├── presentation/
│   ├── widgets/
│   │   ├── connect_final_surge_button.dart
│   │   ├── integration_status_card.dart
│   │   └── sync_status_indicator.dart
│   ├── screens/
│   │   ├── integrations_screen.dart
│   │   └── final_surge_connect_screen.dart
│   └── providers/
│       ├── final_surge_controller.dart
│       └── final_surge_controller.g.dart
│
├── application/
│   ├── final_surge_oauth_service.dart
│   ├── final_surge_sync_service.dart
│   └── integration_manager_service.dart
│
├── domain/
│   ├── integration.dart
│   ├── final_surge_workout.dart
│   └── final_surge_athlete.dart
│
└── data/
    ├── integration_repository.dart
    └── final_surge_api_client.dart
```

**Key Classes:**

**1. FinalSurgeOAuthService (Application Layer)**
```dart
class FinalSurgeOAuthService {
  Future<Integration> authenticate() async {
    // 1. Generate OAuth URL
    // 2. Open in-app browser or deep link
    // 3. Handle redirect callback
    // 4. Exchange code for token
    // 5. Store in IntegrationRepository
    // 6. Return Integration object
  }

  Future<void> disconnect(String userId) async {
    // 1. Revoke token (if Final Surge supports)
    // 2. Delete from IntegrationRepository
    // 3. Mark synced activities as disconnected
  }
}
```

**2. FinalSurgeSyncService (Application Layer)**
```dart
class FinalSurgeSyncService {
  Future<SyncResult> syncWorkouts(String userId) async {
    // 1. Get integration from repository
    // 2. Fetch upcoming workouts from Final Surge API
    // 3. Map to Mealvana activities
    // 4. Upsert to ActivitiesRepository
    // 5. Update last_sync_at timestamp
    // 6. Return SyncResult (counts, errors)
  }

  Future<void> importHistoricalWorkouts(
    String userId,
    DateTime startDate,
  ) async {
    // Batch import past workouts (premium feature)
  }
}
```

**3. FinalSurgeApiClient (Data Layer)**
```dart
class FinalSurgeApiClient {
  final String baseUrl = 'https://log.finalsurge.com';
  final String clientId;
  final String clientSecret;

  Future<FinalSurgeTokenResponse> exchangeCodeForToken(String code) async {
    // POST /oauth/token
  }

  Future<List<FinalSurgeWorkout>> getUpcomingWorkouts(
    String accessToken,
    {int numDays = 7, int numWorkouts = 21}
  ) async {
    // GET /API/v1/UpcomingWorkouts
  }

  Future<FinalSurgeProfileInfo> getProfileInfo(String accessToken) async {
    // GET /API/v1/ProfileInfo
  }

  Future<void> setProfileInfo(
    String accessToken,
    String uniqueId,
    String profile,
  ) async {
    // POST /API/v1/ProfileInfo
  }
}
```

**4. IntegrationRepository (Data Layer)**
```dart
class IntegrationRepository {
  final AppDatabase _db;

  Future<Integration?> getIntegration(String userId, String provider) async {
    // Query Drift for integration
  }

  Future<void> saveIntegration(Integration integration) async {
    // Upsert to Drift + Supabase
  }

  Future<void> deleteIntegration(String userId, String provider) async {
    // Delete from Drift + Supabase
  }

  Future<void> updateSyncStatus(
    String userId,
    String provider,
    SyncStatus status,
  ) async {
    // Update last_sync_at, last_sync_status
  }
}
```

**5. FinalSurgeController (Presentation Layer)**
```dart
@riverpod
class FinalSurgeController extends _$FinalSurgeController {
  @override
  FutureOr<FinalSurgeState> build() async {
    // Load integration status from repository
    final integration = await ref.read(integrationRepositoryProvider)
      .getIntegration(userId, 'final_surge');

    return FinalSurgeState(
      isConnected: integration != null,
      lastSyncAt: integration?.lastSyncAt,
      syncStatus: integration?.lastSyncStatus,
    );
  }

  Future<void> connect() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final integration = await ref.read(finalSurgeOAuthServiceProvider)
        .authenticate();

      // Trigger initial sync
      await ref.read(finalSurgeSyncServiceProvider)
        .syncWorkouts(userId);

      return FinalSurgeState(
        isConnected: true,
        lastSyncAt: DateTime.now(),
        syncStatus: 'success',
      );
    });
  }

  Future<void> disconnect() async {
    // Disconnect logic
  }

  Future<void> syncNow() async {
    // Manual sync trigger
  }
}
```

### UI Screens to Create

**1. IntegrationsScreen** (Settings → Integrations)
```dart
// Shows all available integrations
// Final Surge, TrainingPeaks, Strava, Garmin
// Each with connect/disconnect button
// Sync status indicators
```

**2. FinalSurgeConnectScreen** (Onboarding or Settings)
```dart
// Value proposition
// "Connect Final Surge" button
// OAuth flow handling
// Success/error states
```

**3. SyncStatusWidget** (Home Screen or Activities Screen)
```dart
// Shows last sync time
// "Sync Now" button
// Loading indicator during sync
```

**4. ConnectedAppsCard** (Profile/Settings)
```dart
// List of connected integrations
// Disconnect buttons
// Sync settings toggles
```

### OAuth Flow via flutter_web_auth_2

**Approach**: Use `flutter_web_auth_2` package instead of manual deep linking.

This is the same pattern as Google/Apple native SDKs but for web-based OAuth:
- Opens secure in-app browser (ASWebAuthenticationSession on iOS, Custom Tabs on Android)
- Handles callback automatically via app bundle ID
- Returns auth code directly - no manual deep linking configuration needed

**Flutter Package:**
```yaml
dependencies:
  flutter_web_auth_2: ^3.1.2  # Handles OAuth flow and callbacks
```

**OAuth Redirect URI** (uses app bundle ID automatically):
```
com.mealvana.endurance://callback
```

**Implementation:**
```dart
// In FinalSurgeOAuthService
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

Future<String> authenticate() async {
  final authUrl = Uri.https('log.finalsurge.com', '/oauth/authorize', {
    'client-id': _clientId,
    'redirect-uri': 'com.mealvana.endurance://callback',
    'state': _generateState(),
  });

  // Opens secure browser, returns callback URL with auth code
  final result = await FlutterWebAuth2.authenticate(
    url: authUrl.toString(),
    callbackUrlScheme: 'com.mealvana.endurance',
  );

  final callbackUri = Uri.parse(result);
  final code = callbackUri.queryParameters['code']!;
  return code;
}
```

**Note**: No iOS Info.plist or Android Manifest changes needed - the package handles this automatically.

---

## 8. Open Questions

### 1. Token Refresh Strategy
**Question**: Does Final Surge access token expire? If so, when?

**Current Status**:
- ❌ Not documented in API PDF
- ❌ Test script doesn't handle refresh
- ✅ No explicit refresh token in response

**Action Items**:
- [ ] Test token longevity (use test script daily for 30 days)
- [ ] Contact Final Surge support for token lifecycle documentation
- [ ] Implement proactive token refresh if needed (similar to TrainingPeaks 1-hour expiry)

**Hypothesis**: Tokens are long-lived (days/weeks), no refresh needed for MVP.

### 2. Multi-Device Sync Coordination
**Question**: How do we prevent duplicate workouts when user has Mealvana on multiple devices?

**Scenarios**:
- User has Mealvana on iPhone + iPad
- Both devices sync from Final Surge simultaneously
- Risk: Duplicate activities created

**Options**:
A. **Server-Side Deduplication** (Recommended)
   - Supabase trigger checks for duplicates before insert
   - Match on: `user_id + provider_workout_id`
   - Return existing activity instead of creating new

B. **Client-Side Deduplication**
   - Check local Drift DB before creating activity
   - Risk: Race condition if both devices sync simultaneously

C. **Sync Lock in Supabase**
   - Add `sync_in_progress` boolean to integrations table
   - Device 1 sets lock, syncs, releases
   - Device 2 waits for lock

**Recommendation**: **Option A** (simplest, most reliable)

**Implementation**:
```sql
-- Supabase function
CREATE OR REPLACE FUNCTION upsert_synced_activity(
  p_user_id UUID,
  p_provider TEXT,
  p_provider_workout_id TEXT,
  p_activity_data JSONB
) RETURNS UUID AS $$
DECLARE
  v_activity_id UUID;
BEGIN
  -- Check if activity already exists
  SELECT id INTO v_activity_id
  FROM activities
  WHERE user_id = p_user_id
    AND synced_from_provider = p_provider
    AND provider_workout_id = p_provider_workout_id;

  IF v_activity_id IS NULL THEN
    -- Create new activity
    INSERT INTO activities (user_id, synced_from_provider, provider_workout_id, ...)
    VALUES (p_user_id, p_provider, p_provider_workout_id, ...)
    RETURNING id INTO v_activity_id;
  ELSE
    -- Update existing activity (if not user_modified)
    UPDATE activities
    SET ... = ..., last_synced_at = NOW()
    WHERE id = v_activity_id AND user_modified = false;
  END IF;

  RETURN v_activity_id;
END;
$$ LANGUAGE plpgsql;
```

### 3. Historical Workout Import
**Question**: Should we import past workouts (30/60/90 days)?

**Pros**:
- Better training analysis
- More accurate sport detection
- Historical nutrition plans

**Cons**:
- API doesn't support historical range (only 14 days future)
- Would need to use StructuredWorkout endpoints (undocumented)
- Risk of cluttering user's calendar

**Recommendation**:
- ❌ Not for MVP (only sync upcoming 14 days)
- 🔮 Future feature: "Import Training History" button in settings
- Gate behind premium (intensive API operation)

### 4. Structured Workout Parsing
**Question**: Should we parse structured workout data for better nutrition calculations?

**Example**:
- Simple workout: "10 mile run" → Basic macro calculation
- Structured workout: "10 mile run (2 mile warmup @ easy, 6x1 mile @ tempo, 2 mile cooldown)" → Adjust for high-intensity intervals

**Pros**:
- More accurate calorie/carb calculations
- Differentiate easy runs from tempo/interval workouts
- Show structured plan in Mealvana UI

**Cons**:
- Complex parsing logic
- Final Surge's `json_fs_v1` format is proprietary
- Not all workouts have structured data

**Recommendation**:
- ❌ Not for MVP (use simple PlannedDistance + PlannedTime)
- 🔮 Phase 2: Parse structured workouts for intensity adjustment
- Use `WorkoutSubTypeName` as intensity hint for MVP ("Tempo Run" → higher carbs)

### 5. Two-Way Sync
**Question**: Should Mealvana push nutrition data back to Final Surge?

**Use Cases**:
- Display macro targets in Final Surge calendar
- Show "Nutrition Plan Complete" status
- Link to Mealvana plan from Final Surge

**API Support**:
- ❌ No nutrition endpoints in Final Surge API (unlike TrainingPeaks)
- ✅ Could use POST /API/v1/uploads to upload custom TCX files with nutrition notes
- ✅ Could use ProfileInfo to store link to Mealvana plan

**Recommendation**:
- ❌ Not possible for MVP (no nutrition API)
- 🔮 Future: Explore custom file uploads or wait for Final Surge to add nutrition endpoints
- Alternative: Use `POST /API/v1/ProfileInfo` to store Mealvana plan URL

### 6. Webhook Support
**Question**: Does Final Surge support webhooks for real-time workout updates?

**Current Status**:
- ❌ Not mentioned in API documentation
- ❌ No webhook endpoints listed
- ❓ Unknown if Final Surge offers push notifications

**Fallback**:
- ✅ Polling sync (every 24 hours or on app open)
- ✅ Manual "Sync Now" button

**Action Items**:
- [ ] Contact Final Surge support to ask about webhooks
- [ ] Check if POST /API/v1/ProfileInfo can store webhook URL

**Recommendation**: Assume no webhooks for MVP, use polling.

### 7. Premium vs Free Feature Split
**Question**: Which integration features should be premium-only?

**Options**:

**Option A: All Free**
- Connect Final Surge (OAuth)
- Import upcoming workouts
- Auto-sync daily

**Option B: Freemium**
- **Free**: Manual one-time import (connect, import, disconnect)
- **Premium**:
  - Keep connection active
  - Auto-sync in background
  - Historical workout import
  - Priority sync (every 6 hours vs 24 hours)

**Option C: All Premium**
- Final Surge integration requires subscription
- Free users: Manual entry only

**Market Research**:
- Strava: Free integrations (but upsell premium features)
- TrainingPeaks: Integration is free (subscription is for TP itself)
- MyFitnessPal: Free integrations to major platforms

**Recommendation**: **Option B (Freemium)**
- Allows trial of integration (acquisition)
- Incentivizes premium upgrade (retention)
- Competitive with other nutrition apps

### 8. Race Detection Heuristic
**Question**: How do we identify which workouts are "races" vs regular training?

**Challenges**:
- Final Surge doesn't have explicit "race" flag
- `WorkoutSubTypeName` may contain "Race" but not always
- Long distance doesn't always mean race (could be long run training)

**Heuristics (in order of confidence):**
1. **WorkoutSubTypeName contains "Race" or "Event" or "Marathon"** → 95% confidence
2. **Distance ≥ 13.1 miles (half marathon)** → 70% confidence
3. **WorkoutTitle contains "Race" or target time (e.g., "3:30")** → 80% confidence
4. **WorkoutDescription contains "goal pace" or "PR attempt"** → 60% confidence
5. **First workout in calendar over certain distance** → 50% confidence

**Recommendation**:
```dart
bool isLikelyRace(FinalSurgeWorkout workout) {
  // High confidence: Explicit race keyword
  if (workout.workoutSubTypeName?.toLowerCase().contains('race') == true ||
      workout.workoutTitle?.toLowerCase().contains('race') == true) {
    return true;
  }

  // Medium confidence: Race-distance threshold + no "training" keyword
  if (workout.plannedDistance != null &&
      workout.plannedDistance! >= 13.1 &&
      !workout.workoutTitle?.toLowerCase().contains('training') == true) {
    return true;
  }

  // Low confidence: Ask user
  return false; // Default: treat as training, let user select race manually
}
```

**Fallback**: Show "Select Your Next Race" screen with all long-distance workouts, let user choose.

---

## 9. Next Steps

### Phase 0: Foundation (Weeks 1-2)
**Goal**: Set up database schema and core architecture

**Tasks**:
- [ ] Create `integrations` table schema (Drift + Supabase)
- [ ] Add sync columns to `activities` table
- [ ] Write Drift migration script
- [ ] Create Supabase migration SQL
- [ ] Test migration in dev environment
- [ ] Create FOA directory structure (`lib/features/integrations/`)
- [ ] Define domain models: `Integration`, `FinalSurgeWorkout`, `FinalSurgeAthlete`
- [ ] Set up environment variables for Final Surge credentials

**Deliverables**:
- ✅ Database schema deployed to dev + prod
- ✅ Drift database updated to v2
- ✅ Empty FOA feature structure
- ✅ Domain models defined

### Phase 1: OAuth Implementation (Weeks 3-4)
**Goal**: Working OAuth flow (connect, store token, disconnect)

**Tasks**:
- [ ] Add `flutter_web_auth_2` package to pubspec.yaml
- [ ] Create `FinalSurgeOAuthService` (using flutter_web_auth_2)
- [ ] Build `FinalSurgeApiClient` (API wrapper)
- [ ] Create `IntegrationRepository`
- [ ] Build `FinalSurgeConnectScreen` UI
- [ ] Implement token storage (encrypted in Drift)
- [ ] Add "Connect Final Surge" button to onboarding
- [ ] Test OAuth flow on iOS + Android
- [ ] Add disconnect functionality
- [ ] Add error handling (network failures, user cancellation)

**Deliverables**:
- ✅ User can connect Final Surge account
- ✅ Token stored securely in Drift database
- ✅ User can disconnect account
- ✅ OAuth works on iOS + Android

### Phase 2: Workout Sync (Weeks 5-6)
**Goal**: Import upcoming workouts from Final Surge

**Tasks**:
- [ ] Create `FinalSurgeSyncService`
- [ ] Implement workout fetching (`GET /API/v1/UpcomingWorkouts`)
- [ ] Map Final Surge workouts to Mealvana activities
- [ ] Handle distance unit conversion (miles ↔ kilometers)
- [ ] Implement sport detection logic
- [ ] Create `SyncStatusWidget` UI
- [ ] Add "Sync Now" button to activities screen
- [ ] Implement duplicate prevention (server-side)
- [ ] Add sync progress indicators
- [ ] Test with various workout types (Run, Bike, Swim)

**Deliverables**:
- ✅ Upcoming workouts imported to Mealvana
- ✅ Activities marked as `synced_from_final_surge`
- ✅ No duplicate activities across devices
- ✅ Manual sync button works

### Phase 3: Onboarding Integration (Weeks 7-8)
**Goal**: Pre-fill onboarding data from Final Surge

**Tasks**:
- [ ] Create welcome screen with "Connect Final Surge" option
- [ ] Implement athlete name pre-fill
- [ ] Build sport detection from workout history
- [ ] Create "Confirm Your Profile" screen (editable pre-filled data)
- [ ] Implement race detection heuristic
- [ ] Build "Select Your Next Race" screen
- [ ] Test onboarding flow end-to-end
- [ ] Add analytics tracking (conversion rates)
- [ ] Implement "Skip for Now" flow
- [ ] Add "Connect Later" reminder banner

**Deliverables**:
- ✅ Onboarding pre-filled from Final Surge
- ✅ Primary sport detected automatically
- ✅ Race selection from imported workouts
- ✅ Skip flow still works
- ✅ Analytics tracking in place

### Phase 4: Background Sync (Weeks 9-10)
**Goal**: Automatic daily sync in background

**Tasks**:
- [ ] Integrate `workmanager` package
- [ ] Set up daily background task (6 AM local time)
- [ ] Implement background sync logic
- [ ] Add sync frequency setting (user preference)
- [ ] Handle network failures gracefully
- [ ] Show notification on new workouts synced
- [ ] Add sync history log (last 10 syncs)
- [ ] Test battery impact
- [ ] Optimize for Android Doze mode
- [ ] Test on low battery scenarios

**Deliverables**:
- ✅ Daily automatic sync works
- ✅ User can configure sync frequency
- ✅ Notifications on new workouts
- ✅ Battery-efficient background task

### Phase 5: Polish & Testing (Weeks 11-12)
**Goal**: Production-ready integration

**Tasks**:
- [ ] Implement premium feature gating (if applicable)
- [ ] Add error handling for all edge cases
- [ ] Write integration tests
- [ ] Perform security audit (token storage, API calls)
- [ ] Test with Final Surge support (validate API usage)
- [ ] Create user documentation
- [ ] Add help/FAQ section in app
- [ ] Implement analytics dashboard (sync metrics)
- [ ] Load testing (100 users syncing simultaneously)
- [ ] A/B test onboarding flow (with vs without Final Surge)

**Deliverables**:
- ✅ All edge cases handled
- ✅ Integration tests passing
- ✅ Security audit complete
- ✅ User documentation written
- ✅ Ready for production release

### Phase 6: Launch & Monitor (Week 13+)
**Goal**: Deploy to production and monitor

**Tasks**:
- [ ] Deploy to production (iOS + Android)
- [ ] Announce in release notes
- [ ] Monitor error rates (Sentry)
- [ ] Track sync success rates (analytics)
- [ ] Collect user feedback
- [ ] Fix bugs as reported
- [ ] Iterate on UX based on feedback
- [ ] Plan future enhancements (structured workouts, historical import)

**Success Metrics**:
- 📊 >50% of new users connect Final Surge
- 📊 >90% sync success rate
- 📊 <1% error rate
- 📊 >80% user retention after 7 days
- 📊 Positive user reviews mentioning integration

---

## 10. References

### Documentation
- [Final Surge Partner API PDF](/Users/leemartin/development/mealvana_endurance/docs/integration/final_surge/Final-Surge-Partner-API-Uploads.pdf)
- [Test Script](/Users/leemartin/development/mealvana_endurance/tool/final_surge_api_test.dart)
- [TrainingPeaks Integration README](/Users/leemartin/development/mealvana_endurance/docs/integration/training_peaks/README.md)
- [Mealvana FOA Architecture](/Users/leemartin/development/mealvana_endurance/docs/technical/foa-architecture.md)

### External Resources
- Final Surge Website: https://www.finalsurge.com
- Final Surge Support: support@finalsurge.com (assumed)
- API Support: Check Final Surge developer portal (URL TBD)

### Comparison: TrainingPeaks vs Final Surge

| Feature | TrainingPeaks | Final Surge |
|---------|---------------|-------------|
| **OAuth Flow** | OAuth 2.0 (complex) | OAuth 2.0 (simple) |
| **Token Refresh** | 1 hour expiry | Unknown (likely long-lived) |
| **Athlete Profile** | Separate API call | Included in token response |
| **Upcoming Workouts** | ✅ Events API | ✅ UpcomingWorkouts API |
| **Nutrition Endpoints** | ✅ Yes (`nutrition:write`) | ❌ No |
| **Webhooks** | ✅ Supported | ❓ Unknown |
| **Structured Workouts** | ✅ Yes | ✅ Yes (json_fs_v1) |
| **Historical Data** | ✅ No limit | ❌ 14 days future only |
| **Premium Restrictions** | ✅ Yes (403 errors) | ❓ Unknown |
| **Sandbox Environment** | ✅ Yes | ❓ Unknown |
| **API Documentation** | ✅ Comprehensive | ⚠️ Basic PDF only |

**Advantage: Final Surge**
- Simpler OAuth (no PKCE, localhost whitelisted)
- Athlete data in token (fewer API calls)
- No explicit premium restrictions (more accessible)

**Advantage: TrainingPeaks**
- Nutrition API (two-way sync possible)
- Webhook support (real-time updates)
- Better documentation
- Sandbox environment for testing

---

## 11. Nutrition Plan Generation Strategy

### Implementation Decision: Chunked Parallel Generation

**DECISION (2025-12-17)**: Using **chunked parallel generation in Flutter** instead of pg_cron + pgmq background processing.

### Why This Approach
- ✅ **Simpler** - No pg_cron/pgmq infrastructure needed
- ✅ **Faster** - 15-20 seconds vs 7 minutes with cron
- ✅ **Better UX** - User sees live progress instead of waiting
- ✅ **Easier to debug** - All in Flutter code, not distributed across database + edge functions
- ✅ **Rate limit safe** - Max 5 concurrent API calls at a time
- ✅ **Real-time feedback** - Calendar updates as each plan completes

### Technical Implementation

**Chunked Processing:**
```dart
const chunkSize = 5; // Process 5 at a time
for (var i = 0; i < activities.length; i += chunkSize) {
  final chunk = activities.skip(i).take(chunkSize).toList();
  await Future.wait(chunk.map((a) => generatePlan(a)));
  // Update progress UI after each chunk
}
```

**Performance:**
- 14 workouts = 3 chunks of 5 + 1 chunk of 4
- ~5 seconds per chunk (API calls run in parallel)
- Total time: ~15-20 seconds

**User Experience:**
1. User connects Final Surge account
2. OAuth completes, workouts imported
3. Progress dialog shows: "Generating plans... 7/14" with progress bar
4. Calendar updates in real-time as plans complete
5. Success dialog: "Found 14 workouts, generated 14 nutrition plans"

### Alternative Considered: Background Processing (Rejected)

**Approach:** pg_cron + pgmq with 30-second polling
- Process 1 plan every 30 seconds
- 14 workouts = 7 minutes total time
- No live progress feedback
- More complex infrastructure

**Why Rejected:**
- ❌ Too slow - 7 minutes is a poor user experience
- ❌ No feedback - user doesn't know if it's working
- ❌ Complex - requires pg_cron, pgmq, and edge function coordination
- ❌ Harder to debug - distributed across multiple systems

---

## 12. UI Placement & Settings Integration

### Onboarding Flow

**Final Surge Connection Screen:**
- **Position:** First screen in onboarding (before User Profile)
- **User Flow:** Welcome → Connect Final Surge → User Profile → Sports Selection → ...

**Sport Auto-Detection:**
- If user connects Final Surge, analyze workout history
- Rule: 2+ workouts of a sport type = active sport
- Pre-populate Sports Selection screen with detected sports
- Optional: User can skip Final Surge and manually enter sports

**Example User Flow:**
```
1. User installs app
2. Sees "Connect Your Training" screen with Final Surge option
3. Taps "Connect Final Surge" → OAuth flow
4. After OAuth success: "Importing workouts..."
5. Progress dialog: "Generating plans... 7/14"
6. Success: "Found 14 workouts, generated 14 nutrition plans"
7. Sports Selection screen pre-populated (Running ✓, Cycling ✓, Swimming ✗)
8. User confirms or adjusts sports
9. Continue with rest of onboarding
```

### Settings Integration

**New "Connected Apps" Section:**

Location: Settings → Connected Apps

**Data to Display:**
```dart
FinalSurgeConnection {
  athleteName: "John Doe"           // From Final Surge API
  athleteId: "12345"                // From athlete.id
  connectedAt: "Jan 15, 2025"      // integration.created_at
  lastSyncAt: "2 hours ago"        // integration.last_sync_at
  lastSyncStatus: "Success - 3 new workouts"  // Computed
  isActive: true                    // integration.is_active
}
```

**UI Components:**

1. **Connection Card:**
   - Final Surge logo
   - Athlete name: "John Doe"
   - Connection status badge (Active/Disconnected)
   - Last sync: "2 hours ago"
   - Last sync result: "Success - 3 new workouts"

2. **Actions:**
   - "Sync Now" button (manual refresh)
   - "Disconnect" button (with confirmation dialog)
   - Show sync history (last 5 syncs with timestamps)

3. **Coming Soon:**
   - TrainingPeaks card (greyed out, "Coming Soon" badge)
   - Strava card (greyed out, "Coming Soon" badge)

**Settings Screen Mockup:**
```
┌─────────────────────────────────────┐
│  Connected Apps                     │
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐ │
│  │ [FS Logo] Final Surge          │ │
│  │ John Doe • Active              │ │
│  │ Last sync: 2 hours ago         │ │
│  │ Success - 3 new workouts       │ │
│  │                                │ │
│  │ [Sync Now]  [Disconnect]       │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ [TP Logo] TrainingPeaks        │ │
│  │ Coming Soon                    │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ [ST Logo] Strava               │ │
│  │ Coming Soon                    │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Disconnect Dialog:**
```
┌─────────────────────────────────────┐
│  Disconnect Final Surge?            │
│                                     │
│  Your imported workouts will        │
│  remain, but automatic syncing      │
│  will stop.                         │
│                                     │
│  [Cancel]  [Disconnect]             │
└─────────────────────────────────────┘
```

### Activity Display

**Synced Workout Badge:**
- Show small "Final Surge" badge on synced activities
- Badge displays provider logo + text
- Tapping badge opens workout in Final Surge (via deep link)

**Badge Design:**
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: AppColors.electrolyte.withOpacity(0.1),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    children: [
      Icon(Icons.sync, size: 12),
      SizedBox(width: 4),
      Text('Final Surge', style: TextStyle(fontSize: 11)),
    ],
  ),
)
```

---

## 13. API Rate Limiting Strategy

### Sync Frequency
- **On app open**: Only if >6 hours since last sync (configurable: 3h, 6h, 12h, 24h)
- **Background sync**: Every 12 hours via WorkManager (on WiFi)
- **Upcoming workouts**: Increase to 3-hour sync when workout within 48 hours
- **Manual sync**: Always available with rate limit check

### ETag-Based Caching
Use HTTP 304 Not Modified responses to minimize bandwidth:
```dart
final response = await http.get(
  Uri.parse('$baseUrl/API/v1/UpcomingWorkouts'),
  headers: {
    'Authorization': 'Bearer $token',
    'If-None-Match': previousETag ?? '',
  },
);

if (response.statusCode == 304) {
  // Data unchanged - use cached version (saves ~95% bandwidth)
  return await _cache.getWorkouts();
}
```

### Client-Side Throttling
```dart
class FinalSurgeRateLimiter {
  static const maxRequestsPerMinute = 10;
  static const maxRequestsPerHour = 120;

  Future<void> checkRateLimit() async {
    // Enforce conservative rate limits
    // Final Surge doesn't publish limits, so be a good API citizen
  }
}
```

### Exponential Backoff
```dart
Duration calculateBackoff(int attempt) {
  // 2^attempt * 1 second + random jitter
  final delay = Duration(seconds: pow(2, attempt).toInt());
  final jitter = Random().nextInt(1000);
  return delay + Duration(milliseconds: jitter);
}
```

### Sync Trigger Hierarchy
1. **Manual user refresh** - Always honor immediately
2. **App foreground + threshold exceeded** - If >6 hours since last sync
3. **Background periodic** - WorkManager every 12 hours on WiFi
4. **Upcoming workout window** - 3-hour sync when workout within 48 hours
5. **Post-workout completion** - Sync 1 hour after expected end time

### Store Sync Metadata
```dart
// In Drift database
class SyncMetadata extends Table {
  TextColumn get endpoint => text()();
  DateTimeColumn get lastSyncAt => dateTime()();
  TextColumn get etag => text().nullable()();
}
```

---

## 13. Onboarding Screen Changes

### User Profile Screen
**Changes Required**: Minimal
- Add "Connected to Final Surge" badge if connected
- Pre-fill name from `athlete.firstname` + `athlete.lastname` (if we add name field)
- All biometric fields remain manual (not provided by Final Surge)

**Badge Widget**:
```dart
if (_connectedToFinalSurge) {
  Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.electrolyte.withOpacity(0.1),
      borderRadius: AppRadius.cardRadius,
    ),
    child: Row(
      children: [
        Icon(Icons.check_circle, color: AppColors.electrolyte),
        SizedBox(width: 12),
        Text('Connected to Final Surge'),
      ],
    ),
  );
}
```

### Sport Preferences Screen
**Changes Required**: Significant

1. **Auto-detect sports from workout history**
```dart
Future<void> _detectSportsFromFinalSurge() async {
  final workouts = await _finalSurgeService.fetchUpcomingWorkouts();

  final sportCounts = <String, int>{};
  for (final workout in workouts) {
    final sport = workout.workoutTypeName; // "Run", "Bike", "Swim"
    sportCounts[sport] = (sportCounts[sport] ?? 0) + 1;
  }

  // Auto-enable sports with 2+ workouts
  setState(() {
    _doesRunning = (sportCounts['Run'] ?? 0) >= 2;
    _doesCycling = (sportCounts['Bike'] ?? 0) >= 2;
    _doesSwimming = (sportCounts['Swim'] ?? 0) >= 2;
    _detectedFromFinalSurge = true;
  });
}
```

2. **Show detection badge**
```dart
if (_detectedFromFinalSurge) {
  Text('We detected your sports from Final Surge workouts',
    style: TextStyle(color: AppColors.electrolyte));
}
```

3. **Mark detected sports in UI**
- Add "Detected from Final Surge" label below pre-checked sports
- User can still modify selections

4. **FTP/CSS Estimation** (Optional for MVP)
- Can estimate from structured workout power/pace targets
- Show "Estimate from Final Surge Workouts?" button

### Food Preferences Screen
**Changes Required**: None
- Final Surge doesn't provide food/nutrition data
- Keep screen as-is

### Edge Cases
| Scenario | Handling |
|----------|----------|
| No workout history | Show message, proceed with manual entry |
| Only one sport detected | Pre-check that sport, show others unchecked |
| Stale data (>7 days) | Prompt to sync before using |
| OAuth failed | Show error, retry button, allow skip |

---

## 14. Multi-Integration Architecture

### Integrations Table Design
Designed to support Final Surge, TrainingPeaks, Strava, and future integrations:

```sql
CREATE TABLE integrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL CHECK (provider IN ('final_surge', 'training_peaks', 'strava', 'garmin')),

  -- OAuth tokens
  access_token TEXT NOT NULL,
  refresh_token TEXT,
  token_expires_at TIMESTAMPTZ,

  -- Provider data
  provider_athlete_id TEXT NOT NULL,
  provider_athlete_name TEXT,

  -- Sync metadata
  is_active BOOLEAN DEFAULT true,
  last_sync_at TIMESTAMPTZ,
  last_sync_status TEXT,

  UNIQUE(user_id, provider)
);
```

### Activity Tracking Columns
Add to existing `activities` table:
```sql
ALTER TABLE activities ADD COLUMN synced_from_provider TEXT;           -- 'final_surge', 'training_peaks', etc.
ALTER TABLE activities ADD COLUMN provider_workout_id TEXT;            -- UUID extracted from WorkoutURL
ALTER TABLE activities ADD COLUMN provider_workout_url TEXT;           -- Full URL for deep linking
ALTER TABLE activities ADD COLUMN provider_content_hash TEXT;          -- SHA256 hash for change detection
ALTER TABLE activities ADD COLUMN structured_workout_url TEXT;         -- json_fs_v1 URL if available
ALTER TABLE activities ADD COLUMN last_synced_at TIMESTAMPTZ;          -- When last checked
```

### Change Detection Strategy

**CRITICAL**: Final Surge API does NOT provide modification timestamps. We must use hash-based change detection.

**Fields to extract `provider_workout_id` from:**
```dart
String extractWorkoutId(String? workoutUrl) {
  // WorkoutURL format: https://log.finalsurge.com/WorkoutDetails?s=...&id=<workout-id>
  if (workoutUrl == null) return '';
  final uri = Uri.parse(workoutUrl);
  return uri.queryParameters['id'] ?? '';
}
```

**Content hash generation (for detecting changes):**
```dart
String generateWorkoutHash(FinalSurgeWorkout workout) {
  final canonicalString = [
    workout.workoutDate,
    workout.workoutTime,
    workout.workoutTitle,
    workout.workoutDescription,
    workout.plannedTime?.toString(),
    workout.plannedDistance?.toString(),
    workout.plannedPace,
    workout.structuredWorkoutUrls?.json_fs_v1,
  ].where((field) => field != null).join('|');

  return sha256.convert(utf8.encode(canonicalString)).toString();
}
```

**Sync logic:**
```dart
if (localWorkout == null) {
  // New workout → Insert + generate nutrition plan
} else if (localWorkout.contentHash != newContentHash) {
  // Workout changed → Update + regenerate nutrition plan
} else {
  // No changes → Skip
}
```

**Deletion detection:**
- Final Surge doesn't notify of deleted workouts
- On each sync, compare local synced workouts with API response
- If a local workout's `provider_workout_id` is not in API response → Mark as deleted

### "Coming Soon" UI for TrainingPeaks/Strava
```dart
Widget _buildIntegrationCard({
  required String name,
  required bool isActive,
  required bool isComingSoon,
}) {
  return Card(
    child: ListTile(
      leading: Image.asset('assets/images/$name_logo.png'),
      title: Text(name),
      subtitle: isComingSoon
        ? Text('Coming Soon', style: TextStyle(color: Colors.grey))
        : null,
      trailing: isActive
        ? ElevatedButton(onPressed: _connect, child: Text('Connect'))
        : TextButton(onPressed: null, child: Text('Coming Soon')),
      enabled: !isComingSoon,
    ),
  );
}
```

---

## 15. Integration Tests Required

### Edge Function Tests (sync-final-surge)
Create tests in `supabase/functions/sync-final-surge/index.test.ts`:

1. **OAuth token exchange**
   - Valid code → returns access token + athlete info
   - Invalid code → returns error

2. **Workout fetching**
   - Valid token → returns workouts array
   - Expired token → returns 401 error
   - Empty calendar → returns empty array

3. **Multi-sport filtering**
   - Running workouts → sport_type: 'running'
   - Cycling workouts → sport_type: 'cycling'
   - Swimming workouts → sport_type: 'swimming'
   - Mixed sports → all included

4. **Error handling**
   - Network timeout → graceful error
   - Invalid response → parse error
   - Rate limit → backoff response

### Flutter Integration Tests
- OAuth flow end-to-end
- Sync button triggers refresh
- Synced activities show badge
- Settings disconnect works

---

---

## 16. Data Mapping & Schema Decisions

**Last Updated**: December 17, 2025

### Overview
This section documents the critical data transformation decisions for mapping Final Surge API data to Mealvana's database schema.

---

### Unit Conversions (CONFIRMED)

| Data Type | Final Surge Format | Mealvana Storage | Conversion Logic |
|-----------|-------------------|------------------|------------------|
| **Distance** | `PlannedDistance` + `PlannedDistanceType` ("mi" or "km") | Always store in **miles** | If `PlannedDistanceType == "km"`: `miles = km * 0.621371` |
| **Duration** | `PlannedTime` (seconds) | Store in **minutes** | `minutes = seconds / 60` |
| **Pace** | `PlannedPace` + `PlannedPaceType` (e.g., "5:40-5:55 min/mi") | Store **midpoint** in `pace_target` | Parse range, calculate midpoint: `(5:40 + 5:55) / 2 = 5:47.5 min/mile` |
| **Cycling Speed** | `PlannedDistance` ÷ `PlannedTime` | Calculate speed in **mph** or **kph** | `speed = distance / (time / 3600)` |
| **Swimming Pace** | `PlannedDistance` ÷ `PlannedTime` | Calculate **seconds per 100m** | `pace_per_100m = (time / distance) * 100` |

**Implementation Notes:**
- Always convert to miles for consistency (US market focus)
- Store duration in minutes (more human-readable than seconds)
- For pace ranges, store midpoint as primary value
- Optional: Add `pace_min` and `pace_max` columns if range precision needed

---

### Intensity Mapping (CONFIRMED)

**Mealvana 4-Level Enum:** `easy`, `moderate`, `hard`, `race`

**Mapping Strategy:**

```dart
String mapIntensity(FinalSurgeWorkout workout) {
  final subType = workout.workoutSubTypeName?.toLowerCase() ?? '';

  // Race intensity
  if (subType.contains('race') || subType.contains('event')) {
    return 'race';
  }

  // Hard intensity
  if (subType.contains('tempo') ||
      subType.contains('threshold') ||
      subType.contains('interval') ||
      subType.contains('speed')) {
    return 'hard';
  }

  // Moderate intensity
  if (subType.contains('steady') ||
      subType.contains('aerobic') ||
      subType.contains('marathon pace')) {
    return 'moderate';
  }

  // Easy intensity (default)
  return 'easy'; // Recovery, Long Run (easy pace), Base
}
```

**Keyword Mapping Table:**

| Final Surge `WorkoutSubTypeName` | Mealvana Intensity |
|----------------------------------|-------------------|
| "Race", "Event", "Marathon", "Half Marathon" | `race` |
| "Tempo Run", "Threshold", "Intervals", "Speed Work" | `hard` |
| "Steady State", "Aerobic", "Marathon Pace" | `moderate` |
| "Recovery", "Long Run", "Base", "Easy" | `easy` |

**Edge Cases:**
- Missing `WorkoutSubTypeName` → Default to `easy`
- Walk workouts → Import as `running` with `easy` intensity
- Cross Training / Strength → Skip import (not supported sports)

---

### Sport Type Mapping (CONFIRMED)

**Final Surge → Mealvana:**

```dart
String? mapSportType(int workoutIcon) {
  switch (workoutIcon) {
    case 1: return 'running';   // Run
    case 2: return 'cycling';   // Bike
    case 3: return 'swimming';  // Swim
    default: return null;       // Unsupported (skip import)
  }
}
```

**Supported Sports:**
- ✅ Running (WorkoutIcon: 1)
- ✅ Cycling (WorkoutIcon: 2)
- ✅ Swimming (WorkoutIcon: 3)

**Unsupported Sports (Skip Import):**
- ❌ Cross Training (4)
- ❌ Strength Training (5)
- ❌ Rest Day (6)
- ❌ Recovery (7)
- ❌ Other (8)
- ❌ Transition (9)
- ❌ Custom (10)
- ❌ Walk (11) → **DECISION PENDING**: Import as running with easy intensity?

---

### External Workout ID Extraction (CONFIRMED)

**WorkoutURL Format:**
```
https://log.finalsurge.com/WorkoutDetails?s=<WORKOUT_ID>&id=<SECONDARY_ID>
```

**Extraction Logic:**
```dart
String extractWorkoutId(String? workoutUrl) {
  if (workoutUrl == null || workoutUrl.isEmpty) {
    return ''; // Handle missing URLs gracefully
  }

  final uri = Uri.parse(workoutUrl);

  // Primary: Extract 's' parameter (most reliable)
  final workoutId = uri.queryParameters['s'];
  if (workoutId != null && workoutId.isNotEmpty) {
    return workoutId;
  }

  // Fallback: Extract 'id' parameter
  final secondaryId = uri.queryParameters['id'];
  return secondaryId ?? '';
}
```

**Storage:**
- Store in `activities.provider_workout_id`
- Use for deduplication checks
- Use for deep linking back to Final Surge

---

### Completed Workouts Sync (CONFIRMED)

**DECISION:** YES, import completed workouts.

**Rationale:**
- Users may have completed workouts scheduled in next 14 days
- We can still generate nutrition plans for completed workouts (historical analysis)
- Helps with training load tracking

**Implementation:**
```dart
// Don't filter by WorkoutCompleted status
final supportedWorkouts = workouts.where((w) =>
  ['Run', 'Bike', 'Swim'].contains(w.workoutTypeName)
  // WorkoutCompleted can be true or false
).toList();
```

**UI Display:**
- Show completed badge: "✓ Completed" on activity card
- Generate nutrition plan anyway (for review/analysis)
- Don't send reminders for completed workouts

---

### Schema Changes Required

#### 1. Add Sync Tracking Columns (REQUIRED)

```sql
ALTER TABLE activities
  ADD COLUMN synced_from_provider TEXT,           -- 'final_surge', 'training_peaks', etc.
  ADD COLUMN provider_workout_id TEXT,            -- Extracted from WorkoutURL 's' parameter
  ADD COLUMN provider_workout_url TEXT,           -- Full URL for deep linking
  ADD COLUMN last_synced_at TIMESTAMPTZ;          -- When last checked/updated

-- Index for fast lookups
CREATE INDEX idx_activities_provider_workout
  ON activities(provider_workout_id, synced_from_provider);
```

**Why These Columns:**
- `synced_from_provider`: Track which integration imported this workout
- `provider_workout_id`: Unique identifier for deduplication
- `provider_workout_url`: Deep link back to Final Surge workout
- `last_synced_at`: Track when last synchronized (for change detection)

#### 2. Add Pace Range Columns (PENDING DECISION)

**Option A: Store midpoint only (CURRENT)**
```sql
-- Use existing pace_target column
-- Calculate midpoint from "5:40-5:55" → store as "5:47.5"
```

**Option B: Store full range**
```sql
ALTER TABLE activities
  ADD COLUMN pace_min_minutes_per_mile REAL,
  ADD COLUMN pace_max_minutes_per_mile REAL;

-- Store "5:40-5:55" as:
--   pace_min_minutes_per_mile: 5.67 (5 minutes 40 seconds)
--   pace_max_minutes_per_mile: 5.92 (5 minutes 55 seconds)
```

**DECISION NEEDED:** Does Mealvana need pace range precision, or is midpoint sufficient?

#### 3. Add Workout Subtype Field (PENDING DECISION)

```sql
ALTER TABLE activities
  ADD COLUMN workout_subtype TEXT; -- Store "Tempo Run", "Long Run", etc.
```

**Why:**
- Preserve Final Surge's granular workout classification
- Can use for more intelligent intensity mapping in future
- Helps with training plan analysis

**DECISION NEEDED:** Is this worth storing, or is intensity enum sufficient?

---

### Sync Strategy (CONFIRMED)

#### Sync Triggers

| Trigger | Frequency | Conditions |
|---------|-----------|------------|
| **Initial import** | Once | OAuth connection (import 14 days) |
| **App startup** | Every open | Max once per 6 hours (check `last_synced_at`) |
| **Manual refresh** | Unlimited | Settings → Connected Apps → Sync Now |
| **Pull-to-refresh** | Unlimited | Calendar screen |
| **Background** | Once per 12 hours | iOS/Android background refresh (WiFi only) |

#### Sync Behavior

```dart
Future<SyncResult> syncWorkouts(String userId) async {
  // 1. Fetch 14 days upcoming + completed workouts
  final workouts = await _apiClient.getUpcomingWorkouts(
    token,
    numDays: 7,
    numWorkouts: 21,
  );

  // 2. Filter to Run/Bike/Swim only
  final supported = workouts.where((w) =>
    [1, 2, 3].contains(w.workoutIcon)
  ).toList();

  // 3. Check existing by provider_workout_id
  final newWorkouts = <Activity>[];
  for (final workout in supported) {
    final workoutId = extractWorkoutId(workout.workoutUrl);

    final existing = await _repository.findByProviderWorkoutId(
      'final_surge',
      workoutId,
    );

    if (existing != null) {
      // Skip existing workouts (preserve user customizations)
      continue;
    }

    // Import new workout
    final activity = _mapToActivity(workout, userId);
    await _repository.insert(activity);
    newWorkouts.add(activity);
  }

  // 4. Queue nutrition plan generation for new imports
  await _generateNutritionPlansInParallel(newWorkouts);

  return SyncResult(newWorkouts: newWorkouts.length);
}
```

**Key Decisions:**
- ✅ Skip existing workouts (don't overwrite user changes)
- ✅ Import completed workouts (for historical analysis)
- ✅ Generate nutrition plans for all new imports
- ✅ Process in chunks (5 concurrent API calls)

---

### Open Questions & Risks

#### 1. Range Columns
**Question:** Add `pace_min/max`, `distance_min/max`, or just store midpoint?

**Considerations:**
- **Midpoint only:** Simpler schema, less storage
- **Full range:** More precision, better for training zones

**Recommendation:** Start with midpoint, add range columns if users request it.

---

#### 2. Workout Subtype Field
**Question:** Add `workout_subtype` column to preserve Final Surge's granular classification?

**Considerations:**
- **Yes:** Better training plan analysis, future-proof
- **No:** Intensity enum may be sufficient

**Recommendation:** Add field (low cost, high future value).

---

#### 3. Swimming Distance Units
**Question:** Store swimming distance in meters or miles?

**Considerations:**
- Final Surge uses meters for swimming
- US market uses yards (1 yard ≈ 0.9144 meters)
- Mealvana currently stores everything in miles

**Recommendation:** Convert to miles for consistency (with precision warning for users).

---

#### 4. Update Behavior
**Question:** What happens when a synced workout changes in Final Surge?

**Options:**
- **A. Skip** - Preserve user customizations (CURRENT)
- **B. Update** - Overwrite with Final Surge data (lose user changes)
- **C. Notify** - Show "Workout updated in Final Surge" banner with option to sync

**Recommendation:** Start with **Option A** (skip), add **Option C** (notify) in Phase 2.

---

#### 5. Delete Behavior
**Question:** Auto-delete activities if removed from Final Surge?

**Options:**
- **A. Auto-delete** - Keep perfect sync with Final Surge
- **B. Mark deleted** - Soft delete with `deleted_at` timestamp
- **C. Keep orphaned** - Leave activities, remove sync link

**Recommendation:** **Option B** (soft delete) - Archive with banner "Workout deleted in Final Surge".

---

#### 6. Walk Workouts
**Question:** Import walk workouts (WorkoutIcon: 11)?

**Options:**
- **A. Skip** - Only Run/Bike/Swim (CURRENT)
- **B. Import as running** - Treat as easy run with walking pace
- **C. New sport type** - Add "walking" sport (major schema change)

**Recommendation:** Start with **Option A** (skip), consider **Option B** if users request it.

---

#### 7. Missing Data
**Question:** What if `PlannedDistance` or `PlannedTime` is null?

**Options:**
- **A. Skip import** - Only import complete workouts
- **B. Import anyway** - Allow partial data (show "No distance planned")
- **C. Estimate** - Parse from `WorkoutDescription` or structured workout

**Recommendation:** **Option B** (import anyway) - Users may add details later in Mealvana.

---

## Changelog

### 2025-12-17 (Update 2)
- **NEW SECTION:** Added Section 16: Data Mapping & Schema Decisions
- Documented all unit conversion rules (distance, duration, pace, speed)
- Defined intensity mapping from WorkoutSubTypeName
- Confirmed sport type mapping (Run/Bike/Swim only)
- Specified external workout ID extraction from URL query parameter
- Documented sync strategy and behavior
- Added 7 open questions for future decisions
- Captured schema changes required (4 confirmed columns, 2 pending columns)

### 2025-12-17
- **MAJOR DECISION:** Switched from pg_cron + pgmq background processing to chunked parallel generation
- Updated Section 11: Nutrition Plan Generation Strategy with new approach
- Added Section 12: UI Placement & Settings Integration with detailed mockups
- Updated User Decisions table to reflect chunked parallel generation
- Added performance comparison: 15-20 seconds vs 7 minutes
- Documented Settings screen data structure and UI components
- Added activity badge design specifications

### 2025-12-05 (Update 2)
- Added Section 0: User Decisions (finalized all choices)
- Added Section 11: Supabase Background Processing (pg_cron + pgmq) [DEPRECATED - See 2025-12-17]
- Added Section 12: API Rate Limiting Strategy
- Added Section 13: Onboarding Screen Changes
- Added Section 14: Multi-Integration Architecture
- Added Section 15: Integration Tests Required
- Verified production schema has all multi-sport columns
- Identified sync-final-surge edge function needs multi-sport update

### 2025-12-05
- Initial comprehensive notes document created
- Consolidated all research findings
- Analyzed API capabilities and test script
- Designed database schema and architecture
- Planned onboarding integration
- Created phased implementation roadmap

---

*This is a living document. Update as new information is discovered or decisions are made.*
