# Native OAuth Setup Guide

Complete guide for configuring native Google Sign-In and Apple Sign-In for Mealvana Endurance.

## Overview

This guide covers the complete setup for native OAuth authentication:
- **Google Cloud Console** configuration
- **Apple Developer Portal** configuration
- **Supabase Dashboard** configuration
- **Client app** configuration (iOS & Android)
- **Environment variables** setup
- **Testing** procedures

---

## Prerequisites

**Required Access:**
- [ ] Google Cloud Platform Console (for Google OAuth)
- [ ] Apple Developer Portal (for Apple Sign-In)
- [ ] Supabase Dashboard (project: `wvmvsodrvbkxfydabqed`)
- [ ] 1Password vault (for credential storage)
- [ ] Xcode (for iOS capability configuration)

**App Identifiers:**
- **Bundle ID:** `com.milkman.mealvanaendurance`
- **Package Name:** `com.milkman.mealvanaendurance`
- **Supabase Project:** `wvmvsodrvbkxfydabqed`

---

## Part 1: Google Cloud Console Setup

### 1.1 Create OAuth Consent Screen

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create new one: "Mealvana Endurance")
3. Navigate to **APIs & Services** → **OAuth consent screen**
4. Configure consent screen:
   - **User Type:** External
   - **App name:** Mealvana Endurance
   - **User support email:** Your email
   - **Developer contact:** Your email
   - **App logo:** Upload app icon (optional)
   - **Scopes:** Add `email` and `profile`
5. Save and continue

### 1.2 Create Web OAuth Client ID

This is used for server-side token verification with Supabase.

1. Navigate to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **OAuth client ID**
3. Select **Application type:** Web application
4. Configure:
   - **Name:** Mealvana Endurance Web Client
   - **Authorized redirect URIs:** `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`
5. Click **Create**
6. **Copy the Client ID** (format: `123456789-abcdefg.apps.googleusercontent.com`)
7. **Store in 1Password** with label: `Google Web Client ID`

### 1.3 Create iOS OAuth Client ID

1. Navigate to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **OAuth client ID**
3. Select **Application type:** iOS
4. Configure:
   - **Name:** Mealvana Endurance iOS
   - **Bundle ID:** `com.milkman.mealvanaendurance`
5. Click **Create**
6. **Copy the Client ID** (format: `123456789-hijklmn.apps.googleusercontent.com`)
7. **Store in 1Password** with label: `Google iOS Client ID`

### 1.4 Create Android OAuth Client ID

This requires your app's SHA-1 fingerprint.

**Get Debug SHA-1 Fingerprint:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**Get Release SHA-1 Fingerprint:**
```bash
keytool -list -v -keystore /path/to/your/release.keystore -alias your-alias
```

**Create Android Client:**
1. Navigate to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **OAuth client ID**
3. Select **Application type:** Android
4. Configure:
   - **Name:** Mealvana Endurance Android
   - **Package name:** `com.milkman.mealvanaendurance`
   - **SHA-1 certificate fingerprint:** Paste debug SHA-1
5. Click **Create**
6. **Repeat for release SHA-1** (create separate client)
7. **Copy both Client IDs**
8. **Store in 1Password** with labels: `Google Android Client ID (Debug)` and `Google Android Client ID (Release)`

### 1.5 Summary - Google Credentials

You should now have **4 client IDs** stored in 1Password:
- ✅ Google Web Client ID
- ✅ Google iOS Client ID
- ✅ Google Android Client ID (Debug)
- ✅ Google Android Client ID (Release)

---

## Part 2: Apple Developer Portal Setup

### 2.1 Enable Sign in with Apple for App ID

