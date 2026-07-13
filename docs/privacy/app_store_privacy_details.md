# Mealvana Endurance - App Store Privacy Details

> **⚠️ KEEP THIS IN SYNC.** This document is an answer sheet for the App Store Connect "App Privacy"
> questionnaire. It has **two** sources of truth it must agree with at all times:
> 1. `ios/Runner/PrivacyInfo.xcprivacy` (the shipped privacy manifest), and
> 2. the **live** App Store Connect privacy label.
>
> If you change what the app collects, update the manifest first, then this doc, then the live label.
>
> **⚠️ The previous version of this file was dangerously wrong.** It declared that the app
> "does NOT collect, transmit, or share any user data", claimed "No Analytics", "Local Storage Only
> (Hive)" and "No Network Requests", and instructed the reader to answer **NO** to
> "Does this app collect data from users?". Every one of those statements was false — it described a
> different, older, offline-only app. Copying it into App Store Connect would have produced a
> materially false privacy label. It has been replaced in full. Do not resurrect it from git history.

**Last verified: 2026-07-13**
**Live label verified against App Store Connect: 2026-07-11**
**Bundle ID**: `com.milkman.mealvanaendurance`
**Privacy Policy URL**: https://www.mealvana.io/privacy-policy

## Summary

**Mealvana Endurance collects user data.** It is an online, account-based, cloud-synced app. It
stores personal health and fitness data on a backend, runs product analytics, and reports crashes.

## App Store Connect answers

| Question | Answer |
| -------- | ------ |
| Does this app collect data from users? | **YES** |
| Do you or your third-party partners collect data from this app? | **YES** |
| Is data collected from this app used for tracking purposes? | **NO** |
| Do you or your third-party partners use data from this app for advertising or marketing purposes? | **NO** |

"Tracking" = No is correct in Apple's narrow sense: no IDFA, no ad SDKs, no data-broker sharing, no
linking with third-party data for ad targeting or measurement. This is consistent with
`NSPrivacyTracking = false` in the privacy manifest. **No ATT prompt is required.**

Note that "Tracking = No" does **not** exempt us from Guideline 5.1.1(ii), which requires consent for
usage/analytics collection even when anonymous. See `privacy_manifest_explanation.md`.

## Data types declared on the live label

Nine types. "Linked" = linked to the user's identity.

### Health & Fitness
| Type | Linked | Purposes |
| ---- | ------ | -------- |
| Health | Yes | Analytics, App Functionality |
| Fitness | Yes | Analytics, App Functionality |

Nutrition intake, biometrics (weight, height, age, body fat), workouts, distance, pace, duration.
Required to generate fueling plans and to sync training data.

### Identifiers
| Type | Linked | Purposes |
| ---- | ------ | -------- |
| User ID | Yes | App Functionality |

Account identifier / anonymous device ID. Used to associate a user with their own data across
sessions and devices, and by Mixpanel, Sentry, OneSignal and RevenueCat to key their records.
**No Device ID / advertising identifier is collected.**

### Contact Info
| Type | Linked | Purposes |
| ---- | ------ | -------- |
| Email Address | Yes | App Functionality |

Email authentication and account identity. Not used for marketing.

### Location
| Type | Linked | Purposes |
| ---- | ------ | -------- |
| Precise Location | **No** (per live label) | App Functionality |

Used to fetch weather forecasts for planned workouts, which drive hydration and sodium
recommendations.

> **Known discrepancy:** the privacy manifest declares Precise Location as **linked**; the live label
> declares it **not linked**. The manifest takes the conservative position. Reconcile deliberately —
> decide which is actually true of the data flow before changing either side.

### Usage Data
| Type | Linked | Purposes |
| ---- | ------ | -------- |
| Product Interaction | Yes | Analytics |

Mixpanel: screen views, feature usage, funnel events. Internal/QA traffic is tagged `is_internal`.

### Diagnostics
| Type | Linked | Purposes |
| ---- | ------ | -------- |
| Crash Data | No | App Functionality |
| Performance Data | No | App Functionality |
| Other Diagnostic Data | No | App Functionality |

Sentry: crash reports, performance traces, and error-triggered session replay (content masked).

### Not collected
Financial Info, Payment Info (handled by Apple / RevenueCat, never touches our servers), Contacts,
User Content (photos/audio), Browsing History, Search History, Sensitive Info, Device ID /
Advertising ID, Other Data.

## Third-party processors

| Processor  | Role | Data it receives |
| ---------- | ---- | ---------------- |
| Supabase   | Backend (auth, database, edge functions) | Email, User ID, health, fitness, plans, activities |
| Mixpanel   | Product analytics | User ID, Product Interaction events |
| Sentry     | Crash / performance / masked session replay | Crash, Performance, Other Diagnostic Data |
| OneSignal  | Push notifications | User ID, push token |
| RevenueCat | Subscription / entitlement state | User ID, purchase state |

None of these are ad networks or data brokers. None receive data for advertising purposes.

## Also declared in the manifest

Required-reason API declarations (`NSPrivacyAccessedAPITypes`): File Timestamp (`C617.1`) and
UserDefaults (`CA92.1`). Both originate in the Flutter engine / plugin layer. Details in
`privacy_manifest_explanation.md`.

## Before every submission

- [ ] Re-read `ios/Runner/PrivacyInfo.xcprivacy` — did any data type change?
- [ ] Did any new SDK land in `pubspec.yaml` that touches user data?
- [ ] Does the live App Store Connect label still match the table above?
- [ ] Does https://www.mealvana.io/privacy-policy still describe the real data flows?
- [ ] Bump the "Last verified" dates in this doc and `privacy_manifest_explanation.md`.
