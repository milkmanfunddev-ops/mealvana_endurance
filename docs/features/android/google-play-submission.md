# Google Play Store Submission Guide

**Version:** 1.9.0+30
**Target:** Open Testing Release
**Last Updated:** 2025-11-12

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Store Listing Setup](#store-listing-setup)
- [Asset Requirements](#asset-requirements)
- [Data Safety Declaration](#data-safety-declaration)
- [Content Rating](#content-rating)
- [App Release Process](#app-release-process)
- [Post-Submission](#post-submission)

---

## Overview

This guide provides step-by-step instructions for submitting Mealvana Endurance v1.9.0+30 to Google Play Store for Open Testing. Open Testing allows you to distribute the app to unlimited testers before a full production release.

### Submission Timeline

| Phase | Duration | Notes |
|-------|----------|-------|
| Store listing setup | 1-2 hours | One-time configuration |
| Asset creation | 2-3 hours | Screenshots, graphics |
| Data safety form | 30-60 minutes | Comprehensive declaration |
| Content rating | 15-30 minutes | Questionnaire |
| AAB upload | 5-10 minutes | Build + upload time |
| **Google review** | **1-3 days** | First submission (longer) |
| **Future updates** | **1-24 hours** | Subsequent submissions (faster) |

---

## Prerequisites

Before starting Google Play Console setup:

### Technical Prerequisites

- [ ] Release AAB built successfully: `flutter build appbundle --release`
- [ ] AAB signed with production keystore (not debug keys)
- [ ] All required permissions in AndroidManifest.xml
- [ ] Target SDK set to 34 (Android 14)
- [ ] App tested on physical Android device
- [ ] No critical bugs or crashes

### Business Prerequisites

- [ ] Google Play Developer account ($25 one-time fee)
- [ ] Privacy policy URL live and accessible
- [ ] Terms of service URL live (if applicable)
- [ ] Support email address set up
- [ ] App name decided (max 30 characters)
- [ ] App icon finalized (512x512 PNG)

### Asset Prerequisites

- [ ] Phone screenshots (2-8 required)
- [ ] 7-inch tablet screenshots (optional but recommended)
- [ ] 10-inch tablet screenshots (optional but recommended)
- [ ] Feature graphic (1024x500 PNG)
- [ ] App icon (512x512 PNG)

---

## Store Listing Setup

### Step 1: Create App in Play Console

1. Go to [Google Play Console](https://play.google.com/console/)
2. Click **Create app**
3. Fill in basic information:

| Field | Value | Notes |
|-------|-------|-------|
| **App name** | Mealvana Run | Max 30 characters, user-visible |
| **Default language** | English (United States) | Primary language |
| **App or game** | App | Not a game |
| **Free or paid** | Free | No upfront cost |

4. **Declarations:**
   - [ ] Check "I confirm this app complies with Google Play policies"
   - [ ] Check "I confirm this app does not contain ads" (if true)
   - [ ] Accept developer program policies

5. Click **Create app**

### Step 2: Store Listing Details

**Navigation:** Dashboard > Store presence > Main store listing

#### App Details

**App name:**
```
Mealvana Run
```

**Short description (80 characters max):**
```
Personalized nutrition plans for endurance athletes. Science-based fueling.
```

**Full description (4000 characters max):**
```
Mealvana Run provides personalized nutrition fueling plans for endurance athletes—from 5K runners to ultra-marathoners and triathletes.

🏃 SCIENCE-BASED CALCULATIONS
Our algorithm uses ACSM (American College of Sports Medicine) formulas to calculate your energy expenditure based on:
• Distance and pace
• Body weight
• Gut training level
• Sport-specific demands

🍽️ PERSONALIZED FOOD SELECTION
Never eat foods you dislike again. Our system:
• Respects your food preferences
• Considers pre-run, during-run, and post-run needs
• Optimizes for carbs, protein, fat, and hydration
• Provides portion sizes and timing guidance

📱 OFFLINE-FIRST DESIGN
• All nutrition plans stored locally
• Works without internet connection
• Sync across devices when online
• Fast, reliable access to your plans

📊 BARCODE SCANNING
• Quickly add foods by scanning barcodes
• Access nutritional information instantly
• Build custom food lists

🔔 MEAL REMINDERS
• Set notifications for pre-run meals
• During-run fueling reminders
• Post-run recovery nutrition

🎯 EVIDENCE-BASED GUIDELINES
• Carbohydrate requirements based on gut training
• Hydration based on exercise intensity
• Sodium supplementation for duration
• Safety limits and recommendations

WHO IT'S FOR
• Marathon and ultra-marathon runners
• Triathletes (Ironman, 70.3, Olympic, Sprint)
• Cyclists planning long rides
• Any endurance athlete seeking nutrition guidance

FEATURES
✅ Personalized nutrition plans
✅ ACSM-based calculations
✅ Food preference integration
✅ Barcode scanning
✅ Offline mode
✅ Meal reminders
✅ Multi-sport support (running, cycling, swimming)
✅ Race day preparation
✅ Gut training optimization

GET STARTED
1. Input your activity details (distance, pace, weight)
2. Set your food preferences
3. Indicate your gut training level
4. Generate your personalized plan
5. Follow the guidance on race day

SUPPORT
Questions? Contact us at support@mealvana.com
Privacy policy: https://yourmealvana.com/privacy-policy

Fuel smarter. Perform better. 🚀
```

#### Contact Details

**Email:**
```
support@mealvana.com
```

**Phone (optional):**
```
(Optional - leave blank unless you want to provide phone support)
```

**Website:**
```
https://yourmealvana.com
```

**Privacy Policy URL:**
```
https://yourmealvana.com/privacy-policy
```

⚠️ **CRITICAL:** Privacy policy URL **must** be live and accessible before submission.

#### Category & Tags

**Category:**
```
Health & Fitness
```

**Tags (up to 5):**
```
- Nutrition
- Running
- Endurance Sports
- Fitness
- Health
```

#### Store Settings

**Enable app contains ads:**
```
☐ No (assuming no ads)
```

**Merchandising:**
```
☐ This app is an internal app (private distribution)
```

---

## Asset Requirements

### Required Assets

#### 1. App Icon (512x512 PNG)

**Specifications:**
- Size: 512x512 pixels
- Format: PNG (32-bit)
- Max file size: 1024 KB
- No transparency
- Square, no rounded corners (Google applies rounding)

**Source:**
- Use existing launcher icon: `/assets/images/endurance_launcher_icon_basecream_1024.png`
- Resize to 512x512 if needed

**Design Guidelines:**
- Clear, simple design
- Recognizable at small sizes
- No text or small details
- Avoid transparency (will be ignored)

#### 2. Feature Graphic (1024x500 PNG)

**Specifications:**
- Size: 1024x500 pixels (exact)
- Format: PNG or JPEG
- Max file size: 1024 KB

**Design Guidelines:**
- Showcase app's key feature or brand
- No text (will be covered by Play Store badge)
- High-quality, professional design
- Use brand colors (#FFF9F0 base cream)

**Example Content:**
- Hero image of runner with nutrition plan overlay
- App screenshot with mockup device
- Brand logo + tagline

#### 3. Phone Screenshots (2-8 required)

**Specifications:**
- Min: 320px on short edge
- Max: 3840px on short edge
- Aspect ratio: 16:9 or 9:16
- Format: PNG or JPEG
- Max file size: 8 MB each

**Recommended Size:**
```
1080x2400 pixels (9:16 portrait)
```

**Required Screens:**
1. **Home/Onboarding** - First impression
2. **Nutrition Plan** - Core feature
3. **Activity Input** - User interaction
4. **Food Selection** - Personalization
5. **Calendar/Schedule** - Organization
6. **Settings/Profile** - Customization
7. **Barcode Scanner** - Convenience feature (optional)
8. **Analytics/Progress** - Tracking (optional)

**Design Tips:**
- Use actual app screens (not mockups)
- Add minimal text overlay if needed
- Show key features in action
- Use consistent device frame (optional)
- Ensure text is readable

**How to Capture:**
```bash
# Connect Android device
adb devices

# Take screenshot
adb shell screencap -p /sdcard/screenshot.png

# Pull to computer
adb pull /sdcard/screenshot.png

# Or use Android Studio:
# View > Tool Windows > Device File Explorer > /sdcard/
```

#### 4. Tablet Screenshots (Optional but Recommended)

**7-inch Tablet:**
```
1200x1920 pixels (10:16)
```

**10-inch Tablet:**
```
1600x2560 pixels (10:16)
```

**Note:** If you don't have tablet screenshots, Play Store will use phone screenshots with letterboxing.

### Asset Checklist

- [ ] App icon (512x512 PNG)
- [ ] Feature graphic (1024x500 PNG)
- [ ] At least 2 phone screenshots (1080x2400)
- [ ] Up to 8 phone screenshots total
- [ ] 7-inch tablet screenshots (optional)
- [ ] 10-inch tablet screenshots (optional)

---

## Data Safety Declaration

**Navigation:** Dashboard > App content > Data safety

This section is **critical** for Google Play approval. You must disclose all data collection, sharing, and security practices.

### Overview Section

**Does your app collect or share any user data?**
```
✅ Yes
```

**Is all of the user data collected by your app encrypted in transit?**
```
✅ Yes
```

**Do you provide a way for users to request deletion of their data?**
```
✅ Yes
```

**How to request deletion:**
```
Users can request data deletion by emailing support@mealvana.com.
We will delete all user data within 30 days of the request.
```

### Data Types Collected

#### 1. Name

**Collected:**
```
✅ Yes
```

**Is this data collection optional?**
```
☐ No (required for account creation)
```

**Purpose:**
```
☑ App functionality (account creation)
☐ Personalization
☐ Analytics
```

**Shared with third parties:**
```
☐ No
```

#### 2. Email Address

**Collected:**
```
✅ Yes
```

**Is this data collection optional?**
```
☐ No (required for authentication)
```

**Purpose:**
```
☑ App functionality (authentication)
☑ Account management
☐ Analytics
```

**Shared with third parties:**
```
☐ No
```

#### 3. User ID

**Collected:**
```
✅ Yes
```

**Is this data collection optional?**
```
☐ No (automatic)
```

**Purpose:**
```
☑ App functionality (user identification)
☑ Account management
☐ Analytics
```

**Shared with third parties:**
```
☐ No
```

**Note:**
```
Internally generated user ID, not tied to external services
```

#### 4. Health & Fitness Data

**Data types:**
```
☑ Body measurements (weight)
☑ Fitness information (running distance, pace)
☑ Nutrition information (meal plans, food intake)
```

**Collected:**
```
✅ Yes
```

**Is this data collection optional?**
```
☐ No (core app functionality)
```

**Purpose:**
```
☑ App functionality (nutrition plan generation)
☐ Personalization
☐ Analytics
```

**Shared with third parties:**
```
☐ No
```

#### 5. App Activity

**Data types:**
```
☑ App interactions (button taps, screen views)
☑ In-app search history (food searches)
☐ Installed apps
☐ Other user-generated content
```

**Collected:**
```
✅ Yes
```

**Is this data collection optional?**
```
☐ No (automatic)
```

**Purpose:**
```
☑ Analytics (Mixpanel)
☑ App functionality
☐ Personalization
```

**Shared with third parties:**
```
✅ Yes
```

**Third party:**
```
Mixpanel (Analytics platform)
```

#### 6. App Info & Performance

**Data types:**
```
☑ Crash logs
☑ Diagnostics
☐ Performance data
```

**Collected:**
```
✅ Yes
```

**Is this data collection optional?**
```
☐ No (automatic)
```

**Purpose:**
```
☑ Analytics (error tracking)
☑ App functionality
☐ Personalization
```

**Shared with third parties:**
```
✅ Yes
```

**Third party:**
```
Sentry (Error tracking platform)
```

#### 7. Device ID

**Collected:**
```
✅ Yes
```

**Is this data collection optional?**
```
☐ No (automatic)
```

**Purpose:**
```
☑ App functionality (user identification)
☑ Analytics
☐ Fraud prevention
```

**Shared with third parties:**
```
☐ No
```

**Note:**
```
Used for anonymous user identification. Not shared with third parties.
Generated using device_info_plus package.
```

### Security Practices

**Is data encrypted in transit?**
```
✅ Yes (HTTPS for all network traffic)
```

**Is data encrypted at rest?**
```
✅ Yes (Supabase PostgreSQL with encryption at rest)
```

**Can users request data deletion?**
```
✅ Yes
```

**Deletion process:**
```
Users email support@mealvana.com
Data deleted within 30 days
Confirmation sent to user
```

### Data Safety Summary

| Data Type | Collected | Shared | Purpose |
|-----------|-----------|--------|---------|
| Name | Yes | No | Account creation |
| Email | Yes | No | Authentication |
| User ID | Yes | No | User identification |
| Health & Fitness | Yes | No | Nutrition plan generation |
| App Activity | Yes | Yes (Mixpanel) | Analytics |
| Crash Logs | Yes | Yes (Sentry) | Error tracking |
| Device ID | Yes | No | User identification |

---

## Content Rating

**Navigation:** Dashboard > App content > Content rating

### Questionnaire

Google Play uses IARC (International Age Rating Coalition) for content rating.

**App Category:**
```
○ Reference, News, or Educational
○ Entertainment
○ Social, Communication, or User-Generated Content
● Utilities, Productivity, Communication, or Other
```

**Does your app contain violence?**
```
○ Yes
● No
```

**Does your app contain sexual content?**
```
○ Yes
● No
```

**Does your app contain language some users might find objectionable?**
```
○ Yes
● No
```

**Does your app contain adult/suggestive themes?**
```
○ Yes
● No
```

**Does your app allow users to interact or exchange information?**
```
○ Yes
● No (no social features, messaging, or user-to-user interaction)
```

**Does your app share user location with other users?**
```
○ Yes
● No
```

**Can users purchase digital goods or services?**
```
○ Yes
● No
```

**Does your app contain ads?**
```
○ Yes
● No
```

**Expected Rating:**
```
ESRB: Everyone
PEGI: 3
USK: All ages
```

---

## App Release Process

### Step 1: Build Final Release AAB

```bash
# Clean build environment
flutter clean

# Build release AAB
flutter build appbundle --release

# Verify build succeeded
ls -lh build/app/outputs/bundle/release/app-release.aab

# Expected: ~30-50MB file
```

### Step 2: Upload AAB to Play Console

**Navigation:** Dashboard > Release > Testing > Open testing

1. Click **Create new release**
2. Click **Upload** button
3. Select `build/app/outputs/bundle/release/app-release.aab`
4. Wait for upload and processing (~5-10 minutes)

**During Processing:**
- Google scans for malware
- Generates APKs for different device configurations
- Analyzes supported devices
- Checks for policy violations

### Step 3: Review Release Details

After processing, review:

**App Bundle Details:**
```
Version: 1.9.0 (30)
Size: ~30-50MB
Supported devices: ~12,000+ (check coverage)
API levels: 21-35 (Android 5.0 - Android 15)
```

**Supported Devices:**
- Click **View supported devices**
- Expected: 99%+ device coverage
- If low coverage, investigate issues

**Size Warnings:**
- Review any size warnings
- Large app size may impact download conversion
- Consider ProGuard/R8 if size is concerning

### Step 4: Add Release Notes

**Release notes (500 characters max):**
```
Initial Android release of Mealvana Run! 🎉

New Features:
• Personalized nutrition plans for endurance athletes
• Science-based ACSM calculations
• Food preference integration
• Barcode scanning
• Offline mode with local database
• Meal reminders
• Multi-sport support (running, cycling, swimming)

This is an open testing release. We'd love your feedback!
Report issues: support@mealvana.com
```

**Notes for Different Languages:**
- Can add localized release notes later
- English is sufficient for initial release

### Step 5: Review and Rollout

1. Review all information
2. Click **Review release**
3. Address any issues flagged by Play Console
4. Click **Start rollout to Open testing**

**Confirmation Dialog:**
```
"Are you sure you want to start this rollout?"
```

Click **Rollout**

### Step 6: Wait for Review

**What Happens Next:**
1. Google reviews app for policy compliance
2. Reviews typically take 1-3 days (first submission)
3. You'll receive email when review completes
4. App becomes available to testers after approval

**Review Email:**
- ✅ Approved: App available for open testing
- ❌ Rejected: Review feedback and resubmit

---

## Post-Submission

### Get Opt-In URL

After approval, get the open testing opt-in URL:

**Navigation:** Dashboard > Release > Testing > Open testing > Testers tab

**Opt-in URL:**
```
https://play.google.com/apps/testing/com.milkman.mealvana endurance
```

**Share with Testers:**
1. Send via email
2. Post on social media
3. Add to website
4. Share in communities/forums

### Monitor Feedback

**Play Console Feedback:**
- Dashboard > Quality > Reviews
- Read tester reviews
- Respond to feedback

**Crash Reports:**
- Dashboard > Quality > Android vitals
- Monitor crash rate (should be < 1%)
- Review crash stack traces

**Sentry Dashboard:**
- Monitor Android crashes
- Track error frequency
- Review breadcrumbs

**Mixpanel Analytics:**
- Track Android user behavior
- Compare iOS vs Android usage
- Identify popular features

### Track Metrics

**Key Metrics to Monitor:**

| Metric | Target | Source |
|--------|--------|--------|
| Install conversion | >50% | Play Console |
| Crash rate | <1% | Play Console, Sentry |
| ANR rate | <0.5% | Play Console |
| Tester reviews | >4.0 stars | Play Console |
| Active testers | >10 users | Play Console |
| Feature usage | Track key features | Mixpanel |

### Respond to Testers

**Response Template:**
```
Thank you for testing Mealvana Run! We appreciate your feedback.

[Address specific feedback]

We're actively working on improvements. Please continue sharing your thoughts!

- Mealvana Team
```

**Response Guidelines:**
- Respond within 1-3 days
- Be professional and grateful
- Address specific concerns
- Don't make promises you can't keep
- Explain when features are coming

### Release Updates

**For Dart Code Changes (Shorebird Patch):**
```bash
# Create patch
shorebird patch android --target lib/main.dart

# Users receive update automatically (no review)
# Typical delivery time: 1-24 hours
```

**For Native Changes (Full Release):**
```bash
# Build new AAB
flutter build appbundle --release

# Upload to Play Console
# Go through review process again (~1-24 hours)
```

---

## Submission Checklist

### Pre-Submission

- [ ] Release AAB built successfully
- [ ] AAB signed with production keystore
- [ ] Target SDK = 34
- [ ] All permissions declared in manifest
- [ ] App tested on physical Android device
- [ ] No critical bugs
- [ ] Privacy policy URL live
- [ ] Support email set up

### Play Console Setup

- [ ] App created in Play Console
- [ ] Store listing completed
- [ ] App description written (4000 char max)
- [ ] Contact details added
- [ ] Category and tags selected
- [ ] App icon uploaded (512x512)
- [ ] Feature graphic uploaded (1024x500)
- [ ] Phone screenshots uploaded (2-8)
- [ ] Tablet screenshots uploaded (optional)

### App Content

- [ ] Data safety declaration completed
- [ ] All data types disclosed
- [ ] Third-party sharing declared
- [ ] Security practices described
- [ ] Data deletion process explained
- [ ] Content rating questionnaire completed
- [ ] Privacy policy linked

### Release

- [ ] AAB uploaded to open testing
- [ ] Release notes written
- [ ] Review started
- [ ] Opt-in URL obtained
- [ ] Testers invited

### Post-Launch

- [ ] Monitoring set up (Sentry, Mixpanel)
- [ ] Feedback process established
- [ ] Update plan defined (Shorebird)
- [ ] Team trained on patch vs. release

---

## Resources

- [Google Play Console](https://play.google.com/console/)
- [Play Store Listing Guidelines](https://support.google.com/googleplay/android-developer/answer/9866151)
- [Data Safety Guide](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Content Rating Guide](https://support.google.com/googleplay/android-developer/answer/9859655)
- [App Review Process](https://support.google.com/googleplay/android-developer/answer/9859455)

---

*Last updated: 2025-11-12 for Mealvana Endurance v1.9.0+30*
