# Supabase Anonymous to OAuth Account Linking - Research Report

**Date:** 2025-11-19
**Status:** Critical Bug Identified - Solution Available
**Severity:** High - Data Loss Risk in Current Implementation

---

## Executive Summary

### The Problem

**Current Implementation:** Using `signInWithIdToken()` to link Google/Apple accounts to anonymous users
**Result:** Creates NEW user with different UUID, orphaning all anonymous user data

**Example from Production Logs:**
```
Anonymous User ID: c5f84ee0-cf42-40f4-abea-8eeb9b8f8919
After Google Sign-In: 7ca1fed1-51e6-4fc1-ac97-7d63e3aa55ec ❌
Result: User onboarding data lost
```

### The Solution

**Correct Method:** Use `supabase.auth.linkIdentity()` instead of `signInWithIdToken()`
**Result:** Preserves user UUID, all data remains accessible
**Requirement:** Enable "Manual Linking" in Supabase Dashboard

**Status:** ✅ Available in `supabase_flutter` v2.1.0+ (you have v2.8.5)

---

## Root Cause Analysis

### Why signInWithIdToken() Creates New Users

`signInWithIdToken()` is an **authentication method**, not a linking method:

1. **Purpose:** Sign in to existing account OR create new account
2. **Behavior:**
   - Validates OAuth token with provider (Google/Apple)
   - Searches for existing user with that OAuth identity
   - If NOT found → Creates brand new user with new UUID
   - Returns the new user session

3. **Why it fails for linking:**
   - Anonymous user exists with UUID `abc-123`
   - Call `signInWithIdToken()` with Google token
   - Supabase doesn't find Google identity in system
   - Creates new user with UUID `xyz-789`
   - All data on `abc-123` is now orphaned

### Why linkIdentity() Works

`linkIdentity()` is a **linking method** specifically designed for this:

1. **Purpose:** Add OAuth identity to existing authenticated user
2. **Behavior:**
   - Requires active user session (anonymous or permanent)
   - Validates OAuth token with provider
   - Checks if identity is already linked to another user
   - If available → Links identity to current user, **preserves UUID**
   - Returns updated user with new identity attached

3. **Why it succeeds:**
   - Anonymous user exists with UUID `abc-123`
   - Call `linkIdentity()` with Google token
   - Supabase links Google identity to user `abc-123`
   - User remains `abc-123`, now has Google identity
   - All data remains accessible

---

## Official Supabase Recommendations

### Configuration Required

