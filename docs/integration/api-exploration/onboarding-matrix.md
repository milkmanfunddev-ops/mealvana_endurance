# Onboarding Matrix - API Coverage

**Purpose:** compare the data collected by the active Mealvana Endurance onboarding flow with data
available from every implemented training-platform integration.

**Last verified:** 2026-07-23 against
`lib/features/onboarding/presentation/screens/onboarding_pageview_screen.dart`,
`user_profile_screen.dart`, `sports_selection_screen.dart`,
`dietary_preference_screen.dart`, and `allergies_screen.dart`.

## Coverage matrix

| Active onboarding field | App requirement / type | Garmin | TrainingPeaks | Final Surge | VDOT O2 | Runna |
|---|---|---|---|---|---|---|
| First name | Optional string | No | **Yes** - `FirstName` | **Yes** - `firstname` | No | No |
| Last name | Optional string | No | **Yes** - `LastName` | **Yes** - `lastname` | No | No |
| Email | Optional email string | No | **Yes** - `Email` | No | No | No |
| Gender | Required enum: male, female, non-binary | No | **Partial** - `Sex` is `m` or `f` only | No | No | No |
| Birthday | Required full date | No | **Partial** - `BirthMonth` is `YYYY-MM`; no day | No | No | No |
| Height | Required integer; cm or ft/in input | No* | No | No | No | No |
| Weight | Required number; kg or lb input | **Yes** - `weightInGrams` | **Yes** - profile `Weight` in kg; metrics also expose `WeightInKilograms` | No | No | No |
| Unit system | Required enum with default: metric or imperial | No | **Yes** - `PreferredUnits` is `English` or `Metric` | No | No | No |
| Sports trained | One or more of running, cycling, swimming | **Partial** - activity/workout sport can be inferred | **Partial** - workout types and sport-specific zones can be inferred | **Partial** - workout type/sport can be inferred | **Partial** - event/cross-training type can be inferred | **Partial** - every imported event is treated as running |
| Dietary preference | Optional enum | No | No | No | No | No |
| Allergies | Optional list of nine supported allergens | No | No | No | No | No |

\* Garmin Women's Health pregnancy snapshots can contain
`weightGoalUserInput.heightInCentimeters`, but that is a pregnancy-specific goal input, not a
general athlete height/profile field. It is intentionally classified as **No** for onboarding.

### Legend

- **Yes** - direct semantic match exposed by the provider API.
- **Partial** - incomplete value or a value that can only be inferred; user confirmation is still
  required.
- **No** - no equivalent field in any documented endpoint available to this integration.

## Exact source endpoints

| Provider | Endpoint(s) relevant to onboarding | Direct onboarding data |
|---|---|---|
| Garmin | Health API body composition push/ping; `/wellness-api/rest/bodyComps`; backfill equivalent | Weight. Body-fat percentage is also available, but the active onboarding flow does not ask for it. |
| TrainingPeaks | `GET /v1/athlete/profile` | First name, last name, email, birth month, binary sex, weight, preferred units. |
| Final Surge | `POST /oauth/token` response | First name and last name. `/API/v1/ProfileInfo` is partner-owned storage, not a user profile. |
| VDOT O2 | No profile endpoint | None. The token identifies the athlete, and workout endpoints return workout data only. |
| Runna | User-specific calendar-subscription URL fetched as iCalendar (`.ics`) | No athlete profile. Planned running events expose date/time, title, distance/duration text, notes, URL, and event id. |

## What the app currently prefills

The API surface and the implemented prefill behavior are not identical:

| Provider | Current onboarding prefill behavior |
|---|---|
| TrainingPeaks | Name, weight, birthday (day defaults to the first of the returned month), and binary gender. |
| Final Surge | Name only. |
| Garmin | Weight from body composition; Garmin is preferred over TrainingPeaks when both have weight. |
| VDOT O2 | No profile prefill. |
| Runna | No profile prefill. |

Email is available from TrainingPeaks, but the current profile-loading block does not copy the
integration email into the onboarding email field. The field may instead be populated from the
authenticated Supabase account.

## Scope boundary

The current onboarding PageView deliberately skips the preserved running, cycling, and swimming
detail screens and removed the food-like selection screen. Consequently this matrix excludes
water-bottle usage, GI sensitivity, FTP, bike-storage setup, CSS pace, wetsuit/cap preferences, and
food likes. Those remain model or settings fields, but they are not collected by the active
onboarding flow.

## Provider data dictionaries

For the complete field-level API inventories - including field names, types, units, descriptions,
endpoint coverage, and payload examples - use:

- [Garmin complete field reference](./garmin/field-reference.md)
- [TrainingPeaks field reference](./training-peaks/field-reference.md)
- [Final Surge field reference](./final-surge/field-reference.md)
- [VDOT O2 field reference](./vdot-o2/field-reference.md)
- [Runna calendar-feed field reference](./runna/README.md)

The searchable single-file version is [index.html](./index.html).
