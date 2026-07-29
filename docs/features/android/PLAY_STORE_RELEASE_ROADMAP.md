# Android Play Store Release Roadmap

**Created:** December 8, 2025
**Updated:** December 8, 2025
**Target:** Open Testing Release in 1-2 weeks
**App Version:** 1.11.2+39

---

## Executive Summary

This roadmap is split into two parts:
1. **LLM Tasks** - Everything Claude can automate/prepare
2. **Human Tasks** - Actions only the developer can perform

**Current Status:** 70% ready. Critical blockers are:
- ✅ ~~Android OAuth Client ID~~ (DONE)
- 🔴 Keystore generation
- 🔴 **OneSignal requires Firebase setup** (FCM credentials)

---

## Part 1: LLM Automated Tasks

### 1.1 Pre-Release Verification (Can Run Now)

#### Code Analysis & Validation

```bash
# Flutter analysis - check for errors
flutter analyze

# Verify Android build configuration
cat android/app/build.gradle.kts | grep -E "compileSdk|targetSdk|minSdk"

# Verify permissions in manifest
grep -E "uses-permission|uses-feature" android/app/src/main/AndroidManifest.xml

# Check ProGuard rules exist
cat android/app/proguard-rules.pro | head -50
```

#### Service Configuration Audit

| Service | File to Check | What to Verify |
|---------|---------------|----------------|
| OneSignal | `lib/shared/services/push_notification_service.dart` | Initialization, permission handling |
| Mixpanel | `lib/shared/services/analytics/analytics_tracker.dart` | Event tracking |
| Sentry | `lib/main.dart` | DSN configuration, environment |
| Wiredash | `lib/shared/widgets/root_app_widget.dart` | Project ID |
| Supabase | `lib/shared/services/app_config.dart` | URLs for dev/prod |

### 1.2 Documentation Updates (LLM Can Do)

- [x] Create this roadmap document
- [ ] Update `/docs/features/android/README.md` with current version (1.11.1+38)
- [ ] Create testing checklist document
- [ ] Document OAuth Client ID creation steps
- [ ] Create Play Store asset specifications

### 1.3 Code Preparation (LLM Can Do)

#### Verify Release Build Configuration

```kotlin
// android/app/build.gradle.kts - CURRENT CONFIG (verified)
android {
    namespace = "com.milkman.mealvanaendurance"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.milkman.mealvanaendurance"
        minSdk = 21
        targetSdk = 34
        versionCode = 38
        versionName = "1.11.1"
        multiDexEnabled = true
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(...)
        }
    }
}
```

#### Verify Deep Linking (OAuth Callbacks)

```xml
<!-- android/app/src/main/AndroidManifest.xml - VERIFIED -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="com.milkman.mealvanaendurance" android:host="auth-callback"/>
</intent-filter>
```

### 1.4 Testing Preparation (LLM Can Create)

#### Test Case Document

| ID | Feature | Steps | Expected Result | Priority |
|----|---------|-------|-----------------|----------|
| T1 | Push Notifications | 1. Open app 2. Accept permission 3. Send test from OneSignal | Notification appears | Critical |
| T2 | Google Sign-In | 1. Tap Sign In 2. Select Google account 3. Complete flow | User logged in, data synced | Critical |
| T3 | Create Activity | 1. Tap + 2. Enter distance/pace 3. Save | Activity appears in list | Critical |
| T4 | Generate Plan | 1. Select activity 2. Tap Generate Plan 3. Wait | Nutrition plan displays | Critical |
| T5 | Barcode Scanner | 1. Go to Settings > Foods 2. Tap scan 3. Scan barcode | Food info appears | High |
| T6 | Location | 1. Create event 2. Search location 3. Select | Address saved | High |
| T7 | Offline Mode | 1. Enable airplane mode 2. Use app 3. Disable 4. Sync | Data preserved & synced | High |
| T8 | Wiredash | 1. Shake device 2. Draw on screenshot 3. Submit | Feedback sent | Medium |
| T9 | Local Notifications | 1. Create activity 2. Enable reminder 3. Wait | Reminder fires at time | Medium |

### 1.5 Play Store Listing Content (LLM Can Prepare)

#### Short Description (80 chars max)
```
Personalized nutrition plans for runners. Science-based fueling for your runs.
```

