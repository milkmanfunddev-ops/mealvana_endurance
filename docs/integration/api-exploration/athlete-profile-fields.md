# Athlete Profile Fields — Which API Call Gives Us What

**Question this answers:** "I need the athlete's name / email / height / weight / upcoming race —
which provider, which endpoint?"

This is a routing table only. Field types, units, and full payloads live in each provider's own
doc; this page tells you where to go and, more often, that there is nowhere to go.

**Derived from** the provider docs in this folder (verified 2026-07-20 against `release/1.21.1`).
Where those docs and this one disagree, the provider doc wins.

---

## The short answer

**TrainingPeaks is the only provider that gives us athlete identity.** Name, email, sex, birth
month, and the race calendar come from TrainingPeaks or from nowhere. Garmin gives us body
measurements but never tells us who the person is. Final Surge and VDOT O2 give us neither.

**Nobody gives us height** in a usable profile endpoint — see the note below.

---

## Matrix

| Field | Garmin | TrainingPeaks | Final Surge | VDOT O2 |
|---|:--:|:--:|:--:|:--:|
| First / last name | ✗ | ✅ | ✗ | ✗ hardcoded `'V.O2'` |
| Email | ✗ | ✅ | ✗ | ✗ |
| Sex | ✗ | ✅ | ✗ | ✗ |
| Birth date | ✗ | ⚠️ month only | ✗ | ✗ |
| Height | ⚠️ Women's API only | ✗ | ✗ | ✗ |
| Weight | ✅ | ✅ two sources | ✗ | ✗ |
| Body composition (fat %, BMI, muscle) | ✅ | ✗ | ✗ | ✗ |
| Race / event calendar | ✗ | ✅ | ✗ | ✗ |
| Coach relationship | ✗ | ✅ | ✗ | ✗ |
| Stable athlete identifier | ✅ opaque | ✅ | ✅ | ✗ we mint our own |

Legend: ✅ available · ⚠️ available with a caveat, read the note · ✗ not available to us

---

## Where each field comes from

### Name, email, sex, birth month

`GET /v1/athlete/profile` (TrainingPeaks, scope `athlete:profile`) — the single call that returns
`FirstName`, `LastName`, `Email`, `Sex`, `BirthMonth`, `TimeZone`, `CoachedBy`, and `Weight` in one
response. A coach reads the same object shape for managed athletes via `GET /v1/coach/athletes`
(scope `coach:athletes`).

Two things to know before you rely on it: `BirthMonth` is `YYYY-MM` with **no day**, so you cannot
compute an exact age from it; and `Weight` on this object is always kilograms regardless of the
athlete's `PreferredUnits`, which is a display preference only.

Full field table: [`training-peaks/athlete-data.md`](./training-peaks/athlete-data.md) §1.

### Weight

Three different calls, and they are not interchangeable:

| Call | Field | Unit | Character |
|---|---|---|---|
| TP `GET /v1/athlete/profile` | `Weight` | kg | Current profile value, one number |
| TP `GET /v2/metrics/{metricId}` | `WeightInKilograms` | kg | Dated daily metric, a time series |
| Garmin `bodyComps` push | `weightInGrams` | **grams** | Dated measurement, scale or manual |

Note the Garmin unit is grams, not kilograms — it is the one place in this table where the unit
differs from the obvious. Garmin's payload also carries `percentFat`, `percentHydration`,
`boneMassInGrams`, `muscleMassInGrams`, and `bmi` when the measurement came from an Index scale;
a manual weight entry carries the time and weight only.

TP range reads (`GET /v2/metrics/{startDate}/{endDate}`) are **premium only**.

Details: [`training-peaks/athlete-data.md`](./training-peaks/athlete-data.md) §3 ·
[`garmin/health-data.md`](./garmin/health-data.md) §body composition.

### Height — read this before planning around it

No provider exposes height on a profile endpoint. The only occurrence of height anywhere in the
four APIs is `weightGoalUserInput.heightInCentimeters`, nested inside the **pregnancy snapshot** of
Garmin's Women's Health API ([`garmin/field-reference.md`](./garmin/field-reference.md)).

That is not a height source. It requires the Women's Health scope, it only exists for athletes who
have an active pregnancy record, and reaching for it to fill a general profile field would be both
unreliable and inappropriate. **If the app needs height, ask the athlete for it.**

### Race / event calendar

`GET /v2/events/next` and `GET /v2/events/{date}` (TrainingPeaks, scope `events:read`) return
`EventDate`, `EventType`, `Name`, `Description`, linked `WorkoutIds`, and a `Goals` array
(distance / time / place / PR targets).

Two behaviours to code against: there is **no bulk "all events" endpoint** — enumerate a range by
querying per date — and a `404` means *no events*, a normal empty result rather than an error.

Details: [`training-peaks/athlete-data.md`](./training-peaks/athlete-data.md) §4.

### Athlete identifiers

- **Garmin** — `GET /wellness-api/rest/user/id` returns an opaque stable `userId`
  (e.g. `d3315b1072421d0dd7c8f6b8e1de4df8`). It identifies the account across sessions but carries
  no personal information. `GET /wellness-api/rest/user/permissions` returns granted scopes.
- **TrainingPeaks** — `Id` on the profile object.
- **Final Surge** — the athlete key on workout payloads.
- **VDOT O2** — none. We store our own userId as `provider_athlete_id` and the athlete name is
  hardcoded `'V.O2'`.

---

## Two dead ends worth naming

**Final Surge `GET /API/v1/ProfileInfo` is not an athlete profile.** The name misleads. It is
partner-scoped key/value storage that Final Surge holds *on our behalf* — `uniqueid` (max 200
chars) and `profile` (max 3000 chars) are both `null` until we `POST` to it ourselves. Final Surge
exposes **no athlete profile endpoint at all**; all eight of its endpoints are auth, workouts,
uploads, or this storage slot. It also returns `ErrorDescription` rather than `ErrorMessage`,
unlike the rest of that API.

**Garmin will not tell you who the athlete is.** There is no name or email field anywhere in the
Garmin surface we consume. Garmin is a measurement source, not an identity source — pair it with
our own account record.

---

## If you need a field this table marks ✗

The options, in the order worth trying:

1. **Collect it in the app.** This is the answer for height, and the honest answer for most
   identity fields when TrainingPeaks is not connected.
2. **Check whether it is a scope decision rather than a limitation.** Garmin training data is
   unavailable to us because we request only `ACTIVITY_EXPORT HEALTH_EXPORT` — a choice on our
   side. No profile field is known to be gated this way, but confirm before assuming.
3. **Do not infer it from workout payloads.** Deriving identity or body metrics from activity data
   is how you get plausible-looking wrong values.

---

## Related

- [README.md](./README.md) — capability matrix for workout/training data, and the evidence markers
  explaining how far to trust each example
- [`training-peaks/athlete-data.md`](./training-peaks/athlete-data.md) — the substantive source for
  most of this page; also covers training zones
- [`garmin/health-data.md`](./garmin/health-data.md) — body composition, sleep, stress
