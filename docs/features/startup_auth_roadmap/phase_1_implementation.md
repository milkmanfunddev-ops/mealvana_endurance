# Phase 1 Implementation: Supabase Anonymous Authentication

**Status:** ✅ Complete (2025-11-18)

**Summary:** Replaced device-based authentication with Supabase Anonymous Auth. All new users now get a Supabase UUID as their canonical identifier, with device_id kept only for backwards compatibility and analytics.

---

## Critical Architectural Decisions

### 🎯 **Supabase UUID is the Canonical User Identifier**

**THIS IS THE MOST IMPORTANT RULE FOR ALL FUTURE DEVELOPMENT:**

| Field | Purpose | Usage |
|-------|---------|-------|
| **`id`** (UserProfile) | **CANONICAL USER ID** | ✅ Use everywhere - foreign keys, queries, RLS policies |
| **`auth_user_id`** (Database) | Supabase auth.users.id | ✅ Same as `id`, stores the Supabase UUID |
| **`device_id`** (UserProfile) | Legacy metadata | ❌ **NEVER** use for queries, joins, or user identification |

**Code Examples:**

```dart
// ✅ CORRECT - Use Supabase UUID
final userId = _supabase.auth.currentUser!.id;
await _database.getActivitiesForUser(userId);

// ❌ WRONG - Don't use device_id for user identification
final deviceId = await _getDeviceId();
await _database.getActivitiesForUser(deviceId); // NO!
```

**Why device_id is kept:**
- Backwards compatibility during transition
- Analytics correlation (link old events to new users)
- Debugging (easier to identify specific physical devices)

**Why device_id should NOT be used:**
- Not guaranteed to be unique (Android ID can be empty)
- Not stable across app reinstalls (iOS identifierForVendor)
- Not compatible with Supabase Auth architecture
- Not usable for Row Level Security policies

---

## What Was Implemented

### 1. App Startup Integration

**File:** `lib/features/app_startup/application/app_startup_service.dart`

**New Method:** `initializeSupabaseAuth()`

```dart
/// Initialize Supabase Anonymous Authentication
/// Creates or restores an anonymous auth session for the user
/// This is the foundation for all Supabase Auth-based operations
Future<void> initializeSupabaseAuth() async {
  // Check if we already have a session (SDK auto-restores from secure storage)
  final existingSession = _supabase.auth.currentSession;

  if (existingSession != null) {
    // Session restored from iOS Keychain / Android KeyStore
    _logger.info('✅ Existing Supabase session restored');
    return;
  }

  // No existing session - create anonymous user
  final response = await _supabase.auth.signInAnonymously();

  // User now has a Supabase UUID as their canonical ID
  _logger.info('✅ Anonymous Supabase user created successfully');
}
```

**Key Features:**
- ✅ Runs during app startup (before user sees any UI)
- ✅ Auto-restores sessions from secure storage
- ✅ Creates anonymous user if no session exists
- ✅ Tracks analytics: `auth_session_restored`, `anonymous_auth_created`
- ✅ Handles errors gracefully with retry capability

### 2. Updated App Startup Sequence

**File:** `lib/features/app_startup/application/app_startup_provider.dart`

**Before:**
```dart
1. Initialize database
2. Initialize analytics
3. Set Sentry context
4. Check user session
```

**After:**
```dart
1. Initialize database
2. Initialize Supabase Anonymous Auth  ⬅️ NEW (Step 2)
3. Initialize analytics (parallel)
4. Set Sentry context (parallel)
5. Check user session (parallel)
```

**Why Step 2:** Ensures every user has a Supabase auth session before any other operations that might need user identity.

### 3. User Creation Rewrite

**File:** `lib/features/auth/application/auth_service.dart`

**Before (Device-Based):**
```dart
Future<UserProfile> createUser(...) async {
  // Get device ID
  final deviceId = await _getDeviceId();

  // Call Edge Function to create user
  final result = await _authRepositoryEdge.createUser(
    deviceId: deviceId,
    ...
  );

  // User ID = device_id
  return result.user!;
}
```

**After (Supabase Auth-Based):**
```dart
Future<UserProfile> createUser(...) async {
  // Get Supabase auth session (created during app startup)
  final authUser = _supabase.auth.currentUser!;

  // Create UserProfile with Supabase UUID as canonical ID
  final userProfile = UserProfile(
    id: authUser.id,              // ⬅️ CANONICAL ID (Supabase UUID)
    deviceId: deviceId,            // ⬅️ METADATA ONLY
    authUserId: authUser.id,       // ⬅️ Links to auth.users.id
    authProvider: 'anonymous',     // ⬅️ Auth method
    isAnonymous: true,             // ⬅️ Until linked to email/social
    ...
  );

  // Save to Supabase directly (no Edge Function)
  await _supabase.from('users').upsert(userProfile.toJson());

  // Save locally for caching
  await userRepo.saveUserProfile(userProfile);

  return userProfile;
}
```

