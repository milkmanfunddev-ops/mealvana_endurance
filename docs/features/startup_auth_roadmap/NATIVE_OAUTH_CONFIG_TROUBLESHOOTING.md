# Native OAuth Configuration & Troubleshooting Guide

**Last Updated:** 2025-11-19 20:00
**Status:** ✅ Implementation complete - using linkIdentityWithIdToken() for account linking

---

## 🎉 What Changed (2025-11-19)

### Code Updates
- ✅ **Apple Sign-In**: Changed from `signInWithIdToken()` to `linkIdentityWithIdToken()`
- ✅ **Google Sign-In**: Changed from `signInWithIdToken()` to `linkIdentityWithIdToken()`
- ✅ **Package Upgrade**: Upgraded `supabase_flutter` from ^2.8.5 to ^2.10.0 (installed 2.10.3)
- ✅ **User ID Preservation**: Now guaranteed - no data loss during account linking
- ✅ **Error Messages**: Updated to reflect expected behavior

### Configuration Updates
- ✅ **Supabase Dashboard**: "Enable Manual Linking" turned ON
- ⏳ **Google Cloud Console**: iOS Bundle ID needs update
- ⏳ **Supabase Authorized IDs**: iOS client ID needs to be added

### Expected Behavior
**Before (signInWithIdToken):**
- Anonymous user: `abc-123` → Google Sign-In → New user: `xyz-789` ❌
- Result: Data loss (orphaned on old user ID)

**After (linkIdentityWithIdToken):**
- Anonymous user: `abc-123` → Google Sign-In → Same user: `abc-123` ✅
- Result: User ID preserved, all data remains accessible

---

## 📋 Table of Contents

