# Android Release Roadmap - Lee's Action Items

**Manual Tasks**: These are tasks that you (Lee) need to complete independently. They cannot be fully automated by AI assistance.

**Target:** Open Testing release on Google Play Store
**Timeline:** 7-10 days (depending on asset creation speed)

---

## 🔐 Phase 1: Create Release Keystore (Day 1) - CRITICAL

### Why This Matters
This cryptographic key signs your app. Without it, you cannot upload to Google Play. **You must keep this file and passwords safe forever.**

### Step-by-Step Instructions

1. **Open Terminal** and navigate to your Android app folder:
   ```bash
   cd ~/development/mealvana_endurance/android/app
   ```

2. **Generate the keystore** (you'll be prompted for information):
   ```bash
   keytool -genkey -v -keystore mealvana-release-key.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias mealvana-release
   ```

3. **Answer the prompts:**
   - **Keystore password:** Create a strong password (WRITE THIS DOWN)
   - **Re-enter password:** Same as above
   - **Key password:** Can be same as keystore password (WRITE THIS DOWN)
   - **What is your first and last name?** Your name or company name
   - **What is the name of your organizational unit?** (e.g., "Development" or press Enter)
   - **What is the name of your organization?** "Milkman" or "Mealvana"
   - **What is the name of your City or Locality?** Your city
   - **What is the name of your State or Province?** Your state
   - **What is the two-letter country code for this unit?** US (or your country)
   - **Is CN=..., OU=..., O=..., L=..., ST=..., C=... correct?** Type "yes"

4. **Verify the file was created:**
   ```bash
   ls -la mealvana-release-key.jks
   ```
   You should see a file around 2-3 KB.

5. **Create key.properties file:**
   ```bash
   cd ~/development/mealvana_endurance/android
   nano key.properties
   ```

   **Type this (replace with YOUR passwords):**
   ```properties
   storePassword=YOUR_KEYSTORE_PASSWORD_HERE
   keyPassword=YOUR_KEY_PASSWORD_HERE
   keyAlias=mealvana-release
   storeFile=app/mealvana-release-key.jks
   ```

   **Save:** Press `Ctrl+X`, then `Y`, then `Enter`

6. **CRITICAL: Back up these files securely:**
   - `android/app/mealvana-release-key.jks`
   - `android/key.properties`
   - The passwords you created (use a password manager)

   **⚠️ If you lose these, you can NEVER update your app on Google Play again!**

7. **Verify it's not in git** (should already be ignored):
   ```bash
   git status
   # Should NOT show key.properties or *.jks files
   ```

---

## 📸 Phase 2: Create Store Listing Assets (Days 2-5)

### 2.1 App Screenshots (REQUIRED)

**What Google Play Needs:**
- **Minimum:** 2 screenshots
- **Recommended:** 4-8 screenshots
- **Format:** PNG or JPEG
- **Dimensions:**
  - **Phone:** 16:9 aspect ratio (e.g., 1920x1080, 1080x1920)
  - **Tablet (optional but recommended):** 7-inch or 10-inch tablet screenshots

**Screen Ideas to Capture:**

1. **Onboarding/Welcome Screen** - Show the value proposition
2. **User Profile Setup** - Show personalization
3. **Distance/Pace Entry** - Core functionality
4. **Generated Nutrition Plan** - The main value delivery
5. **Food Selection** - Show food preferences
6. **Calendar/Schedule View** - If applicable
7. **Barcode Scanner** - Unique feature
8. **Settings/Profile** - Show control options

**How to Capture on Pixel 7 Pro:**

```bash
# Method 1: Using flutter run
flutter run --release

# While app is running, take screenshots:
# 1. Power + Volume Down buttons on Pixel 7 Pro
# 2. Screenshots saved to Photos app

# Method 2: Using adb
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png ~/Desktop/mealvana_screenshots/
```

**Pro Tips:**
- Use a clean test account with realistic data
- Remove any personal information
- Use the app in "pretty" state (no errors, full data)
- Ensure good lighting/contrast
- Consider adding text overlays explaining each screen (optional)

**Tools for Adding Text Overlays/Polish:**
- **Figma** (free): https://figma.com - Design tool for adding text
- **Canva** (free): https://canva.com - Templates for app screenshots
- **Sketch** (Mac, paid): Professional design tool
- **Photoshop/GIMP** (free GIMP): Advanced editing

**Recommended Screenshot Sizes:**
- **1080 x 1920** (portrait) - Most common
- **1920 x 1080** (landscape) - Alternative

---

### 2.2 Feature Graphic (REQUIRED)

**Specifications:**
- **Size:** 1024 x 500 pixels
- **Format:** PNG or JPEG
- **Max file size:** 1 MB
- **Purpose:** Displayed at the top of your app's listing

**What to Include:**
- App name: "Mealvana Run" or "Mealvana Endurance"
- Tagline: e.g., "Personalized Nutrition for Endurance Athletes"
- App icon (your peach/cream logo)
- Attractive background (use your brand colors)

**Design Tools:**
- **Canva** (recommended for beginners):
  1. Go to https://canva.com
  2. Search "Google Play Feature Graphic" template
  3. Customize with your branding
  4. Download as PNG

- **Figma** (more control):
  1. Create 1024x500 frame
  2. Add your app icon
  3. Add text and branding
  4. Export as PNG

**Example Structure:**
```
[Left Side: App Icon]  |  [Right Side: Text]
                       |  "Mealvana Run"
Your Peach Logo        |  "Fuel Your Run"
                       |  "Science-Based Nutrition Plans"
```

---

### 2.3 App Icon Verification (DONE ✅)

**Good news!** Your existing icon is perfect:
- ✅ 1024 x 1024 pixels
- ✅ PNG format
- ✅ Clear, recognizable design
- ✅ Looks good at small sizes

**No action needed here!**

---

### 2.4 Write Store Listing Text

**A. App Title** (30 characters max)
```
Mealvana Run
```
**Alternative:**
```
Mealvana Endurance
```

**B. Short Description** (80 characters max)
```
Science-based nutrition plans for endurance athletes. Fuel your performance.
```
**Character count:** 78 ✅

**Alternative:**
```
Personalized fueling plans for runners, cyclists, and triathletes.
```
**Character count:** 69 ✅

**C. Full Description** (4000 characters max)

**Here's a draft:**

```
Mealvana Run - Personalized Nutrition for Endurance Athletes

Train smarter, not harder. Mealvana Run generates science-based nutrition plans tailored to your body, your workout, and your food preferences.

🏃 FOR RUNNERS, CYCLISTS & TRIATHLETES
Whether you're training for a 5K or an ultra-marathon, get personalized fueling strategies that match your intensity, distance, and goals.

⚡ FEATURES:

• Personalized Nutrition Plans
  - Enter your distance, pace, and body weight
  - AI-powered algorithms based on ACSM research
  - Carb, protein, fat, sodium, and hydration calculated for your needs

• Food Preference Integration
  - Tell us what you like and dislike
  - Scan barcodes to quickly add foods
  - Plans adapt to your dietary preferences

• Gut Training Support
  - Progressive carb loading protocols
  - Help your stomach adapt to race-day nutrition
  - Science-backed carb tolerance building

• Pre-Run & During-Run Guidance
  - What to eat before your workout
  - Fueling strategies during long runs
  - Hydration and electrolyte recommendations

• Offline-First Design
  - Works without internet connection
  - Plans stored locally on your device
  - Sync across devices with your account

• Calendar Integration
  - Schedule your workouts and nutrition plans
  - Track your training and fueling
  - Never miss a nutrition window

🔬 EVIDENCE-BASED ALGORITHMS
Our nutrition calculations use formulas from the American College of Sports Medicine (ACSM) and peer-reviewed nutrition research. No guesswork, just science.

🥗 FLEXIBLE & REALISTIC
Unlike rigid meal plans, Mealvana adapts to:
- Your food preferences (vegetarian, vegan, gluten-free, etc.)
- Your schedule and lifestyle
- Your gut training level
- Your race-day goals

📊 TRACK YOUR PROGRESS
- Monitor your nutrition adherence
- See how fueling affects performance
- Adjust plans based on your feedback

💪 WHO IT'S FOR:
- Marathon and half-marathon runners
- Ultra-distance athletes
- Triathletes (running, cycling, swimming)
- Cyclists training for long rides
- Anyone seeking science-based sports nutrition

🎯 WHY MEALVANA?
Traditional sports nutrition advice is generic. Mealvana personalizes every recommendation to YOUR body, YOUR workout, and YOUR preferences. Stop guessing what to eat—get a plan that works for you.

📱 PRIVACY-FIRST
Your data stays yours. We use industry-standard encryption and never sell your information. See our privacy policy for details.

⏱️ SAVE TIME
No more:
- Googling "what to eat before a long run"
- Calculating carb-to-weight ratios
- Guessing sodium intake
- Trial-and-error fueling on race day

Get your personalized plan in seconds.

🚀 GET STARTED TODAY
1. Download Mealvana Run
2. Create your profile (weight, goals, preferences)
3. Enter your next workout details
4. Get your personalized nutrition plan
5. Fuel your best performance

SUPPORT & FEEDBACK
We're constantly improving based on athlete feedback. Questions or suggestions? Contact us at [your_email@domain.com]

SUBSCRIPTION (if applicable - adjust based on your monetization)
[Add details if you have in-app purchases]

ABOUT US
Mealvana is built by athletes, for athletes. Our mission: make science-based sports nutrition accessible to everyone, not just elite athletes with personal nutritionists.

Train hard. Fuel smart. Perform better.

---

Privacy Policy: https://milkmanfunddev-ops.github.io/mealvana_endurance_landing_page/privacypolicy
Terms of Service: https://milkmanfunddev-ops.github.io/mealvana_endurance_landing_page/terms
```

**Character count:** ~2,850 (well within 4,000 limit)

**Feel free to edit this to match your voice!**

---

## 🏪 Phase 3: Google Play Console Setup (Days 6-7)

### 3.1 Complete Store Listing

1. **Go to:** https://play.google.com/console
2. **Select your app** (or create new app if first time)
3. **Navigate to:** Main store listing

**Fill in these fields:**

| Field | Value | Notes |
|-------|-------|-------|
| **App name** | Mealvana Run | 30 chars max |
| **Short description** | (Use draft from 2.4.B above) | 80 chars max |
| **Full description** | (Use draft from 2.4.C above) | 4000 chars max |
| **App icon** | Upload 512x512 PNG | Use `endurance_launcher_icon_basecream_1024.png` (resize to 512x512) |
| **Feature graphic** | Upload 1024x500 | (Created in 2.2 above) |
| **Phone screenshots** | Upload 2-8 images | (Created in 2.1 above) |
| **7-inch tablet screenshots** | Optional | If you created tablet screenshots |
| **10-inch tablet screenshots** | Optional | If you created tablet screenshots |

4. **Click "Save"**

---

### 3.2 Set App Category & Details

**Still in Google Play Console:**

1. **Navigate to:** App content
2. **App category:**
   - Primary: **Health & Fitness**
   - Tags: "Sports", "Nutrition", "Running", "Cycling"

3. **Target audience and content:**
   - **Target age group:** 13+ (or 18+ if collecting sensitive data)
   - **Appeal to children:** No
   - **Content rating:** (See section 3.4 below)

4. **Contact details:**
   - Email: your_email@domain.com
   - Phone: (optional but recommended)
   - Website: https://milkmanfunddev-ops.github.io/mealvana_endurance_landing_page/

5. **Privacy Policy URL:**
   ```
   https://milkmanfunddev-ops.github.io/mealvana_endurance_landing_page/privacypolicy
   ```

---

### 3.3 Complete Data Safety Form

**Navigate to:** App content → Data safety

**I've prepared a detailed guide in `data_safety_answers.md`**, but here's the quick summary:

**Data Collected:**
- ✅ User account (email)
- ✅ Health & fitness data (weight, nutrition plans)
- ✅ App activity (analytics)
- ✅ Device ID
- ❌ Location (NOT collected)

**Data Sharing:**
- ✅ Analytics data → Mixpanel
- ✅ Error logs → Sentry
- ❌ Health data → NOT shared

**Security practices:**
- ✅ Data encrypted in transit
- ✅ Data encrypted at rest
- ✅ Users can request deletion
- ✅ Privacy policy provided

**See `data_safety_answers.md` for complete form-filling guide.**

---

### 3.4 Complete Content Rating Questionnaire

**Navigate to:** App content → Content rating → Start questionnaire

**Select:** International Age Rating Coalition (IARC)

**Answer honestly based on app content:**

| Question | Answer | Reason |
|----------|--------|--------|
| Does your app contain violence? | No | No violent content |
| Does your app contain sexual content? | No | No sexual content |
| Does your app contain profanity? | No | No user-generated content with profanity |
| Does your app contain user interaction? | No | No chat/social features |
| Does your app share user location? | No | No location tracking |
| Does your app allow purchases? | (Your choice) | If you have IAP, select Yes |

**Expected rating:** EVERYONE (general audience)

**Save and submit** - Rating will be issued within a few minutes.

---

### 3.5 Upload App Bundle (AAB)

**Prerequisites:**
- ✅ Technical setup complete (see `roadmap.md`)
- ✅ Release build created: `flutter build appbundle --release`
- ✅ Keystore configured

**Steps:**

1. **Navigate to:** Release → Testing → Open testing
2. **Click:** "Create new release"
3. **Upload AAB:**
   - Click "Upload"
   - Select file: `build/app/outputs/bundle/release/app-release.aab`
   - Wait for upload and processing (2-5 minutes)

4. **Add release name:**
   ```
   1.7.1 (26) - Initial Open Testing Release
   ```

5. **Add release notes:**
   ```
   Initial open testing release of Mealvana Run!

   Features:
   - Personalized nutrition plans for endurance athletes
   - Distance, pace, and body weight calculations
   - Food preference integration
   - Barcode scanning for quick food entry
   - Offline-first functionality
   - Notification reminders for nutrition plans

   This is an early test version. Please report any bugs or feedback to [your_email@domain.com]

   Thank you for testing!
   ```

6. **Click "Save"** (don't submit yet)

---

### 3.6 Configure Google Play App Signing

**Navigate to:** Release → Setup → App integrity

**Steps:**

1. **Select:** "Use Google Play App Signing"
2. **Choose:** "Upload a key exported from Android Studio or Java keystore"
3. **Upload your keystore:**
   - File: `android/app/mealvana-release-key.jks`
   - Upload key password: (your keystore password from Phase 1)

4. **Google will:**
   - Accept your upload key
   - Generate a new production signing key
   - Provide `deployment_cert.der` for download

5. **Download and save:**
   - `deployment_cert.der` - Keep this safe for future reference
   - Note the new key SHA-1 fingerprint (for Firebase/Supabase if needed)

**⚠️ This is ONE-TIME only. After this, you'll always use your upload key (mealvana-release-key.jks), but Google signs with a different key.**

---

## 🧪 Phase 4: Testing & Feedback (Days 8-9)

### 4.1 Test on Physical Device (Pixel 7 Pro)

**Complete Testing Checklist:**

```bash
# Install release build
flutter install --release
```

**Test each feature:**

- [ ] **User registration** - Create new account
- [ ] **Login** - Sign in with existing account
- [ ] **Onboarding flow** - Complete profile setup
- [ ] **Create nutrition plan** - Enter distance/pace/weight
- [ ] **View nutrition plan** - Check calculations
- [ ] **Food preferences** - Add liked/disliked foods
- [ ] **Barcode scanning** - Scan a food barcode (camera permission)
- [ ] **Schedule notification** - Set up reminder (notification permission)
- [ ] **Offline mode** - Turn off wifi/data, app should still work
- [ ] **Sync when online** - Turn data back on, changes should sync
- [ ] **Settings** - Update profile, preferences
- [ ] **Logout/Login** - Test persistence
- [ ] **App startup** - Cold start should be fast
- [ ] **Navigation** - All screens accessible
- [ ] **Error handling** - Try invalid inputs

**Record any issues:**
- Screenshot errors
- Note steps to reproduce bugs
- Document any crashes (check Sentry dashboard)

---

### 4.2 Share with Internal Testers (Optional)

**Before Open Testing, test with friends/colleagues:**

**Navigate to:** Release → Testing → Internal testing

1. **Create internal testing release**
2. **Add internal testers:**
   - Click "Testers" tab
   - Create email list
   - Add testers' Google account emails

3. **Share opt-in URL** (provided by Play Console)
4. **Collect feedback** (use Google Form or email)

**Test for ~3-5 days before Open Testing**

---

### 4.3 Address Critical Bugs

**Before submitting to Open Testing:**

1. **Review Sentry** - Check for crashes: https://sentry.io
2. **Review Mixpanel** - Check analytics events are firing
3. **Fix critical issues:**
   - App crashes
   - Data loss bugs
   - Permission issues
   - UI breaking issues

4. **Build new release if needed:**
   ```bash
   flutter build appbundle --release
   # Re-upload to Play Console
   ```

---

## 🚀 Phase 5: Submit for Open Testing (Day 10)

### 5.1 Final Pre-Submission Checklist

**Verify everything is ready:**

- [ ] Store listing complete (name, description, images)
- [ ] Data safety form complete
- [ ] Content rating received (EVERYONE rating)
- [ ] Privacy policy URL added
- [ ] App bundle uploaded
- [ ] Google Play App Signing configured
- [ ] Release notes written
- [ ] Internal testing complete (if you did it)
- [ ] Critical bugs fixed
- [ ] All required screenshots uploaded
- [ ] Feature graphic uploaded
- [ ] App icon uploaded

---

### 5.2 Submit for Review

**Navigate to:** Release → Testing → Open testing

1. **Review your release draft**
2. **Click "Review release"**
3. **Review warnings:**
   - Yellow warnings: Informational (usually OK to proceed)
   - Red errors: Must fix before submission

4. **Click "Start rollout to Open testing"**

5. **Confirm submission**

**Google will now review your app. This typically takes 1-3 days.**

---

### 5.3 Create Opt-In URL for Testers

**After submission approval:**

1. **Navigate to:** Release → Testing → Open testing → Testers tab
2. **Click "Copy link"** next to "Opt-in URL"
3. **Share this URL** with testers:
   ```
   https://play.google.com/apps/internaltest/...
   ```

**Anyone with this link can join your open test** (no approval needed).

---

### 5.4 Monitor Review Process

**During review (1-3 days):**

1. **Check Play Console daily** for review status
2. **Monitor email** - Google will send updates
3. **Possible outcomes:**
   - ✅ **Approved** - App goes live in Open Testing
   - ⚠️ **Rejected** - Google provides reasons, fix and resubmit
   - 🔄 **More info needed** - Respond to Google's questions

**If rejected, common reasons:**
- Privacy policy issues
- Data safety form incomplete
- Content rating mismatch
- Permissions not justified
- Malware/security concerns (very rare for Flutter apps)

---

## 📊 Phase 6: Post-Launch (Ongoing)

### 6.1 Monitor Testing Feedback

**Check these regularly:**

1. **Play Console → Testing feedback**
   - Read user comments
   - Respond to questions
   - Prioritize reported bugs

2. **Sentry dashboard** (https://sentry.io)
   - Monitor crash rates
   - Fix critical errors first

3. **Mixpanel analytics** (https://mixpanel.com)
   - Track user engagement
   - See which features are used most
   - Identify drop-off points

---

### 6.2 Iterate with Shorebird (For Code Changes)

**For minor updates (no native changes):**

```bash
# Make code changes in Dart
# Then push update via Shorebird
shorebird patch android

# Users get update instantly (no Play Store wait)
```

**For major updates (native changes, new permissions):**

```bash
# Full release build
flutter build appbundle --release

# Upload new version to Open Testing
# Follow section 5.2 again
```

---

### 6.3 Promote to Production (When Ready)

**After successful Open Testing (2-4 weeks recommended):**

1. **Navigate to:** Release → Testing → Open testing
2. **Click:** "Promote release"
3. **Select:** "Production"
4. **Choose rollout:**
   - **Staged rollout:** 5% → 10% → 20% → 50% → 100% (recommended)
   - **Full rollout:** 100% immediately

5. **Monitor crashes/ratings closely**
6. **Halt rollout if critical issues** (emergency stop button available)

---

## 🆘 Common Issues & Solutions

### Issue: "App not available in your country"

**Cause:** Country targeting not set

**Fix:**
1. Go to: **Release → Setup → Countries/regions**
2. Select all countries you want to support
3. Save changes

---

### Issue: "Waiting for review" for >3 days

**Cause:** Google sometimes reviews slower

**Fix:**
1. Check **Status** tab in Play Console
2. If >5 days, contact Play Console support
3. Be patient - it varies

---

### Issue: Screenshots rejected for "misleading content"

**Cause:** Screenshots show features not in the app

**Fix:**
1. Use only real app screenshots
2. Don't use mockups or design concepts
3. Don't show competitor apps

---

### Issue: Testers can't find the app

**Cause:** They need the opt-in URL

**Fix:**
1. Share the opt-in URL from section 5.3
2. They must click "Become a tester"
3. Then they can install from Play Store

---

### Issue: Can't upload AAB - "App signature mismatch"

**Cause:** Built with wrong keystore or no keystore

**Fix:**
```bash
# Ensure key.properties exists
cat ~/development/mealvana_endurance/android/key.properties

# Rebuild
flutter clean
flutter build appbundle --release

# Re-upload
```

---

## 📋 Quick Reference Checklists

### Pre-Launch Checklist
```
[ ] Keystore created and backed up
[ ] key.properties configured
[ ] 4-8 screenshots captured
[ ] Feature graphic designed
[ ] Store listing text written
[ ] Privacy policy URL added
[ ] Data safety form complete
[ ] Content rating received
[ ] AAB uploaded
[ ] Google Play App Signing enabled
[ ] Release notes written
[ ] All features tested on Pixel 7 Pro
```

### Launch Day Checklist
```
[ ] Final build uploaded
[ ] Release notes reviewed
[ ] All warnings addressed
[ ] Submitted for review
[ ] Confirmation email received
[ ] Opt-in URL ready to share
[ ] Testers notified
[ ] Monitoring dashboard open (Sentry, Mixpanel)
```

### Post-Launch Monitoring Checklist
```
[ ] Check Play Console daily for feedback
[ ] Monitor Sentry for crashes
[ ] Review Mixpanel analytics
[ ] Respond to user questions
[ ] Fix critical bugs with Shorebird patches
[ ] Plan next version features
```

---

## 🔗 Important URLs to Bookmark

- **Google Play Console:** https://play.google.com/console
- **Your Privacy Policy:** https://milkmanfunddev-ops.github.io/mealvana_endurance_landing_page/privacypolicy
- **Your Terms of Service:** https://milkmanfunddev-ops.github.io/mealvana_endurance_landing_page/terms
- **Sentry Dashboard:** https://sentry.io/organizations/milkman-24/projects/mealvana-endurance/
- **Mixpanel Dashboard:** https://mixpanel.com
- **Shorebird Console:** https://console.shorebird.dev

---

## 🤝 Getting Help

### If you get stuck:

1. **Check the technical roadmap:** `roadmap.md` for configuration issues
2. **Google Play Console Help:** https://support.google.com/googleplay/android-developer
3. **Flutter Community:** https://flutter.dev/community
4. **Ask AI assistant:** Provide specific error messages

### Contact Information for Support:

- **Google Play Support:** Via Play Console (Help button)
- **Shorebird Support:** support@shorebird.dev
- **Sentry Support:** Via dashboard

---

## ✅ Success Criteria

**You'll know you're ready when:**

- ✅ Release build installs on Pixel 7 Pro without errors
- ✅ All features work (auth, plans, scanning, notifications)
- ✅ Play Console shows green checkmarks on all requirements
- ✅ Opt-in URL is shareable
- ✅ First testers successfully install and use the app

---

**Estimated Total Time:** 7-10 days
**Most Time-Consuming:** Screenshot creation and store listing text
**Easiest:** Following Play Console guided workflow

**You've got this! Each step brings you closer to launch. 🚀**

---

**Last Updated:** 2025-10-17
**Status:** Ready to start
**Next Action:** Phase 1 - Create keystore