**Key Changes:**
- ✅ **Removed**: Edge Function dependency (`create-user`)
- ✅ **Removed**: Device-based user creation
- ✅ **Added**: Direct Supabase insert via `.from('users').upsert()`
- ✅ **Changed**: User ID = Supabase UUID (not device_id)
- ✅ **Kept**: device_id for backwards compatibility

---

## Database Schema

### Users Table

```sql
CREATE TABLE users (
  -- PRIMARY KEY (Canonical User ID)
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Auth fields (Phase 0/1)
  auth_user_id UUID,              -- Links to auth.users.id (same as id)
  auth_provider TEXT DEFAULT 'anonymous',
  is_anonymous BOOLEAN DEFAULT true,

  -- Legacy field (backwards compatibility only)
  device_id TEXT,                 -- DO NOT USE FOR QUERIES

  -- User data
  gender TEXT NOT NULL,
  birthday TIMESTAMPTZ NOT NULL,
  ...
);

-- Index for auth integration
CREATE INDEX idx_users_auth_user_id ON users(auth_user_id);
```

**Field Usage:**
- **`id`**: Use for all foreign keys, queries, RLS policies
- **`auth_user_id`**: Same value as `id`, links to Supabase Auth
- **`device_id`**: Analytics and debugging only
- **`auth_provider`**: Tracks authentication method ('anonymous', 'google', 'apple', 'email')
- **`is_anonymous`**: True until user links to email/social account

---

## Data Flow

### Fresh Install (New User)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. App Startup                                              │
│    ├─ Database initialized                                  │
│    └─ initializeSupabaseAuth() called                       │
│       └─ supabase.auth.signInAnonymously()                  │
│          ├─ Creates auth.users record (UUID generated)      │
│          ├─ Session stored in Keychain/KeyStore             │
│          └─ Returns: auth.currentUser.id = UUID             │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. User Completes Onboarding                                │
│    └─ AuthService.createUser() called                       │
│       ├─ Gets auth.currentUser.id (Supabase UUID)           │
│       ├─ Creates UserProfile(id: UUID, device_id: metadata) │
│       ├─ Saves to Supabase: users table                     │
│       └─ Saves to Drift: user_profiles table                │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. User Identity Established                                │
│    ├─ Canonical ID: Supabase UUID (e.g., a1b2c3d4-...)      │
│    ├─ Auth Provider: 'anonymous'                            │
│    ├─ Is Anonymous: true                                    │
│    └─ Device ID: Stored as metadata                         │
└─────────────────────────────────────────────────────────────┘
```

### App Restart (Existing User)

```
┌─────────────────────────────────────────────────────────────┐
│ App Startup                                                 │
│ ├─ Database initialized                                     │
│ └─ initializeSupabaseAuth() called                          │
│    └─ Supabase SDK auto-restores session from storage       │
│       ├─ iOS: Keychain                                      │
│       ├─ Android: KeyStore                                  │
│       └─ Returns: Same UUID as before                       │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ User Identity Restored                                      │
│ ├─ Same Canonical ID: Supabase UUID                         │
│ ├─ Same Auth Session (auto-refreshed by SDK)                │
│ └─ No user migration needed                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Code Guidelines for Future Development

### ✅ DO

```dart
// Get current user ID
final userId = _supabase.auth.currentUser!.id;

// Query by user ID
final activities = await _database.getActivitiesForUser(userId);

// Save data with user ID
await _database.saveActivity(
  userId: userId,
  activityData: data,
);

// RLS policies use auth.uid()
CREATE POLICY "Users can only see their own data"
  ON activities FOR SELECT
  USING (auth.uid() = user_id);
```

### ❌ DON'T

```dart
// ❌ Don't use device_id for user identification
final deviceId = await _getDeviceId();
final activities = await _database.getActivitiesForUser(deviceId);

// ❌ Don't query by device_id
final user = await _supabase
  .from('users')
  .select()
  .eq('device_id', deviceId)  // NO!
  .single();

// ❌ Don't use device_id in RLS policies
CREATE POLICY "Users can only see their own data"
  ON activities FOR SELECT
  USING (device_id = current_setting('app.device_id'));  // NO!
```

### ✅ Only Acceptable Uses of device_id