**Step 1: Enable Manual Linking**
- Navigate to: [Supabase Dashboard](https://supabase.com/dashboard/project/wvmvsodrvbkxfydabqed) → Authentication → Settings
- Find: "Enable Manual Linking" toggle
- **Turn it ON**
- Note: This is OFF by default for security

**Step 2: Enable Anonymous Sign-Ins** (Already Done ✅)
- Same location: Authentication → Settings
- Find: "Allow anonymous sign-ins"
- Should already be ON

**Step 3: Enable CAPTCHA** (Security Best Practice)
- Prevents bots from creating unlimited anonymous users
- Required for production use of anonymous auth

### Code Implementation Patterns

#### Pattern 1: OAuth Linking (Google/Apple)

**Current (Incorrect):**
```dart
// ❌ WRONG - Creates new user
await supabase.auth.signInWithIdToken(
  provider: OAuthProvider.google,
  idToken: googleIdToken,
  accessToken: googleAccessToken,
);
```

**Correct:**
```dart
// ✅ CORRECT - Links to existing user
try {
  final response = await supabase.auth.linkIdentity(
    provider: OAuthProvider.google,
    token: googleIdToken,           // Note: parameter name is "token" not "idToken"
    accessToken: googleAccessToken, // Required for Google
  );

  // Success! User ID preserved
  print('Linked successfully: ${response.user?.id}');

} on AuthException catch (e) {
  if (e.message.contains('already linked')) {
    // This Google account exists on another user
    // See "Known Limitations" section for handling
    print('Account already exists');
  } else {
    rethrow;
  }
}
```

#### Pattern 2: Email/Password Conversion

**For email/password, use `updateUser()`:**

```dart
// Convert anonymous user to email/password
if (supabase.auth.currentUser?.isAnonymous == true) {
  final response = await supabase.auth.updateUser(
    UserAttributes(
      email: email,
      password: password,
    ),
  );

  // User ID preserved, no longer anonymous
  print('Converted to email: ${response.user?.id}');
}
```

---

## Known Limitations & Bugs

### Critical Bug: GitHub Issue #1525

**Title:** "Anonymous user identity not linking"
**Status:** Open (as of June 2024)
**Impact:** HIGH - Blocks legitimate user flows

**Scenario:**
1. User installs app, creates account with Google → User ID: `user-123`
2. User uninstalls app
3. User reinstalls app → Creates anonymous user → User ID: `anon-456`
4. User tries to link Google account → **ERROR**: "Identity is already linked to another user"

**Expected:** Anonymous user `anon-456` merges with existing `user-123`
**Actual:** Linking fails because Google identity belongs to `user-123`

**Workaround:** None official. Requires data migration (see Solutions section)

### Other Limitations

1. **Cannot pre-check if OAuth identity exists**
   - You must attempt linking to discover if account exists
   - No API to query "does this Google email have an account?"

2. **Automatic linking only works by email**
   - Supabase auto-links accounts with same verified email
   - Does NOT apply to anonymous users (no email)

3. **No credential returned in error**
   - Firebase provides the existing credential in error object
   - Supabase only provides error message
   - Cannot automatically sign in to existing account

---

## Recommended Solutions

### Solution 1: Use linkIdentity() + Handle Errors (RECOMMENDED)

**Best for:** MVP and fast iteration
**Complexity:** Low
**Time:** 4-6 hours

**Implementation:**

```dart
// lib/features/auth/application/oauth_service.dart

/// Link Google account using native SDK + linkIdentity
Future<void> linkGoogleAccount() async {
  state = const AsyncLoading();

  state = await AsyncValue.guard(() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('No active auth session');
    }

    final anonymousUserId = currentUser.id;

    // Get Google credentials from native SDK
    final googleSignIn = _getGoogleSignIn();
    await googleSignIn.signOut(); // Force account picker

    final GoogleSignInAccount? account = await googleSignIn.signIn();
    if (account == null) {
      throw Exception('Google Sign-In cancelled');
    }

    final GoogleSignInAuthentication auth = await account.authentication;

    if (auth.idToken == null) {
      throw Exception('No ID token received from Google');
    }

    try {
      // Use linkIdentity instead of signInWithIdToken
      final response = await _supabase.auth.linkIdentity(
        provider: OAuthProvider.google,
        token: auth.idToken!,        // Note: "token" not "idToken"
        accessToken: auth.accessToken, // Optional but recommended for Google
      );

      // Verify user ID preserved
      if (response.user?.id != anonymousUserId) {
        _logger.error('USER ID CHANGED during linking');
        throw Exception('User ID changed unexpectedly');
      }

      // Update local profile
      final userRepo = await ref.read(userRepositoryProvider.future);
      await userRepo.updateAuthProvider(
        authProvider: 'google',
        isAnonymous: false,
      );

      _logger.info('Google account linked successfully');
      await _analytics.track('auth_google_native_linked');

    } on AuthException catch (e) {
      if (e.message.contains('already linked')) {
        // This Google account already exists
        _logger.warning('Google account already exists');
        await _analytics.track('auth_google_account_exists');

        // Throw custom exception to show user dialog
        throw AccountAlreadyExistsException(
          'This Google account is already registered.',
          email: account.email,
        );
      }
      rethrow;
    }
  });

  if (state.hasError) {
    _logger.error('Google linking failed', error: state.error);
    throw state.error!;
  }
}
```

**UI Handling:**

```dart
// lib/features/auth/presentation/providers/post_onboarding_auth_controller.dart

Future<void> handleGoogleSignIn() async {
  state = const AsyncLoading();

  state = await AsyncValue.guard(() async {
    final oauthService = ref.read(oAuthServiceProvider.notifier);

    try {
      await oauthService.linkGoogleAccount();

      // Success! Navigate to main app
      _router.go('/home');

    } on AccountAlreadyExistsException catch (e) {
      // Show dialog: "You already have an account with {email}"
      final choice = await _showAccountExistsDialog(e.email);

      if (choice == AccountExistsChoice.signIn) {
        // User wants to sign in to existing account
        // WARNING: This will orphan anonymous data
        await _signInToExistingGoogleAccount();
      } else if (choice == AccountExistsChoice.useEmail) {
        // User will create email/password instead
        _router.go('/auth/email-signup');
      } else {
        // User cancelled
        return;
      }
    }
  });
}

enum AccountExistsChoice {
  signIn,   // Sign in to existing Google account (lose anonymous data)
  useEmail, // Use email/password instead
  cancel,   // Stay anonymous
}
```

**Pros:**
- ✅ Works for new Google accounts (majority case)
- ✅ User ID preserved (no data loss)
- ✅ Handles "already exists" gracefully
- ✅ Fast to implement

**Cons:**
- ⚠️ Requires user decision when account exists
- ⚠️ May still lose data if user chooses to sign in to existing

---

### Solution 2: linkIdentity() + Data Migration (COMPLETE)

**Best for:** Production apps, best user experience
**Complexity:** Medium
**Time:** 2-3 days

**Additional Components:**

**A. Edge Function for Data Migration**

```typescript
// supabase/functions/migrate-anonymous-data/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const { fromUserId, toUserId } = await req.json()

    // Validate request
    const authHeader = req.headers.get('Authorization')!
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user } } = await supabaseClient.auth.getUser()

    // Security: Verify user owns the target account
    if (user?.id !== toUserId) {
      return new Response('Unauthorized', { status: 403 })
    }

    // Use service role for migration (bypasses RLS)
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Call PostgreSQL function for atomic migration
    const { error } = await adminClient.rpc('migrate_user_data', {
      from_user_id: fromUserId,
      to_user_id: toUserId,
    })

    if (error) {
      console.error('Migration failed:', error)
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('Migration error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
```

**B. PostgreSQL Function**

```sql
-- Create migration function
CREATE OR REPLACE FUNCTION migrate_user_data(
  from_user_id UUID,
  to_user_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Migrate all user-related tables atomically

  -- 1. Update user profile (keep latest, merge metadata)
  UPDATE users
  SET
    auth_user_id = to_user_id,
    auth_provider = COALESCE((SELECT auth_provider FROM users WHERE id = to_user_id), auth_provider),
    is_anonymous = false,
    updated_at = NOW()
  WHERE id = from_user_id;

  -- 2. Migrate food preferences
  UPDATE food_preferences
  SET user_id = to_user_id
  WHERE user_id = from_user_id;

  -- 3. Migrate nutrition plans
  UPDATE nutrition_plans
  SET user_id = to_user_id
  WHERE user_id = from_user_id;

  -- 4. Migrate activities
  UPDATE activities
  SET user_id = to_user_id
  WHERE user_id = from_user_id;

  -- 5. Migrate calendar events
  UPDATE calendar_events
  SET user_id = to_user_id
  WHERE user_id = from_user_id;

  -- 6. Update device_id mapping (keep reference)
  UPDATE users
  SET device_id = (SELECT device_id FROM users WHERE id = from_user_id)
  WHERE id = to_user_id
  AND device_id IS NULL;

  -- 7. Soft-delete the anonymous user (for audit trail)
  UPDATE users
  SET
    deleted_at = NOW(),
    migrated_to = to_user_id
  WHERE id = from_user_id;

  -- Or hard delete if preferred:
  -- DELETE FROM users WHERE id = from_user_id;

END;
$$;
```

**C. Flutter Integration**

```dart
Future<void> handleAccountExists(String googleEmail) async {
  final anonymousUserId = _supabase.auth.currentUser!.id;

  // Show loading
  _showDialog('Merging your data...');

  try {
    // Sign in to existing Google account
    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: googleIdToken,
      accessToken: googleAccessToken,
    );

    final newUserId = _supabase.auth.currentUser!.id;

    // Trigger data migration
    final result = await _supabase.functions.invoke(
      'migrate-anonymous-data',
      body: {
        'fromUserId': anonymousUserId,
        'toUserId': newUserId,
      },
    );

    if (result.data['success'] == true) {
      // Success! All data migrated
      _showSuccess('Your data has been merged!');
      _router.go('/home');
    } else {
      throw Exception('Migration failed: ${result.data['error']}');
    }

  } catch (e) {
    _showError('Failed to merge accounts. Please contact support.');
    _logger.error('Migration failed', error: e);
  }
}
```

**Pros:**
- ✅ Best user experience (no data loss ever)
- ✅ Handles all edge cases
- ✅ Atomic transaction (all or nothing)
- ✅ Works for returning users

**Cons:**
- ⚠️ Requires Edge Function deployment
- ⚠️ More complex testing
- ⚠️ Need to handle migration failures

---

### Solution 3: Email/Password Fallback (SIMPLE)

**Best for:** Quick workaround while building full solution
**Complexity:** Very Low
**Time:** 1-2 hours

**Implementation:**

```dart
// When OAuth linking fails, offer email/password
Future<void> handleGoogleSignIn() async {
  try {
    await oauthService.linkGoogleAccount();
  } on AccountAlreadyExistsException catch (e) {
    // Show dialog
    final useEmail = await _showDialog(
      title: 'Account Already Exists',
      message: 'This Google account is already registered. Would you like to create an email/password account instead?',
      actions: ['Use Email', 'Cancel'],
    );

    if (useEmail) {
      _router.go('/auth/email-signup');
    }
  }
}

// Email signup preserves user ID using updateUser()
Future<void> signUpWithEmail(String email, String password) async {
  if (_supabase.auth.currentUser?.isAnonymous == true) {
    // Convert anonymous to email/password
    await _supabase.auth.updateUser(
      UserAttributes(
        email: email,
        password: password,
      ),
    );
    // User ID preserved! ✅
  } else {
    // Regular signup
    await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }
}
```

**Pros:**
- ✅ Very simple implementation
- ✅ Always works (no "already exists" error)
- ✅ User ID preserved
- ✅ Good for MVP

**Cons:**
- ⚠️ Less convenient than OAuth
- ⚠️ Requires email verification (optional)
- ⚠️ Doesn't solve OAuth linking

---

## Implementation Roadmap

### Phase 1: Immediate Fix (This Week)

**Goal:** Stop creating new users, preserve user IDs

**Tasks:**
1. ✅ Enable "Manual Linking" in Supabase Dashboard
2. ✅ Replace `signInWithIdToken()` with `linkIdentity()` in `oauth_service.dart`
3. ✅ Update email signup to use `updateUser()` for anonymous users
4. ✅ Add error handling for "already linked" exception
5. ✅ Test with fresh anonymous user → Google link (should work)

**Expected Outcome:**
- New users can link Google accounts successfully
- User IDs preserved
- Data remains accessible

**Blocking Issues:**
- Returning users with existing Google accounts still fail (see Phase 2)

### Phase 2: Error Handling (Next Sprint)

**Goal:** Handle "account already exists" gracefully

**Tasks:**
1. ✅ Create custom `AccountAlreadyExistsException`
2. ✅ Add UI dialog for account conflict
3. ✅ Offer choices: sign in existing OR use email/password
4. ✅ Track analytics for how often this occurs
5. ✅ Test with existing Google account → reinstall → link attempt

**Expected Outcome:**
- Users get clear explanation when account exists
- Can choose to sign in or use alternative method
- Analytics show how often this occurs

### Phase 3: Data Migration (Next Month)

**Goal:** Zero data loss, even for returning users

**Tasks:**
1. ✅ Create PostgreSQL migration function
2. ✅ Create Edge Function for migration orchestration
3. ✅ Implement client-side migration trigger
4. ✅ Add rollback logic for failed migrations
5. ✅ Test migration with production-like data
6. ✅ Monitor migration success rates

**Expected Outcome:**
- All users can link Google accounts
- Data automatically migrates from anonymous to OAuth user
- No data loss in any scenario

---

## Testing Checklist

### Test Case 1: Fresh User + OAuth Link ✅

**Scenario:** New user, never used app before

```
1. Launch app → Creates anonymous user
2. Complete onboarding (save preferences, food data)
3. Tap "Continue with Google"
4. Select Google account
5. ✅ Verify user ID unchanged
6. ✅ Verify all data still accessible
7. ✅ Verify Settings shows "Signed in with Google"
8. ✅ Verify can sign out and back in
```

### Test Case 2: Fresh User + Email/Password ✅

**Scenario:** New user using email instead of OAuth

```
1. Launch app → Creates anonymous user
2. Complete onboarding
3. Tap "Sign up with Email"
4. Enter email and password
5. ✅ Verify user ID unchanged
6. ✅ Verify all data accessible
7. ✅ Verify can sign in after sign out
```

### Test Case 3: Returning User (Existing Google Account) ⚠️

**Scenario:** User previously had Google account, reinstalled app

```
1. Install app, create Google account → User ID: abc-123
2. Save some data
3. Uninstall app
4. Reinstall app → Creates anonymous user → User ID: xyz-789
5. Complete onboarding (new data)
6. Tap "Continue with Google"
7. ⚠️ Error: "Identity already linked"
8. ✅ Show dialog with options
9. If user chooses "Sign In":
   - ✅ Trigger data migration from xyz-789 → abc-123
   - ✅ Verify all data accessible under abc-123
10. If user chooses "Use Email":
   - ✅ Navigate to email signup
   - ✅ User ID xyz-789 preserved
```

### Test Case 4: Offline Linking Attempt ⚠️

**Scenario:** User tries to link while offline

```
1. Create anonymous user
2. Turn off internet
3. Tap "Continue with Google"
4. ✅ Show appropriate error message
5. ✅ User remains anonymous
6. ✅ Data not corrupted
```

---

## Security Considerations

### 1. Enable CAPTCHA for Anonymous Sign-Ins

**Risk:** Bots creating unlimited anonymous users
**Mitigation:**
- Supabase Dashboard → Authentication → Settings
- Enable "Automatic CAPTCHA for anonymous sign-ins"
- Use Cloudflare Turnstile (free, privacy-friendly)

### 2. Automatic Anonymous User Cleanup

**Risk:** Database filled with abandoned anonymous users
**Mitigation:**
- Supabase Dashboard → Authentication → Settings
- Configure "Automatic cleanup of anonymous users"
- Recommended: 30 days for anonymous users

### 3. Service Role Key Protection

**Risk:** Edge Function exposes service role key
**Mitigation:**
- Never expose service role key to client
- Use Edge Functions for all privileged operations
- Validate user JWT in Edge Functions

### 4. Data Migration Validation

**Risk:** User A migrates user B's data
**Mitigation:**
- Always validate JWT in Edge Function
- Verify user owns the target account
- Use `SECURITY DEFINER` functions carefully

### 5. RLS Policy Bypass

**Risk:** Migration function bypasses Row Level Security
**Mitigation:**
- Use `SECURITY DEFINER` only for migration function
- Add extensive logging
- Monitor for abuse patterns

---

## Monitoring & Analytics

### Key Metrics to Track

1. **Linking Success Rate**
   - `auth_google_native_linked` / `auth_google_native_started`
   - Target: >95%

2. **"Already Exists" Rate**
   - `auth_google_account_exists` / `auth_google_native_started`
   - Indicates how often users reinstall

3. **Migration Success Rate** (Phase 3)
   - `data_migration_success` / `data_migration_started`
   - Target: 100%

4. **User Choice Distribution**
   - When account exists: Sign In vs Use Email vs Cancel
   - Helps prioritize UX improvements

### Alerting

Set up alerts for:
- Linking failure rate >5%
- Migration failures (any)
- Anonymous user creation spike
- "Already exists" error spike

---

## Cost Implications

### Edge Functions
- Free tier: 500,000 invocations/month
- Your usage: Estimated <1,000/month
- Cost: $0

### Database Operations
- Migrations are single transactions
- Minimal impact on database performance
- Cost: Negligible

### Authentication
- Anonymous users count toward MAU
- Linking converts anonymous → permanent (no change in MAU)
- Cost: No increase

---

## Timeline for Complete Implementation

### Week 1: Core Linking (Phase 1)
- Enable Manual Linking: 5 minutes
- Update code to use `linkIdentity()`: 2 hours
- Testing: 2 hours
- **Total: 4-5 hours**

### Week 2: Error Handling (Phase 2)
- Custom exception handling: 2 hours
- UI dialogs: 3 hours
- Analytics integration: 1 hour
- Testing: 2 hours
- **Total: 8 hours (1 day)**

### Week 3-4: Data Migration (Phase 3)
- PostgreSQL function: 4 hours
- Edge Function: 6 hours
- Client integration: 4 hours
- Testing & debugging: 8 hours
- **Total: 22 hours (3 days)**

**Grand Total: 4-5 days for complete implementation**

---

## References

### Supabase Official Documentation
- [Identity Linking Guide](https://supabase.com/docs/guides/auth/auth-identity-linking)
- [Anonymous Sign-Ins](https://supabase.com/docs/guides/auth/auth-anonymous)
- [Flutter linkIdentity API](https://supabase.com/docs/reference/dart/auth-linkidentity)
- [Auth Configuration](https://supabase.com/docs/guides/auth/general-configuration)

### Known Issues
- [GitHub Issue #1525](https://github.com/supabase/auth/issues/1525) - Anonymous linking bug

### Community Resources
- [ApparenceKit Tutorial](https://apparencekit.dev/flutter-tips/supabase-link-anonymous-user-to-authenticated/)
- [Stack Overflow](https://stackoverflow.com/questions/78682123/flutter-linking-an-anonymous-user-to-a-google-account-in-supabase)

### Package Changelogs
- [supabase_flutter Changelog](https://pub.dev/packages/supabase_flutter/changelog)

---

## Conclusion

### Current Status: Critical Bug in Production

**Problem:** Using wrong Supabase method creates new users, loses data

**Solution:** Replace `signInWithIdToken()` with `linkIdentity()`

**Timeline:** 4 hours for core fix, 4-5 days for complete solution

**Recommendation:** Implement Phase 1 immediately (this week), then schedule Phases 2-3 based on user feedback and analytics

---

**Last Updated:** 2025-11-19
**Next Review:** After Phase 1 implementation
**Owner:** Development Team
