# Android Deployment Documentation

**Version:** 1.9.0+30
**Status:** 🔴 Pre-deployment (Critical blockers exist)
**Last Updated:** 2025-11-12

---

## Quick Links

- [Technical Requirements](./technical-requirements.md) - SDK versions, package requirements, Gradle config
- [Implementation Roadmap](./implementation-roadmap.md) - Step-by-step deployment plan
- [Notification Implementation](./notification-implementation.md) - Android notification setup guide
- [Build Configuration](./build-configuration.md) - Gradle, signing, and build setup
- [Google Play Submission](./google-play-submission.md) - Store listing and submission checklist
- [Legacy Documentation](../features/android/) - Outdated v1.7.1+26 docs (archived)

---

## Executive Summary

Mealvana Endurance (v1.9.0+30) is currently deployed on iOS and requires Android deployment to Google Play Store. This documentation provides a comprehensive guide for implementing the necessary technical requirements and submitting the app for Open Testing.

### Current Status

**✅ What's Working:**
- Core app functionality is platform-agnostic
- All major features work on Android (tested locally)
- Minimal platform-specific code (12 Platform.is checks)
- Well-abstracted architecture using FOA patterns

**🔴 Critical Blockers:**
1. **Target SDK not set to 34** - Google Play requires Android 14 (API 34)
2. **Release signing using debug keys** - Cannot publish without proper signing
3. **Android notification implementation missing** - iOS-only code in `notification_service.dart`
4. **Missing permissions** - POST_NOTIFICATIONS, CAMERA, RECEIVE_BOOT_COMPLETED

**🟡 Medium Priority:**
- compileSdk should be 35 (future-proofing)
- MultiDex should be enabled
- Desugaring needed for notification compatibility
- Shorebird Android setup pending

### Timeline Estimate

**Technical Implementation:** 5-7 days
- Day 1: Manifest & permissions
- Day 2: Target SDK & build config
- Day 3: Release signing setup
- Day 4: Notification implementation
- Day 5: Shorebird Android setup
- Day 6-7: Testing & validation

**Store Listing Assets:** 2-3 days (manual)
- Screenshots (phone & tablet)
- Feature graphic
- Store description
- Privacy policy

**Total:** 7-10 days

---

## Priority Order

### Phase 1: Critical Fixes (Days 1-3)
These must be completed before any submission to Google Play:

1. **Update AndroidManifest.xml** - Add required permissions
2. **Update build.gradle.kts** - Set targetSdk to 34, compileSdk to 35
3. **Configure Release Signing** - Generate keystore and configure signing
4. **Implement Android Notifications** - Replace iOS-only code

### Phase 2: Testing & Validation (Days 4-5)
Ensure all features work correctly on Android:

1. **Test on Physical Device** - Pixel 7 Pro recommended
2. **Verify Permissions** - Camera, notifications, location
3. **Test Offline Mode** - Drift database functionality
4. **Validate Analytics** - Mixpanel and Sentry integration

### Phase 3: Deployment Preparation (Days 6-7)
Prepare for Google Play Store submission:

1. **Build Release AAB** - `flutter build appbundle --release`
2. **Configure Shorebird** - Enable OTA updates for Android
3. **Create Store Listing** - Screenshots, descriptions, data safety
4. **Submit for Open Testing** - Initial release to testers

---

## Key Files Reference

### Current State Files

**Build Configuration:**
- `/android/app/build.gradle.kts` - Build settings (needs update)
- `/android/app/src/main/AndroidManifest.xml` - Permissions (incomplete)

**Platform-Specific Code:**
- `/lib/shared/services/notification_service.dart:60-96` - 🔴 iOS-only (CRITICAL)
- `/lib/features/auth/application/auth_service.dart:191-212` - ✅ Cross-platform OK

**Dependencies:**
- `/pubspec.yaml` - Package versions (all compatible)

### Files to Create