```dart
// ✅ Analytics correlation
await _analytics.track('event_name', properties: {
  'user_id': userId,           // Canonical ID
  'device_id': deviceId,       // For analytics correlation
});

// ✅ Debugging logs
_logger.info('User action', data: {
  'user_id': userId,           // Canonical ID
  'device_id': deviceId,       // Helps identify physical device
});

// ✅ Storing as metadata (not for queries)
final userProfile = UserProfile(
  id: userId,                  // Canonical ID
  deviceId: deviceId,          // Metadata only
);
```

---

## Testing Verification

### Fresh Install Test

```dart
testWidgets('Fresh install creates anonymous Supabase user', (tester) async {
  // 1. Clear all data
  await clearDatabase();

  // 2. Start app
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();

  // 3. Verify Supabase session exists
  final session = Supabase.instance.client.auth.currentSession;
  expect(session, isNotNull);
  expect(session!.user.id.length, equals(36)); // UUID format

  // 4. Complete onboarding
  await completeOnboarding(tester);

  // 5. Verify user created with Supabase UUID
  final user = await database.getCurrentUserProfile();
  expect(user, isNotNull);
  expect(user!.id, equals(session.user.id)); // Same UUID
  expect(user.authUserId, equals(session.user.id));
  expect(user.authProvider, equals('anonymous'));
  expect(user.isAnonymous, isTrue);
});
```

### Session Restoration Test

```dart
testWidgets('App restart restores Supabase session', (tester) async {
  // 1. Create user and get UUID
  await completeOnboarding(tester);
  final originalUserId = Supabase.instance.client.auth.currentUser!.id;

  // 2. Restart app
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();

  // 3. Verify same UUID restored
  final restoredUserId = Supabase.instance.client.auth.currentUser!.id;
  expect(restoredUserId, equals(originalUserId));
});
```

---

## Migration Notes

### No Migration Needed for Fresh Users

Since you're starting with Phase 1 from the beginning (no existing users with device_id-based accounts), **no migration logic is needed**.

All users will:
1. Get a Supabase UUID from day one
2. Have `id = auth_user_id = Supabase UUID`
3. Have `device_id` as metadata only

### If You Had Existing Users (Not Applicable)

If you had existing users with device_id-based accounts, you would need:
- Migration service to convert device_id → Supabase UUID
- Temporary dual-ID support during transition
- RLS policy updates

**Since you're starting fresh, skip all migration code.**

---

## Files Modified

| File | Changes |
|------|---------|
| `lib/features/app_startup/application/app_startup_service.dart` | Added `initializeSupabaseAuth()` method |
| `lib/features/app_startup/application/app_startup_provider.dart` | Integrated auth initialization into startup sequence |
| `lib/features/auth/application/auth_service.dart` | Completely rewrote `createUser()` to use Supabase Auth |

**Files NOT Modified (No Migration Needed):**
- ❌ No migration service created
- ❌ No legacy device_id query support
- ❌ No dual-ID transition logic

---

## Analytics Events

### New Events Tracked

| Event | When | Properties |
|-------|------|------------|
| `auth_session_restored` | App startup (existing user) | `user_id`, `timestamp` |
| `anonymous_auth_created` | App startup (new user) | `user_id`, `timestamp` |

**Usage in Mixpanel:**
```javascript
// Query: How many new users created this week?
mixpanel.query({
  event: 'anonymous_auth_created',
  date_range: 'last 7 days',
  group_by: 'day'
});

// Query: How many returning users (session restored)?
mixpanel.query({
  event: 'auth_session_restored',
  date_range: 'last 7 days',
  group_by: 'day'
});
```

---

## Next Steps

### Phase 2: Account Linking UI

Now that anonymous auth is working, you can add:
- Google Sign-In
- Apple Sign-In
- Email/Password signup
- Account linking via `supabase.auth.linkIdentity()`

**Important:** When linking accounts, the **same Supabase UUID persists**:
```dart
// Before linking: anonymous user with UUID abc-123
final beforeId = _supabase.auth.currentUser!.id; // abc-123

// Link to Google account
await _supabase.auth.linkIdentity(GoogleAuthProvider());

// After linking: same UUID, different provider
final afterId = _supabase.auth.currentUser!.id; // abc-123 (same!)
final provider = _supabase.auth.currentUser!.appMetadata['provider']; // 'google'
```

---

## Summary: The Golden Rule

**🎯 For all future development:**

| Question | Answer |
|----------|--------|
| What is the user's ID? | `_supabase.auth.currentUser!.id` |
| Where do I store it? | `UserProfile.id`, `users.id`, `auth_user_id` |
| When do I use device_id? | Analytics and debugging ONLY |
| Can I query by device_id? | ❌ **NO** - Always use Supabase UUID |

**If you see code using device_id for user identification, it's probably wrong.**

---

**Phase 1 Status:** ✅ **COMPLETE**

**Next Phase:** Phase 2 - Account Linking UI (Google, Apple, Email)
