# Privacy Manifest Explanation

> **Source of truth:** `ios/Runner/PrivacyInfo.xcprivacy`. This document only *explains* that
> file — it never overrides it. If the two disagree, the manifest is right and this doc is stale.
> Keep this doc, the manifest, and the live App Store Connect privacy label in sync
> (see `app_store_privacy_details.md`).

**Last verified: 2026-07-13**
**Manifest verified against the code and the live App Store label: 2026-07-13 — they agree on all 9 types.**

## What the manifest is

Apple requires a privacy manifest (`PrivacyInfo.xcprivacy`) for iOS 17+ App Store submissions. It
declares (a) whether the app tracks users, (b) every category of data the app collects, and (c) the
"required reason" APIs the app or its dependencies call.

Mealvana Endurance **does collect user data**. The manifest declares nine data types.

## NSPrivacyTracking: `false`

Correct as of the last verification. "Tracking" in Apple's sense is a narrow term: linking user or
device data with third-party data *for targeted advertising or ad measurement*, or sharing it with a
data broker.

- No IDFA / `AppTrackingTransparency` usage.
- No ad SDKs or ad networks in the dependency tree.
- No data broker sharing.

Because none of that is present, the ATT prompt is genuinely **not required**, and
`NSPrivacyTrackingDomains` is correctly empty.

> **Important caveat — this is not a blanket exemption.** `NSPrivacyTracking = false` only means we
> do not do *ad tracking*. It does **not** exempt us from **App Store Review Guideline 5.1.1(ii)
> (Data Collection and Storage — Permission)**, which requires user consent before collecting usage
> or analytics data, *even when that data is anonymous or pseudonymous*. We ship Mixpanel product
> analytics, so 5.1.1(ii) applies to us. Treat analytics consent as a separate obligation from ATT.

## NSPrivacyTrackingDomains: `[]`

Empty, consistent with `NSPrivacyTracking = false`. Note this array is for *tracking* domains only —
it is **not** a claim that the app makes no network requests. The app talks to Supabase, Mixpanel,
Sentry, OneSignal and RevenueCat.

## NSPrivacyCollectedDataTypes

Nine declared types. "Linked" = associated with the user's identity.

| Data type (manifest key)                        | Linked | Tracking | Purposes                       | Why we collect it |
| ----------------------------------------------- | ------ | -------- | ------------------------------ | ----------------- |
| `NSPrivacyCollectedDataTypeHealth`              | Yes    | No       | App Functionality + Analytics  | Nutrition data and biometrics (weight, height, age) used to compute fueling plans. Also reaches Mixpanel — see below |
| `NSPrivacyCollectedDataTypeFitness`             | Yes    | No       | App Functionality + Analytics  | Activity data (distance, pace, duration) driving plan generation and the training calendar. Also reaches Mixpanel — see below |
| `NSPrivacyCollectedDataTypeCrashData`           | Yes    | No       | App Functionality + Analytics  | Sentry crash reporting |
| `NSPrivacyCollectedDataTypePerformanceData`     | Yes    | No       | App Functionality + Analytics  | Sentry performance monitoring |
| `NSPrivacyCollectedDataTypeOtherDiagnosticData` | Yes    | No       | App Functionality + Analytics  | Sentry diagnostics, incl. error-triggered session replay (content masked) |
| `NSPrivacyCollectedDataTypeProductInteraction`  | Yes    | No       | Analytics + App Functionality  | Mixpanel product analytics (screen views, feature usage) |
| `NSPrivacyCollectedDataTypeUserID`              | Yes    | No       | App Functionality + Analytics  | Anonymous device ID / account identifier used to associate a user's own data across sessions and devices, and as the analytics identity |
| `NSPrivacyCollectedDataTypePreciseLocation`     | **No** | No       | App Functionality              | Weather forecasts for planned workouts (drives hydration/sodium recommendations). Cached locally only — see below |
| `NSPrivacyCollectedDataTypeEmailAddress`        | Yes    | No       | App Functionality              | Email authentication / account identity |

Every type is declared with `NSPrivacyCollectedDataTypeTracking = false` — none of this data is used
for advertising or shared with data brokers.

