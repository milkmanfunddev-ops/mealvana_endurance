# Lee's App Store Release Checklist

**Last Updated**: 2025-11-28
**Target**: ASAP Release
**Launch Model**: FREE (subscriptions in future update)

This checklist contains all tasks that YOU (Lee) need to complete before submitting to the App Store. Check off items as you complete them.

---

## Already Done in App Store Connect

These items are already configured - no action needed:

- [x] App Name: Mealvana Endurance
- [x] Subtitle: Race-Day & Training Nutrition
- [x] Bundle ID: com.milkman.mealvanaendurance
- [x] Primary Category: Health & Fitness
- [x] Secondary Category: Food & Drink
- [x] Age Rating: 9+ (173 countries)
- [x] App Availability: 175 countries
- [x] Keywords configured
- [x] Privacy Labels configured (7 data types - need to add 2 more, see below)
- [x] Promotional Text written
- [x] Description written
- [x] Copyright: Milkman Inc.
- [x] Apple Silicon Mac: Enabled

---

## App Store Connect - Fixes Needed

### Fix Privacy Policy URL
- [ ] Current URL in ASC: `https://www.mealvana.io/privacy-policy`
- [ ] Correct URL should be: `https://endurance.mealvana.io/privacypolicy`
- [ ] Go to: App Privacy > Edit > Update Privacy Policy URL

### Add Missing Privacy Labels (2 more needed)
Your current 7 data types are correct, but you need to add 2 more:

**Add Location Data:**
- [ ] Go to: App Privacy > Edit > Data Types
- [ ] Add: **Location > Precise Location**
- [ ] Purpose: App Functionality (for weather forecasts)
- [ ] Linked to User: Yes

**Add Email (Contact Info):**
- [ ] Go to: App Privacy > Edit > Data Types
- [ ] Add: **Contact Info > Email Address**
- [ ] Purpose: App Functionality (for email authentication)
- [ ] Linked to User: Yes

**Current (keep these):** Health, Fitness, Crash Data, Performance Data, Other Diagnostic Data, Product Interaction, User ID

### Fix Support URL
- [ ] Current: `http://example.com` (placeholder!)
- [ ] Change to: `https://endurance.mealvana.io/support`
- [ ] Go to: Version page > Support URL field

### Disable Vision Pro
- [ ] Go to: Pricing and Availability
- [ ] Uncheck "Make this app available on Apple Vision Pro"
- [ ] (Shows compatibility warning - avoid complications for v1.0)

### Uncheck Sign-in Required
- [ ] Go to: App Review Information
- [ ] Uncheck "Sign-in required" checkbox
- [ ] App uses anonymous auth - no credentials needed

### Add Contact Information
- [ ] Go to: App Review Information > Contact Information
- [ ] First Name: _______________
- [ ] Last Name: _______________
- [ ] Phone: _______________
- [ ] Email: _______________

---

## Screenshots (Required!)

**You need screenshots!** Currently: 0 of 10 uploaded

### Screenshot Guidance

**Required Size**: iPhone 6.5" Display (1242 x 2688 pixels)
- Take screenshots on iPhone 14 Pro Max, 15 Pro Max, or use Simulator

**Recommended Screens to Capture** (in order of importance):

1. **Home/Dashboard** - Shows upcoming activity with nutrition plan summary
2. **Nutrition Plan Detail** - Full plan with pre/during/post sections and food items
3. **Create Activity** - Shows the activity creation flow (distance, pace, etc.)
4. **Carb Loading Plan** - 3-day carb loading view for race week
5. **Food Preferences** - Likes/dislikes selection screen
6. **Activity Calendar** - Monthly view with activities
7. **Food Swap** - Swapping foods in a nutrition plan
8. **Settings/Profile** - User profile and preferences
9. **Weather Integration** - Activity with weather forecast
10. **Macro Targets** - Adjust macros screen

**Screenshot Tips**:
- Show real data, not empty states
- Use attractive/appetizing food images
- First 3 screenshots appear in search results - make them count!
- No device frames needed (Apple adds them)
- PNG or JPEG, max 10MB each

### Upload Screenshots
- [ ] Screenshot 1: Home/Dashboard
- [ ] Screenshot 2: Nutrition Plan Detail
- [ ] Screenshot 3: Create Activity
- [ ] Screenshot 4: Carb Loading
- [ ] Screenshot 5: Food Preferences
- [ ] Screenshot 6-10: Additional screens

