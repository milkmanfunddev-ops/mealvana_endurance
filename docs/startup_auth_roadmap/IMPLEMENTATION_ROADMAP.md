# Supabase Authentication Implementation Roadmap

**Last Updated:** 2025-11-17
**Status:** Planning Phase
**Estimated Duration:** 6-8 weeks
**Risk Level:** Medium-High (Offline session management critical)

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Critical Issues & Mitigations](#critical-issues--mitigations)
4. [Detailed Implementation Phases](#detailed-implementation-phases)
5. [Technical Implementation Details](#technical-implementation-details)
6. [Testing Strategy](#testing-strategy)
7. [Deployment & Rollout](#deployment--rollout)
8. [Success Metrics](#success-metrics)

---

## Executive Summary

### Goals (Aligned with startup_auth_roadmap/README.md)

1. ✅ **Stabilize Onboarding**: Remove device_id/Drift UUID conflicts
2. ✅ **Adopt Supabase UUIDs**: Use auth.uid() as canonical identifier
3. ✅ **Environment Routing**: Debug builds → dev telemetry automatically
4. ✅ **Post-Onboarding Auth**: Supabase Auth with "Skip for now" option
5. ✅ **Improve Observability**: Sentry + Mixpanel breadcrumbs throughout
6. ✅ **Offline-First Support**: Custom session persistence (critical requirement)
7. ✅ **Multi-Device Sync**: Enable via Google/Apple/Email authentication
8. ✅ **Enhanced Security**: Proper JWT-based RLS policies

### Authentication Strategy

**Hybrid Approach:**
- **Default**: Supabase Anonymous Auth (replaces device_id)
- **Optional**: Link to Google/Apple/Email accounts (post-onboarding)
- **Offline**: Custom Drift-based session persistence (24-hour grace period)
- **Migration**: Seamless upgrade from device_id to auth.uid()

### Key Technical Decisions

| Decision | Rationale |
|----------|-----------|
| **Supabase Anonymous Auth** | Provides proper JWT tokens, no PII required, upgradeable to full auth |
| **Custom Session Persistence** | Mitigates Supabase offline bug (GitHub issue #716) - CRITICAL |
| **Keep device_id column** | Historical reference, migration safety, fallback identifier |
| **auth.uid() as primary key** | Enables proper RLS, cross-device sync, Supabase-native features |
| **Post-onboarding auth screen** | Reduces friction, maintains zero-signup onboarding flow |
| **Apple + Google Sign-In** | App Store compliance, maximum user coverage |

---

## Architecture Overview

### Current State (Device-Based)
```
User Launch
    ↓
Get/Create Device ID (iOS: identifierForVendor, Android: Android ID)
    ↓
Onboarding Flow (user inputs biometrics, preferences)
    ↓
Create User (AuthService.createUser)
    ↓
PROBLEM: Saves device_id into user_profiles.id (expects UUID, gets short string)
    ↓
Drift Validation Fails (36-char UUID constraint)
    ↓
UI Stuck on "Saving…" (Android users)
```

### Target State (Supabase Auth)
```
User Launch
    ↓
Check Local Session (Drift DB - offline support)
    ↓
    ├─ Session Found → Restore (offline grace period: 24 hours)
    │   ↓
    │   Try Refresh if Online
    │   ↓
    │   Continue to App
    │
    └─ No Session → Create Anonymous User (Supabase Auth)
        ↓
        Store Session in Drift DB (CRITICAL for offline)
        ↓
        Onboarding Flow
        ↓
        Save Profile (user_profiles.id = auth.uid(), device_id preserved)
        ↓
        [OPTIONAL] Authentication Screen
        ↓
        ├─ Skip → Continue with anonymous auth
        │   ↓
        │   Settings: "Create Account" reminder badge
        │
        └─ Link Account → Google/Apple/Email
            ↓
            Preserve same auth.uid() (data persists)
            ↓
            Enable Cross-Device Sync
```

### Database Schema Changes

**users table (Supabase):**
```sql
-- BEFORE (Current)
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id TEXT UNIQUE NOT NULL,  -- Short Android IDs cause issues
  gender TEXT,
  birthday DATE,
  -- ... other fields
);

-- AFTER (Target)
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),  -- Supabase auth.uid()
  device_id TEXT,  -- Kept for historical reference, NOT unique
  auth_provider TEXT,  -- 'anonymous', 'google', 'apple', 'email'
  gender TEXT,
  birthday DATE,
  -- ... other fields

  CONSTRAINT users_id_is_auth_uid CHECK (id = auth.uid())  -- Enforce match
);
```

**user_profiles table (Drift):**
```dart
// BEFORE (Current)
@DataClassName('UserProfile')
class UserProfiles extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();  // UUID string
  TextColumn get deviceId => text()();  // Problematic
  // ...
}

// AFTER (Target)
@DataClassName('UserProfile')
class UserProfiles extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();  // Supabase auth.uid()
  TextColumn get deviceId => text().nullable()();  // Optional, for migration
  TextColumn get authProvider => text().nullable()();  // 'anonymous', 'google', etc.
  BoolColumn get isAnonymous => boolean().withDefault(const Constant(true))();
  DateTimeColumn get authCreatedAt => dateTime().nullable()();
  // ...
}
```

**New: auth_sessions table (Drift - Offline Support):**
```dart
@DataClassName('AuthSessionData')
class AuthSessions extends Table {
  TextColumn get userId => text()();  // auth.uid()
  TextColumn get accessToken => text()();
  TextColumn get refreshToken => text()();
  DateTimeColumn get expiresAt => dateTime()();
  TextColumn get userMetadata => text().map(const JsonConverter()).nullable()();
  DateTimeColumn get lastSyncedAt => dateTime()();
  BoolColumn get isAnonymous => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {userId};
}
```

---

## Critical Issues & Mitigations

### 🚨 CRITICAL: Supabase Auth Offline Bug

**Issue:** Supabase Auth clears sessions on any network error (GitHub #716)

**Impact:**
- User goes offline → Session lost → Can't access app
- UNACCEPTABLE for runners in remote areas
- App becomes unusable during runs (primary use case)

**Mitigation (MANDATORY):**

```dart
// lib/features/auth/data/session_repository.dart

class SessionRepository {
  final AppDatabase _db;
  final SupabaseClient _supabase;

  /// Store session in Drift DB after EVERY auth event
  Future<void> persistSession(Session session) async {
    await _db.into(_db.authSessions).insertOnConflictUpdate(
      AuthSessionsCompanion.insert(
        userId: session.user.id,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken!,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          session.expiresAt! * 1000,
        ),
        userMetadata: Value(session.user.userMetadata),
        lastSyncedAt: DateTime.now(),
        isAnonymous: Value(session.user.isAnonymous ?? false),
      ),
    );
  }

  /// Restore session with 24-hour offline grace period
  Future<Session?> getPersistedSession() async {
    final sessionData = await (_db.select(_db.authSessions)
      ..orderBy([(t) => OrderingTerm.desc(t.lastSyncedAt)])
      ..limit(1))
      .getSingleOrNull();

    if (sessionData == null) return null;

    // Allow 24-hour offline grace period
    final gracePeriod = Duration(hours: 24);
    final effectiveExpiry = sessionData.expiresAt.add(gracePeriod);

    if (DateTime.now().isAfter(effectiveExpiry)) {
      return null;  // Too old
    }

    return Session(
      accessToken: sessionData.accessToken,
      refreshToken: sessionData.refreshToken,
      expiresAt: sessionData.expiresAt.millisecondsSinceEpoch ~/ 1000,
      user: User(
        id: sessionData.userId,
        userMetadata: sessionData.userMetadata,
        createdAt: sessionData.authCreatedAt?.toIso8601String() ?? '',
        // ... other fields
      ),
    );
  }

  /// Setup auth state interceptor (stores every session update)
  void setupAuthPersistence() {
    _supabase.auth.onAuthStateChange.listen((data) async {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
          if (data.session != null) {
            await persistSession(data.session!);
          }
          break;

        case AuthChangeEvent.signedOut:
          await _db.delete(_db.authSessions).go();
          break;

        default:
          break;
      }
    });
  }
}
```

**Supabase Configuration:**
- **JWT Expiry**: Increase from 1 hour → 8-12 hours (Supabase Dashboard)
- **Reduces**: Refresh frequency, offline failures
- **Trade-off**: Slightly longer exposure window (acceptable for offline requirement)

---

### ⚠️ HIGH: Device ID → UUID Migration

**Issue:** Existing production users have device_id stored in user_profiles.id

**Impact:**
- Breaking schema change
- Data loss if not handled correctly
- Users re-onboarded if migration fails

**Migration Strategy:**

```dart
// lib/features/auth/application/migration_service.dart

class AuthMigrationService {
  final AppDatabase _db;
  final SupabaseClient _supabase;
  final AppLogger _logger;

  /// Run on app startup (once per user)
  Future<MigrationResult> migrateDeviceIdToAuth() async {
    // Check if already migrated
    final migrationStatus = await _db.getAppSetting('auth_migration_complete');
    if (migrationStatus == 'true') {
      return MigrationResult.alreadyMigrated();
    }

    try {
      // 1. Get existing device-based profile
      final oldProfile = await _db.getUserProfileByDeviceId();

      if (oldProfile == null) {
        // New user, no migration needed
        await _db.setAppSetting('auth_migration_complete', 'true');
        return MigrationResult.newUser();
      }

      // 2. Create Supabase anonymous user with device_id in metadata
      final authResponse = await _supabase.auth.signInAnonymously(
        options: AuthOptions(
          data: {
            'device_id': oldProfile.deviceId,
            'device_type': Platform.isIOS ? 'ios' : 'android',
            'migrated_from_device_id': true,
            'migration_date': DateTime.now().toIso8601String(),
          },
        ),
      );

      final newAuthId = authResponse.user!.id;

      // 3. Store session in Drift
      await _sessionRepo.persistSession(authResponse.session!);

      // 4. Update local profile with new auth ID
      await _db.updateUserProfileId(
        oldId: oldProfile.id,
        newId: newAuthId,
        deviceId: oldProfile.deviceId,  // Keep for reference
        authProvider: 'anonymous',
        isAnonymous: true,
      );

      // 5. Sync to Supabase (creates user record with auth.uid())
      await _syncService.syncUserProfile();

      // 6. Mark migration complete
      await _db.setAppSetting('auth_migration_complete', 'true');

      _logger.info('Device ID migration successful', {
        'old_id': oldProfile.id,
        'new_auth_id': newAuthId,
        'device_id': oldProfile.deviceId,
      });

      // 7. Track in analytics
      await _analytics.track('auth_migration_completed', {
        'migration_type': 'device_to_anonymous',
        'platform': Platform.isIOS ? 'ios' : 'android',
      });

      return MigrationResult.success(newAuthId);

    } catch (e, stackTrace) {
      _logger.error('Device ID migration failed', e, stackTrace);

      await Sentry.captureException(
        e,
        stackTrace: stackTrace,
        hint: Hint.withMap({'migration_step': 'device_to_auth'}),
      );

      return MigrationResult.failed(e.toString());
    }
  }
}
```

**Rollback Mechanism:**
```dart
// If migration fails, user can retry
await _db.setAppSetting('auth_migration_complete', 'false');

// Keep old profile data intact until migration succeeds
// Don't delete device_id-based data until confirmed synced
```

---

### ⚠️ MEDIUM: Apple Sign-In Compliance

**Issue:** App Store requires Apple Sign-In if offering Google Sign-In

**App Store Review Guidelines 4.8:**
> "Apps that use a third-party or social login service [...] to set up or authenticate the user's primary account with the app must also offer Sign in with Apple as an equivalent option."

**Mitigation:**

1. **Implement Apple Sign-In FIRST** (before Google)
2. **Display Apple button prominently** (above Google in UI)
3. **Test on physical devices** (Simulator doesn't support Apple Sign-In)
4. **Configure Xcode capabilities** (Signing & Capabilities → Sign in with Apple)

```dart
// lib/features/auth/application/apple_auth_service.dart

import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleAuthService {
  final SupabaseClient _supabase;

  Future<AuthResponse> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    return await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: credential.identityToken!,
      nonce: credential.identityToken,
    );
  }

  /// Link to existing anonymous account
  Future<AuthResponse> linkAppleAccount() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    // Preserves existing user data
    return await _supabase.auth.linkIdentity(
      OAuthProvider.apple,
      idToken: credential.identityToken!,
    );
  }
}
```

---

### ⚠️ MEDIUM: Privacy Policy Updates

**Issue:** Current policy claims "no data collection" but app syncs to Supabase

**Risk:** App Store rejection, legal liability

**Current Privacy Policy (INCORRECT):**
> "Mealvana Run does NOT collect, transmit, or share any user data."

**What We Actually Collect:**
- ✅ Device IDs (Supabase sync)
- ✅ User profiles (Supabase sync)
- ✅ Food preferences (Supabase sync)
- ✅ Analytics (Mixpanel)
- ✅ Crash reports (Sentry)

**Updated Privacy Policy (REQUIRED):**

```markdown
# Mealvana Endurance Privacy Policy

## Data Collection

Mealvana Endurance offers two usage modes:

### Anonymous Mode (Default)
- No personal information required
- Anonymous identifier only (no email, name, or phone)
- Data stored locally on your device
- Optional cloud backup using anonymous ID
- Can use app fully offline

**What we collect in Anonymous Mode:**
- Anonymous user ID (generated automatically)
- Biometric data (height, weight, age, gender) - stored locally
- Nutrition preferences - stored locally
- App usage analytics (anonymized)
- Crash reports (anonymized)

### Account Mode (Optional - Post-Onboarding)
- Link anonymous data to a real account
- Enable cross-device synchronization
- Choose from: Google Sign-In, Apple Sign-In, or Email/Password

**Additional data collected in Account Mode:**
- Email address (required for account creation)
- Name (if using Google/Apple Sign-In)
- OAuth profile data (from Google/Apple)

## How We Use Your Data
- **Local Storage**: All nutrition data stored on your device (Drift SQLite)
- **Cloud Backup**: Optional sync to Supabase (encrypted in transit)
- **Analytics**: Track app usage to improve features (Mixpanel, anonymized)
- **Error Tracking**: Crash reports to fix bugs (Sentry, anonymized)

## Data Sharing
We DO NOT sell or share your data with third parties. We use:
- Supabase (data storage and sync)
- Mixpanel (analytics)
- Sentry (error tracking)

## Your Rights
- **Delete Account**: Settings → Account → Delete Account
- **Export Data**: Settings → Export My Data
- **Opt-out of Analytics**: Settings → Privacy → Disable Analytics

## Contact
privacy@mealvana.com
```

**App Store Data Safety Updates:**

| Data Type | Collection | Purpose | Linked to User? |
|-----------|-----------|---------|-----------------|
| Email | Optional | Account creation (if user chooses) | Yes (Account Mode only) |
| Name | Optional | OAuth (Google/Apple Sign-In) | Yes (Account Mode only) |
| User ID | Yes | App functionality | Anonymous (Anonymous Mode), Yes (Account Mode) |
| Device ID | Yes | App functionality | No (deprecated, kept for migration) |
| Health & Fitness | Yes | Core feature (nutrition planning) | No (stored locally) |
| Usage Data | Yes | Analytics | No (anonymized) |
| Diagnostics | Yes | Crash reporting | No (anonymized) |

---

## Detailed Implementation Phases

### Phase 0: Prerequisites & Foundation (Week 1)

**Goal:** Fix immediate onboarding bugs, set up infrastructure

#### Tasks

**0.1 Fix Drift UUID Constraint Issue** ⚠️ URGENT
```dart
// lib/shared/database/tables/user_profiles.dart

@DataClassName('UserProfile')
class UserProfiles extends Table {
  // BEFORE: Strict 36-char UUID (fails with short device IDs)
  // TextColumn get id => text().withLength(min: 36, max: 36)();

  // AFTER: Allow any string temporarily (migration phase)
  TextColumn get id => text()();

  // Add new column for Supabase auth ID
  TextColumn get authUserId => text().nullable()();

  // Keep device_id for migration
  TextColumn get deviceId => text().nullable()();

  // Track auth state
  TextColumn get authProvider => text().nullable()();
  BoolColumn get isAnonymous => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
```

**0.2 Create auth_sessions Table**
```dart
// lib/shared/database/tables/auth_sessions.dart

@DataClassName('AuthSessionData')
class AuthSessions extends Table {
  TextColumn get userId => text()();
  TextColumn get accessToken => text()();
  TextColumn get refreshToken => text()();
  DateTimeColumn get expiresAt => dateTime()();
  TextColumn get userMetadata => text().map(const JsonConverter()).nullable()();
  DateTimeColumn get lastSyncedAt => dateTime()();
  BoolColumn get isAnonymous => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {userId};
}
```

**0.3 Run Drift Code Generation**
```bash
dart run build_runner build --delete-conflicting-outputs
```

**0.4 Create Drift Migration (v1 → v2)**
```dart
// lib/shared/database/app_database.dart

@DriftDatabase(
  tables: [
    UserProfiles,
    AuthSessions,  // NEW
    // ... other tables
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 2;  // Increment

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from == 1 && to == 2) {
        // Add new columns to user_profiles
        await m.addColumn(userProfiles, userProfiles.authUserId);
        await m.addColumn(userProfiles, userProfiles.authProvider);
        await m.addColumn(userProfiles, userProfiles.isAnonymous);

        // Create auth_sessions table
        await m.createTable(authSessions);
      }
    },
  );
}
```

**0.5 Environment Routing Fix**
```dart
// lib/shared/services/app_config.dart

class AppConfig {
  // BEFORE: Defaults to dev mode = false (uses prod env)
  // static const bool _DEFAULT_DEV_MODE = false;

  // AFTER: Derive from build mode
  static final bool _DEFAULT_DEV_MODE = !kReleaseMode;

  // Debug/Profile builds → .env.dev.local
  // Release builds → .env.prod.local

  bool get isDevMode {
    // Allow override via hidden switcher (for QA)
    final override = _prefs.getBool('force_dev_mode');
    if (override != null) return override;

    // Default: dev mode in debug/profile builds
    return _DEFAULT_DEV_MODE;
  }
}
```

**0.6 Update .env.dev.local**
```bash
# .env.dev.local (debug/profile builds)
SUPABASE_URL=https://dev-project.supabase.co
SUPABASE_ANON_KEY=dev_anon_key
SENTRY_DSN=https://dev-sentry-dsn@sentry.io/dev-project-id
MIXPANEL_TOKEN=dev_mixpanel_token

# .env.prod.local (release builds only)
SUPABASE_URL=https://wvmvsodrvbkxfydabqed.supabase.co
SUPABASE_ANON_KEY=prod_anon_key
SENTRY_DSN=https://prod-sentry-dsn@sentry.io/prod-project-id
MIXPANEL_TOKEN=prod_mixpanel_token
```

**0.7 Create SessionRepository**
```dart
// lib/features/auth/data/session_repository.dart

@riverpod
SessionRepository sessionRepository(SessionRepositoryRef ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = ref.watch(supabaseClientProvider);
  return SessionRepository(db, supabase);
}

class SessionRepository {
  final AppDatabase _db;
  final SupabaseClient _supabase;

  SessionRepository(this._db, this._supabase);

  /// Store session locally (called after every auth event)
  Future<void> persistSession(Session session) async {
    // Implementation from "Critical Issues" section
  }

  /// Restore session on app launch (offline support)
  Future<Session?> getPersistedSession() async {
    // Implementation from "Critical Issues" section
  }

  /// Setup auth state interceptor
  void setupAuthPersistence() {
    // Implementation from "Critical Issues" section
  }
}
```

#### Acceptance Criteria
- ✅ Onboarding completes successfully on Android (short device IDs accepted)
- ✅ Debug builds automatically use .env.dev.local (Sentry dev project, Mixpanel dev token)
- ✅ Release builds use .env.prod.local
- ✅ Drift migration runs successfully (v1 → v2)
- ✅ auth_sessions table created
- ✅ SessionRepository wired up and tested

#### Testing
```bash
# Test onboarding on Android emulator
flutter run --debug  # Should use dev env
flutter run --release  # Should use prod env

# Verify in logs:
# [AppConfig] Environment: dev (Supabase: https://dev-project.supabase.co)
# [AppConfig] Environment: prod (Supabase: https://wvmvsodrvbkxfydabqed.supabase.co)

# Test Drift migration
flutter test test/database/migration_test.dart
```

---

### Phase 1: Anonymous Authentication (Week 2)

**Goal:** Replace device_id with Supabase Anonymous Auth

#### Tasks

**1.1 Update AuthService to Use Anonymous Auth**
```dart
// lib/features/auth/application/auth_service.dart

@riverpod
class AuthService extends _$AuthService {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);
  SessionRepository get _sessionRepo => ref.read(sessionRepositoryProvider);
  AppDatabase get _db => ref.read(appDatabaseProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  FutureOr<User?> build() async {
    // Setup session persistence interceptor
    _sessionRepo.setupAuthPersistence();

    // Try to restore session on startup
    return await _restoreOrCreateSession();
  }

  /// Restore session from Drift or create new anonymous user
  Future<User?> _restoreOrCreateSession() async {
    try {
      // 1. Check local session first (offline support)
      final localSession = await _sessionRepo.getPersistedSession();

      if (localSession != null) {
        _logger.info('Session restored from Drift DB (offline mode)', {
          'user_id': localSession.user.id,
          'expires_at': localSession.expiresAt,
          'is_anonymous': localSession.user.isAnonymous,
        });

        // Try to refresh if online
        if (await _isOnline()) {
          try {
            final freshSession = await _supabase.auth.refreshSession();
            if (freshSession.session != null) {
              await _sessionRepo.persistSession(freshSession.session!);
              return freshSession.session!.user;
            }
          } catch (e) {
            _logger.warning('Session refresh failed, using cached session', {
              'error': e.toString(),
            });
            // Continue with local session
          }
        }

        return localSession.user;
      }

      // 2. No local session, create new anonymous user (if online)
      if (await _isOnline()) {
        return await _createAnonymousUser();
      }

      // 3. Offline and no session - can't proceed
      _logger.error('Cannot create anonymous user: offline and no cached session');
      return null;

    } catch (e, stackTrace) {
      _logger.error('Failed to restore/create session', e, stackTrace);
      await Sentry.captureException(e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Create Supabase anonymous user
  Future<User> _createAnonymousUser() async {
    final deviceId = await _getDeviceId();

    final response = await _supabase.auth.signInAnonymously(
      options: AuthOptions(
        data: {
          'device_id': deviceId,
          'device_type': Platform.isIOS ? 'ios' : 'android',
          'app_version': await _getAppVersion(),
          'created_at': DateTime.now().toIso8601String(),
        },
      ),
    );

    _logger.info('Anonymous user created', {
      'user_id': response.user!.id,
      'device_id': deviceId,
    });

    // Store in Drift DB (critical for offline)
    await _sessionRepo.persistSession(response.session!);

    // Track in analytics
    await ref.read(analyticsServiceProvider).track('anonymous_auth_created', {
      'device_type': Platform.isIOS ? 'ios' : 'android',
    });

    return response.user!;
  }

  /// Get device ID (legacy, stored in metadata only)
  Future<String> _getDeviceId() async {
    if (Platform.isIOS) {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? _generateFallbackId();
    } else {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id ?? _generateFallbackId();
    }
  }

  String _generateFallbackId() {
    return 'fallback-${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<bool> _isOnline() async {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity != ConnectivityResult.none;
  }
}
```

**1.2 Update UserRepository to Use auth.uid()**
```dart
// lib/features/auth/data/user_repository.dart

class UserRepository {
  final AppDatabase _db;
  final SupabaseClient _supabase;

  /// Save user profile (uses auth.uid() as primary key)
  Future<void> saveUserProfile(UserProfile profile) async {
    // Get current auth user
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) {
      throw Exception('No authenticated user');
    }

    // Use auth.uid() as profile ID
    final profileWithAuthId = profile.copyWith(
      id: authUser.id,  // Supabase auth.uid()
      authUserId: authUser.id,
      deviceId: authUser.userMetadata?['device_id'],  // Keep for reference
      authProvider: authUser.isAnonymous == true ? 'anonymous' : 'authenticated',
      isAnonymous: authUser.isAnonymous ?? true,
    );

    // Save to Drift (local)
    await _db.into(_db.userProfiles).insertOnConflictUpdate(
      profileWithAuthId.toCompanion(),
    );

    // Sync to Supabase
    await _syncToSupabase(profileWithAuthId);
  }

  /// Sync to Supabase (uses auth.uid())
  Future<void> _syncToSupabase(UserProfile profile) async {
    try {
      await _supabase.from('users').upsert({
        'id': profile.id,  // auth.uid()
        'device_id': profile.deviceId,  // Historical reference
        'auth_provider': profile.authProvider,
        'gender': profile.gender,
        'birthday': profile.birthday?.toIso8601String(),
        // ... other fields
      });
    } catch (e) {
      // Offline - will sync later
      _logger.warning('Failed to sync user profile to Supabase', {
        'error': e.toString(),
      });
    }
  }
}
```

**1.3 Create Migration Service**
```dart
// lib/features/auth/application/migration_service.dart
// Implementation from "Critical Issues" section
```

**1.4 Update App Startup Service**
```dart
// lib/features/app_startup/application/app_startup_service.dart

class AppStartupService {
  Future<void> initialize() async {
    // 1. Restore/create auth session
    final authUser = await ref.read(authServiceProvider.future);

    if (authUser == null) {
      // No session and offline - can't proceed
      throw Exception('Cannot initialize: offline and no cached session');
    }

    // 2. Run migration if needed (device_id → auth.uid())
    final migrationResult = await ref.read(migrationServiceProvider).migrateDeviceIdToAuth();

    if (migrationResult.isFailed) {
      _logger.error('Auth migration failed', {
        'error': migrationResult.error,
      });
      // Continue anyway - user can retry later
    }

    // 3. Load user profile (uses auth.uid() now)
    final userProfile = await ref.read(userRepositoryProvider).getUserProfile();

    // 4. Determine initial route
    if (userProfile == null || !userProfile.onboardingCompleted) {
      // New user or onboarding incomplete
      _initialRoute = '/onboarding';
    } else {
      _initialRoute = '/home';
    }

    // 5. Initialize other services (content, sync, etc.)
    await _initializeServices();
  }
}
```

#### Acceptance Criteria
- ✅ New users get Supabase anonymous auth (not device_id)
- ✅ Existing users migrated from device_id to auth.uid() seamlessly
- ✅ Session persists in Drift DB (offline support works)
- ✅ App works offline for 24 hours after last online session
- ✅ Onboarding completes successfully with auth.uid()
- ✅ User profile synced to Supabase with proper auth.uid()

#### Testing
```dart
// test/features/auth/anonymous_auth_test.dart

testWidgets('New user gets anonymous auth', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();

  final authUser = await ref.read(authServiceProvider.future);
  expect(authUser, isNotNull);
  expect(authUser!.isAnonymous, isTrue);
  expect(authUser.id.length, equals(36));  // UUID
});

testWidgets('Existing device_id user migrates to auth.uid()', (tester) async {
  // Setup: Create old user with device_id
  await _db.into(_db.userProfiles).insert(
    UserProfilesCompanion.insert(
      id: 'old-device-id',
      deviceId: 'old-device-id',
      gender: 'male',
    ),
  );

  // Act: Launch app (triggers migration)
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();

  // Assert: User migrated to auth.uid()
  final profile = await ref.read(userRepositoryProvider).getUserProfile();
  expect(profile!.id.length, equals(36));  // UUID, not device_id
  expect(profile.deviceId, equals('old-device-id'));  // Preserved
  expect(profile.authProvider, equals('anonymous'));
});

testWidgets('Session persists offline for 24 hours', (tester) async {
  // Create anonymous user (online)
  await ref.read(authServiceProvider.future);
  final userId = _supabase.auth.currentUser!.id;

  // Simulate 23 hours passing + offline mode
  await tester.runAsync(() async {
    await Future.delayed(Duration(hours: 23));
  });
  mockConnectivity.setOffline();

  // Restart app
  await tester.pumpWidget(Container());
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();

  // Session restored from Drift
  final restoredUser = await ref.read(authServiceProvider.future);
  expect(restoredUser!.id, equals(userId));
});
```

---

### Phase 2: Account Linking UI (Week 3-4)

**Goal:** Add optional authentication screen after onboarding

#### Tasks

**2.1 Create Authentication Screen UI**
```dart
// lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart

class PostOnboardingAuthScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentService = ref.watch(contentServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(contentService.getText('auth.title') ?? 'Create Account'),
        actions: [
          TextButton(
            onPressed: () => _skipAuth(context, ref),
            child: Text(contentService.getText('auth.skip') ?? 'Skip for now'),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Benefits Section
            _buildBenefitsCard(contentService),

            SizedBox(height: 32),

            // Apple Sign-In (MUST be first for App Store compliance)
            _buildAppleSignInButton(ref),

            SizedBox(height: 16),

            // Google Sign-In
            _buildGoogleSignInButton(ref),

            SizedBox(height: 16),

            // Divider
            Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('or'),
                ),
                Expanded(child: Divider()),
              ],
            ),

            SizedBox(height: 16),

            // Email/Password
            _buildEmailSignUpButton(ref),

            Spacer(),

            // Privacy Notice
            _buildPrivacyNotice(contentService),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsCard(ContentService contentService) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_upload, size: 48, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              contentService.getText('auth.benefits.title') ??
              'Sync Across Devices',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              contentService.getText('auth.benefits.description') ??
              'Create an account to access your nutrition plans on all your devices.',
            ),
            SizedBox(height: 16),
            _buildBenefitItem(
              Icons.devices,
              contentService.getText('auth.benefits.multi_device') ??
              'Access on phone, tablet, and web',
            ),
            _buildBenefitItem(
              Icons.backup,
              contentService.getText('auth.benefits.backup') ??
              'Automatic cloud backup',
            ),
            _buildBenefitItem(
              Icons.lock,
              contentService.getText('auth.benefits.secure') ??
              'Secure and private',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppleSignInButton(WidgetRef ref) {
    if (!Platform.isIOS) return SizedBox.shrink();

    return SignInWithAppleButton(
      onPressed: () async {
        await ref.read(authControllerProvider.notifier).linkAppleAccount();
      },
    );
  }

  Widget _buildGoogleSignInButton(WidgetRef ref) {
    return ElevatedButton.icon(
      icon: Image.asset('assets/images/google_logo.png', height: 24),
      label: Text('Continue with Google'),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      onPressed: () async {
        await ref.read(authControllerProvider.notifier).linkGoogleAccount();
      },
    );
  }

  void _skipAuth(BuildContext context, WidgetRef ref) {
    // Track skip action
    ref.read(analyticsServiceProvider).track('auth_screen_skipped');

    // Show reminder in settings
    ref.read(appStateProvider.notifier).setAuthReminderBadge(true);

    // Navigate to home
    context.go('/home');
  }
}
```

**2.2 Implement Apple Sign-In Service**
```dart
// lib/features/auth/application/apple_auth_service.dart

@riverpod
class AppleAuthService extends _$AppleAuthService {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  FutureOr<void> build() {}

  /// Link Apple account to existing anonymous user
  Future<void> linkAppleAccount() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      try {
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

        // Link to current anonymous session
        final response = await _supabase.auth.linkIdentity(
          OAuthProvider.apple,
          idToken: credential.identityToken!,
        );

        _logger.info('Apple account linked', {
          'user_id': response.user!.id,
          'email': response.user!.email,
        });

        // Track in analytics
        await ref.read(analyticsServiceProvider).track('apple_account_linked', {
          'user_id': response.user!.id,
        });

        // Update local profile
        await ref.read(userRepositoryProvider).updateAuthProvider('apple');

      } catch (e, stackTrace) {
        _logger.error('Apple Sign-In failed', e, stackTrace);
        await Sentry.captureException(e, stackTrace: stackTrace);
        rethrow;
      }
    });
  }
}
```

**2.3 Implement Google Sign-In Service**
```dart
// lib/features/auth/application/google_auth_service.dart

@riverpod
class GoogleAuthService extends _$GoogleAuthService {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  static const String webClientId = 'YOUR-WEB-CLIENT-ID.apps.googleusercontent.com';
  static const String iosClientId = 'YOUR-IOS-CLIENT-ID.apps.googleusercontent.com';

  @override
  FutureOr<void> build() {}

  /// Link Google account to existing anonymous user
  Future<void> linkGoogleAccount() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      try {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: iosClientId,
          serverClientId: webClientId,
        );

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception('Google Sign-In cancelled');
        }

        final googleAuth = await googleUser.authentication;

        // Link to current anonymous session
        final response = await _supabase.auth.linkIdentity(
          OAuthProvider.google,
          idToken: googleAuth.idToken!,
          accessToken: googleAuth.accessToken!,
        );

        _logger.info('Google account linked', {
          'user_id': response.user!.id,
          'email': response.user!.email,
        });

        // Track in analytics
        await ref.read(analyticsServiceProvider).track('google_account_linked', {
          'user_id': response.user!.id,
        });

        // Update local profile
        await ref.read(userRepositoryProvider).updateAuthProvider('google');

      } catch (e, stackTrace) {
        _logger.error('Google Sign-In failed', e, stackTrace);
        await Sentry.captureException(e, stackTrace: stackTrace);
        rethrow;
      }
    });
  }
}
```

**2.4 Add Email/Password Flow**
```dart
// lib/features/auth/presentation/screens/email_signup_screen.dart

class EmailSignUpScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends ConsumerState<EmailSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(emailAuthServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Create Account')),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: _validateEmail,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: _validatePassword,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: authState.isLoading ? null : _signUp,
                child: authState.isLoading
                    ? CircularProgressIndicator()
                    : Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(emailAuthServiceProvider.notifier).linkEmailAccount(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (mounted && !ref.read(emailAuthServiceProvider).hasError) {
      context.go('/home');
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email required';
    if (!value.contains('@')) return 'Invalid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }
}
```

**2.5 Update Onboarding Flow**
```dart
// lib/features/onboarding/presentation/controllers/onboarding_controller.dart

class OnboardingController extends _$OnboardingController {
  Future<void> completeOnboarding() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      // Save all onboarding data
      await _saveUserProfile();
      await _saveFoodPreferences();

      // Mark onboarding complete
      await ref.read(userRepositoryProvider).markOnboardingComplete();

      // Navigate to auth screen (OPTIONAL)
      // User can skip and continue to home
      return '/auth';  // PostOnboardingAuthScreen
    });
  }
}
```

**2.6 Add Settings UI for Auth**
```dart
// lib/features/settings/presentation/screens/settings_screen.dart

class SettingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authServiceProvider).value;
    final isAnonymous = authUser?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        children: [
          // Account Section
          ListTile(
            leading: Icon(Icons.account_circle),
            title: Text('Account'),
            subtitle: Text(
              isAnonymous
                  ? 'Anonymous (Create account to sync devices)'
                  : authUser?.email ?? 'Authenticated',
            ),
            trailing: isAnonymous
                ? Badge(
                    label: Text('NEW'),
                    child: Icon(Icons.arrow_forward_ios),
                  )
                : null,
            onTap: () => context.push('/auth'),
          ),

          if (isAnonymous)
            Card(
              margin: EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload, color: Colors.blue),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Create an account to sync your data across devices',
                        style: TextStyle(color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Other settings...
        ],
      ),
    );
  }
}
```

#### Acceptance Criteria
- ✅ Post-onboarding auth screen displays with Apple, Google, Email options
- ✅ User can skip auth and continue to home
- ✅ Apple Sign-In links to anonymous account (preserves data)
- ✅ Google Sign-In links to anonymous account (preserves data)
- ✅ Email signup links to anonymous account (preserves data)
- ✅ Settings shows "Create Account" reminder for anonymous users
- ✅ Account linking preserves all user data (nutrition plans, preferences, etc.)

#### Testing
```dart
testWidgets('User can skip auth and see reminder in settings', (tester) async {
  // Complete onboarding
  await _completeOnboarding(tester);

  // Auth screen displays
  expect(find.byType(PostOnboardingAuthScreen), findsOneWidget);

  // Skip auth
  await tester.tap(find.text('Skip for now'));
  await tester.pumpAndSettle();

  // Navigate to settings
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();

  // Reminder badge visible
  expect(find.byType(Badge), findsOneWidget);
  expect(find.text('Anonymous (Create account to sync devices)'), findsOneWidget);
});

testWidgets('Google Sign-In links to anonymous account', (tester) async {
  // Create anonymous user
  await ref.read(authServiceProvider.future);
  final anonymousId = _supabase.auth.currentUser!.id;

  // Link Google account
  await ref.read(googleAuthServiceProvider.notifier).linkGoogleAccount();

  // Same user ID (data preserved)
  expect(_supabase.auth.currentUser!.id, equals(anonymousId));
  expect(_supabase.auth.currentUser!.isAnonymous, isFalse);

  // Profile accessible
  final profile = await ref.read(userRepositoryProvider).getUserProfile();
  expect(profile, isNotNull);
  expect(profile!.authProvider, equals('google'));
});
```

---

### Phase 3: Security & RLS (Week 5)

**Goal:** Implement proper JWT-based security policies

#### Tasks

**3.1 Update Supabase RLS Policies**
```sql
-- supabase/migrations/YYYYMMDDHHMMSS_add_auth_rls_policies.sql

-- Drop old permissive policies
DROP POLICY IF EXISTS "Users can insert own data" ON users;
DROP POLICY IF EXISTS "Users can read own data" ON users;
DROP POLICY IF EXISTS "Users can update own data" ON users;

-- Users table: Only auth.uid() can access own profile
CREATE POLICY "Users can only read own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can only update own profile"
  ON users FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can create own profile"
  ON users FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Food preferences: Users can only access own preferences
CREATE POLICY "Users can access own food preferences"
  ON food_preferences FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Nutrition plans: Users can only access own plans
CREATE POLICY "Users can access own nutrition plans"
  ON nutrition_plans FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- User foods: Only authenticated users can create custom foods
CREATE POLICY "Authenticated users can create custom foods"
  ON user_foods FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    (auth.jwt() ->> 'is_anonymous')::boolean = false AND
    auth.uid() = user_id
  );

-- Public foods: Everyone can read (including anonymous)
CREATE POLICY "Everyone can read public foods"
  ON foods FOR SELECT
  USING (is_public = true);

-- User can read their own custom foods
CREATE POLICY "Users can read own custom foods"
  ON foods FOR SELECT
  USING (
    created_by_user_id IS NOT NULL AND
    auth.uid() = created_by_user_id
  );
```

**3.2 Update Edge Functions to Use JWT Auth**
```typescript
// supabase/functions/save-user-profile/index.ts

import { createClient } from '@supabase/supabase-js';

Deno.serve(async (req) => {
  try {
    // Get JWT from Authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401 }
      );
    }

    // Create Supabase client with user's JWT
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    );

    // Get authenticated user
    const { data: { user }, error: authError } = await supabase.auth.getUser();

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' }),
        { status: 401 }
      );
    }

    // Parse request body
    const body = await req.json();

    // RLS automatically enforces user can only update own profile
    const { data, error } = await supabase
      .from('users')
      .upsert({
        id: user.id,  // auth.uid()
        ...body,
      })
      .select()
      .single();

    if (error) {
      throw error;
    }

    return new Response(
      JSON.stringify({ success: true, data }),
      { status: 200 }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 }
    );
  }
});
```

**3.3 Add RLS Policy Tests**
```sql
-- test/sql/rls_policies_test.sql

-- Test 1: User can only read own profile
BEGIN;
  SELECT set_config('request.jwt.claims', '{"sub": "user-123"}', true);

  -- Should succeed
  SELECT * FROM users WHERE id = 'user-123';

  -- Should return empty (not error)
  SELECT COUNT(*) = 0 AS test_passed
  FROM users
  WHERE id = 'user-456';

  ASSERT (SELECT test_passed FROM test_passed);
ROLLBACK;

-- Test 2: Anonymous users can't create custom foods
BEGIN;
  SELECT set_config('request.jwt.claims', '{"sub": "user-123", "is_anonymous": true}', true);

  -- Should fail with RLS policy violation
  DO $$
  BEGIN
    INSERT INTO user_foods (id, user_id, name)
    VALUES ('food-123', 'user-123', 'Custom Food');

    RAISE EXCEPTION 'RLS policy not enforced!';
  EXCEPTION
    WHEN insufficient_privilege THEN
      -- Expected - test passes
      NULL;
  END $$;
ROLLBACK;

-- Test 3: Authenticated users can create custom foods
BEGIN;
  SELECT set_config('request.jwt.claims', '{"sub": "user-123", "is_anonymous": false}', true);

  -- Should succeed
  INSERT INTO user_foods (id, user_id, name)
  VALUES ('food-123', 'user-123', 'Custom Food');

  SELECT COUNT(*) = 1 AS test_passed
  FROM user_foods
  WHERE id = 'food-123';

  ASSERT (SELECT test_passed FROM test_passed);
ROLLBACK;
```

#### Acceptance Criteria
- ✅ All RLS policies use auth.uid() (no permissive `true` policies)
- ✅ Users can only access their own data
- ✅ Anonymous users have appropriate restrictions
- ✅ Edge functions use JWT authentication (not SERVICE_ROLE_KEY where possible)
- ✅ RLS policy tests pass in SQL
- ✅ Integration tests confirm security enforcement

---

### Phase 4: Privacy, Observability & Launch (Week 6)

**Goal:** Legal compliance, monitoring, phased rollout

#### Tasks

**4.1 Update Privacy Policy**
```markdown
# Create new privacy policy (from "Critical Issues" section)
# Location: /docs/legal/PRIVACY_POLICY.md
# Also update: App Store Connect → App Privacy → Data Types
```

**4.2 Add Structured Logging**
```dart
// lib/shared/services/app_logger.dart

class AppLogger {
  void logAuthEvent(String event, {Map<String, dynamic>? metadata}) {
    log(
      event,
      level: LogLevel.info,
      category: 'auth',
      metadata: {
        'timestamp': DateTime.now().toIso8601String(),
        'user_id': _supabase.auth.currentUser?.id,
        'is_anonymous': _supabase.auth.currentUser?.isAnonymous,
        ...?metadata,
      },
    );

    // Send to Sentry as breadcrumb
    Sentry.addBreadcrumb(Breadcrumb(
      message: event,
      category: 'auth',
      data: metadata,
    ));
  }

  void logOnboardingStep(String step, {bool success = true}) {
    log(
      'Onboarding: $step',
      level: success ? LogLevel.info : LogLevel.error,
      category: 'onboarding',
      metadata: {
        'step': step,
        'success': success,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    // Track in Mixpanel
    _analytics.track('onboarding_step', {
      'step': step,
      'success': success,
    });
  }
}
```

**4.3 Add Analytics Events**
```dart
// lib/shared/services/analytics_service.dart

enum AuthAnalyticsEvent {
  anonymousAuthCreated,
  googleAccountLinked,
  appleAccountLinked,
  emailAccountCreated,
  authScreenShown,
  authScreenSkipped,
  sessionRestoredFromCache,
  sessionRefreshFailed,
  migrationCompleted,
  migrationFailed,
}

void trackAuthEvent(AuthAnalyticsEvent event, {Map<String, dynamic>? properties}) {
  final eventName = event.toString().split('.').last;

  mixpanel.track(eventName, properties: {
    'is_anonymous': _supabase.auth.currentUser?.isAnonymous ?? true,
    'auth_provider': _supabase.auth.currentUser?.appMetadata?['provider'],
    'platform': Platform.isIOS ? 'ios' : 'android',
    ...?properties,
  });
}
```

**4.4 Create Monitoring Dashboard**
```markdown
# Sentry Custom Dashboard

## Auth Metrics
- Session Refresh Failure Rate (target: <1%)
- Offline Session Usage (trend monitoring)
- Migration Success Rate (target: >99.9%)
- Auth Linking Success Rate (target: >90%)

## Onboarding Metrics
- Onboarding Completion Rate (target: >80%)
- Step-by-step completion funnel
- Failure points (which step users abandon)

## Performance
- App Startup Time (target: <2s)
- Session Restore Time (target: <500ms)
- Auth Linking Time (target: <3s)
```

**4.5 Phased Rollout Plan**
```markdown
# Rollout Strategy

## Week 1: Internal Testing
- Deploy to TestFlight (internal team only)
- Run integration tests
- Monitor Sentry for auth errors
- Verify migration works (create test accounts with old device_ids)

## Week 2: Beta Testing
- Deploy to TestFlight (beta testers)
- 100 beta users minimum
- Monitor:
  - Migration success rate
  - Session refresh failures
  - Account linking completion
  - Offline usage patterns

## Week 3: Staged Rollout
- Release to 10% of App Store users
- Monitor for 3 days:
  - Crash rate (target: <0.1%)
  - Session failures (target: <1%)
  - Migration failures (target: <0.1%)

- If metrics good → 50% rollout
- Monitor for 2 days
- If metrics good → 100% rollout

## Rollback Triggers
- Crash rate >0.5%
- Migration failure rate >1%
- Session refresh failure rate >5%
- Critical security issue

## Rollback Procedure
1. Pause app store distribution
2. Pull latest working version from Git
3. Deploy hotfix
4. Resume distribution to smaller percentage
```

**4.6 Create Deployment Checklist**
```markdown
# Pre-Launch Checklist

## Code
- [ ] All tests passing (unit + integration)
- [ ] Flutter analyze shows 0 issues
- [ ] Code generation up-to-date (build_runner)
- [ ] Drift schema snapshot created

## Supabase
- [ ] RLS policies deployed to production
- [ ] Edge functions deployed
- [ ] JWT expiry set to 8-12 hours
- [ ] Database backups enabled

## Environment
- [ ] .env.prod.local configured correctly
- [ ] Debug builds use dev environment
- [ ] Release builds use prod environment
- [ ] Environment switcher hidden in release builds

## Legal
- [ ] Privacy policy updated
- [ ] App Store privacy details submitted
- [ ] Google Play data safety form updated
- [ ] Terms of service reviewed

## Monitoring
- [ ] Sentry prod project configured
- [ ] Mixpanel prod token configured
- [ ] Analytics events tested
- [ ] Error tracking tested

## App Store
- [ ] Apple Sign-In capability enabled
- [ ] OAuth redirect URLs configured
- [ ] App Store screenshots updated (show auth screen)
- [ ] App Store description mentions account features

## Testing
- [ ] Migration tested (device_id → auth.uid())
- [ ] Offline session tested (24-hour grace period)
- [ ] Apple Sign-In tested (physical device)
- [ ] Google Sign-In tested
- [ ] Email signup tested
- [ ] Account linking preserves data
```

#### Acceptance Criteria
- ✅ Privacy policy updated and submitted
- ✅ All analytics events firing correctly
- ✅ Sentry monitoring configured
- ✅ Beta testing completed (100+ users)
- ✅ Rollback plan documented
- ✅ Deployment checklist completed

---

## Technical Implementation Details

### Supabase Configuration

**Dashboard Settings:**

```
Authentication → Settings
├─ JWT Expiry: 43200 (12 hours)
├─ Enable Anonymous Sign-Ins: ON
├─ Site URL: https://mealvana.com
└─ Redirect URLs:
    ├─ com.mealvana.endurance://auth/callback
    └─ https://mealvana.com/auth/callback

Authentication → Providers
├─ Google: Enabled
│   ├─ Client ID: (from GCP Console)
│   └─ Client Secret: (from GCP Console)
├─ Apple: Enabled
│   ├─ Services ID: com.mealvana.endurance.auth
│   └─ Key ID: (from Apple Developer)
└─ Email: Enabled
    └─ Confirm email: Optional (for faster onboarding)
```

### Dependencies

```yaml
# pubspec.yaml

dependencies:
  supabase_flutter: ^2.6.0
  google_sign_in: ^6.2.1
  sign_in_with_apple: ^6.1.0
  connectivity_plus: ^6.0.0
  device_info_plus: ^10.1.0

dev_dependencies:
  drift_dev: ^2.16.0
  build_runner: ^2.4.8
```

### Platform Configuration

**iOS (Xcode):**
```xml
<!-- ios/Runner/Info.plist -->

<!-- Supabase Deep Linking -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.mealvana.endurance</string>
      <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
    </array>
  </dict>
</array>

<!-- Apple Sign-In Capability (add in Signing & Capabilities) -->
```

**Android (Gradle):**
```gradle
// android/app/build.gradle

android {
  defaultConfig {
    manifestPlaceholders = [
      'appAuthRedirectScheme': 'com.mealvana.endurance'
    ]
  }
}
```

---

## Testing Strategy

### Unit Tests
```bash
# Run all unit tests
flutter test test/

# Test coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Integration Tests
```bash
# Test auth flows
flutter test integration_test/auth_flow_test.dart

# Test migration
flutter test integration_test/migration_test.dart

# Test offline session
flutter test integration_test/offline_session_test.dart
```

### Manual Testing Checklist
```markdown
## Anonymous Auth
- [ ] New user gets anonymous auth on first launch
- [ ] Session persists after app restart (offline)
- [ ] Session refreshes when online
- [ ] 24-hour offline grace period works

## Migration
- [ ] Existing device_id user migrates to auth.uid()
- [ ] All user data preserved (profile, preferences, plans)
- [ ] Migration is idempotent (can retry safely)
- [ ] Migration tracked in analytics

## Account Linking
- [ ] Apple Sign-In links to anonymous account
- [ ] Google Sign-In links to anonymous account
- [ ] Email signup links to anonymous account
- [ ] All data preserved after linking
- [ ] Settings shows correct auth status

## Offline Mode
- [ ] App works fully offline after initial session
- [ ] Session restored from Drift DB on app launch
- [ ] 24-hour grace period enforced
- [ ] Expired sessions force re-auth (online only)

## Security
- [ ] RLS policies prevent cross-user access
- [ ] Anonymous users can't create custom foods
- [ ] Authenticated users can create custom foods
- [ ] JWT expiry enforced

## Privacy
- [ ] Privacy policy accessible in app
- [ ] Data export works
- [ ] Account deletion works
- [ ] Analytics opt-out works
```

---

## Deployment & Rollout

### Pre-Production Checklist
- [ ] All tests passing
- [ ] Privacy policy updated
- [ ] Sentry/Mixpanel configured
- [ ] RLS policies deployed
- [ ] Edge functions deployed

### TestFlight Beta
- [ ] Deploy to internal testers (week 1)
- [ ] Deploy to external testers (week 2)
- [ ] Collect feedback
- [ ] Monitor crash reports

### App Store Submission
- [ ] Screenshots updated
- [ ] Description mentions accounts
- [ ] Privacy details submitted
- [ ] Apple Sign-In approved

### Staged Rollout
- [ ] 10% rollout (3 days)
- [ ] 50% rollout (2 days)
- [ ] 100% rollout

---

## Success Metrics

### Technical Metrics
| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Migration Success Rate | >99.9% | <99% |
| Session Refresh Failure | <1% | >5% |
| Offline Session Usage | Monitor | N/A (trend) |
| App Startup Time | <2s | >3s |
| Account Linking Success | >90% | <80% |

### Business Metrics
| Metric | Target | Timeline |
|--------|--------|----------|
| Account Creation Rate | >20% of active users | 30 days |
| Anonymous User % | 50-80% | Ongoing |
| Cross-Device Users | >10% of accounts | 60 days |
| Retention (w/ account) | >70% | 90 days |

### Monitoring
- **Sentry**: Session errors, migration failures, auth errors
- **Mixpanel**: Funnel analysis (onboarding → auth → usage)
- **Supabase**: Database performance, RLS policy violations

---

## Open Questions (From Original Roadmap)

### 1. How should we backfill UUIDs for existing production users?

**Answer:** Use the migration service in Phase 1:
- On app startup, check if migration needed
- Create Supabase anonymous user with device_id in metadata
- Update local profile with new auth.uid()
- Sync to Supabase
- Mark migration complete

**Edge Cases:**
- User has multiple devices with same device_id → First device wins, others get new auth
- User deletes app before migration → Treated as new user (data on Supabase preserved if we keep device_id reference)

### 2. Which Supabase Auth method do we want first?

**Answer:** All three simultaneously (Apple, Google, Email) in Phase 2:
- **Apple Sign-In**: Required for App Store compliance
- **Google Sign-In**: Largest user base
- **Email/Password**: Fallback for users without OAuth accounts

### 3. What analytics thresholds signal we can retire device-id access?

**Answer:** Retire device_id when:
- ✅ Anonymous user adoption >95%
- ✅ Migration success rate >99.9%
- ✅ Account linking rate stabilizes (>20% of active users)
- ✅ 90 days post-launch (gives time for all users to update)

**Retirement Plan:**
- Phase 1 (Launch): Both device_id and auth.uid() supported
- Phase 2 (30 days): Deprecate device_id in new code
- Phase 3 (90 days): Remove device_id from RLS policies
- Phase 4 (180 days): Drop device_id column (keep in users table only)

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation | Owner |
|------|-----------|--------|----------|-------|
| Offline session bug | High | Critical | Custom Drift persistence (MANDATORY) | Engineering |
| Migration data loss | Medium | Critical | Idempotent migration, rollback plan | Engineering |
| Apple Sign-In rejection | Medium | High | Implement Apple first, test thoroughly | Engineering |
| Privacy policy violation | Low | Critical | Legal review, update App Store | Legal/Product |
| Low account adoption | Medium | Medium | Clear benefits messaging, reminders | Product |
| RLS security gap | Low | Critical | Security audit, policy tests | Engineering |

---

## Timeline Summary

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| Phase 0: Prerequisites | Week 1 | Fix onboarding, add auth_sessions table, environment routing |
| Phase 1: Anonymous Auth | Week 2 | Replace device_id, migration service, offline persistence |
| Phase 2: Account Linking | Weeks 3-4 | Apple/Google/Email sign-in, UI flows |
| Phase 3: Security | Week 5 | RLS policies, edge function auth, security audit |
| Phase 4: Launch | Week 6 | Privacy policy, monitoring, phased rollout |

**Total: 6 weeks** (assumes no major blockers)

---

## Next Steps

1. **Review this roadmap** with team
2. **Get legal review** of privacy policy
3. **Set up dev environment** (Supabase dev project, Sentry dev, Mixpanel dev)
4. **Create GitHub project board** with tasks from each phase
5. **Start Phase 0** (fix immediate onboarding bugs)

---

**Last Updated:** 2025-11-17
**Document Owner:** Engineering Team
**Review Cadence:** Weekly during implementation

