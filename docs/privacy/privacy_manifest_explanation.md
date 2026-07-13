# Privacy Manifest Explanation

> **Source of truth:** `ios/Runner/PrivacyInfo.xcprivacy`. This document only *explains* that
> file — it never overrides it. If the two disagree, the manifest is right and this doc is stale.
> Keep this doc, the manifest, and the live App Store Connect privacy label in sync
> (see `app_store_privacy_details.md`).

**Last verified: 2026-07-13**

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

| Data type (manifest key)                        | Linked | Tracking | Purpose          | Why we collect it |
| ----------------------------------------------- | ------ | -------- | ---------------- | ----------------- |
| `NSPrivacyCollectedDataTypeHealth`              | Yes    | No       | App Functionality | Nutrition data and biometrics (weight, height, age) used to compute fueling plans |
| `NSPrivacyCollectedDataTypeFitness`             | Yes    | No       | App Functionality | Activity data (distance, pace, duration) driving plan generation and the training calendar |
| `NSPrivacyCollectedDataTypeCrashData`           | No     | No       | App Functionality | Sentry crash reporting |
| `NSPrivacyCollectedDataTypePerformanceData`     | No     | No       | App Functionality | Sentry performance monitoring |
| `NSPrivacyCollectedDataTypeOtherDiagnosticData` | No     | No       | App Functionality | Sentry diagnostics, incl. error-triggered session replay (content masked) |
| `NSPrivacyCollectedDataTypeProductInteraction`  | Yes    | No       | Analytics        | Mixpanel product analytics (screen views, feature usage) |
| `NSPrivacyCollectedDataTypeUserID`              | Yes    | No       | App Functionality | Anonymous device ID / account identifier used to associate a user's own data across sessions and devices |
| `NSPrivacyCollectedDataTypePreciseLocation`     | Yes    | No       | App Functionality | Weather forecasts for planned workouts (drives hydration/sodium recommendations) |
| `NSPrivacyCollectedDataTypeEmailAddress`        | Yes    | No       | App Functionality | Email authentication / account identity |

Every type is declared with `NSPrivacyCollectedDataTypeTracking = false` — none of this data is used
for advertising or shared with data brokers.

### Note on the Precise Location "Linked" flag

The manifest declares Precise Location as **linked**; the current live App Store Connect label
declares it as **not linked**. This is a known discrepancy. The conservative declaration (linked) is
the safe one, and the manifest is intentionally *not* being loosened here. Reconcile deliberately —
do not "fix" one side to match the other without deciding which is actually true of the data flow.

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
| Mixpanel     | Product analytics events                                             | Product Interaction, User ID |
| Sentry       | Crashes, performance traces, error-only session replay (masked)      | Crash, Performance, Other Diagnostic |
| OneSignal    | Push notification delivery (device/push token)                       | User ID |
| RevenueCat   | Subscription / purchase state                                        | User ID |

## Maintenance

Re-verify this document whenever any of the following changes:

- A dependency that touches user data is added, removed, or upgraded (see `pubspec.yaml`).
- A new data type starts being collected, or an existing one stops.
- An analytics event begins carrying a new class of personal data.
- The App Store Connect privacy label is edited.

Update `ios/Runner/PrivacyInfo.xcprivacy` **first**, then this doc, then the App Store Connect label.
Bump the "Last verified" date on both privacy docs when you do.