### Why the diagnostics types are "linked"

Crash Data, Performance Data and Other Diagnostic Data are all declared **linked**. `setUserContext()`
attaches the device id (and gut-training level) to Sentry events, so every diagnostic payload is
associated with an identity. An earlier version of the manifest declared these as *not* linked, which
**under-declared** what we actually send.

### Health and Fitness reach Mixpanel (Analytics purpose is load-bearing)

Health and Fitness both carry the **Analytics** purpose, and that is not defensive over-declaration —
it is required. `identifyUser()` in `lib/shared/services/analytics/analytics_tracker.dart` sets
**Gender**, **Age**, **Weight (lbs)**, **Runs With Water Bottle** and **Gut Training Level** as
Mixpanel People properties, and fires a `user_identified` event carrying the same values. Health and
fitness data therefore genuinely *is* used for analytics. An earlier version of the manifest declared
these as "App Functionality" only, which **under-declared**.

> **If those People properties are ever removed from `analytics_tracker.dart`**, drop the Analytics
> purpose from Health and Fitness in `PrivacyInfo.xcprivacy` (and on the live label), and tighten the
> in-app consent copy to match — it currently has to cover health/fitness data flowing to Mixpanel.

### Note on the Precise Location "Linked" flag — RESOLVED 2026-07-13

There used to be a discrepancy here: the manifest declared Precise Location as **linked** while the
live App Store Connect label declared it **not linked**. This was **resolved on 2026-07-13 in favour
of "not linked"**, and the manifest was corrected to match the label.

Reason: coordinates are sent to the weather provider and cached only in the **local Drift
`weather_forecasts` table**, which has **no `user_id` column**, is **never synced to Supabase**, and
is **never sent to Mixpanel**. Nothing associates a coordinate with the user's identity, so "linked"
was an **over-declaration**. The manifest and the live label now agree.

## NSPrivacyAccessedAPITypes

Required-reason API declarations. Both come from the Flutter engine / plugin layer, not from
first-party product code.

### `NSPrivacyAccessedAPICategoryFileTimestamp`
- **Reason code:** `C617.1` — timestamps accessed only for files inside the app container.
- **Usage:** Local filesystem operations (Flutter engine, Drift database files, caches).

### `NSPrivacyAccessedAPICategoryUserDefaults`
- **Reason code:** `CA92.1` — `UserDefaults` used to read/write only the app's own preferences.
- **Usage:** Local preference storage (`shared_preferences` and SDK-internal state).

## Third-party processors reflected in this manifest

| Processor    | What it receives                                                     | Manifest types it drives |
| ------------ | -------------------------------------------------------------------- | ------------------------ |
| Supabase     | Backend: account, profile, health/fitness, plans, activities         | Health, Fitness, User ID, Email |
| Mixpanel     | Product analytics events, **plus health/fitness People properties** (Gender, Age, Weight, Runs With Water Bottle, Gut Training Level) via `identifyUser()` | Product Interaction, User ID, **Health, Fitness** |
| Sentry       | Crashes, performance traces, error-only session replay (masked), with device id attached via `setUserContext()` | Crash, Performance, Other Diagnostic, User ID |
| OneSignal    | Push notification delivery (device/push token)                       | User ID |
| RevenueCat   | Subscription / purchase state                                        | User ID |

## Maintenance

Re-verify this document whenever any of the following changes:

- A dependency that touches user data is added, removed, or upgraded (see `pubspec.yaml`).
- A new data type starts being collected, or an existing one stops.
- An analytics event begins carrying a new class of personal data.
- `identifyUser()` in `lib/shared/services/analytics/analytics_tracker.dart` gains or loses People
  properties — in particular, if the health/fitness properties (Gender, Age, Weight (lbs), Runs With
  Water Bottle, Gut Training Level) are removed, drop the Analytics purpose from Health and Fitness
  and tighten the in-app consent copy.
- The App Store Connect privacy label is edited.

Update `ios/Runner/PrivacyInfo.xcprivacy` **first**, then this doc, then the App Store Connect label.
Bump the "Last verified" date on both privacy docs when you do.