---

## Build & Upload

### Wait for LLM Tasks
- [ ] LLM has completed all tasks in `llm_roadmap.md`
- [ ] Review changes made by LLM

### Pre-Build Verification
- [ ] Run `flutter analyze` - no errors
- [ ] Run `flutter test` - all tests pass

### Generate Release Build
```bash
# Clean build
flutter clean
flutter pub get

# Build IPA for production
flutter build ipa --release
```

### Upload to App Store Connect
**Option A: Apple Transporter (Easier)**
1. [ ] Download Transporter from Mac App Store (if not installed)
2. [ ] Sign in with Apple Developer account
3. [ ] Drag `build/ios/ipa/*.ipa` to Transporter
4. [ ] Click "Deliver"
5. [ ] Wait for processing (5-15 minutes)

**Option B: xcrun (Faster)**
```bash
xcrun altool --upload-app --type ios --file build/ios/ipa/*.ipa --apiKey YOUR_KEY_ID --apiIssuer YOUR_ISSUER_ID
```

---

## Final Submission

### Select Build
- [ ] Wait for build to finish processing in App Store Connect
- [ ] Go to Version page > Build section
- [ ] Click "+" and select your build
- [ ] Click "Done"

### Submit for Review
- [ ] Click "Add for Review"
- [ ] **CRITICAL**: Click "Submit to App Review" (don't forget this step!)

---

## Post-Submission

### Monitor Review
- [ ] Check App Store Connect for status updates
- [ ] Monitor email for Apple communications
- [ ] Typical review time: 24-48 hours

### If Rejected
- [ ] Read rejection reason carefully
- [ ] Make required changes
- [ ] Increment build number in pubspec.yaml
- [ ] Rebuild and resubmit

### If Approved
- [ ] App goes live automatically (or manually if you selected that option)
- [ ] Monitor for user feedback
- [ ] Plan v1.1 with RevenueCat subscriptions

---

## Future v1.1 Tasks (RevenueCat - After Initial Launch)

These are NOT needed for initial release:

### Decide Subscription Pricing
- [ ] Monthly price: $____/month
- [ ] Annual price: $____/year
- [ ] Free trial: ____ days

### App Store Connect IAP Setup
- [ ] Create Subscription Group
- [ ] Add subscription products
- [ ] Set pricing in all regions

### RevenueCat Dashboard
- [ ] Create RevenueCat account
- [ ] Create project
- [ ] Add iOS app with Bundle ID
- [ ] Add App Store Connect API key
- [ ] Create Offerings
- [ ] Map product identifiers

### RevenueCat SDK
- [ ] Add `purchases_flutter` to pubspec.yaml
- [ ] Configure API keys
- [ ] Implement restore purchases
- [ ] Create paywall UI
- [ ] Test sandbox purchases

---

## Quick Reference

### Important URLs
- App Store Connect: https://appstoreconnect.apple.com
- Apple Developer: https://developer.apple.com
- Review Guidelines: https://developer.apple.com/app-store/review/guidelines/

### Your App Details
- Bundle ID: `com.milkman.mealvanaendurance`
- App Store Connect Version: 1.0
- Privacy Policy: https://endurance.mealvana.io/privacypolicy
- Support URL: https://endurance.mealvana.io/support
- Platform: iPhone only

---

## Estimated Timeline

| Task | Time |
|------|------|
| Fix ASC settings (URLs, privacy labels, Vision Pro) | 20 min |
| Create & upload screenshots | 1-2 hours |
| Wait for LLM tasks | 1-2 hours |
| Build and upload | 30 min |
| Apple review | 24-48 hours |

**Total to submission**: ~3-5 hours of work
**Total to live**: ~2-3 days including review

---

## Common Rejection Reasons to Avoid

1. **Missing screenshots** - You need these!
2. **Placeholder URLs** - Fix that Support URL
3. **Crashes/bugs** - Test thoroughly
4. **Privacy policy mismatch** - Fix the URL
5. **Incomplete metadata** - All fields filled
6. **Privacy label mismatch** - Must match actual data collection (add Location + Email)

---

*This checklist was updated based on App Store Connect review on 2025-11-28*