#### Full Description (4000 chars max)
```
Mealvana Run creates personalized nutrition plans for endurance athletes.

KEY FEATURES:
• Personalized Plans - Based on your distance, pace, body weight, and gut training level
• Science-Based - Uses ACSM formulas and evidence-based nutrition research
• Food Preferences - Respects your liked and disliked foods
• Works Offline - Full functionality without internet connection
• Weather-Aware - Adjusts hydration based on race day conditions

WHAT YOU GET:
✓ Pre-run meal recommendations
✓ During-run fueling schedule
✓ Carbohydrate, sodium, and hydration targets
✓ Food product recommendations from real brands

SUPPORTED ACTIVITIES:
• Road running (5K to ultramarathons)
• Trail running
• Triathlons (coming soon)
• Cycling (coming soon)

BACKED BY SCIENCE:
Our algorithms use American College of Sports Medicine (ACSM) guidelines and peer-reviewed research to calculate your energy expenditure and nutritional needs.

FREE TO USE:
Create unlimited nutrition plans. No subscription required for core features.

PRIVACY FIRST:
Your data stays on your device. Optional cloud sync available.

Download now and fuel your next PR!
```

#### App Category
- **Primary:** Health & Fitness
- **Secondary:** Sports

#### Tags (5 max)
1. running
2. nutrition
3. marathon
4. sports nutrition
5. endurance

### 1.6 Data Safety Declaration (LLM Can Prepare)

| Data Type | Collected | Shared | Purpose |
|-----------|-----------|--------|---------|
| Email (optional) | Yes | No | Account linking |
| Location (optional) | Yes | No | Weather forecasts, event locations |
| App activity | Yes | No | Analytics (Mixpanel) |
| Crash logs | Yes | No | Bug fixes (Sentry) |
| Device ID | Yes | No | Anonymous authentication |

**Data handling:**
- Data encrypted in transit (HTTPS)
- Users can request data deletion
- No data sold to third parties

---

## Part 2: Human-Only Tasks

### 2.1 Critical Blockers (Must Do First)

#### A. Generate Production Keystore

```bash
# Run this command (replace YOUR_NAME with your name)
cd ~
keytool -genkey -v \
    -keystore mealvana-upload-keystore.jks \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -alias upload

# You'll be prompted for:
# - Keystore password (save this!) ← This is "storePassword"
# - Key password (press ENTER to use same as keystore) ← This is "keyPassword"
# - Your name, organization, location
```

**Password Clarification:**
- `storePassword` = Password to unlock the `.jks` FILE
- `keyPassword` = Password to unlock the KEY inside (usually same as storePassword)

#### B. Create key.properties

```bash
# Create the file
cat > /Users/leemartin/development/mealvana_endurance/android/key.properties << 'EOF'
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/Users/leemartin/mealvana-upload-keystore.jks
EOF

# Verify it's in .gitignore (should already be)
grep "key.properties" .gitignore
```

#### C. BACKUP KEYSTORE IMMEDIATELY

**CRITICAL:** If you lose this keystore, you can NEVER update the app on Play Store.

Backup locations:
1. 1Password or password manager
2. Encrypted external drive
3. Google Drive (encrypted zip)

#### D. Create Android OAuth Client ID

✅ **COMPLETED** - Client ID: `171527646530-5sjjs6che5nsl7nom9l8cfh64087aitb.apps.googleusercontent.com`

Updated in `android/app/src/main/res/values/strings.xml`

#### E. 🔴 OneSignal Firebase Setup (REQUIRED for Push Notifications)

OneSignal on Android requires Firebase Cloud Messaging (FCM). Without this, push notifications will NOT work.

**Step 1: Create Firebase Project (5 min)**
1. Go to https://console.firebase.google.com/
2. Click **Add project**
3. Name: `mealvana-endurance`
4. Disable Google Analytics (optional)
5. Click **Create project**

**Step 2: Add Android App to Firebase (5 min)**
1. Click **Add app** → **Android**
2. Package name: `com.milkman.mealvanaendurance`
3. App nickname: `Mealvana Run`
4. Debug SHA-1: `BE:B9:37:51:39:7E:AE:C9:6A:D7:63:29:6E:34:5A:1D:CD:2A:CB:AA`
5. Click **Register app**
6. **Download `google-services.json`**
7. Save to: `android/app/google-services.json`

**Step 3: Enable Cloud Messaging API (2 min)**
1. Firebase Console → Project Settings (gear icon)
2. **Cloud Messaging** tab
3. If disabled, click three dots → **Manage API in Cloud Console** → **Enable**

**Step 4: Generate Service Account JSON (3 min)**
1. Firebase Console → Project Settings → **Service accounts** tab
2. Click **Generate new private key**
3. Save the downloaded JSON file

