# Android Google Play Release Documentation (LEGACY)

⚠️ **NOTICE: This documentation is outdated and archived.**

---

## 🔴 DEPRECATED DOCUMENTATION

**Original Version:** 1.7.1+26
**Last Updated:** 2025-10-17
**Status:** ARCHIVED - DO NOT USE

This documentation is **no longer accurate** for the current version of Mealvana Endurance.

---

## ✅ Current Documentation Location

**Updated Android deployment documentation for v1.9.0+30 is now available at:**

📂 **[/docs/features/android/](/docs/features/android/)**

### New Documentation Structure

| Document | Purpose |
|----------|---------|
| [README.md](/docs/features/android/README.md) | Overview, quick links, status summary |
| [technical-requirements.md](/docs/features/android/technical-requirements.md) | SDK versions, package requirements, Gradle config |
| [implementation-roadmap.md](/docs/features/android/implementation-roadmap.md) | Step-by-step deployment plan (5-7 days) |
| [notification-implementation.md](/docs/features/android/notification-implementation.md) | Complete Android notification setup guide |
| [build-configuration.md](/docs/features/android/build-configuration.md) | Gradle, signing, AndroidManifest configuration |
| [google-play-submission.md](/docs/features/android/google-play-submission.md) | Store listing and submission process |

---

## Key Differences Between v1.7.1+26 and v1.9.0+30

### Version Changes
- **Old Version:** 1.7.1+26 (documented here)
- **New Version:** 1.9.0+30 (current)
- **Build Number Jump:** +4 versions
- **Code Changes:** Major refactoring, new features

### Technical Updates
| Requirement | v1.7.1+26 (Old) | v1.9.0+30 (New) |
|-------------|-----------------|-----------------|
| **compileSdk** | Unknown/34 | **35** (critical change) |
| **targetSdk** | Unknown/34 | **34** (explicit) |
| **minSdk** | Unknown | **21** (explicit) |
| **Desugaring** | Not configured | **Required** |
| **MultiDex** | Not enabled | **Required** |
| **Notifications** | Partially implemented | **Full Android support needed** |
| **Camera Permissions** | Not configured | **Required in manifest** |

### Package Updates
Several packages have updated requirements:
- **supabase_flutter:** 2.8.5 requires compileSdk 35
- **sentry_flutter:** 9.6.0 requires compileSdk 35
- **flutter_local_notifications:** 19.4.1 requires Android notification channels

### Critical Blockers (New in v1.9.0+30)
1. **Notification Implementation** - iOS-only code in `notification_service.dart` lines 60-96
2. **Target SDK** - Must be explicitly set to 34 (Google Play requirement)
3. **Release Signing** - Currently using debug keys (cannot publish)
4. **Missing Permissions** - POST_NOTIFICATIONS, CAMERA, RECEIVE_BOOT_COMPLETED

---

## Why This Documentation Was Archived

This directory contains outdated information that:
- References old package versions
- Missing critical Android 13+ permission requirements
- Does not cover new notification channel implementation
- Incomplete build configuration for current dependencies
- Missing Shorebird Android setup (now required)

**Using this old documentation could result in:**
- ❌ Build failures (wrong SDK versions)
- ❌ Google Play rejection (missing permissions)
- ❌ App crashes (missing desugaring)
- ❌ Features not working (notification channels)

---

## Migration Guide

If you were following this old documentation:

### Stop Following Old Docs
1. Ignore SDK version recommendations here
2. Don't use old permission configurations
3. Skip outdated package setup instructions

### Start Using New Docs
1. Read [/docs/features/android/README.md](/docs/features/android/README.md) for overview
2. Follow [/docs/features/android/implementation-roadmap.md](/docs/features/android/implementation-roadmap.md) step-by-step
3. Reference [/docs/features/android/technical-requirements.md](/docs/features/android/technical-requirements.md) for package details

### Key Migration Steps
1. **Update build.gradle.kts:**
   - Set compileSdk = 35 (not 34)
   - Set targetSdk = 34 explicitly
   - Enable multiDexEnabled = true
   - Enable desugaring

2. **Update AndroidManifest.xml:**
   - Add POST_NOTIFICATIONS permission
   - Add CAMERA permission
   - Add notification receivers
   - Add RECEIVE_BOOT_COMPLETED permission

3. **Implement Android Notifications:**
   - Update notification_service.dart
   - Add notification channels
   - Implement Android 13+ permission requests

4. **Configure Release Signing:**
   - Generate production keystore
   - Create key.properties
   - Update build.gradle.kts signing configs

---

## What's Preserved Here

For historical reference, this directory still contains:

- **roadmap.md** - Original technical roadmap (v1.7.1+26)
- **roadmap_lee.md** - Original manual tasks (v1.7.1+26)
- **data_safety_answers.md** - Data safety declaration (still relevant)

**Note:** The data safety declaration is still largely accurate, but should be reviewed against the new documentation.

---

## Questions?

- **For current Android deployment:** See [/docs/features/android/README.md](/docs/features/android/README.md)
- **For technical requirements:** See [/docs/features/android/technical-requirements.md](/docs/features/android/technical-requirements.md)
- **For step-by-step guide:** See [/docs/features/android/implementation-roadmap.md](/docs/features/android/implementation-roadmap.md)

---

## Archive Information

**This directory will remain for historical reference but should not be used for current development.**

**Archived Date:** 2025-11-12
**Archived Version:** 1.7.1+26
**Reason:** Major version update and technical requirement changes

---

*For all current Android deployment tasks, please use [/docs/features/android/](/docs/features/android/) documentation.*
