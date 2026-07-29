# Android Implementation Complete - Next Steps

**Date**: 2025-11-12
**App Version**: v1.9.0+30
**Status**: ✅ Critical implementation complete, ready for testing

---

## ✅ What's Been Completed

### 1. Build Configuration (`android/app/build.gradle.kts`)

**SDK Versions** ✅
- `compileSdk = 35` - Required by supabase_flutter and sentry_flutter
- `targetSdk = 34` - Google Play Store requirement (will be 35 by August 2025)
- `minSdk = 21` - Supports Android 5.0+ (95%+ market coverage)

**Optimizations** ✅
- `multiDexEnabled = true` - Handles notification library method count
- `isCoreLibraryDesugaringEnabled = true` - Java.time APIs for Android 14+ notifications
- R8 code shrinking enabled - Reduces APK size by 30-40%
- ProGuard rules configured for all major dependencies

**Release Signing** ✅
- Configuration ready for keystore
- Reads from `android/key.properties` file
- **Action Required**: Generate keystore (see below)

### 2. Android Manifest (`android/app/src/main/AndroidManifest.xml`)

**Permissions Added** ✅
- `POST_NOTIFICATIONS` - Android 13+ notification permission
- `CAMERA` - Barcode scanning
- `RECEIVE_BOOT_COMPLETED` - Notification persistence after reboot
- `SCHEDULE_EXACT_ALARM` - Exact notification timing
- `USE_EXACT_ALARM` - Alternative exact alarm API
- Location permissions already present ✅

**Notification Receivers** ✅
- `ScheduledNotificationReceiver` - Handles scheduled notifications
- `ScheduledNotificationBootReceiver` - Restores notifications after reboot

**Package Visibility Queries** ✅
- HTTP/HTTPS - For url_launcher web links
- MAILTO - For email links
- TEL - For phone dialer

**Camera Features** ✅
- Camera and autofocus declared as optional (app works without camera)

### 3. Notification Service (`lib/shared/services/notification_service.dart`)

**Android Notification Channels Created** ✅
1. **nutrition_plan_reminders** - High priority, sound, vibration
2. **carb_loading_reminders** - High priority, sound, vibration
3. **general_notifications** - Default priority, no sound

**Platform-Specific Implementation** ✅
- Android 13+ runtime permission request
- Android notification status checking
- Notification icon set to `@mipmap/launcher_icon`
- Full parity with iOS implementation

### 4. ProGuard Rules (`android/app/proguard-rules.pro`)

**Dependencies Configured** ✅
- Supabase (reflection-based classes)
- Drift database
- Sentry (auto-handled by plugin)
- RudderStack analytics
- OkHttp, Gson, Kotlin Coroutines
- Removes debug logging in release builds

---

## 🎯 Critical Next Steps (Before Testing)

### Step 1: Generate Release Keystore (15 minutes)

**⚠️ IMPORTANT**: Back up your keystore securely. Losing it means you can never update your app!

```bash
# Navigate to your home directory
cd ~

# Generate keystore (you'll be prompted for passwords and info)
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Keystore details to enter:
# - Password: Choose a strong password (save in password manager!)
# - Name: Milkman Technologies (or your company name)
# - Organizational Unit: Development
# - Organization: Milkman Technologies
# - City: Your city
# - State: Your state
# - Country Code: US (or your country)

# When asked "Is this correct?", type: yes
```

**Output**: Creates `~/upload-keystore.jks` file

### Step 2: Create key.properties File (5 minutes)

```bash
# Create the file
cd ~/development/mealvana_endurance/android
nano key.properties
```

**Add this content** (replace with your actual passwords):
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/Users/leemartin/upload-keystore.jks
```

**Save and exit**: Ctrl+O, Enter, Ctrl+X

**⚠️ SECURITY**:
- Add `key.properties` to `.gitignore` (should already be there)
- Never commit keystore or passwords to git
- Store keystore backup in secure location (1Password, encrypted drive, etc.)

### Step 3: Add key.properties to .gitignore (1 minute)

```bash
# Check if already ignored
cd ~/development/mealvana_endurance
grep -r "key.properties" .gitignore

