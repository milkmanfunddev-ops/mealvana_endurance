# Google Play Data Safety Form - Complete Answers

**For:** Mealvana Run (Mealvana Endurance)
**Date:** 2025-10-17
**Status:** Template for Google Play Console submission

---

## Overview

The Data Safety form is **mandatory** for all apps on Google Play. It tells users what data your app collects, how it's used, and what security measures are in place.

**Where to complete:** Google Play Console → App content → Data safety

**Time required:** 15-20 minutes (first time), 5 minutes (updates)

---

## Section 1: Data Collection & Security

### Question 1: Does your app collect or share any of the required user data types?

**Answer:** ✅ **YES**

**Explanation:** Your app collects user account information, health/fitness data, and analytics data.

---

### Question 2: Is all of the user data collected by your app encrypted in transit?

**Answer:** ✅ **YES**

**Explanation:** All network communication uses HTTPS (Supabase, Sentry, Mixpanel).

**Technical proof:**
- Supabase uses HTTPS (wss:// for realtime)
- Sentry uses HTTPS
- Mixpanel uses HTTPS
- No unencrypted HTTP calls in your app

---

### Question 3: Do you provide a way for users to request that their data is deleted?

**Answer:** ✅ **YES**

**Explanation:** Users can request data deletion via your support email or in-app settings (if implemented).

**What you need to provide:**
- Email address for deletion requests (e.g., privacy@yourdomain.com or your main email)
- Response time commitment: "We'll process deletion requests within 30 days"

**Note for Lee:** Ensure you have a process to:
1. Delete user data from Supabase
2. Anonymize analytics data in Mixpanel
3. Remove personally identifiable info from Sentry

---

## Section 2: Data Types Collected

For each data type, you'll specify:
- Whether it's collected
- Whether it's shared with third parties
- Whether it's optional or required
- The purpose of collection

---

### 2.1 Personal Information

#### ✅ Email Address

| Question | Answer | Explanation |
|----------|--------|-------------|
| **Collected?** | YES | Required for account creation |
| **Shared?** | NO | Stored only in Supabase (data processor) |
| **Optional?** | NO (Required) | Needed for authentication |
| **Purpose** | ☑️ Account management<br>☑️ App functionality | Login and account recovery |
| **Encrypted in transit?** | YES | HTTPS only |
| **Ephemeral?** | NO | Stored persistently |

---

#### ✅ Name (if you collect it)

**Check your app:** Do you ask for user's first/last name in profile?

| Question | Answer | Explanation |
|----------|--------|-------------|
| **Collected?** | YES (if applicable) | For personalization |
| **Shared?** | NO | Stored only in Supabase |
| **Optional?** | YES | Not required for core functionality |
| **Purpose** | ☑️ App functionality<br>☑️ Personalization | Display name in app |
| **Encrypted in transit?** | YES | HTTPS only |
| **Ephemeral?** | NO | Stored persistently |

**If you DON'T collect names, answer NO to this section.**

---

### 2.2 Health & Fitness

#### ✅ Fitness Info (Body Weight, Nutrition Plans)

| Question | Answer | Explanation |
|----------|--------|-------------|
| **Collected?** | YES | Core app functionality |
| **Shared?** | NO | Stored locally (Drift) and in Supabase |
| **Optional?** | NO (Required) | Needed for nutrition calculations |
| **Purpose** | ☑️ App functionality<br>☑️ Personalization | Calculate macros and nutrition plans |
| **Encrypted in transit?** | YES | HTTPS to Supabase |
| **Encrypted at rest?** | YES | Supabase database encryption |
| **Ephemeral?** | NO | Stored persistently |

**Examples of fitness info you collect:**
- Body weight
- Run distance
- Run pace
- Nutrition plans
- Food preferences
- Gut training level

---

### 2.3 App Activity

#### ✅ App Interactions (Analytics)

| Question | Answer | Explanation |
|----------|--------|-------------|
| **Collected?** | YES | For analytics and improvement |
| **Shared?** | YES | Shared with Mixpanel |
| **Optional?** | NO | Collected automatically |
| **Purpose** | ☑️ Analytics<br>☑️ App functionality | Understand user behavior, improve app |
| **Encrypted in transit?** | YES | HTTPS to Mixpanel |
| **Ephemeral?** | NO | Stored by Mixpanel for analytics |

**Examples of app interactions:**
- Screen views
- Button clicks
- Feature usage
- Time in app
- App launches

---

#### ✅ Crash Logs (Error Tracking)

| Question | Answer | Explanation |
|----------|--------|-------------|
| **Collected?** | YES | For error tracking and bug fixes |
| **Shared?** | YES | Shared with Sentry |
| **Optional?** | NO | Collected automatically |
| **Purpose** | ☑️ Analytics<br>☑️ App functionality | Detect and fix crashes |
| **Encrypted in transit?** | YES | HTTPS to Sentry |
| **Ephemeral?** | NO | Stored by Sentry for debugging |
| **PII included?** | NO | `sendDefaultPii = false` in your Sentry config |

---

### 2.4 Device or Other IDs

#### ✅ Device ID (for user identification)

| Question | Answer | Explanation |
|----------|--------|-------------|
| **Collected?** | YES | For device-based authentication |
| **Shared?** | NO | Used only internally (Supabase) |
| **Optional?** | NO | Required for auth and sync |
| **Purpose** | ☑️ App functionality<br>☑️ Account management | Associate data with device |
| **Encrypted in transit?** | YES | HTTPS only |
| **Ephemeral?** | NO | Stored persistently |

**Note:** You use `device_info_plus` to get device ID for authentication.

---

### 2.5 Photos & Videos

#### ⚠️ Photos (Camera Access for Barcode Scanner)

| Question | Answer | Explanation |
|----------|--------|-------------|
| **Collected?** | NO | Camera used, but photos NOT stored |
| **Shared?** | NO | N/A |
| **Optional?** | YES | Only when user scans barcode |
| **Purpose** | ☑️ App functionality | Scan food barcodes |
| **Processed locally?** | YES | MLKit processes on-device |
| **Stored or transmitted?** | NO | Barcode data extracted, image discarded |

**Important clarification for Google:**
- "Camera permission is used only for barcode scanning"
- "Images are processed on-device and never stored or transmitted"
- "Only the barcode data (UPC code) is extracted and used"

---

### 2.6 Data Types You DON'T Collect

Answer **NO** to these (based on your app):

- ❌ **Location** - No GPS tracking
- ❌ **Contacts** - No contact access
- ❌ **Calendar** - You store events locally, but don't access device calendar
- ❌ **Files & Docs** - No file access beyond app sandbox
- ❌ **Audio** - speech_to_text NOT used
- ❌ **Browsing History** - No browser activity
- ❌ **Search History** - No search tracking
- ❌ **Financial Info** - No payment info stored (unless you add IAP)
- ❌ **Messages** - No SMS/email access
- ❌ **Web Browsing** - No tracking across websites

---

## Section 3: Data Usage & Purpose

### For Each Data Type Collected, Select Purpose(s):

#### Email Address
- ☑️ Account management
- ☑️ App functionality

#### Body Weight & Fitness Data
- ☑️ App functionality (nutrition calculations)
- ☑️ Personalization

#### App Interactions (Analytics)
- ☑️ Analytics
- ☑️ App functionality
- ☐ Advertising (only if you show ads)
- ☐ Marketing (only if you send promotional emails)

#### Crash Logs
- ☑️ Analytics
- ☑️ App functionality (bug fixes)

#### Device ID
- ☑️ App functionality
- ☑️ Account management

---

## Section 4: Data Sharing

### Question: Do you share any of the required user data types with third parties?

**Answer:** ✅ **YES** (but only for service provision)

### Third-Party Services & Data Shared

#### 1. Supabase (Backend/Database)
- **Data shared:** Email, fitness data, nutrition plans, device ID
- **Purpose:** App functionality (backend services)
- **Type:** Service provider / Data processor
- **Data handling:** Supabase processes data on your behalf
- **Google Play category:** "Service provider"

#### 2. Mixpanel (Analytics)
- **Data shared:** App interactions, anonymous usage data
- **Purpose:** Analytics
- **Type:** Analytics provider
- **Data handling:** Used for aggregated analytics only
- **Google Play category:** "Analytics provider"

#### 3. Sentry (Error Tracking)
- **Data shared:** Crash logs, error reports (no PII)
- **Purpose:** App functionality (bug detection)
- **Type:** Service provider
- **Data handling:** Error tracking only
- **Google Play category:** "Service provider"

### Important Notes for "Sharing":

**What Google considers "sharing":**
- Data transmitted to third-party services
- Even if those services are processors (not controllers)

**What Google does NOT consider sharing:**
- Data stored locally on device (Drift database)
- Encrypted data transmitted to your own backend

**Your answer strategy:**
- Be transparent about Mixpanel and Sentry
- Clarify that Supabase is a backend service provider
- Emphasize no data is sold or used for advertising

---

## Section 5: Security Practices

### Question: What security practices does your app implement?

Select all that apply:

- ☑️ **Data is encrypted in transit** (HTTPS)
- ☑️ **Data is encrypted at rest** (Supabase encryption)
- ☑️ **Users can request deletion** (via email or in-app)
- ☐ **Data is anonymized** (if you implement this later)
- ☐ **Users can opt-out of data collection** (analytics opt-out, if implemented)
- ☑️ **Complies with privacy policy** (yes, you have one)
- ☑️ **Committed to Google Play Families Policy** (if targeting children, you're not)
- ☑️ **Independent security review** (optional, only if you've had one)

---

## Section 6: Additional Information

### Privacy Policy URL

**Required:** YES

**URL:**
```
https://milkmanfunddev-ops.github.io/mealvana_endurance_landing_page/privacypolicy
```

### Data Deletion Instructions

**Provide clear instructions:**

```
Users can request data deletion by:

1. Email: Send deletion request to [your_email@domain.com]
2. In-app: Settings → Account → Delete Account (if implemented)

We will process all deletion requests within 30 days.

Deleted data includes:
- User profile (email, name, preferences)
- Fitness data (body weight, run history)
- Nutrition plans
- App usage analytics (anonymized)

After deletion, data cannot be recovered.
```

### Contact Information

**For privacy inquiries:**
- Email: [your_email@domain.com]
- Response time: Within 48 hours

---

## Section 7: Preview Your Data Safety Section

**Before submitting, Google will show you a preview of what users see:**

### Example Preview:

```
Data Safety

The developer says this app collects the following data:

Personal info
• Email address

Health & fitness
• Fitness info

App activity
• App interactions
• Crash logs

Device or other IDs
• Device or other IDs

This data is shared with:
• Analytics companies (Mixpanel)
• Service providers (Sentry, Supabase)

Data is encrypted in transit
You can request data deletion

See the developer's privacy policy for more info
```

**Review carefully and ensure accuracy!**

---

## Common Mistakes to Avoid

### ❌ Don't Do This:
1. **Claim you collect no data** if you use analytics
2. **Say data isn't shared** if you use Mixpanel/Sentry
3. **Omit camera access** even if you don't store photos
4. **Forget to mention encryption**
5. **Skip the privacy policy URL**

### ✅ Do This:
1. **Be transparent** about all data collection
2. **Explain "why"** - users understand if it's for app functionality
3. **Highlight security** (encryption, deletion options)
4. **Link to detailed privacy policy**
5. **Update the form** when you add new features

---

## Updating the Data Safety Form

**When to update:**

- ✅ You add new analytics events
- ✅ You integrate a new third-party service
- ✅ You request new permissions (e.g., location)
- ✅ You change data handling practices
- ✅ Every major app version (as a best practice)

**How to update:**

1. Go to: App content → Data safety
2. Click "Edit"
3. Update relevant sections
4. Save changes
5. Changes take effect immediately (no review delay)

---

## Compliance Checklist

Before submitting, verify:

- [ ] All collected data types listed
- [ ] All third-party services disclosed
- [ ] Purposes clearly stated
- [ ] Security practices accurately described
- [ ] Privacy policy URL is live and accessible
- [ ] Deletion instructions are clear
- [ ] Contact email is monitored
- [ ] Form matches your actual app behavior (test it!)

---

## If Google Rejects Your Data Safety Form

**Common rejection reasons:**

1. **Privacy policy doesn't match form**
   - Fix: Update privacy policy to reflect data collection
   - Example: Privacy policy says "we don't collect analytics" but form says you do

2. **Missing required data types**
   - Fix: Review app permissions and add all data types
   - Check AndroidManifest.xml for clues (CAMERA, etc.)

3. **Sharing not disclosed**
   - Fix: Add Mixpanel/Sentry to shared services
   - Be clear about analytics sharing

4. **Unclear deletion process**
   - Fix: Provide specific email or in-app instructions
   - Include expected response time

**How to appeal:**
- Google will email rejection reason
- Update form based on feedback
- Resubmit (no penalty for revisions)

---

## Pro Tips

1. **Err on the side of transparency** - Users appreciate honesty
2. **Use simple language** - Avoid technical jargon in descriptions
3. **Test your app** - Ensure form matches reality
4. **Save a draft** - Google autosaves, but review before publishing
5. **Screenshot your answers** - Keep a record for future reference
6. **Review competitors** - See how similar apps answer (search for fitness apps)

---

## Resources

### Official Google Documentation
- [Data Safety Form Guide](https://support.google.com/googleplay/android-developer/answer/10787469)
- [User Data Policies](https://support.google.com/googleplay/android-developer/answer/9888170)
- [Privacy Policy Requirements](https://support.google.com/googleplay/android-developer/answer/9859455)

### Your Links
- **Privacy Policy:** https://milkmanfunddev-ops.github.io/mealvana_endurance_landing_page/privacypolicy
- **Terms of Service:** https://milkmanfunddev-ops.github.io/mealvana_endurance_landing_page/terms

### Third-Party Privacy Policies (for reference)
- **Supabase:** https://supabase.com/privacy
- **Mixpanel:** https://mixpanel.com/legal/privacy-policy/
- **Sentry:** https://sentry.io/privacy/

---

## Quick Answer Summary

**Copy-paste these for quick form filling:**

### Email Address
- **Collected?** Yes
- **Shared?** No
- **Optional?** No
- **Purpose:** Account management, App functionality

### Fitness Info
- **Collected?** Yes
- **Shared?** No
- **Optional?** No
- **Purpose:** App functionality, Personalization

### App Interactions
- **Collected?** Yes
- **Shared?** Yes (Mixpanel)
- **Optional?** No
- **Purpose:** Analytics, App functionality

### Crash Logs
- **Collected?** Yes
- **Shared?** Yes (Sentry)
- **Optional?** No
- **Purpose:** Analytics, App functionality

### Device ID
- **Collected?** Yes
- **Shared?** No
- **Optional?** No
- **Purpose:** App functionality, Account management

### Camera/Photos
- **Collected?** No (used but not stored)
- **Purpose:** App functionality (barcode scanning)
- **Note:** "Images processed on-device, not stored or transmitted"

---

**Estimated Time to Complete Form:** 15-20 minutes
**Review Time:** 5 minutes
**Google Review:** Instant (usually no review for this form, only on app submission)

---

**Last Updated:** 2025-10-17
**Status:** Complete reference guide
**Next Action:** Complete form in Play Console during store listing setup
