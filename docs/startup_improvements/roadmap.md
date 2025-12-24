# Authentication & Startup Improvements Roadmap

## Overview

This roadmap outlines the implementation plan for improving the authentication, startup, and logout flows in Mealvana Endurance. Tasks are organized by priority and dependency.

---

## Phase 1: Critical UX Fixes (Immediate)

### 1.1 Add Logout Button to Settings Screen

**Priority**: P0 - Critical
**Effort**: 2-4 hours
**Dependencies**: None

**Description**: Users currently have no visible way to log out. Add a clearly visible logout option.

**Implementation Steps**:
1. Add `LogoutSection` widget to settings screen
2. Implement confirmation dialog
3. Call existing `signOut()` method in settings controller
4. Navigate to welcome screen after logout

**Files to Modify**:
- `lib/features/settings/presentation/screens/settings_screen.dart`

**Acceptance Criteria**:
- [ ] Logout button visible in settings
- [ ] Confirmation dialog shown before logout
- [ ] User redirected to welcome screen after logout
- [ ] Pre-logout sync completes before sign out

---

### 1.2 Clear Local Data on Logout

**Priority**: P0 - Critical
**Effort**: 4-6 hours
**Dependencies**: 1.1

**Description**: Currently logout preserves local data, causing confusion when a new anonymous user is created. Implement clean logout.

**Implementation Steps**:
1. Add `deleteEverything()` method to AppDatabase
2. Update settings controller `signOut()` to clear data
3. Add option for "Keep data" vs "Clear data" logout
4. Test sync + clear + new session flow

**Files to Modify**:
- `lib/shared/database/app_database.dart`
- `lib/features/settings/presentation/providers/settings_controller.dart`

**Acceptance Criteria**:
- [ ] `deleteEverything()` method clears all user tables
- [ ] Logout clears local database by default
- [ ] New anonymous session created cleanly
- [ ] User sees welcome/onboarding without old data

---

### 1.3 Add Account Info Section

**Priority**: P1 - High
**Effort**: 3-4 hours
**Dependencies**: None

**Description**: Show current authentication state in settings so users understand their account status.

**Implementation Steps**:
1. Create `AccountInfoSection` widget
2. Display email/provider from current user profile
3. Show sync status (last synced timestamp)
4. Add "Manage Account" button (placeholder for future)

**Files to Create**:
- `lib/features/settings/presentation/widgets/account_info_section.dart`

**Files to Modify**:
- `lib/features/settings/presentation/screens/settings_screen.dart`

**Acceptance Criteria**:
- [ ] Account email/provider displayed
- [ ] "Anonymous" shown for guest users
- [ ] Last sync time visible
- [ ] Sign out button in section

---

## Phase 2: Improved Auth Recovery

### 2.1 Account Recovery Detection

**Priority**: P1 - High
**Effort**: 6-8 hours
**Dependencies**: Phase 1

**Description**: When a new anonymous user is created but local data exists from a previous session, offer recovery options.

**Implementation Steps**:
1. Check for existing profiles in local DB during app startup
2. Show recovery dialog if profiles found but current user is new
3. Options: "Continue as Guest" or "Sign In to Recover"
4. If sign in, match auth_user_id to recover data

**Files to Modify**:
- `lib/features/app_startup/application/app_startup_service.dart`
- `lib/features/app_startup/presentation/widgets/app_startup_widget.dart`

**Files to Create**:
- `lib/features/auth/presentation/widgets/account_recovery_dialog.dart`

**Acceptance Criteria**:
- [ ] Recovery dialog shown when orphaned data exists
- [ ] User can choose to sign in or continue as guest
- [ ] Sign in recovers previous data
- [ ] "Continue as guest" clears old data

---

### 2.2 Improve Sign-In Flow After Logout

**Priority**: P2 - Medium
**Effort**: 4-6 hours
**Dependencies**: 2.1

**Description**: When user signs back in with same account after logout, restore their data from Supabase seamlessly.

**Implementation Steps**:
1. Detect if signing in as previous user
2. Fetch full profile from Supabase
3. Sync all child tables (activities, events, etc.)
4. Show "Welcome back!" confirmation

**Files to Modify**:
- `lib/features/auth/application/email_auth_service.dart`
- `lib/features/auth/application/oauth_service.dart`
- `lib/features/auth/data/user_repository.dart`

**Acceptance Criteria**:
- [ ] Previous data restored on sign-in
- [ ] All child tables synced
- [ ] User sees their activities/events
- [ ] Sync status indicator during restore

---

### 2.3 Onboarding Resume Capability

**Priority**: P2 - Medium
**Effort**: 6-8 hours
**Dependencies**: None

**Description**: Save onboarding progress to secure storage so users can resume if app is closed mid-onboarding.

**Implementation Steps**:
1. Save onboarding state after each step
2. Check for saved state on welcome screen
3. Offer "Continue where you left off?" option
4. Load cached data into onboarding controller

**Files to Modify**:
- `lib/features/onboarding/presentation/providers/onboarding_controller.dart`
- `lib/features/onboarding/presentation/screens/welcome_screen.dart`

**Acceptance Criteria**:
- [ ] Onboarding progress saved to secure storage
- [ ] Resume option shown on welcome screen
- [ ] Previous selections pre-filled
- [ ] Can also choose "Start Fresh"

---

## Phase 3: Data Integrity & Security

### 3.1 Implement RLS Policies

**Priority**: P1 - High (Security)
**Effort**: 8-12 hours
**Dependencies**: None