# If not found, add it:
echo "android/key.properties" >> .gitignore
```

---

## 📱 Testing on Pixel 7 Pro

### Prerequisites
1. Enable Developer Options on Pixel 7 Pro
2. Enable USB Debugging
3. Connect phone to Mac via USB
4. Trust the computer on phone

### Test Build Commands

**Debug Build** (test basic functionality):
```bash
flutter run --debug
```

**Profile Build** (test performance):
```bash
flutter run --profile
```

**Release Build** (final testing before deployment):
```bash
flutter run --release
```

### Critical Test Cases

#### 1. Notifications ⭐ HIGHEST PRIORITY
- [ ] App requests notification permission on first launch (Android 13+)
- [ ] Can schedule a nutrition plan reminder
- [ ] Notification appears at scheduled time
- [ ] Tapping notification opens correct activity
- [ ] Notifications persist after phone reboot
- [ ] Check notification settings shows all 3 channels

#### 2. Barcode Scanning
- [ ] App requests camera permission when needed
- [ ] Can scan barcode for food product
- [ ] Gracefully handles camera permission denial

#### 3. Location Services
- [ ] App requests location permission for weather
- [ ] Location-based weather forecast works
- [ ] Gracefully handles location permission denial

#### 4. Offline Mode
- [ ] App works without internet connection
- [ ] Drift database syncs when connection restored
- [ ] No crashes when offline

#### 5. Core Features
- [ ] Create nutrition plan for activity
- [ ] View carb loading protocol
- [ ] Calendar view shows events
- [ ] User profile and settings work
- [ ] Analytics tracking working (check Mixpanel)

---

## 🏗️ Build Release AAB (When Ready)

### Build Command
```bash
# Build Android App Bundle (for Google Play Store)
flutter build appbundle --release

# Output location:
# build/app/outputs/bundle/release/app-release.aab
```

### Verify Build
```bash
# Check file was created
ls -lh build/app/outputs/bundle/release/app-release.aab

# Expected size: 40-60 MB (with R8 optimization)
```

---

## 🚀 Shorebird Setup for Android

### Initialize Android Platform
```bash
# Initialize Shorebird for Android
shorebird init --platforms android

# Create baseline release
shorebird release android --target lib/main.dart

# Output: Creates baseline release with version 1.9.0+30
```

### Future Patches
```bash
# After code changes (not native changes):
shorebird patch android --target lib/main.dart

# Check patch status:
shorebird patch list
```

**Note**: Shorebird can only patch Dart code, not:
- Native Android changes (Kotlin/Java)
- Dependencies (pubspec.yaml)
- Assets
- Flutter SDK version

---

## 📦 Google Play Store Submission

### Required Assets (Your Action)

**Screenshots** (need to create):
- Phone screenshots (minimum 2, recommended 8)
  - 1080x1920 or 1440x2560
  - Show key features: nutrition plan, calendar, carb loading, barcode scan
- 7-inch tablet screenshots (minimum 2)
  - 1200x1920
- 10-inch tablet screenshots (optional)
  - 1600x2560

**Feature Graphic**:
- 1024x500 pixels
- Banner image for Play Store listing

**App Icon**:
- Already configured ✅ (`assets/images/endurance_launcher_icon_basecream_1024.png`)

### Store Listing Content

**App Title**: Mealvana Endurance

**Short Description** (80 characters max):
```
Personalized nutrition plans for endurance athletes - runners, cyclists, swimmers
```

**Full Description** (4000 characters max):
- Adapt from iOS App Store listing
- Highlight key features
- Mention science-based approach (ACSM formulas)
- Include "Run better, fuel smarter" tagline

**Category**: Health & Fitness

**Content Rating**:
- Complete questionnaire (likely Everyone or 3+)
- No violence, mature content, etc.

### Data Safety Declaration

**Data Collected**:
- Email address (authentication)
- User profile (weight, height, preferences)
- Activity data (runs, nutrition plans)
- Device ID (anonymous analytics)
- Location (weather forecasts) - optional, can be denied

**Data Usage**:
- Provide personalized nutrition plans
- Sync across devices
- Improve app performance
- No data sharing with third parties (except Supabase backend, Mixpanel analytics)

**Data Security**:
- Data encrypted in transit (HTTPS/TLS)
- Data encrypted at rest (Supabase)
- Users can request data deletion
- Privacy policy: [Your Supabase URL]

See full details: `/docs/android/google-play-submission.md`

---

## 🐛 Known Issues / Limitations

### Flutter Deprecation Warnings
- **Status**: 234 deprecation warnings from `flutter analyze`
- **Impact**: None - all are API changes (MaterialState → WidgetState, etc.)
- **Action**: Can fix later, not blocking for Android deployment
- **Files Affected**: Mostly theme files and Kyle's design screens

### ProGuard/R8 Optimization
- **Status**: Enabled for 30-40% APK size reduction
- **Risk**: Low - all packages support R8
- **Action**: Test thoroughly in release mode before submission

---

## 📋 Complete Pre-Submission Checklist

### Technical Setup
- [x] Build configuration updated (SDK versions, MultiDex)
- [x] Android manifest permissions added
- [x] Notification channels implemented
- [x] ProGuard rules configured
- [ ] **Release keystore generated** ← YOU NEED TO DO THIS
- [ ] **key.properties file created** ← YOU NEED TO DO THIS
- [ ] key.properties added to .gitignore

### Testing
- [ ] Tested on Pixel 7 Pro (Android 14)
- [ ] Notifications working end-to-end
- [ ] Camera/barcode scanning working
- [ ] Location services working
- [ ] Offline mode working
- [ ] All core features functional
- [ ] Performance acceptable in release mode
- [ ] No crashes or critical bugs

### Build & Deploy
- [ ] Release AAB built successfully
- [ ] AAB file verified and tested
- [ ] Shorebird Android initialized
- [ ] Baseline release created

### Play Store Assets
- [ ] Phone screenshots created (min 2, rec 8)
- [ ] Tablet screenshots created (min 2)
- [ ] Feature graphic created (1024x500)
- [ ] App icon confirmed ✅
- [ ] Store listing text prepared
- [ ] Privacy policy reviewed

### Play Store Submission
- [ ] Google Play Developer account ready ✅
- [ ] Content rating completed
- [ ] Data safety declaration completed
- [ ] App submitted for review
- [ ] Open testing track configured

---

## 🎯 Estimated Timeline

**Immediate** (Today):
- [x] Critical Android implementation ← DONE
- [ ] Generate keystore and key.properties (30 mins)

**This Week**:
- [ ] Test on Pixel 7 Pro (4-8 hours)
- [ ] Fix any bugs found (2-4 hours)
- [ ] Build release AAB (30 mins)

**Next Week**:
- [ ] Create Play Store assets (2-3 days)
- [ ] Complete store listing (2 hours)
- [ ] Submit for open testing (1 hour)
- [ ] Set up Shorebird Android (1 hour)

**Total to Open Testing**: 2-3 weeks

---

## 🆘 Troubleshooting

### Build Errors

**"keystore not found"**:
```bash
# Check keystore exists
ls -la ~/upload-keystore.jks