- `/android/key.properties` - Release signing configuration (Lee creates this)
- `/android/app/mealvana-release-key.jks` - Release keystore (Lee generates this)

---

## Package Compatibility Summary

All major packages have been researched for Android compatibility:

| Package | Version | Android Requirements | Status |
|---------|---------|---------------------|--------|
| flutter_local_notifications | 19.4.1 | API 34+, notification channels | 🔴 Needs implementation |
| mobile_scanner | 7.0.1 | Camera permission | ✅ Works (needs permission) |
| supabase_flutter | 2.8.5 | compileSdk 35 | ✅ Compatible |
| sentry_flutter | 9.6.0 | compileSdk 35 | ✅ Compatible |
| drift | 2.20.0 | No special requirements | ✅ Works |
| geolocator | 13.0.2 | Location permissions | ✅ Has permissions |
| mixpanel_flutter | 2.4.4 | No special requirements | ✅ Works |

See [Technical Requirements](./technical-requirements.md) for detailed package analysis.

---

## Risk Assessment

### High Risk (Blockers)
- **Notification Implementation**: Largest gap, requires new Android-specific code
- **Release Signing**: If keystore is lost, cannot update the app ever
- **Target SDK 34**: Google Play rejects submissions without this

### Medium Risk (Manageable)
- **Camera Permissions**: `mobile_scanner` handles most of this automatically
- **Testing Coverage**: Need physical Android device testing
- **Shorebird Android**: New deployment method, requires setup

### Low Risk (Minor)
- **Analytics Integration**: Already works, just needs testing
- **Offline Mode**: Drift database is platform-agnostic
- **UI/UX**: Flutter renders consistently across platforms

---

## Success Criteria

Before submitting to Google Play Open Testing:

- [ ] App builds successfully: `flutter build appbundle --release`
- [ ] No `flutter analyze` errors or warnings
- [ ] Target SDK is 34 (Android 14)
- [ ] Compile SDK is 35 (future-proofing)
- [ ] All required permissions in AndroidManifest.xml
- [ ] Notification channels created and working on Android
- [ ] Camera permission requested and handled
- [ ] Release signing configured with production keystore
- [ ] Shorebird Android initialized and tested
- [ ] App tested on physical Android device (Pixel 7 Pro)
- [ ] All critical features working (auth, plans, notifications, scanning)
- [ ] Data Safety form completed in Play Console
- [ ] Privacy Policy and Terms of Service URLs live
- [ ] Screenshots and store listing assets uploaded

---

## Getting Started

1. **Read [Implementation Roadmap](./implementation-roadmap.md)** - Understand the full deployment plan
2. **Review [Technical Requirements](./technical-requirements.md)** - Ensure you understand all Android-specific needs
3. **Start with [Build Configuration](./build-configuration.md)** - Begin with Gradle and manifest updates
4. **Follow [Notification Implementation](./notification-implementation.md)** - Implement Android notifications
5. **Complete [Google Play Submission](./google-play-submission.md)** - Prepare store listing

---

## Resources

### Official Documentation
- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [Android Developer Docs](https://developer.android.com/docs)

### Package Documentation
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- [mobile_scanner](https://pub.dev/packages/mobile_scanner)
- [sentry_flutter](https://docs.sentry.io/platforms/flutter/)
- [Shorebird Docs](https://docs.shorebird.dev/)

### Tools
- [Android Studio](https://developer.android.com/studio)
- [adb (Android Debug Bridge)](https://developer.android.com/tools/adb)
- [Bundletool](https://developer.android.com/tools/bundletool) - AAB testing

---

## Support

**Internal Resources:**
- CLAUDE.md - Project context and architecture
- /docs/technical/ - Technical documentation
- /docs/database/ - Database architecture

**Questions?**
- Check existing documentation first
- Review similar iOS implementations
- Consult Flutter and Android official docs

---

*This documentation is part of the Mealvana Endurance project and follows the Feature-Oriented Architecture (FOA) patterns established by Andrea Bizzotto.*