**Description**: Add Row Level Security policies to all user-scoped tables in Supabase.

**Implementation Steps**:
1. Create RLS policy SQL migration
2. Add policies for: users, activities, events, food_preferences, user_foods, carb_loading_*
3. Test with anonymous and authenticated users
4. Verify existing Edge Functions still work with service role

**Files to Create**:
- `supabase/migrations/YYYYMMDD_add_rls_policies.sql`

**Tables Requiring Policies**:
- `users`
- `activities`
- `events`
- `food_preferences`
- `user_foods`
- `carb_loading_plans`
- `carb_loading_user_foods`

**Acceptance Criteria**:
- [ ] All user-scoped tables have RLS enabled
- [ ] Users can only read/write own data
- [ ] Edge Functions work with service role bypass
- [ ] Tests confirm security

---

### 3.2 Standardize User Identification

**Priority**: P2 - Medium
**Effort**: 6-8 hours
**Dependencies**: 3.1

**Description**: Remove redundant `device_id` columns from user-scoped tables, standardize on `user_id` only.

**Implementation Steps**:
1. Audit all tables using device_id
2. Migrate data to use user_id only
3. Update Drift table definitions
4. Update repository queries

**Files to Modify**:
- `lib/shared/database/tables/*.dart`
- `lib/features/*/data/*_repository.dart`
- Database migrations

**Acceptance Criteria**:
- [ ] device_id removed from user_foods, carb_loading_user_foods
- [ ] All queries use user_id
- [ ] Drift schema updated
- [ ] Migration tested

---

### 3.3 Add Auth Transition Audit Log

**Priority**: P3 - Low
**Effort**: 4-6 hours
**Dependencies**: 3.1

**Description**: Log all auth state transitions for debugging and support.

**Implementation Steps**:
1. Create auth_transitions table in Supabase
2. Log: sign_in, sign_out, link_account, token_refresh
3. Include user_id, provider, timestamp
4. Add viewing UI in developer settings

**Files to Create**:
- `supabase/migrations/YYYYMMDD_add_auth_transitions.sql`

**Acceptance Criteria**:
- [ ] Auth events logged to database
- [ ] Events visible in Supabase dashboard
- [ ] Helps debug user issues

---

## Phase 4: Polish & Future Features

### 4.1 Add deleteEverything() Method

**Priority**: P1 - High
**Effort**: 2 hours
**Dependencies**: None

**Description**: Implement Drift-recommended method to clear all tables atomically.

**Implementation**:
```dart
Future<void> deleteEverything() {
  return transaction(() async {
    await customStatement('PRAGMA foreign_keys = OFF');
    for (final table in allTables) {
      await delete(table).go();
    }
    await customStatement('PRAGMA foreign_keys = ON');
  });
}
```

**Files to Modify**:
- `lib/shared/database/app_database.dart`

---

### 4.2 Session Timeout Handling

**Priority**: P3 - Low
**Effort**: 4-6 hours
**Dependencies**: Phase 1

**Description**: Handle expired sessions gracefully with user notification.

**Implementation Steps**:
1. Detect auth token expiration
2. Show "Session expired - please sign in again" dialog
3. Preserve local data if possible
4. Redirect to login flow

---

### 4.3 Account Deletion Flow

**Priority**: P3 - Low (GDPR compliance)
**Effort**: 8-12 hours
**Dependencies**: 3.1

**Description**: Allow users to completely delete their account and all data.

**Implementation Steps**:
1. Add "Delete Account" button in settings
2. Confirmation with password/re-auth
3. Call delete-user Edge Function
4. Clear local data
5. Create new anonymous session

---

## Summary Timeline

| Phase | Description | Effort | Priority |
|-------|-------------|--------|----------|
| **Phase 1** | Critical UX Fixes | 1-2 days | P0/P1 |
| **Phase 2** | Auth Recovery | 2-3 days | P1/P2 |
| **Phase 3** | Data Integrity | 2-3 days | P1/P2 |
| **Phase 4** | Polish | 2-3 days | P2/P3 |

**Recommended Order**:
1. 1.1, 1.2, 4.1 (logout + clear data) - **Start here**
2. 1.3 (account info section)
3. 3.1 (RLS policies - security critical)
4. 2.1, 2.2 (account recovery)
5. Remaining items by priority

---

## Quick Wins (Can Do Today)

1. **Add logout button to settings** - Just add UI and call existing signOut()
2. **Add deleteEverything() to AppDatabase** - 10 lines of code
3. **Show account info in settings** - Display current user email/provider

---

## Testing Requirements

### Manual Testing Checklist

- [ ] Fresh install → anonymous user → onboarding → main screen
- [ ] Sign in with Google → verify data syncs
- [ ] Sign out → verify data cleared → verify welcome screen
- [ ] Sign back in → verify data restored from Supabase
- [ ] Kill app during onboarding → restart → verify resume works
- [ ] Offline sign out → online sign in → verify sync
- [ ] Account linking (anonymous → Google) → verify ID preserved

### Automated Testing Needs

- [ ] RLS policy tests (SQL)
- [ ] Auth state transition tests
- [ ] Database clear/restore tests
- [ ] Sync coordinator tests for logout trigger

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2024-12-23 | Clear data on logout by default | Matches user expectations, simpler than multi-user |
| 2024-12-23 | Add visible logout button | Users need obvious way to sign out |
| 2024-12-23 | Implement RLS before production | Security requirement for user data isolation |
| 2024-12-23 | Preserve offline-first architecture | Core value proposition of the app |
