# Runna - Calendar Feed Data Reference

Runna is an implemented training integration, but it does **not** expose a conventional OAuth/JSON
API to Mealvana. The athlete pastes the personal calendar-subscription URL from Runna Settings.
Mealvana fetches the iCalendar (`.ics`) document and imports planned running workouts.

**Last verified:** 2026-07-23 against `runna_ics_client.dart`, `runna_ics_parser.dart`,
`runna_transformer.dart`, `runna_sync_service.dart`, and their unit tests.

## Endpoint, authentication, and delivery

| Item | Type | Description |
|---|---|---|
| Feed URL | `webcal://...` or `https://...` string | User-specific calendar-subscription URL copied from Runna. |
| Effective method | HTTP `GET` | `webcal://` is normalized to `https://`; the client also accepts `http://`. |
| Authentication | Embedded URL token | There is no separate OAuth flow or header token. The secret is part of the feed URL and is stored in the integration record's `accessToken` slot. |
| Request `Accept` | string | `text/calendar, text/plain, */*` |
| Success | HTTP `200` with text body | The body must contain `BEGIN:VCALENDAR`. |
| Timeout | duration | 20 seconds. |
| Sync direction | Pull, read-only | Mealvana reads the calendar. It cannot write workouts or results back to Runna. |

The feed URL itself is a credential and must not be logged, placed in screenshots, or shared.
Runna supplies no athlete id or profile; Mealvana derives a stable non-reversible short fingerprint
of the feed URL for the required `providerAthleteId`.

## Raw calendar envelope

Observed top-level iCalendar fields remain available in the raw text but are not mapped:

| Field | Type | Example | Description | App use |
|---|---|---|---|---|
| `BEGIN:VCALENDAR` / `END:VCALENDAR` | structural marker | - | Calendar document envelope. | Validates that the URL returned a calendar. |
| `VERSION` | string | `2.0` | iCalendar version. | Ignored. |
| `PRODID` | string | `-//Runna//Training Plan//EN` | Producer identifier. | Ignored. |
| `X-WR-CALNAME` | string | `Runna Training Plan` | Display name of the subscribed calendar. | Ignored. |
| `BEGIN:VEVENT` / `END:VEVENT` | structural marker | - | One planned calendar event/workout. | Creates one parser candidate. |

The parser is an intentionally bounded RFC 5545 subset. Unknown calendar or event properties remain
in the raw feed but are ignored.

## Complete supported VEVENT field dictionary

| iCalendar field | Parsed type | Required | Example | Description | Mealvana mapping / behavior |
|---|---|:--:|---|---|---|
| `UID` | string | Yes | `runna-evt-001@runna.com` | Stable event identifier and deduplication key. | `providerWorkoutId`; duplicate UIDs are filtered. |
| `DTSTART;VALUE=DATE` | local `DateTime` + `isAllDay=true` | One `DTSTART` form required | `20260724` | All-day planned date; the common Runna form. | Anchored at 06:00 device-local time. |
| `DTSTART` ending in `Z` | UTC timestamp converted to local `DateTime` | One `DTSTART` form required | `20260728T060000Z` | Absolute scheduled start. | Converted with `toLocal()`. |
| `DTSTART;TZID=...` or floating `DTSTART` | local wall-clock `DateTime` | One `DTSTART` form required | `TZID=Europe/London:20260728T060000` | Scheduled local time. | TZID is not resolved; the wall-clock time is kept in the device timezone. |
| `DTEND` | `DateTime?` | No | `20260728T070000Z` | End time for a timed event. | Duration source 2: `DTEND - DTSTART`. All-day exclusive-next-day values are discarded. |
| `DURATION` | `Duration?` | No | `PT45M`, `PT1H30M` | RFC 5545 / ISO 8601 duration. Supports weeks, days, hours, minutes, seconds, and a leading minus sign. | Duration source 3; non-positive/zero values are unusable. |
| `X-WORKOUT-ESTIMATED-DURATION` | positive integer seconds | No | `3120` | Runna's estimated moving time; fractional input is rounded. | Preferred duration source 1. |
| `SUMMARY` | unescaped string | No | `Easy Run - 6mi - 50m - 55m`* | Compact workout label containing title and often distance/duration segments. | Title, distance, duration fallback, subtype, intensity, and non-run filtering. Missing value becomes `Runna workout`. |
| `DESCRIPTION` | unescaped string | No | `Warm up: 10 mins easy\nMain: 4mi at 8:30/mi` | Step-by-step workout text. | `notes`; not structurally parsed into intervals or pace targets. |
| `URL` | string/URL | No | `https://runna.com/workout/001` | Provider deep link. | `providerWorkoutUrl`. |
| `LOCATION` | unescaped string | No | `Track` | Event location. | Parsed and available in `RunnaIcsEvent`, but not stored on the activity. |
| `LAST-MODIFIED` | `DateTime?` | No | `20260720T120000Z` | Provider modification timestamp. | Parsed and available, but not used for change detection or stored. |
| `STATUS` | enum-like string | No | `CANCELLED` | Calendar event status. | `CANCELLED` events are skipped and counted. Other values have no special handling. |
| `RRULE` | recurrence rule string | No | `FREQ=WEEKLY;BYDAY=FR` | Recurring-event definition. | Any event with `RRULE` is skipped; recurrence expansion is not implemented. |

