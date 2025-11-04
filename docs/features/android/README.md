# Android Google Play Release Readiness

## Overview

This directory contains comprehensive documentation for releasing Mealvana Endurance on Google Play Store for Open Testing.

**Current Status:** Version 1.7.1+26
**Target:** Open Testing on Google Play Store
**Timeline:** Estimated 2-3 weeks (depending on asset creation speed)

## Documentation Structure

- **README.md** (this file) - Overview and quick reference
- **roadmap.md** - Complete technical implementation roadmap (AI-assisted tasks)
- **roadmap_lee.md** - Lee's independent action items (manual tasks)

## Quick Status Summary

### ✅ Already Configured
- Google Play Console account exists
- Privacy Policy: https://milkmanfunddev-ops.github.io/mealvana_endurance_landing_page/privacypolicy
- Terms of Service: https://milkmanfunddev-ops.github.io/mealvana_endurance_landing_page/terms
- App Icon: 1024x1024 PNG (meets requirements)
- Package ID: `com.milkman.mealvanaendurance`

### 🔧 Needs Configuration (Technical - AI Can Help)
- [ ] AndroidManifest.xml permissions for notifications, camera, internet
- [ ] Notification channels setup (Android 8.0+)
- [ ] Camera permissions for barcode scanning
- [ ] Target SDK update to Android 14 (API 34) minimum
- [ ] Release signing configuration
- [ ] Shorebird Android integration
- [ ] Data Safety form preparation

### 📸 Needs Creation (Manual - Lee's Tasks)
- [ ] App screenshots (phone & tablet)
- [ ] Feature graphic (1024 x 500)
- [ ] Short description (80 chars max)
- [ ] Full description (4000 chars max)
- [ ] App category selection
- [ ] Content rating questionnaire
- [ ] Store listing review & submission

## Critical Requirements for Google Play (2025)

### 1. Target API Level
- **Required by August 31, 2025:** Target Android 15 (API 35) for new apps
- **Current Requirement:** Target Android 14 (API 34) minimum
- **Your App:** Currently using `flutter.targetSdkVersion` (needs explicit setting)

### 2. Privacy & Data Safety
- **Privacy Policy:** ✅ Ready
- **Data Safety Form:** ⚠️ Needs completion in Play Console
- **Permissions:** Must justify all requested permissions

### 3. App Signing
- **Method:** Google Play App Signing (recommended, you confirmed)
- **Status:** ⚠️ Needs keystore generation and upload

### 4. Content Rating
- **Target:** General Audience (EVERYONE)
- **Status:** ⚠️ Needs questionnaire completion in Play Console

## Testing Strategy

### Device Coverage
- **Primary Test Device:** Google Pixel 7 Pro ✅
- **Minimum SDK:** Android 5.0 (API 21)
- **Recommended Additional Testing:** Android emulators for various screen sizes

### Feature Testing Checklist
- [ ] User authentication flow
- [ ] Offline-first functionality (Drift database)
- [ ] Push notifications (opt-in)
- [ ] Barcode scanning (camera permissions)
- [ ] Supabase backend connectivity
- [ ] Analytics tracking (Mixpanel)
- [ ] Error reporting (Sentry)
- [ ] OTA updates (Shorebird)

## Package-Specific Requirements

Based on your `pubspec.yaml` analysis:

### Active Features Needing Android Setup
1. **flutter_local_notifications** - Notification channels, permissions
2. **mobile_scanner** - Camera permissions, MLKit configuration
3. **sentry_flutter** - ProGuard rules (optional, you declined)
4. **supabase_flutter** - Internet permissions (already basic setup)
5. **mixpanel_flutter** - Internet permissions (covered)
6. **device_info_plus** - Basic permissions (auto-handled)

### Inactive Features (No Setup Needed)
- **speech_to_text** - Not actively used, no microphone permissions needed

## Estimated Timeline

### Week 1: Technical Configuration (AI-Assisted)
- Days 1-2: Android permissions and manifest updates
- Days 3-4: Release build configuration and signing
- Day 5: Shorebird Android setup and testing

### Week 2: Asset Creation & Store Listing (Lee's Manual Work)
- Days 1-3: Screenshot creation and graphic design
- Days 4-5: Store listing text and metadata

### Week 3: Testing & Submission
- Days 1-3: Internal testing and bug fixes
- Days 4-5: Open Testing track submission and review

## Key Contacts & Resources

### Google Play Console
- **URL:** https://play.google.com/console
- **Account:** Your Google Play Developer account

### Documentation Links
- [Android App Release Guide](https://docs.flutter.dev/deployment/android)
- [Google Play Policies](https://developer.android.com/distribute/play-policies)
- [Data Safety Form Guide](https://support.google.com/googleplay/android-developer/answer/10787469)

### External Services Status
- Supabase: ✅ Configured (Dev environment)
- Sentry: ✅ Configured
- Mixpanel: ✅ Configured
- Shorebird: ⚠️ iOS only, needs Android setup

## Next Steps

1. **Start with Technical Configuration** → See `roadmap.md`
2. **Parallel: Begin Asset Creation** → See `roadmap_lee.md`
3. **Test on Pixel 7 Pro** → Follow testing checklist
4. **Submit for Open Testing** → Final steps in `roadmap_lee.md`

## Questions or Issues?

Refer to the detailed roadmaps for step-by-step instructions. Each roadmap includes:
- Prerequisites
- Detailed steps with code examples
- Verification methods
- Common troubleshooting

---

**Last Updated:** 2025-10-17
**App Version:** 1.7.1+26
**Status:** Pre-release planning
