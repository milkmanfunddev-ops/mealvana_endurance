# Authentication & Startup Flow Improvements

## Executive Summary

This document consolidates findings from a comprehensive analysis of the authentication, onboarding, and app startup flows. The analysis identified several architectural issues and proposes a phased improvement roadmap.

**Key Issue Identified**: After a user logs out and restarts the app, a NEW anonymous user is created while the OLD user's local data is preserved. This creates data isolation issues and a confusing user experience where the user must go through onboarding again even though their data exists locally.

---

## Analysis Findings

### 1. Log Analysis - Current Behavior

**Observed Flow** (from `/docs/logs.txt`):

```
1. User e92cb452-... performs pre-logout sync
2. User signs out - "keeping local data for offline access"
3. App startup creates NEW anonymous user: 1b81c083-...
4. "No remote user profile found - user may need to complete onboarding"
5. User goes through onboarding again
6. Edge function upload fails for new anonymous user
```

**Problems Identified**:
- Old user's local data preserved but inaccessible to new anonymous user
- User forced to re-onboard despite existing data
- Edge function failures on anonymous user data upload
- No way to recover/access previous account data

### 2. Authentication Architecture

**Current Flow**:
```
App Launch → Check Session → Create Anonymous if None → Check Onboarding → Route
```

**Key Files**:
- `lib/features/app_startup/application/app_startup_service.dart`
- `lib/features/auth/application/auth_service.dart`
- `lib/features/settings/presentation/providers/settings_controller.dart`

**Logout Behavior** (`settings_controller.dart:499-541`):
- Pre-logout sync to Supabase
- Call `auth.signOut()`
- **Local data NOT cleared** (offline-first design)
- Riverpod providers invalidated

**Issue**: When app restarts after logout, a new anonymous session is created, but old local data remains orphaned.

### 3. Onboarding Flow

**Current Flow**:
```
Welcome → PageView (Profile/Sports/Diet/Allergies/Foods) → Post-Onboarding Auth → Main
```

**Key Files**:
- `lib/features/onboarding/presentation/providers/onboarding_controller.dart`
- `lib/features/onboarding/presentation/screens/onboarding_pageview_screen.dart`

**Issues**:
- Onboarding data cached in-memory only (lost on app restart)
- No partial save/resume capability
- User must complete entire flow in one session

### 4. Anonymous User Creation

**Trigger Points**:
1. App startup when no session exists (`app_startup_service.dart:337-397`)
2. Onboarding if no auth user (`auth_service.dart:36-185`)

**Anonymous User Characteristics**:
- `auth_provider: 'anonymous'`
- `is_anonymous: true`
- `auth_user_id: NULL` until linked
- Session stored in secure storage (Keychain/KeyStore)

### 5. Database Schema Issues

**Problems Identified**:
- Dual identifier system (`device_id` + `user_id`) causes confusion
- Only 2 of 11 user-scoped tables have RLS policies
- No clear data ownership during auth transitions
- Local Drift database doesn't isolate per user

**Key Tables Affected**:
- `users`, `activities`, `events`, `food_preferences`, `user_foods`, `carb_loading_plans`

### 6. Missing Features

- **No Logout Button in Settings** (user must dig for it)
- **No "Clear Data" Option** for complete reset
- **No Account Recovery Flow** for orphaned data
- **No Session Management UI** to see/manage connected accounts

---

## Root Cause Analysis

### Primary Issue: Data Preservation Without User Isolation

**Current Design**:
```dart
// settings_controller.dart signOut()
await supabaseClient.auth.signOut();
// Local data preserved for "offline access"
```

**Problem**: "Offline access" only works if the SAME user signs back in. When a NEW anonymous user is created:
1. Old data exists locally but query filters exclude it
2. User sees "needs onboarding" state
3. Previous data is inaccessible

### Secondary Issue: No Explicit User Switching Logic

The app has no concept of "switching users" or "clearing current user data". It assumes:
- Single user per device
- User will always re-authenticate as same identity
- Anonymous users will always link to permanent account

---

## Recommendations

### Immediate Actions (This Week)

#### 1. Add Logout Button to Settings Screen

**Location**: `lib/features/settings/presentation/screens/settings_screen.dart`

**Implementation**:
```dart
ListTile(
  leading: Icon(Icons.logout),
  title: Text('Sign Out'),
  onTap: () async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out'),
        content: Text('Your data will be preserved locally. You can sign back in anytime.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Sign Out')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(settingsControllerProvider.notifier).signOut();
      context.go('/welcome');
    }
  },
),
```

#### 2. Add Clear All Data Option

**Purpose**: Complete reset for troubleshooting