**Step 5: Upload to OneSignal Dashboard (3 min)**
1. Go to https://dashboard.onesignal.com/
2. Select app `335e597f-9862-4fa1-91f9-506d546ef953`
3. **Settings** → **Push & In-App** → **Push Platforms**
4. Click **Google Android (FCM)** → **Activate**
5. Upload the service account JSON from Step 4
6. Click **Save**

**Android build files already updated by Claude:**
- `android/settings.gradle.kts` - Added Google Services plugin
- `android/app/build.gradle.kts` - Applied Google Services plugin
- Just need to add `google-services.json` file

### 2.2 Build & Test

#### Build Release AAB

```bash
cd /Users/leemartin/development/mealvana_endurance
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
# Expected size: 40-60 MB
```

#### Verify Signing

```bash
# Check the AAB is signed
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

#### Install on Pixel 7 Pro

```bash
# Connect device via USB, enable USB debugging
flutter install --release
```

### 2.3 Testing Checklist (On Device)

Run through each test on your Pixel 7 Pro:

- [ ] **Push Notifications**: Accept permission, receive test notification
- [ ] **Google Sign-In**: Complete OAuth flow with new Client ID
- [ ] **Create Activity**: Add a run, verify it saves
- [ ] **Generate Plan**: Create nutrition plan, verify results
- [ ] **Barcode Scanner**: Scan a product, verify info appears
- [ ] **Location**: Search for an address, verify it resolves
- [ ] **Offline Mode**: Use app in airplane mode, then sync
- [ ] **Wiredash**: Submit test feedback
- [ ] **Notifications**: Set a reminder, verify it fires

### 2.4 Play Store Submission

#### Create Screenshots (On Pixel 7 Pro)

Take screenshots of:
1. Welcome/onboarding screen
2. Activity list (with activities)
3. Nutrition plan view
4. Food preferences
5. Activity creation
6. Settings screen

**Tip:** Use `adb shell screencap` or Power + Volume Down

#### Upload to Play Console

1. Go to: https://play.google.com/console
2. Select your app (or create new)
3. Go to **Release** → **Testing** → **Open testing**
4. Click **Create new release**
5. Upload `app-release.aab`
6. Add release notes
7. Complete store listing (copy from above)
8. Complete data safety form (copy from above)
9. Complete content rating questionnaire
10. Submit for review

---

## Timeline Summary

| Day | LLM Tasks | Human Tasks |
|-----|-----------|-------------|
| 1 | Verify configs, create docs | Generate keystore, create OAuth Client ID |
| 2 | Prepare test cases | Build release, start device testing |
| 3 | Prepare store listing | Continue testing |
| 4 | Prepare data safety | Fix any bugs found |
| 5 | Final verification | Take screenshots |
| 6 | Review submission | Upload to Play Console |
| 7-10 | Monitor | Wait for Google review |

---

## Appendix: Command Reference

### Keystore Commands

```bash
# Generate new keystore
keytool -genkey -v -keystore mealvana-upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# View keystore details
keytool -list -v -keystore mealvana-upload-keystore.jks

# Get SHA-1 fingerprint (for OAuth)
keytool -list -v -keystore mealvana-upload-keystore.jks | grep SHA1

# Get SHA-256 fingerprint (for Play App Signing)
keytool -list -v -keystore mealvana-upload-keystore.jks | grep SHA256
```

### Flutter Build Commands

```bash
# Clean build
flutter clean && flutter pub get

# Build release AAB
flutter build appbundle --release

# Build release APK (for direct install)
flutter build apk --release

# Install on device
flutter install --release

# Run in release mode
flutter run --release
```

### ADB Commands

```bash
# List connected devices
adb devices

# Take screenshot
adb shell screencap -p /sdcard/screenshot.png && adb pull /sdcard/screenshot.png

# View logs
adb logcat | grep -i flutter

# Install APK directly
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Lost keystore | Low | **CRITICAL** | Backup immediately to 3 locations |
| OAuth not working | Medium | High | Test thoroughly before submission |
| Push notifications fail | Medium | Medium | Test with OneSignal dashboard |
| Store rejection | Low | Medium | Follow all guidelines |
| Bugs found in testing | High | Medium | Allow 2 days for fixes |

---

## Success Criteria

Before submitting to Play Store, verify:

- [ ] App builds without errors
- [ ] AAB is properly signed
- [ ] Google Sign-In works on Android
- [ ] Push notifications work
- [ ] All critical features tested
- [ ] Screenshots taken
- [ ] Store listing complete
- [ ] Data safety form complete
- [ ] Content rating complete

---

**Document maintained by:** Claude (LLM) + Lee Martin
**Last updated:** December 8, 2025