# Check key.properties path is correct
cat android/key.properties
```

**"compileSdk 35 not found"**:
```bash
# Update Android SDK
flutter doctor
# Follow instructions to install missing components
```

**"R8 optimization failed"**:
```bash
# Temporarily disable R8 to isolate issue
# In build.gradle.kts, set:
isMinifyEnabled = false
isShrinkResources = false

# Build and test
# If successful, issue is with ProGuard rules
```

### Runtime Errors

**Notifications not appearing**:
1. Check notification permission granted (Android 13+)
2. Check notification channels created (look for logs)
3. Check notification settings on device
4. Verify notification icon exists (`@mipmap/launcher_icon`)

**Camera not working**:
1. Check camera permission granted
2. Check AndroidManifest has CAMERA permission
3. Try on physical device (emulator camera limited)

**Crashes on startup**:
1. Check Android version (should be Android 5.0+)
2. Check logs: `flutter logs`
3. Check Sentry for crash reports
4. Try debug build to get stack trace

---

## 📚 Documentation References

- **Technical Requirements**: `/docs/android/technical-requirements.md`
- **Implementation Roadmap**: `/docs/android/implementation-roadmap.md`
- **Notification Guide**: `/docs/android/notification-implementation.md`
- **Build Configuration**: `/docs/android/build-configuration.md`
- **Play Store Submission**: `/docs/android/google-play-submission.md`
- **Main README**: `/docs/android/README.md`

---

## ✅ Summary

**You're 80% done with Android deployment!**

The critical technical work is complete. Remaining tasks are:
1. Generate keystore (30 mins) ← **DO THIS FIRST**
2. Test on your Pixel 7 Pro (4-8 hours)
3. Create Play Store assets (2-3 days)
4. Submit to Play Store (2 hours)

All the hard technical implementation is done. The notification system (biggest gap) is now fully implemented for Android with proper channels and Android 13+ permission handling.

**Next immediate action**: Generate the keystore and create key.properties file using the commands in Step 1 & 2 above.

---

**Questions?** Refer to the comprehensive documentation in `/docs/android/` or ask for clarification on any step.