**Implementation**:
```dart
// In AppDatabase
Future<void> deleteEverything() {
  return transaction(() async {
    await customStatement('PRAGMA foreign_keys = OFF');
    for (final table in allTables) {
      await delete(table).go();
    }
    await customStatement('PRAGMA foreign_keys = ON');
  });
}

// In settings_controller.dart
Future<void> clearAllData() async {
  final db = ref.read(appDatabaseProvider);
  await db.deleteEverything();
  await ref.read(supabaseProvider).auth.signOut();
  ref.invalidateSelf();
}
```

#### 3. Add Re-Login Detection

**Purpose**: Detect when same user signs back in and recover data

**Implementation** in `app_startup_service.dart`:
```dart
// After anonymous session created
final localProfiles = await database.getAllUserProfiles();
if (localProfiles.isNotEmpty) {
  // Show "Welcome back!" dialog with option to recover previous account
  showAccountRecoveryDialog(localProfiles);
}
```

### Short-Term Actions (This Month)

#### 4. Implement Proper User Switching

**Options**:
- Option A: Clear local data on logout (simpler, matches user expectations)
- Option B: Keep data isolated per user (complex, multi-user support)

**Recommended**: Option A with confirmation dialog

```dart
Future<void> signOut({bool clearLocalData = true}) async {
  await syncCoordinator.sync(trigger: SyncTrigger.preLogout);
  await auth.signOut();

  if (clearLocalData) {
    await database.deleteEverything();
    await secureStorage.deleteAll();
  }

  ref.invalidateSelf();
}
```

#### 5. Add Account Information Section in Settings

Display current auth state:
```
Account: john@example.com (Google)
Member since: Dec 2024
Data synced: 2 minutes ago

[Manage Account] [Sign Out]
```

#### 6. Improve Onboarding Resume Capability

Save partial onboarding state to secure storage:
```dart
// After each onboarding step
await secureStorage.write(
  key: 'onboarding_progress',
  value: jsonEncode({
    'step': currentStep,
    'userData': cachedUserData,
    'timestamp': DateTime.now().toIso8601String(),
  }),
);
```

### Medium-Term Actions (Next Quarter)

#### 7. Implement RLS Policies

All user-scoped tables need proper RLS:
```sql
CREATE POLICY "users_select_own" ON users FOR SELECT
USING (auth.uid() = auth_user_id);
```

#### 8. Standardize on auth_user_id

Remove redundant `device_id` references from user-scoped tables.

#### 9. Add Auth State Logging/Audit

Track auth transitions for debugging:
```sql
CREATE TABLE auth_transitions (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  from_provider TEXT,
  to_provider TEXT NOT NULL,
  transition_type TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Design Considerations for Logout UX

### Option 1: Simple Logout (Recommended)

**Behavior**:
- Pre-logout sync to Supabase
- Clear local database
- Create new anonymous session
- Redirect to Welcome screen

**Pros**: Clean slate, matches user expectations
**Cons**: Must re-sync if same user logs back in

### Option 2: Preserve Data Logout

**Behavior**:
- Pre-logout sync to Supabase
- Keep local data
- Show login options on Welcome screen
- If same user logs in, data available immediately

**Pros**: Faster re-login experience
**Cons**: Complex user switching, data confusion possible

### Option 3: Account Switcher (Future)

**Behavior**:
- Support multiple accounts
- Each account has isolated local database
- Quick switch between accounts

**Pros**: Power user feature
**Cons**: High complexity, niche use case

---

## Files Requiring Changes

### Core Auth Files
- `lib/features/settings/presentation/screens/settings_screen.dart` - Add logout button
- `lib/features/settings/presentation/providers/settings_controller.dart` - Enhance signOut
- `lib/shared/database/app_database.dart` - Add deleteEverything()
- `lib/features/app_startup/application/app_startup_service.dart` - Add account recovery

### New Files to Create
- `lib/features/settings/presentation/widgets/account_info_section.dart`
- `lib/features/auth/presentation/widgets/account_recovery_dialog.dart`

### Documentation to Update
- `docs/technical/README.md` - Add auth flow documentation
- `docs/database/README.md` - Document RLS requirements
- `CLAUDE.md` - Update with new patterns

---

## Related Documentation

- [Roadmap](./roadmap.md) - Prioritized implementation plan
- [Auth Flow Diagrams](./auth-flows.md) - Visual flow documentation
- [RLS Implementation](./rls-implementation.md) - Security policy details

---

## Summary

The current authentication architecture works but has user experience gaps that cause confusion during logout/re-login scenarios. The recommended approach is:

1. **Immediate**: Add visible logout button with data clearing
2. **Short-term**: Implement account info section and recovery options
3. **Medium-term**: Harden with RLS and proper data isolation

This approach prioritizes user clarity while maintaining the offline-first architecture that makes the app valuable.