1. [Configuration Status](#configuration-status)
2. [Required Fixes](#required-fixes)
3. [Complete Configuration Reference](#complete-configuration-reference)
4. [Common Issues & Solutions](#common-issues--solutions)
5. [Testing on Physical Devices](#testing-on-physical-devices)
6. [Simulator Limitations](#simulator-limitations)
7. [Analytics & Monitoring](#analytics--monitoring)

---

## Configuration Status

### ✅ What's Already Configured

**App Code:**
- ✅ Native OAuth implementation in `oauth_service.dart`
- ✅ Google Sign-In package: `google_sign_in: ^6.2.1`
- ✅ Apple Sign-In package: `sign_in_with_apple: ^6.1.0`
- ✅ iOS Info.plist with Google URL scheme and client ID
- ✅ Android build.gradle.kts with package name
- ✅ Environment variables in `.env` (fixed 2025-11-19)

**Apple Developer Portal:**
- ✅ App ID: `com.milkman.mealvanaendurance`
- ✅ Sign in with Apple capability enabled
- ✅ Key ID: `Z875MDK9BR`
- ✅ Team ID: `9Y99749RG3`
- ✅ Private key (.p8) downloaded and stored

**Google Cloud Console:**
- ✅ Web OAuth client created
- ✅ Android OAuth client created
- ✅ iOS OAuth client created
- ✅ SHA-1 fingerprint added for Android

**Supabase Dashboard:**
- ✅ Apple provider enabled with credentials
- ✅ Google provider enabled with credentials

---

## 🚨 Required Fixes

### Fix 1: Google Cloud Console - iOS Bundle ID

**Problem:** iOS OAuth client has wrong bundle ID

**Current Configuration:**
```
Bundle ID: com.example.mealvanaEndurance ❌
```

**Required Configuration:**
```
Bundle ID: com.milkman.mealvanaendurance ✅
```

**How to Fix:**
1. Go to [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials)
2. Find iOS OAuth client: `171527646530-g0u0p8e6vuipqbc5j4svl3j9149u597n`
3. Click **Edit** (pencil icon)
4. Update **Bundle ID** field to: `com.milkman.mealvanaendurance`
5. Click **Save**
6. Wait 10-15 minutes for changes to propagate

**Impact if Not Fixed:**
- Google Sign-In will fail on iOS devices
- Error: "Sign in failed" or "Invalid client ID"

---

### Fix 2: Supabase Dashboard - Google Client IDs

**Problem:** Missing iOS client ID and typo in Android client ID

**Current Configuration:**
```
171527646530-d1hr8a9ja4ucqk28cipcfnlo288qhccn.apps.googleusercontent.com,71527646530-5sjjs6che5nsl7nom9l8cfh64087aitb.apps.googleusercontent.com
```
Issues:
- Android client ID missing first "1" (typo)
- iOS client ID not included

**Required Configuration:**
```
171527646530-d1hr8a9ja4ucqk28cipcfnlo288qhccn.apps.googleusercontent.com,171527646530-5sjjs6che5nsl7nom9l8cfh64087aitb.apps.googleusercontent.com,171527646530-g0u0p8e6vuipqbc5j4svl3j9149u597n.apps.googleusercontent.com
```
Order: **Web, Android, iOS** (comma-separated, no spaces)

**How to Fix:**
1. Go to [Supabase Dashboard → Auth → Providers](https://supabase.com/dashboard/project/wvmvsodrvbkxfydabqed/auth/providers)
2. Click on **Google** provider
3. Click **Edit**
4. Replace **Authorized Client IDs** field with the complete value above
5. Verify **Client Secret** is still: `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`
6. Click **Save**
7. Wait 5-10 minutes for Supabase to sync

**Impact if Not Fixed:**
- Google Sign-In will fail on iOS devices
- Token validation errors from Supabase
- Error: "Bad ID Token" or "Invalid client"

---

## Complete Configuration Reference

### Environment Variables (.env)

```bash
# Google OAuth Configuration (Native Sign-In)
GOOGLE_WEB_CLIENT_ID=171527646530-d1hr8a9ja4ucqk28cipcfnlo288qhccn.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=171527646530-g0u0p8e6vuipqbc5j4svl3j9149u597n.apps.googleusercontent.com
GOOGLE_ANDROID_CLIENT_ID=171527646530-5sjjs6che5nsl7nom9l8cfh64087aitb.apps.googleusercontent.com
```

**Status:** ✅ Fixed on 2025-11-19 (typos corrected)

---

### iOS Configuration (Info.plist)

**File:** `ios/Runner/Info.plist`

```xml
<!-- Google Sign-In URL Scheme -->
<dict>
  <key>CFBundleTypeRole</key>
  <string>Editor</string>
  <key>CFBundleURLSchemes</key>
  <array>
    <string>com.googleusercontent.apps.171527646530-g0u0p8e6vuipqbc5j4svl3j9149u597n</string>
  </array>
</dict>

<!-- Google Sign-In Client ID -->
<key>GIDClientID</key>
<string>171527646530-g0u0p8e6vuipqbc5j4svl3j9149u597n.apps.googleusercontent.com</string>

<!-- Deep Linking for Supabase callbacks -->
<dict>
  <key>CFBundleURLName</key>
  <string>com.milkman.mealvanaendurance</string>
  <key>CFBundleURLSchemes</key>
  <array>
    <string>com.milkman.mealvanaendurance</string>
  </array>
</dict>
```

**Status:** ✅ Correct

**Xcode Capabilities Required:**
- Sign in with Apple (enabled)

---

### Android Configuration (build.gradle.kts)

**File:** `android/app/build.gradle.kts`

```kotlin
android {
    namespace = "com.milkman.mealvanaendurance"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.milkman.mealvanaendurance"
        minSdk = 21  // Required for google_sign_in
        targetSdk = 34
    }
}
```

**Status:** ✅ Correct

**SHA-1 Fingerprint (Debug):**
```
BE:B9:37:51:39:7E:AE:C9:6A:D7:63:29:6E:34:5A:1D:CD:2A:CB:AA
```

---

### Google Cloud Console

**OAuth Consent Screen:**
- User Type: External
- App name: Mealvana Endurance
- Scopes: `email`, `profile`, `openid`

**Web OAuth Client:**
- Client ID: `171527646530-d1hr8a9ja4ucqk28cipcfnlo288qhccn`
- Client Secret: `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`
- Redirect URI: `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`

**Android OAuth Client:**
- Client ID: `171527646530-5sjjs6che5nsl7nom9l8cfh64087aitb`
- Package name: `com.milkman.mealvanaendurance`
- SHA-1: `BE:B9:37:51:39:7E:AE:C9:6A:D7:63:29:6E:34:5A:1D:CD:2A:CB:AA`

**iOS OAuth Client:**
- Client ID: `171527646530-g0u0p8e6vuipqbc5j4svl3j9149u597n`
- Bundle ID: ~~`com.example.mealvanaEndurance`~~ → **FIX TO:** `com.milkman.mealvanaendurance`

---

### Apple Developer Portal

**App ID:**
- Identifier: `com.milkman.mealvanaendurance`
- Capabilities: Sign in with Apple (enabled)

**Services ID (for web OAuth - optional for native):**
- Identifier: `9Y99749RG3.com.milkman.mealvanaendurance`
- Domain: `wvmvsodrvbkxfydabqed.supabase.co`
- Return URL: `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`

**Private Key:**
- Key ID: `Z875MDK9BR`
- Team ID: `9Y99749RG3`
- File: Stored in `/secrets/` (never commit to git)

---

### Supabase Dashboard

**Apple Provider:**
- Enabled: ✅
- Client ID: `com.milkman.mealvanaendurance`
- Secret Key: (from .p8 file)
- Redirect URL: `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`

**Google Provider:**
- Enabled: ✅
- Authorized Client IDs: (see Fix 2 above)
- Client Secret: `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`
- Redirect URL: `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`

---

## Common Issues & Solutions

### Issue 1: "Sign in failed" on iOS

**Symptoms:**
```
PlatformException(sign_in_failed, The operation couldn't be completed)
```

**Possible Causes:**
1. Bundle ID mismatch in Google Cloud Console (see Fix 1)
2. GIDClientID not in Info.plist
3. Testing on simulator instead of physical device
4. Google services not initialized

**Solution:**
1. Verify bundle ID is `com.milkman.mealvanaendurance` in Google Cloud Console
2. Check Info.plist has correct GIDClientID
3. Test on physical iPhone, not simulator
4. Wait 10-15 minutes after making configuration changes

---

### Issue 2: "Bad ID Token" from Supabase

**Symptoms:**
```
AuthException: Bad ID Token (status 400)
```

**Possible Causes:**
1. iOS client ID not in Supabase authorized client IDs (see Fix 2)
2. Token format incorrect
3. Supabase hasn't synced configuration yet

**Solution:**
1. Add iOS client ID to Supabase authorized client IDs (see Fix 2)
2. Ensure all three client IDs are comma-separated with no spaces
3. Wait 5-10 minutes after saving Supabase configuration
4. Check Supabase logs for token validation errors

---

### Issue 3: User ID Changed After Linking

**Symptoms:**
```
USER ID CHANGED during Google/Apple linking - data may be lost!
```

**Possible Causes:**
1. Using `signInWithOAuth()` instead of `signInWithIdToken()`
2. User signed out before linking

**Solution:**
1. Verify `oauth_service.dart` uses `signInWithIdToken()` (already implemented ✅)
2. Ensure user is still signed in with anonymous session
3. Check `_supabase.auth.currentUser` before linking

---

### Issue 4: Apple Sign-In Returns Error 1000

**Symptoms:**
```
ASAuthorizationError code 1000 (unknown)
```

**Possible Causes:**
1. Testing on simulator (doesn't support native Apple Sign-In)
2. Capability not enabled in Xcode
3. iOS version < 13.0

**Solution:**
1. Test on physical iPhone (iOS 13+)
2. Verify "Sign in with Apple" capability in Xcode
3. Check device has iCloud account signed in

---

### Issue 5: Android "Developer Error" for Google Sign-In

**Symptoms:**
```
PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10:)
```

**Possible Causes:**
1. SHA-1 fingerprint mismatch
2. Package name mismatch
3. Google Play Services not updated on device

**Solution:**
1. Verify SHA-1 in Google Cloud Console matches:
   ```bash
   cd android
   ./gradlew signingReport
   ```
2. Ensure package name is `com.milkman.mealvanaendurance`
3. Update Google Play Services on Android device/emulator

---

## Testing on Physical Devices

### iOS Device Setup

**Prerequisites:**
- Physical iPhone (iOS 13+)
- USB cable
- Xcode installed on Mac
- Apple Developer account (free or paid)

**Steps:**
```bash
# 1. Connect iPhone via USB
# 2. Unlock iPhone and tap "Trust This Computer"

# 3. Verify device detected
flutter devices

# Output should show:
# iPhone 15 Pro (mobile) • 00008110-001A123B • ios • iOS 17.0

# 4. Run on device
flutter run -d "iPhone 15 Pro"

# 5. If prompted in Xcode, sign the app:
#    - Open ios/Runner.xcworkspace in Xcode
#    - Select Runner target
#    - Signing & Capabilities tab
#    - Select your Apple ID team
#    - Xcode will auto-provision
```

**First Launch:**
- App may show "Untrusted Developer" error
- Go to: Settings → General → VPN & Device Management
- Tap on developer profile
- Tap "Trust [Your Developer Name]"
- Relaunch app

---

### Android Device Setup

**Prerequisites:**
- Physical Android device OR Android emulator
- USB debugging enabled (for physical device)
- Google account signed in on device/emulator

**Physical Device:**
```bash
# 1. Enable Developer Options on Android:
#    - Settings → About Phone → Tap "Build number" 7 times
#    - Settings → System → Developer Options → Enable USB Debugging

# 2. Connect via USB

# 3. Verify device detected
flutter devices

# 4. Run on device
flutter run -d "Pixel 7"
```

**Emulator:**
```bash
# 1. Launch emulator
flutter emulators --launch Pixel_7_API_34

# 2. Sign in to Google account:
#    - Settings → Accounts → Add Google account

# 3. Run app
flutter run -d "emulator-5554"
```

---

## Simulator Limitations

### ⚠️ CRITICAL: Native OAuth Does NOT Work on iOS Simulators

**Why Simulators Fail:**

**Native Google Sign-In:**
- Requires access to system keychain (simulator keychain is limited)
- Needs Google Play Services integration (not available on simulator)
- Google SDK explicitly blocks simulator for security
- Error: `PlatformException(sign_in_failed, com.google.GIDSignIn, The operation couldn't be completed)`

**Native Apple Sign-In:**
- Requires Secure Enclave for cryptographic operations
- Uses platform authentication services not available on simulator
- Apple SDK returns error code 1000 or 1001
- Requires iCloud account sign-in (not fully functional on simulator)

---

### Testing Alternatives

**Option 1: Physical iPhone** (Recommended)
- ✅ Tests both Google & Apple Sign-In natively
- ✅ Identical to production user experience
- ✅ Complete validation of all flows
- ⏱️ Time: 5 minutes setup, instant testing thereafter

**Option 2: Android Emulator**
- ✅ Tests Google Sign-In (native SDK works on emulators)
- ❌ Cannot test Apple Sign-In (iOS only)
- ⏱️ Faster iteration for Google Sign-In development

**Option 3: Web OAuth Fallback** (Not Implemented)
- Could modify code to use web OAuth on simulator
- Different UX than production (browser redirect)
- Still requires physical device testing before launch
- Not recommended

---

## Analytics & Monitoring

### Expected Analytics Events (Mixpanel)

**Apple Sign-In Flow:**
```
auth_apple_native_started
  → properties: { platform: "ios" }

auth_apple_native_linked (success)
  → properties: { user_id: "...", platform: "ios" }

OR

auth_apple_native_cancelled (user cancelled)
  → properties: { platform: "ios" }

auth_apple_native_failed (error)
  → properties: { error: "...", platform: "ios" }
```

**Google Sign-In Flow:**
```
auth_google_native_started
  → properties: { platform: "ios" | "android" }

auth_google_native_linked (success)
  → properties: { user_id: "...", email: "...", platform: "..." }

OR

auth_google_native_cancelled (user cancelled)
  → properties: { platform: "..." }

auth_google_native_failed (error)
  → properties: { error: "...", platform: "..." }
```

---

### Sentry Breadcrumbs

Check Sentry for authentication flow breadcrumbs:

```
[INFO] Starting native Apple Sign-In flow (context: OAUTH_NATIVE)
[INFO] Apple Sign-In credential received (context: OAUTH_NATIVE)
[INFO] Apple account linked successfully (context: OAUTH_NATIVE)

OR

[ERROR] Apple Sign-In failed (context: OAUTH_NATIVE)
  → error: [error details]
```

---

### Debugging Checklist

**Before testing:**
- [ ] Both configuration fixes applied (Google Cloud Console + Supabase)
- [ ] Waited 10-15 minutes for Google changes to propagate
- [ ] Using physical iOS device (not simulator)
- [ ] Device has iOS 13+ and iCloud account signed in
- [ ] App rebuilt after configuration changes

**During testing:**
- [ ] Monitor Flutter console for errors
- [ ] Check Mixpanel events in real-time
- [ ] Verify Sentry breadcrumbs
- [ ] Test sign-out and re-authentication

**After successful auth:**
- [ ] Settings screen shows correct provider
- [ ] User ID unchanged (Supabase UUID preserved)
- [ ] Profile data still accessible
- [ ] App restart restores session

---

## Quick Reference: Testing Commands

```bash
# Check connected devices
flutter devices

# Run on specific device
flutter run -d "iPhone 15 Pro"
flutter run -d "emulator-5554"

# Run with verbose logging
flutter run -v -d "iPhone 15 Pro"

# Clean and rebuild
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d "iPhone 15 Pro"

# Check SHA-1 fingerprint (Android)
cd android
./gradlew signingReport

# Monitor logs in real-time
flutter logs
```

---

## Support & Resources

**Documentation:**
- [Phase 2 Status](/docs/startup_auth_roadmap/PHASE_2_STATUS.md)
- [Implementation Roadmap](/docs/startup_auth_roadmap/phase_2_implementation.md)
- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)

**Code Locations:**
- OAuth Service: `/lib/features/auth/application/oauth_service.dart`
- Auth Controller: `/lib/features/auth/presentation/providers/post_onboarding_auth_controller.dart`
- iOS Config: `/ios/Runner/Info.plist`
- Android Config: `/android/app/build.gradle.kts`
- Environment: `/.env`

**External Consoles:**
- [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
- [Apple Developer Portal](https://developer.apple.com/account/)
- [Supabase Dashboard](https://supabase.com/dashboard/project/wvmvsodrvbkxfydabqed)
- [Mixpanel](https://mixpanel.com)
- [Sentry](https://sentry.io)

---

**Last Updated:** 2025-11-19
**Maintained By:** Development Team
**Status:** Production-ready with 2 configuration fixes required