1. Go to [Apple Developer Portal - Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Select **App IDs** from the dropdown
3. Find and click **`com.milkman.mealvanaendurance`**
4. Scroll to **Capabilities** section
5. Check **Sign in with Apple**
6. Click **Save**

### 2.2 Create Services ID

Required for Supabase backend integration.

1. In [Apple Developer Portal - Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Click **+** button to create new identifier
3. Select **Services IDs** → **Continue**
4. Configure:
   - **Description:** Mealvana Endurance Auth Service
   - **Identifier:** `com.milkman.mealvanaendurance.auth`
5. Check **Sign in with Apple**
6. Click **Configure** next to Sign in with Apple
7. Configure:
   - **Primary App ID:** `com.milkman.mealvanaendurance`
   - **Website URLs:**
     - **Domains:** `wvmvsodrvbkxfydabqed.supabase.co`
     - **Return URLs:** `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`
8. Click **Save** → **Continue** → **Register**

### 2.3 Generate Private Key (.p8)

⚠️ **CRITICAL:** This key can only be downloaded ONCE. Store it securely!

1. Navigate to [Keys](https://developer.apple.com/account/resources/authkeys/list)
2. Click **+** button to create new key
3. Configure:
   - **Key Name:** Mealvana Endurance Sign in with Apple
   - **Enable:** Sign in with Apple
4. Click **Configure** next to Sign in with Apple
5. Select **Primary App ID:** `com.milkman.mealvanaendurance`
6. Click **Save** → **Continue** → **Register**
7. Click **Download** to get `.p8` file
8. **Note the Key ID** (e.g., `ABC123DEFG`)
9. **Note your Team ID** (top-right corner, e.g., `XYZ456HIJK`)
10. **Store ALL THREE in 1Password:**
    - `.p8` file contents (as secure note)
    - Key ID
    - Team ID

### 2.4 Schedule Key Rotation

⚠️ **SECURITY:** Apple `.p8` keys should be rotated every 6 months.

**Add to calendar:**
- **Date:** 6 months from today
- **Task:** Rotate Apple Sign in with Apple `.p8` key
- **Steps:** Generate new key, update Supabase, revoke old key

### 2.5 Summary - Apple Credentials

You should now have in 1Password:
- ✅ Services ID: `com.milkman.mealvanaendurance.auth`
- ✅ Private Key (.p8 file contents)
- ✅ Key ID (10-character string)
- ✅ Team ID (10-character string)

---

## Part 3: Supabase Dashboard Configuration

### 3.1 Configure Google Provider

1. Go to [Supabase Dashboard - Authentication](https://supabase.com/dashboard/project/wvmvsodrvbkxfydabqed/auth/providers)
2. Find **Google** provider → Click **Edit**
3. Configure:
   - **Enable Google provider:** ✅ Enabled
   - **Client ID (for OAuth):** Paste **Google Web Client ID** from 1Password
   - **Client Secret (for OAuth):** Paste **Google Web Client Secret** from Google Cloud Console
   - **Authorized Client IDs:** Add ALL Google client IDs (comma-separated):
     ```
     WEB_CLIENT_ID,IOS_CLIENT_ID,ANDROID_DEBUG_CLIENT_ID,ANDROID_RELEASE_CLIENT_ID
     ```
     This tells Supabase to trust tokens from all our client apps.
   - **Redirect URL:** `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`
4. Click **Save**

**Why "Authorized Client IDs"?**
- Supabase validates that ID tokens come from trusted clients
- Native apps use different client IDs than the web client
- Must list ALL client IDs that will call `signInWithIdToken`

### 3.2 Configure Apple Provider

1. In [Supabase Dashboard - Authentication](https://supabase.com/dashboard/project/wvmvsodrvbkxfydabqed/auth/providers)
2. Find **Apple** provider → Click **Edit**
3. Configure:
   - **Enable Apple provider:** ✅ Enabled
   - **Services ID:** `com.milkman.mealvanaendurance.auth`
   - **Team ID:** Paste from 1Password (10-character string)
   - **Key ID:** Paste from 1Password (10-character string)
   - **Private Key (.p8):** Paste contents of `.p8` file from 1Password
   - **Redirect URL:** `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`
4. Click **Save**

### 3.3 Verify Configuration

**Test Checklist:**
- [ ] Google provider shows "Enabled" badge
- [ ] Apple provider shows "Enabled" badge
- [ ] Redirect URLs match exactly (no trailing slashes)
- [ ] All client IDs listed in "Authorized Client IDs"

---

## Part 4: Client App Configuration

### 4.1 Environment Variables

Update `.env` file with actual client IDs:

```bash
# Google OAuth Configuration (Native Sign-In)
GOOGLE_WEB_CLIENT_ID=123456789-abcdefg.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=123456789-hijklmn.apps.googleusercontent.com
GOOGLE_ANDROID_CLIENT_ID=123456789-opqrstu.apps.googleusercontent.com
```

**Important:**
- Replace placeholder values with actual client IDs from 1Password
- Use **debug** Android client ID for development builds
- Use **release** Android client ID for production builds

### 4.2 Android Configuration

**File:** `android/app/src/main/res/values/strings.xml`

Replace placeholder values:
```xml
<string name="default_web_client_id" translatable="false">YOUR_GOOGLE_WEB_CLIENT_ID</string>
<string name="default_android_client_id" translatable="false">YOUR_GOOGLE_ANDROID_CLIENT_ID</string>
```

With actual values:
```xml
<string name="default_web_client_id" translatable="false">123456789-abcdefg.apps.googleusercontent.com</string>
<string name="default_android_client_id" translatable="false">123456789-opqrstu.apps.googleusercontent.com</string>
```

**Verify AndroidManifest.xml:**
- Google Sign-In metadata is already configured
- No changes needed

### 4.3 iOS Configuration

**File:** `ios/Runner/Info.plist`

1. Replace `GIDClientID` placeholder:
```xml
<key>GIDClientID</key>
<string>123456789-hijklmn.apps.googleusercontent.com</string>
```

2. Replace reversed client ID in `CFBundleURLSchemes`:
```xml
<string>com.googleusercontent.apps.123456789-hijklmn</string>
```

**To get reversed client ID:**
- Take iOS client ID: `123456789-hijklmn.apps.googleusercontent.com`
- Remove `.apps.googleusercontent.com`
- Reverse: `com.googleusercontent.apps.123456789-hijklmn`

**Add Sign in with Apple Capability in Xcode:**

⚠️ **CRITICAL:** This MUST be done manually in Xcode (cannot be done via files).

1. Open project: `open ios/Runner.xcworkspace`
2. Select **Runner** target
3. Click **Signing & Capabilities** tab
4. Click **+ Capability**
5. Search for and add **Sign in with Apple**
6. Verify capability appears in list

See `/ios/NATIVE_OAUTH_SETUP.md` for detailed instructions.

---

## Part 5: Testing

### 5.1 Pre-Test Checklist

**Configuration:**
- [ ] All Google client IDs created in Google Cloud Console
- [ ] All Apple credentials created in Apple Developer Portal
- [ ] Supabase providers configured with correct credentials
- [ ] Environment variables updated in `.env`
- [ ] Android `strings.xml` updated with real client IDs
- [ ] iOS `Info.plist` updated with real client IDs
- [ ] Xcode Sign in with Apple capability added

**Build:**
- [ ] Run `flutter pub get`
- [ ] Run `dart run build_runner build --delete-conflicting-outputs`
- [ ] App builds successfully on both iOS and Android

### 5.2 Testing Matrix

| Test Case | Platform | Expected Behavior |
|-----------|----------|-------------------|
| **Google Sign-In (New User)** | iOS Simulator | Native Google picker → Account creation → Profile updated |
| **Google Sign-In (New User)** | Android Emulator | Native Google picker → Account creation → Profile updated |
| **Google Sign-In (Existing User)** | iOS Device | Account picker → Immediate sign-in → Profile updated |
| **Google Sign-In (Cancel)** | Both | User cancels → No error → Stays on auth screen |
| **Apple Sign-In (New User)** | iOS Device | Native Apple UI → Account creation → Profile updated |
| **Apple Sign-In (Existing User)** | iOS Device | Face ID/Touch ID → Immediate sign-in → Profile updated |
| **Apple Sign-In (Cancel)** | iOS | User cancels → No error → Stays on auth screen |
| **Data Preservation** | Both | Sign in → All activities/preferences intact |
| **Offline Mode** | Both | No internet → Clear error message |
| **Token Refresh** | Both | Leave app open 60min → Token auto-refreshes |

**⚠️ Apple Sign-In Testing Requirements:**
- Must use **physical iOS device** (simulator not supported)
- Device must be signed into an Apple ID
- Minimum iOS 13+ required

### 5.3 Manual Test Procedure

**For Each Platform (iOS & Android):**

1. **Fresh Install Test:**
   ```bash
   # Uninstall app
   # Install fresh build
   # Complete onboarding
   # Tap "Continue with Google" or "Continue with Apple"
   # Verify native sign-in UI appears (not browser)
   # Complete sign-in
   # Verify profile shows authProvider: 'google' or 'apple'
   ```

2. **Data Preservation Test:**
   ```bash
   # Create anonymous user
   # Add some activities
   # Sign in with Google/Apple
   # Verify all activities still present
   # Verify user ID unchanged
   ```

3. **Cancellation Test:**
   ```bash
   # Tap "Continue with Google"
   # Tap "Cancel" in native picker
   # Verify no error shown
   # Verify stayed on auth screen
   ```

4. **Analytics Verification:**
   ```bash
   # Check Mixpanel for events:
   # - auth_google_native_started
   # - auth_google_native_linked
   # - auth_apple_native_started
   # - auth_apple_native_linked
   ```

### 5.4 Error Scenarios to Test

| Scenario | How to Test | Expected Behavior |
|----------|-------------|-------------------|
| **No internet** | Turn off Wi-Fi/data → Sign in | Clear error: "No internet connection" |
| **Invalid client ID** | Use wrong client ID in config | Error message with retry option |
| **Revoked access** | Revoke app access in Google/Apple settings → Sign in | Re-prompt for consent |
| **Account mismatch** | Sign in with different Google account | User ID changes warning |

---

## Part 6: Troubleshooting

### Common Issues

**Google Sign-In Error: "12500: Sign in cancelled"**
- **Cause:** Client ID mismatch between app and Google Cloud Console
- **Fix:** Verify client IDs in `strings.xml` (Android) or `Info.plist` (iOS) match Google Cloud Console exactly

**Google Sign-In Error: "10: Developer Error"**
- **Cause:** SHA-1 fingerprint mismatch
- **Fix:** Re-verify SHA-1 in Google Cloud Console matches your signing key

**Apple Sign-In Error: "1001: Canceled"**
- **Cause:** User tapped "Cancel" button (this is normal)
- **Fix:** No fix needed - app handles gracefully

**Apple Sign-In Error: "1000: Unknown"**
- **Cause:** Missing Sign in with Apple capability in Xcode
- **Fix:** Open Xcode → Add capability (see Part 4.3)

**Error: "Invalid client ID"**
- **Cause:** Client ID not listed in Supabase "Authorized Client IDs"
- **Fix:** Add ALL client IDs to Supabase dashboard (see Part 3.1)

**Error: "User ID changed during linking"**
- **Cause:** Linking created new user instead of converting anonymous → authenticated
- **Fix:** Check Supabase logs, ensure anonymous session exists before linking

### Verification Commands

```bash
# Verify Google Cloud Console client IDs
gcloud auth application-default print-access-token

# Verify Android SHA-1 fingerprint
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Verify iOS bundle ID
open ios/Runner.xcodeproj
# Check "Bundle Identifier" under General tab

# Verify environment variables loaded
flutter run --dart-define-from-file=.env
```

---

## Part 7: Security Checklist

**Before Production Launch:**

- [ ] All credentials stored in 1Password (never in code)
- [ ] `.env` files added to `.gitignore`
- [ ] Apple `.p8` key rotation scheduled (6 months)
- [ ] SHA-1 fingerprints verified for release build
- [ ] Production Supabase credentials separate from dev
- [ ] Analytics tracking verified in Mixpanel
- [ ] Sentry error tracking configured
- [ ] All test client IDs removed from Supabase

**Post-Launch:**

- [ ] Monitor Sentry for auth errors (>5% failure = alert)
- [ ] Monitor Mixpanel auth funnel metrics
- [ ] Verify token refresh working (check after 60min)
- [ ] Test on multiple iOS/Android versions

---

## Part 8: Rollback Plan

If native OAuth has critical issues in production:

**Emergency Rollback:**
1. Revert to web OAuth code (git revert)
2. Re-deploy previous version via Shorebird patch
3. Notify users via in-app banner
4. Investigate issues in Sentry/Mixpanel

**Partial Rollback:**
1. Disable problematic provider in Supabase dashboard
2. Keep working provider enabled
3. Show "Temporarily unavailable" message for disabled provider

---

## Contact & Resources

**Team Responsibilities:**
- **Google Cloud:** Levi
- **Apple Developer:** Kyle
- **Supabase Config:** Andrea
- **QA Testing:** QA Team

**External Resources:**
- [Google Sign-In iOS Setup](https://developers.google.com/identity/sign-in/ios/start-integrating)
- [Apple Sign-In Documentation](https://developer.apple.com/sign-in-with-apple/get-started/)
- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Native OAuth Roadmap](./NATIVE_OAUTH_ROADMAP.md)

---

**Document Version:** 1.0
**Last Updated:** November 18, 2025
**Next Review:** After first production deployment
