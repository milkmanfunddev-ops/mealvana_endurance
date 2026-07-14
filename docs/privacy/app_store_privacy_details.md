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
**Manifest verified against the code and the live App Store label: 2026-07-13 — they agree on all 9 types.**
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

Nine types. "Linked" = linked to the user's identity. The privacy manifest and the live label are
**fully in sync across all 9 types (verified 2026-07-13)**.

### Health & Fitness
| Type | Linked | Tracking | Purposes |
| ---- | ------ | -------- | -------- |
| Health | Yes | No | App Functionality, Analytics |
| Fitness | Yes | No | App Functionality, Analytics |

Nutrition intake, biometrics (weight, height, age, body fat), workouts, distance, pace, duration.
Required to generate fueling plans and to sync training data.

**Health and Fitness reach Mixpanel.** `identifyUser()` in
`lib/shared/services/analytics/analytics_tracker.dart` sets **Gender**, **Age**, **Weight (lbs)**,
**Runs With Water Bottle** and **Gut Training Level** as Mixpanel People properties and fires a
`user_identified` event with the same values. That is why the **Analytics** purpose is declared on
both types — it is required, not defensive. If those People properties are ever removed from
`analytics_tracker.dart`, drop Analytics from Health/Fitness in the manifest **and** on this label,
and tighten the in-app consent copy accordingly.

### Identifiers
| Type | Linked | Tracking | Purposes |
| ---- | ------ | -------- | -------- |
| User ID | Yes | No | App Functionality, Analytics |

Account identifier / anonymous device ID. Used to associate a user with their own data across
sessions and devices, to key Mixpanel/Sentry/OneSignal/RevenueCat records, and as the analytics
identity. **No Device ID / advertising identifier is collected.**

### Contact Info
| Type | Linked | Tracking | Purposes |
| ---- | ------ | -------- | -------- |
| Email Address | Yes | No | App Functionality |

Email authentication and account identity. Not used for marketing.

### Location
| Type | Linked | Tracking | Purposes |
| ---- | ------ | -------- | -------- |
| Precise Location | **No** | No | App Functionality |

Used to fetch weather forecasts for planned workouts, which drive hydration and sodium
recommendations.

**Not linked, deliberately.** Coordinates go to the weather provider and are cached only in the local
Drift `weather_forecasts` table, which has **no `user_id` column**, is **never synced to Supabase**,
and is **never sent to Mixpanel**. Nothing ties a coordinate to the user's identity. The manifest
previously declared this **linked**, which over-declared; that discrepancy was **resolved on
2026-07-13 in favour of "not linked"**, and the manifest and the live label now agree.

### Usage Data
| Type | Linked | Tracking | Purposes |
| ---- | ------ | -------- | -------- |
| Product Interaction | Yes | No | Analytics, App Functionality |

Mixpanel: screen views, feature usage, funnel events. Internal/QA traffic is tagged `is_internal`.

### Diagnostics
| Type | Linked | Tracking | Purposes |
| ---- | ------ | -------- | -------- |
| Crash Data | Yes | No | App Functionality, Analytics |
| Performance Data | Yes | No | App Functionality, Analytics |
| Other Diagnostic Data | Yes | No | App Functionality, Analytics |

Sentry: crash reports, performance traces, and error-triggered session replay (content masked).

**Linked**, because `setUserContext()` attaches the device id (and gut-training level) to Sentry
events, so diagnostics are associated with an identity. The manifest previously declared these three
as *not* linked, which under-declared; corrected 2026-07-13.

### Not collected
Financial Info, Payment Info (handled by Apple / RevenueCat, never touches our servers), Contacts,
User Content (photos/audio), Browsing History, Search History, Sensitive Info, Device ID /
Advertising ID, Other Data.

## Third-party processors

| Processor  | Role | Data it receives |
| ---------- | ---- | ---------------- |
| Supabase   | Backend (auth, database, edge functions) | Email, User ID, health, fitness, plans, activities |
| Mixpanel   | Product analytics | User ID, Product Interaction events, **Health + Fitness People properties** (Gender, Age, Weight (lbs), Runs With Water Bottle, Gut Training Level) via `identifyUser()` |
| Sentry     | Crash / performance / masked session replay | Crash, Performance, Other Diagnostic Data, User ID (device id via `setUserContext()`) |
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
- [ ] Did `identifyUser()` in `analytics_tracker.dart` gain or lose People properties? If the
      health/fitness ones went away, drop Analytics from Health/Fitness here and in the manifest.
- [ ] Does the live App Store Connect label still match the table above?
- [ ] Does https://www.mealvana.io/privacy-policy still describe the real data flows?
- [ ] Bump the "Last verified" dates in this doc and `privacy_manifest_explanation.md`.