\* Runna commonly uses a leading emoji and bullet separators (`•` or `·`). Plain hyphens in this
rendered example are only for display; the parser splits on bullet characters.

### Property parameters and encoding

Property names and parameter names are case-insensitive. The parser supports semicolon-delimited
parameters (including quoted parameter values), folded physical lines, CRLF/LF/CR line endings, and
RFC text escapes: `\n`/`\N`, `\,`, `\;`, and `\\`. If the same supported property appears more
than once in an event, the last value wins.

## Data derived from SUMMARY

`SUMMARY` is split into bullet-separated segments. The leading emoji/punctuation is removed from
the first segment.

| Derived value | Type / unit | Recognized inputs | Notes |
|---|---|---|---|
| Workout title | string | First segment | Fallback: `Runna workout`. |
| Distance | number, miles | `6mi`, `4.5 miles`, `10km`, `5k` | Kilometres multiply by `0.621371`. Only a segment consisting entirely of distance is recognized. |
| Duration range | integer minutes | `50m - 55m`, `50 min - 55 min` | Midpoint, rounded. |
| Duration hours | integer minutes | `1h`, `1hr`, `1h 10m` | Converted to total minutes. |
| Duration single | integer minutes | `45m`, `45 mins`, `45 minutes` | Used only after custom duration, timed end, and `DURATION`. |
| Workout subtype | enum-like string | Race, Long Run, Tempo, Threshold, Intervals, Speed, Fartlek, Hills, Progression, Recovery, Easy | Keyword heuristic; unrecognized titles remain null. |
| Intensity | enum | easy, moderate, hard, race | Derived from subtype; unknown defaults to moderate. |
| Pace target | number, min/mile | Derived duration / distance | Stored only when both inputs exist and the result is between 4.0 and 20.0 min/mile. |

Duration values are clamped to 1-1,440 minutes.

## Imported activity shape

Every imported event is a **planned running** activity. The integration does not receive completion
or actual-performance data.

| Activity field | Type | Source |
|---|---|---|
| `activityType` | enum | Always `running`. |
| `status` | enum | Always `planned`. |
| `title` | string | Parsed `SUMMARY` title. |
| `scheduledDateTime` | `DateTime` | `DTSTART`. |
| `distanceMiles` | nullable number | Parsed `SUMMARY` distance. |
| `durationMinutes` | nullable integer | Custom duration, timed end, `DURATION`, or `SUMMARY` fallback. |
| `paceTargetMinutesPerMile` | nullable number | Derived from duration and distance. |
| `notes` | nullable string | `DESCRIPTION`. |
| `workoutSubtype` | nullable string | Summary keyword heuristic. |
| `intensityLevel` | enum | Derived from subtype. |
| `providerWorkoutId` | string | `UID`. |
| `providerWorkoutUrl` | nullable string | `URL`. |
| `providerScheduledAt` | `DateTime` | `DTSTART`. |

Strength, mobility, yoga, Pilates, conditioning, and cross-training events are filtered by summary
keywords and are not imported.

## Not available from the Runna feed

- Athlete first/last name, email, gender, date of birth, height, weight, body composition, or unit
  preference.
- Dietary preference or allergies.
- Completed-workout actuals, GPS, heart rate, power, cadence, laps, or sensor samples.
- A structured machine-readable interval tree. Step text is available only as `DESCRIPTION`.
- OAuth scopes, webhooks, write-back, activity uploads, zones, race calendar objects, or profile
  endpoints.

## Sync semantics

- Incoming events are deduplicated by `UID`.
- Malformed, cancelled, recurring, duplicate, and filtered non-run events are counted separately.
- If Runna regenerates UIDs, a same-day + normalized-title fallback adopts the new UID onto an
  existing planned activity.
- A missing event is treated as deleted only when its date lies inside the current feed's observed
  min/max date window. This prevents old workouts from being deleted when they merely roll out of
  Runna's limited subscription window.
