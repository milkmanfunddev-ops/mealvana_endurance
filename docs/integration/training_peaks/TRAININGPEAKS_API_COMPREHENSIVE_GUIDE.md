# TrainingPeaks Partner API - Comprehensive Research Report

**Research Date:** November 26, 2025
**Source:** [TrainingPeaks PartnersAPI GitHub Wiki](https://github.com/TrainingPeaks/PartnersAPI/wiki)

## Table of Contents

1. [Overview](#overview)
2. [OAuth 2.0 Authentication](#oauth-20-authentication)
3. [API Endpoints Reference](#api-endpoints-reference)
4. [Data Models](#data-models)
5. [Webhooks (Early Access)](#webhooks-early-access)
6. [Rate Limiting & Best Practices](#rate-limiting--best-practices)
7. [Error Handling](#error-handling)
8. [Premium vs Basic Athletes](#premium-vs-basic-athletes)
9. [Development & Testing](#development--testing)
10. [Integration for Mealvana](#integration-for-mealvana)

---

## Overview

### What is the TrainingPeaks Partner API?

The TrainingPeaks Partner API enables authenticated external third parties to access athlete data stored in TrainingPeaks. All requests require:
- Valid OAuth 2.0 access tokens
- HTTPS-only communication
- JSON format for requests and responses
- Authorization header with Bearer token
- User-Agent header identifying the calling application

### Environments

| Environment | Base URL | Purpose |
|-------------|----------|---------|
| **Sandbox** | `https://api.sandbox.trainingpeaks.com` | Testing and development |
| **Production** | `https://api.trainingpeaks.com` | Live production use |

**Important:** Sandbox database refreshes weekly from production (every Saturday at 6:00 PM MST). Test data is overwritten during this process.

### API Access Requirements

- **Organizational/Business Use Only** - Not available for personal projects
- Apply at: https://api.trainingpeaks.com/request-access
- Allow 7-10 days for response
- Pre-production validation required before production credentials

---

## OAuth 2.0 Authentication

### OAuth Endpoints

| Environment | Authorization | Token Exchange | Deauthorization |
|-------------|--------------|----------------|-----------------|
| **Sandbox** | `https://oauth.sandbox.trainingpeaks.com/OAuth/Authorize` | `https://oauth.sandbox.trainingpeaks.com/oauth/token` | `https://oauth.sandbox.trainingpeaks.com/oauth/deauthorize` |
| **Production** | `https://oauth.trainingpeaks.com/OAuth/Authorize` | `https://oauth.trainingpeaks.com/oauth/token` | `https://oauth.trainingpeaks.com/oauth/deauthorize` |

### Three-Legged OAuth Flow

#### Step 1: Redirect to Authorization Endpoint

```
GET /OAuth/Authorize
  ?response_type=code
  &client_id={your_client_id}
  &scope={space_delimited_scopes}
  &redirect_uri={your_redirect_uri}
```

**Example:**
```
https://oauth.trainingpeaks.com/OAuth/Authorize?response_type=code&client_id=myapp&scope=athlete%3Aprofile%20workouts%3Aread&redirect_uri=https://myapp.com/callback
```

#### Step 2-3: User Login & Consent
User authenticates with TrainingPeaks and approves requested scopes.

#### Step 4: Authorization Code Redirect
TrainingPeaks redirects to your `redirect_uri` with authorization code:
```
https://myapp.com/callback?code=AUTHORIZATION_CODE
```

**Important:** Authorization code expires in 60 minutes.

#### Step 5: Token Exchange

```http
POST /oauth/token
Content-Type: application/x-www-form-urlencoded

client_id={your_client_id}
&client_secret={your_client_secret}
&code={authorization_code}
&redirect_uri={your_redirect_uri}
&grant_type=authorization_code
```

#### Step 6: Token Response

```json
{
  "access_token": "gAAAAMYien...",
  "token_type": "bearer",
  "expires_in": 600,
  "refresh_token": "i7ne!IAAA...",
  "scope": "athlete:profile workouts:read"
}
```

### Refreshing Expired Tokens

```http
POST /oauth/token
Content-Type: application/x-www-form-urlencoded

client_id={your_client_id}
&client_secret={your_client_secret}
&grant_type=refresh_token
&refresh_token={refresh_token}
```

### Available OAuth Scopes

| Scope | Description |
|-------|-------------|
| `athlete:profile` | Read athlete profile and zones |
| `coach:athletes` | Access coach's athlete list (excludes `athlete:profile`) |
| `workouts:read` | Read workout data |
| `workouts:plan` | Create/update/delete planned workouts |
| `workouts:details` | Access detailed workout data (premium only) |
| `workouts:wod` | Access Workout of the Day |
| `file:write` | Upload workout files |
| `events:read` | Read events from calendar |
| `events:write` | Create events on calendar |
| `metrics:read` | Read metrics data |
| `metrics:write` | Upload metrics data |
| `nutrition:read` | Read nutrition data (premium only) |
| `nutrition:write` | Create/update/delete nutrition data |
| `webhook:write-subscriptions` | Manage webhook subscriptions |

### Important Scope Rules

1. **Scopes are NOT inclusive** - `workouts:details` does NOT include `workouts:read`
2. **Coach vs Athlete Access** - Request `coach:athletes` OR `athlete:profile`, never both
3. **Cannot expand scopes** - Cannot request more scopes than originally authorized
4. **Premium requirements** - Some scopes only work with premium athletes

### Creating Test Users in Sandbox

**Athletes:**
```
https://home.sandbox.trainingpeaks.com/signup?partner={your_client_id}
```

**Coaches:**
```
https://home.sandbox.trainingpeaks.com/coach/signup?partner={your_client_id}
```

**Login:**
```
https://home.sandbox.trainingpeaks.com/login
```

### Deauthorization

```http
POST /oauth/deauthorize
Authorization: Bearer {access_token}
```

Revokes user's access token and refresh token.

---

## API Endpoints Reference

### Information & Status

#### Get API Version
```http
GET /v1/info/version
```

**OAuth Scope:** None required

**Response:**
```json
{
  "Version": "2.0.1234.0",
  "Build": "2.0.1234 1abcd2345 Release"
}
```

---

### Athletes

#### Get Athlete Profile
```http
GET /v1/athlete/profile
Authorization: Bearer {access_token}
```

**OAuth Scope:** `athlete:profile`

**Response:**
```json
{
  "Id": 123456,
  "FirstName": "John",
  "LastName": "Doe",
  "Email": "jdoe@gmail.com",
  "TimeZone": "America/Denver",
  "BirthMonth": "1980-10",
  "Sex": "m",
  "CoachedBy": 987654,
  "Weight": 87.5223617553711,
  "IsPremium": true,
  "PreferredUnits": "English"
}
```

**Field Notes:**
- `Weight`: Always in kilograms
- `Sex`: "m" or "f"
- `IsPremium`: Excludes trial subscriptions
- `TimeZone`: IANA timezone identifier
- `BirthMonth`: Format "YYYY-MM"
- `PreferredUnits`: "English" or metric

#### Get Athlete Zones (All)
```http
GET /v1/athlete/profile/zones
Authorization: Bearer {access_token}
```

**OAuth Scope:** `athlete:profile`

**Response Structure:**
```json
{
  "HeartRateZones": {
    "Default": {
      "Threshold": 164,
      "MaxHeartRate": 192,
      "RestingHeartRate": 48,
      "WorkoutType": "Default",
      "Zones": [
        {
          "Label": "1 - Recovery",
          "Minimum": 48,
          "Maximum": 114
        },
        // ... 7 zones total
      ]
    }
  },
  "SpeedZones": {
    "Default": { /* zones in m/s */ },
    "Swim": { /* swim-specific zones */ },
    "Run": { /* run-specific zones */ }
  },
  "PowerZones": {
    "Default": {
      "Threshold": 250,
      "Zones": [
        {
          "Label": "1",
          "Minimum": 0,
          "Maximum": 137
        },
        // ... 6 zones total
      ]
    }
  }
}
```

**Important:** Speed measurements are always in meters per second (m/s).

#### Get Athlete Zones by Type
```http
GET /v1/athlete/zones/{zoneType}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `athlete:profile`

**Zone Types:** HeartRate, Speed, Power

---

### Coaches

#### Get Coach Profile
```http
GET /v1/coach/profile
Authorization: Bearer {access_token}
```

**OAuth Scope:** `coach:athletes`

**Response:**
```json
{
  "CoachId": 123456,
  "FirstName": "John",
  "LastName": "Doe"
}
```

#### Get Coach's Athletes
```http
GET /v1/coach/athletes
Authorization: Bearer {access_token}
```

**OAuth Scope:** `coach:athletes`

**Response:**
```json
[
  {
    "Id": 123456,
    "FirstName": "Jane",
    "LastName": "Smith",
    "Email": "jane@example.com",
    "TimeZone": "America/Denver",
    "BirthMonth": "1985-03",
    "Sex": "f",
    "CoachedBy": 987654,
    "Weight": 62.5,
    "IsPremium": true,
    "PreferredUnits": "Metric"
  }
]
```

#### Get Coach's Assistants
```http
GET /v1/coach/assistants
Authorization: Bearer {access_token}
```

**OAuth Scope:** `coach:athletes`

#### Get Specific Assistant
```http
GET /v1/coach/assistants/{assistantId}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `coach:athletes`

#### Get Assistant's Athletes
```http
GET /v1/coach/assistants/{assistantId}/athletes
Authorization: Bearer {access_token}
```

**OAuth Scope:** `coach:athletes`

#### Get Athletes' Zones (All Athletes)
```http
GET /v1/coach/athletes/zones
Authorization: Bearer {access_token}
```

**OAuth Scope:** `coach:athletes`

#### Get Athletes' Zones by Type
```http
GET /v1/coach/athletes/zones/{zoneType}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `coach:athletes`

---

### Workouts

#### Get Workouts by Date Range
```http
GET /v2/workouts/{startDate}/{endDate}?includeDescription={bool}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `workouts:read`

**Parameters:**
- `startDate`: Local time (YYYY-MM-DD)
- `endDate`: Local time (YYYY-MM-DD)
- `includeDescription`: Optional boolean

**Constraints:**
- End date cannot exceed 365 days in future
- Date range cannot exceed 45 days

**Response:**
```json
[
  {
    "Distance": 100000,
    "Id": 139283664,
    "StartTime": "2014-04-15T12:57:59",
    "TotalTime": 1.25,
    "WorkoutType": "Bike"
  }
]
```

#### Get Athlete's Workouts by Date Range
```http
GET /v2/workouts/{athleteId}/{startDate}/{endDate}?includeDescription={bool}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `workouts:read`

#### Get Changed Workouts
```http
GET /v2/workouts/changed?date={date}&pageSize={int}&page={int}&workoutTypeFilter={type}&includeDescription={bool}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `workouts:read`

**Parameters:**
- `date`: UTC format, minimum 2000-01-01
- `pageSize`: Max 100
- `page`: Zero-based index
- `workoutTypeFilter`: Optional (swim, bike, run, etc.)
- `includeDescription`: Optional boolean

**Response:**
```json
{
  "Deleted": [123456789],
  "Modified": [
    {
      "LastModifiedDate": "2017-09-25T17:31:28.9428265Z",
      "Id": 234567890,
      "AthleteId": 12345,
      "WorkoutType": "Bike",
      "Title": null,
      "WorkoutDay": "2017-09-13T00:00:00"
    }
  ]
}
```

#### Get Athlete's Changed Workouts
```http
GET /v2/workouts/{athleteId}/changed?date={date}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `workouts:read`

#### Get Specific Workout
```http
GET /v2/workouts/id/{workoutId}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `workouts:read`

#### Get Athlete's Specific Workout
```http
GET /v2/workouts/{athleteId}/id/{workoutId}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `workouts:read`

#### Get Workout Details
```http
GET /v2/workouts/id/{workoutId}/details
Authorization: Bearer {access_token}
```

**OAuth Scope:** `workouts:details`

**Requirements:**
- Premium athlete status
- Completed workout
- Associated workout file

**Response Structure:**
```json
{
  "WorkoutChannels": {
    "Channels": [
      "Cadence", "Distance", "Elevation", "Latitude", "Longitude",
      "HeartRate", "Power", "Speed", "Temperature", "Grade",
      "VerticalOscillation", "StanceTime", "TorqueEffectiveness"
    ],
    "Data": [
      {
        "Event": "Start",
        "TimeOffset": 0,
        "Cadence": 85,
        "Distance": 0,
        "HeartRate": 120,
        "Power": 200
      }
    ]
  },
  "SwimStats": { /* swim-specific metrics */ },
  "WorkoutStats": { /* comprehensive performance summary */ },
  "LapStats": [ /* lap-by-lap breakdowns */ ]
}
```

#### Get Athlete's Workout Details
```http
GET /v2/workouts/{athleteId}/id/{workoutId}/details
Authorization: Bearer {access_token}
```

**OAuth Scope:** `workouts:details`

#### Get Mean Max Data
```http
GET /v2/workouts/id/{workoutId}/meanmaxes
Authorization: Bearer {access_token}
```

**OAuth Scope:** `workouts:details`
**Requirement:** Premium athlete only

#### Get Athlete's Mean Max Data
```http
GET /v2/workouts/{athleteId}/id/{workoutId}/meanmaxes
Authorization: Bearer {access_token}
```

**OAuth Scope:** `workouts:details`
**Requirement:** Premium athlete only

#### Get Time in Zones
```http
GET /v2/workouts/id/{workoutId}/timeinzones
Authorization: Bearer {access_token}
```

**OAuth Scope:** `workouts:details`
**Requirement:** Premium athlete only

#### Get Athlete's Time in Zones
```http
GET /v2/workouts/{athleteId}/id/{workoutId}/timeinzones
Authorization: Bearer {access_token}
```

**OAuth Scope:** `workouts:details`
**Requirement:** Premium athlete only

#### Create Planned Workout
```http
POST /v2/workouts/plan
Authorization: Bearer {access_token}
Content-Type: application/json
```

**OAuth Scope:** `workouts:plan` (plus `athlete:profile` if athlete is the user)

**Required Fields:**
```json
{
  "AthleteId": "123456",
  "WorkoutDay": "2025-12-01",
  "WorkoutType": "run"
}
```

**Optional Fields:**
```json
{
  "Title": "Morning Run",
  "Description": "Easy recovery run",
  "StartTimePlanned": "2025-12-01T06:00:00",
  "TotalTimePlanned": 1.0,
  "DistancePlanned": 10000,
  "TSSPlanned": 50,
  "IFPlanned": 0.75,
  "CaloriesPlanned": 600,
  "EnergyPlanned": 2500,
  "ElevationGainPlanned": 100,
  "Locked": false,
  "Hidden": false,
  "Structure": "{...}",
  "StructureDisplayUnit": "kilometer",
  "Tags": ["recovery", "easy"]
}
```

**WorkoutType Options:** swim, bike, run, x-train, mtb, strength, xc-ski, rowing, walk, other

**Constraints:**
- `WorkoutDay`: Cannot exceed 7 days past or 1 year future
- Time information in `WorkoutDay` is ignored
- `TotalTimePlanned`: Max 99:59:59 (in decimal hours)
- `DistancePlanned`: Max 99999999 meters
- `TSSPlanned`: Max 9999
- `IFPlanned`: Max 5
- Basic athletes cannot create future planned workouts (403 error)

**Important:** When valid non-RPE structure is uploaded, `TotalTimePlanned`, `TSSPlanned`, and `IFPlanned` values are ignored and computed from structure.

#### Update Planned Workout
```http
PUT /v2/workouts/plan/{workoutId}
Authorization: Bearer {access_token}
Content-Type: application/json
```

**OAuth Scope:** `workouts:plan`

**Important:** Any missing or null fields will be overwritten as null. Send complete workout object.

#### Delete Workout
```http
DELETE /v2/workouts/id/{workoutId}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `workouts:read` AND `workouts:plan`

**Response:** 200 OK with `true` if successful

**Limitation:** Can only delete future/incomplete workouts

#### Delete Athlete's Workout
```http
DELETE /v2/workouts/{athleteId}/id/{workoutId}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `workouts:read` AND `workouts:plan`

---

### Workout of the Day (WOD)

#### Get Workout of the Day
```http
GET /v2/workouts/wod/{date}?numberOfDays={int}&includeDescription={bool}&workoutTypeFilter={type}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `workouts:wod`

**Parameters:**
- `date`: Today's date in local time (required)
- `numberOfDays`: Get consecutive days (>1 and ≤7)
- `includeDescription`: Include workout descriptions
- `workoutTypeFilter`: Filter by type

**Response:**
```json
[
  {
    "DistancePlanned": 100000,
    "Id": 139283664,
    "IFPlanned": null,
    "StartTimePlanned": "2014-04-15T12:57:59",
    "TotalTimePlanned": 1,
    "TssPlanned": 80,
    "WorkoutFileFormats": ["erg", "fit", "mrc", "zwo", "json"],
    "WorkoutType": "Bike"
  }
]
```

#### Get WOD File
```http
GET /v2/workouts/wod/file/{workoutId}/?format={fileFormat}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `workouts:wod`

**Format Options:** erg, fit, mrc, zwo, json

---

### File Upload

#### Upload Workout File (Asynchronous)
```http
POST /v3/file
Authorization: Bearer {access_token}
Content-Type: application/json
```

**OAuth Scope:** `file:write`

**Note:** Synchronous uploads deprecated June 2023. Only asynchronous uploads supported.

**Request Body:**
```json
{
  "UploadClient": "MyApp v1.0",
  "Filename": "2025-11-26-15-07-22.fit",
  "Data": "base64_encoded_file_contents",
  "WorkoutDay": "2025-11-26",
  "StartTime": "2025-11-26T15:07:22",
  "SetWorkoutPublic": false,
  "Title": "Afternoon Ride",
  "Comment": "Great workout!",
  "Type": "bike",
  "WorkoutId": 123456789
}
```

**Required Fields:**
- `UploadClient`: String identifying your application
- `Filename`: Original filename with extension (no reserved characters: `/ \ ? % * : | " < > . [space]`)
- `Data`: Base64 encoded file contents (GZipped files supported)

**Optional Fields:**
- `WorkoutDay`: Override file's date (ISO 8601)
- `StartTime`: Override file's start time (ISO 8601)
- `SetWorkoutPublic`: Boolean
- `Title`: Custom workout title
- `Comment`: Post-activity notes
- `Type`: Sport classification (swim, bike, run, x-train, mtb, strength, xc-ski, rowing, walk, other)
- `WorkoutId`: Associates upload with planned workout

**Supported File Types:** FIT, TCX, PWX

**Response:** 202 Accepted
```http
HTTP/1.1 202 Accepted
Location: /v3/status/{fileTrackingId}
```

#### Check Upload Status
```http
GET /v3/status/{fileTrackingId}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `file:write`

**Response:**
```json
{
  "Completed": true,
  "Status": "Success",
  "WorkoutIds": [123456789, 123456790]
}
```

**Polling Flow:**
1. Submit file via POST to `/v3/file`
2. Receive 202 with tracking ID in Location header
3. Poll `/v3/status/{fileTrackingId}` to monitor progress
4. When `Completed` is true, check `Status` for success/failure
5. Retrieve created Workout IDs from response

**Error Response Codes:**
- 415 Unsupported Media Type: File format not supported
- 422 Unprocessable Entity: File already uploaded

---

### Workout Comments

#### Add Workout Comment
```http
POST /v2/workouts/{athleteId}/id/{workoutId}/comment
Authorization: Bearer {access_token}
Content-Type: application/json
```

**OAuth Scope:** `workouts:details`

**Request:**
```json
{
  "Value": "Great workout today!"
}
```

**Response:** 204 No Content

---

### Events

#### Get Events by Date
```http
GET /v2/events/{date}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `events:read`

**Response:**
```json
[
  {
    "Id": 123456,
    "AthleteId": 54321,
    "EventDate": "2020-06-12T00:00:00",
    "EventType": "Triathalon",
    "Name": "Ironman Kona",
    "Description": "World Championship",
    "WorkoutIds": [789, 790, 791],
    "Goals": [
      {
        "GoalType": "Distance",
        "Value": 140.1,
        "Unit": "Miles"
      },
      {
        "GoalType": "Time",
        "Value": 7.85,
        "Unit": "Hours"
      },
      {
        "GoalType": "Place",
        "Value": 10,
        "Unit": null
      },
      {
        "GoalType": "Pr",
        "Value": 1,
        "Unit": null
      }
    ]
  }
]
```

**Goal Types:** Distance, Time, Place, Pr
**Goal Units:** Miles, Hours, or null

#### Get Next Event
```http
GET /v2/events/next
Authorization: Bearer {access_token}
```

**OAuth Scope:** `events:read`

**Response:** Single event object (same structure as above)

#### Create Event
```http
POST /v2/events
Authorization: Bearer {access_token}
Content-Type: application/json
```

**OAuth Scope:** `events:write`

**Request:**
```json
{
  "AthleteId": "54321",
  "EventDate": "2020-06-12",
  "EventType": "RoadCycling",
  "Name": "Twilight Criterium",
  "Description": "Description of the event"
}
```

**Required Fields:**
- `AthleteId`: Integer
- `EventDate`: DateTime
- `EventType`: String
- `Name`: String

**Optional Fields:**
- `Description`: String

**Valid EventType Values:**
- **Running:** RoadRunning, TrailRunning, TrackRunning, CrossCountry, Running
- **Cycling:** RoadCycling, MountainBiking, Cyclocross, TrackCycling, Cycling
- **Swimming:** OpenWaterSwimming, PoolSwimming
- **Multisport:** Triathlon, Xterra, Duathlon, Aquabike, Aquathon, Multisport
- **Other:** Regatta, Rowing, AlpineSkiing, NordicSkiing, SkiMountaineering, Snowshoe, Snow, Adventure, Obstacle, SpeedSkate, Other

---

### Metrics

#### Get Metric by ID (v2)
```http
GET /v2/metrics/{metricId}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `metrics:read`

**Response:**
```json
{
  "MetricId": "uuid-string",
  "AthleteId": 123456789,
  "DateTime": "2016-02-18T22:56:00",
  "UploadClient": "testapplication",
  "WeightInKilograms": 68.1,
  "HRV": 84.1,
  "Steps": 12345,
  "Stress": "Low",
  "SleepQuality": "Good"
}
```

**Note:** Not every field returned for every metric. New fields may be added.

#### Get Metrics by Date Range
```http
GET /v2/metrics/{startDate}/{endDate}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `metrics:read`
**Requirement:** Premium athlete only (403 for basic)

#### Get Athlete's Metrics by Date Range
```http
GET /v2/metrics/{athleteId}/{startDate}/{endDate}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `metrics:read`
**Requirement:** Premium athlete only (403 for basic)

#### Create Metric (v2)
```http
POST /v2/metrics
Authorization: Bearer {access_token}
Content-Type: application/json
```

**OAuth Scope:** `metrics:write`

**Request:**
```json
{
  "DateTime": "2020-06-01T06:12:34",
  "UploadClient": "MyApp v1.0",
  "HRV": 84.1,
  "WeightInKilograms": 68.1,
  "Steps": 12345,
  "Stress": "Low",
  "SleepQuality": "Good"
}
```

**Required Fields:**
- `DateTime`: Local datetime, truncated to minute (cannot exceed 1 day future or 1 year past)
- `UploadClient`: Your application name
- **One or more metrics** from available fields

**Available Metrics:**
- `WeightInKilograms`: Decimal
- `HRV`: Decimal (heart rate variability)
- `Steps`: Integer
- `Stress`: String (e.g., "Low", "Medium", "High")
- `SleepQuality`: String (e.g., "Good", "Fair", "Poor")

**Response:** 201 Created
```http
Location: /v2/metrics/{metricId}
```

---

### Nutrition

#### Get Nutrition Entries
```http
GET /v1/athletes/{athleteId}/nutrition?startDate={date}&endDate={date}&pageSize={int}&page={int}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `nutrition:read`
**Requirement:** Premium athlete only (excludes trials)

**Query Parameters:**
- `startDate`: Beginning of date range (cannot be >10 years past)
- `endDate`: End of date range
- `pageSize`: Max 100
- `page`: Zero-based index

**Response:**
```json
[
  {
    "NutritionId": 111,
    "AthleteId": 123456,
    "NutritionDate": "2025-10-01T00:00:00",
    "Calories": 2200.0,
    "Carbohydrates": 105.15,
    "Fat": 22.5,
    "Protein": 75.0
  }
]
```

#### Create Nutrition Entry
```http
POST /v1/athletes/{athleteId}/nutrition
Authorization: Bearer {access_token}
Content-Type: application/json
```

**OAuth Scope:** `nutrition:write`

**Request:**
```json
{
  "NutritionDate": "2025-10-01T00:00:00",
  "Calories": 2200.0,
  "Carbohydrates": 105.15,
  "Fat": 22.5,
  "Protein": 75.0
}
```

**Required:** `NutritionDate`
**Optional:** `Calories`, `Carbohydrates`, `Fat`, `Protein` (all in grams)

**Response:** 201 Created (same structure with `NutritionId`)

#### Update Nutrition Entry
```http
PUT /v1/athletes/{athleteId}/nutrition/{nutritionId}
Authorization: Bearer {access_token}
Content-Type: application/json
```

**OAuth Scope:** `nutrition:write`

**Request:** Same as POST

**Important Constraint:** Nutrition date must match existing nutrition date or be on a new date where there is no other nutrition card.

**Response:** 200 OK (updated nutrition object)

#### Delete Nutrition Entry
```http
DELETE /v1/athletes/{athleteId}/nutrition/{nutritionId}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `nutrition:write`

**Response:** 202 Accepted

---

## Data Models

### Workout Structure Object

The Workout Structure defines detailed JSON format for organizing training sessions into segments with specific intensity and duration targets.

#### Structure Format

The structure is sent as a JSON string containing an array of workout segments. Each segment can be either a **Step** (individual exercise) or **Repetition** (repeated sequence of steps).

#### Common Fields (All Segments)

```json
{
  "Type": "Step",
  "Length": {
    "Unit": "Second",
    "Value": 600
  },
  "IntensityClass": "Active",
  "Name": "Warm Up",
  "IntensityTarget": {
    "Unit": "PercentOfFtp",
    "Value": 0.60
  }
}
```

**Fields:**
- `Type`: "Step" or "Repetition"
- `Length`: Contains `Unit` (Meter/Second) and integer `Value`
- `IntensityClass`: WarmUp, Active, Rest, CoolDown
- `Name`: Optional segment identifier
- `IntensityTarget`: Intensity specifications with Unit and Value

#### Optional Fields

- `MinValue`/`MaxValue`: Boundary intensities (Value should be midpoint)
- `CadenceTarget`: Only accepts "rpm" unit with Min/Max values
- `OpenDuration`: Boolean flag allowing flexible duration while maintaining minimum Length

#### Intensity Units

Valid `IntensityTarget` units:
- `PercentOfFtp`
- `PercentOfMaxHr`
- `PercentOfThresholdHr`
- `PercentOfThresholdSpeed`
- `Rpe` (integer values, no unit required)

#### Example Structure

```json
{
  "Structure": "[
    {
      \"Type\": \"Step\",
      \"Length\": { \"Unit\": \"Second\", \"Value\": 600 },
      \"IntensityClass\": \"WarmUp\",
      \"Name\": \"Warm Up\",
      \"IntensityTarget\": { \"Unit\": \"PercentOfFtp\", \"Value\": 0.60 }
    },
    {
      \"Type\": \"Repetition\",
      \"RepeatCount\": 4,
      \"Steps\": [
        {
          \"Type\": \"Step\",
          \"Length\": { \"Unit\": \"Second\", \"Value\": 300 },
          \"IntensityClass\": \"Active\",
          \"IntensityTarget\": {
            \"Unit\": \"PercentOfFtp\",
            \"Value\": 0.95,
            \"MinValue\": 0.90,
            \"MaxValue\": 1.00
          },
          \"CadenceTarget\": { \"MinValue\": 90, \"MaxValue\": 100 }
        },
        {
          \"Type\": \"Step\",
          \"Length\": { \"Unit\": \"Second\", \"Value\": 120 },
          \"IntensityClass\": \"Rest\",
          \"IntensityTarget\": { \"Unit\": \"PercentOfFtp\", \"Value\": 0.50 }
        }
      ]
    },
    {
      \"Type\": \"Step\",
      \"Length\": { \"Unit\": \"Second\", \"Value\": 600 },
      \"IntensityClass\": \"CoolDown\",
      \"IntensityTarget\": { \"Unit\": \"PercentOfFtp\", \"Value\": 0.50 }
    }
  ]"
}
```

#### Important Notes

- When you POST or PUT a workout with a `structure` value, computed values override original distance, duration, and TSS fields
- Percentages are decimals (0.60 = 60%)
- Length values are integers
- Repetition segments nest Steps arrays for recurring patterns
- For distance-structured workouts, missing speed thresholds in athlete's profile results in empty calculated fields

---

## Webhooks (Early Access)

### Overview

Webhooks allow you to receive real-time notifications when events occur in TrainingPeaks, such as workout creation, updates, or deletions.

### Webhook Endpoints

#### Create Subscription
```http
POST /v1/webhook/subscriptions
Authorization: Bearer {access_token}
Content-Type: application/json
```

**OAuth Scope:** `webhook:write-subscriptions`

**Request:**
```json
{
  "AthleteId": 54321,
  "EventType": "workout-created",
  "WebhookUrl": "https://api.mycompany.com/callback"
}
```

**Required Fields:**
- `AthleteId`: Integer
- `EventType`: String
- `WebhookUrl`: String (your endpoint that will receive POST requests)

**Response:**
```json
{
  "Id": "0d76e887-8e8a-46f4-bb2b-2f66e4fc40ee",
  "AthleteId": 54321,
  "EventType": "workout-created",
  "WebhookUrl": "https://api.mycompany.com/callback",
  "Active": true,
  "CreatedBy": 54321,
  "CreatedOn": "2025-07-24T21:03:05.1324848Z"
}
```

#### Get Subscriptions
```http
GET /v1/webhook/subscriptions
Authorization: Bearer {access_token}
```

**OAuth Scope:** `webhook:write-subscriptions`

**Response:** Array of subscription objects

#### Update Subscription
```http
PUT /v1/webhook/subscriptions/{subscriptionId}
Authorization: Bearer {access_token}
Content-Type: application/json
```

**OAuth Scope:** `webhook:write-subscriptions`

**Request:**
```json
{
  "EventType": "workout-updated",
  "WebhookUrl": "https://api.mycompany.com/callback2",
  "Active": true
}
```

**Fields:**
- `EventType`: String
- `WebhookUrl`: String
- `Active`: Boolean (enable/disable webhook)

#### Delete Subscription
```http
DELETE /v1/webhook/subscriptions/{subscriptionId}
Authorization: Bearer {access_token}
```

**OAuth Scope:** `webhook:write-subscriptions`

**Response:** 200 OK

### Supported Event Types

- `workout-created`
- `workout-updated`
- `workout-deleted`

### Webhook Payload

When an event occurs, TrainingPeaks will POST to your `WebhookUrl` with event details. The exact payload format is not documented in the publicly available wiki.

---

## Rate Limiting & Best Practices

### Rate Limits

According to the FAQ, TrainingPeaks does **not have a hard rate limit cap**. The guideline is to minimize disruptive impact. Small user bases with normal usage patterns are expected to operate without restrictions.

**Recommendation:** Implement reasonable request throttling and caching to avoid excessive API calls.

### Best Practices

Based on general API best practices research:

1. **Handle 429 Errors Properly**
   - Return clear error messages with HTTP 429 status
   - Include `Retry-After` header
   - Provide user guidance on avoiding rate limits

2. **Implement Intelligent Retry Mechanisms**
   - Use exponential backoff with jitter
   - Respect `Retry-After` headers
   - Don't retry 400-level errors (except 429)

3. **Optimize API Calls**
   - Remove unnecessary/redundant calls
   - Request only essential fields
   - Implement caching for data that doesn't change often
   - Batch operations when possible

4. **Use Granular Control**
   - Categorize endpoints by rate limit sensitivity
   - Prioritize critical requests
   - Queue non-urgent requests

5. **Request Timeouts**
   - Set reasonable timeout values
   - Handle timeout errors gracefully

6. **Monitoring & Logging**
   - Track API usage patterns
   - Monitor error rates
   - Log rate limit responses

### Caching Recommendations

Cache the following data to reduce API calls:

- **Athlete profiles**: Cache for 24 hours
- **Training zones**: Cache for 1 week
- **Workout plans**: Cache until modified
- **Content that rarely changes**: Cache longer

### Pagination Best Practices

For endpoints with pagination:
- Use reasonable `pageSize` values (max 100)
- Track `page` index properly
- Handle empty result sets
- Don't request more data than needed

---

## Error Handling

### HTTP Status Codes

#### Success Codes

| Code | Status | Meaning |
|------|--------|---------|
| 200 | OK | Success |
| 201 | Created | Successfully created |
| 202 | Accepted | Accepted for processing |

#### Redirect Codes

| Code | Status | Meaning |
|------|--------|---------|
| 302 | Object moved | Request made over insecure HTTP connection |

#### Client Error Codes

| Code | Status | Meaning |
|------|--------|---------|
| 400 | Bad Request | One or more required fields missing or incorrect |
| 401 | Unauthorized | Bad, expired, or missing authorization header |
| 403 | Forbidden | Request understood but refused (e.g., accessing disconnected athlete data or premium content for basic accounts) |
| 405 | Method Not Allowed | HTTP method not supported for this endpoint |
| 415 | Unsupported Media Type | Uploaded file format not supported (FIT, TCX, PWX only) |
| 422 | Unprocessable Entity | File already uploaded to athlete's account |

#### Server Error Codes

| Code | Status | Meaning |
|------|--------|---------|
| 500 | Server Error | Processing failure (errors are logged and monitored) |
| 501 | Not Implemented | Functionality not implemented |
| 503 | Service Unavailable | Server overloaded or down for maintenance (temporary, retry later) |

### Error Response Format

For 400 Bad Request errors, the response includes error details:

```json
{
  "error": "invalid_request",
  "error_description": "Field 'WorkoutDay' is required"
}
```

### Error Handling Best Practices

1. **Check HTTP status codes first**
2. **Parse error response body** for 400-level errors
3. **Retry on 5xx errors** with exponential backoff
4. **Don't retry on 4xx errors** (except 429)
5. **Log all errors** for debugging
6. **Provide user-friendly messages** based on error type
7. **Handle token expiration** (401) by refreshing token
8. **Handle 403 gracefully** - may indicate basic vs premium restrictions

---

## Premium vs Basic Athletes

### Feature Restrictions

Basic athletes have restricted access to certain API endpoints and data fields.

### Restricted Endpoints (403 Error)

Basic athletes **cannot** access:
- `/v1/metrics/{startDate}/{endDate}`
- `/v1/metrics/{athleteId}/{startDate}/{endDate}`
- `/v1/athletes/{athleteId}/nutrition` (with date range parameters)
- `/v2/workouts/{athleteId}/id/{workoutId}/meanmaxes`
- `/v2/workouts/{athleteId}/id/{workoutId}/timeinzones`
- `/v2/workouts/{athleteId}/id/{workoutId}/details`
- `/v2/workouts/{athleteId}/id/{workoutId}/comment`
- `/v2/workouts/plan` (basic athletes can only create workouts for today or past dates)

### Restricted Data Fields

For basic athletes, these fields **return null** in workout endpoints and are **ignored** when submitting data:

**Performance Metrics:**
- Calories
- VelocityAverage, VelocityMaximum
- NormalizedSpeed, NormalizedPower
- PowerAverage, PowerMaximum
- Energy
- TorqueAverage, TorqueMaximum
- TssActual, TssPlanned
- IF

**Health Data:**
- HeartRateMinimum, HeartRateMaximum, HeartRateAverage
- TempMin, TempAvg, TempMax

**Training Stats:**
- ElevationGain, ElevationGainPlanned
- ElevationLoss, ElevationMinimum, ElevationAverage, ElevationMaximum
- CadenceAverage, CadenceMaximum
- Rpe, Feeling
- Tags

### Detecting Premium Status

Use the `IsPremium` field in athlete profile:

```json
{
  "Id": 123456,
  "IsPremium": true
}
```

**Note:** `IsPremium` excludes athletes with trial premium subscriptions.

### Development Best Practices

1. **Check `IsPremium` before calling premium endpoints**
2. **Handle 403 errors gracefully** with user-friendly messages
3. **Provide degraded functionality** for basic athletes
4. **Don't send premium fields** for basic athletes (they'll be ignored)
5. **Test with both premium and basic test accounts**

---

## Development & Testing

### Sandbox Environment

**Base URL:** `https://api.sandbox.trainingpeaks.com`

**Characteristics:**
- Refreshes weekly from production (Saturday 6:00 PM MST)
- Test data is overwritten during refresh
- Safe for testing without affecting production data
- May require re-testing after weekend refresh

### Creating Test Accounts

**Athlete Signup:**
```
https://home.sandbox.trainingpeaks.com/signup?partner={your_client_id}
```

**Coach Signup:**
```
https://home.sandbox.trainingpeaks.com/coach/signup?partner={your_client_id}
```

**Login:**
```
https://home.sandbox.trainingpeaks.com/login
```

### Testing OAuth Flow

1. Use sandbox OAuth endpoints
2. Create test athletes and coaches
3. Test both athlete and coach authorization flows
4. Test scope combinations
5. Test token refresh flow
6. Test deauthorization

### Pre-Production Validation

Before receiving production credentials, TrainingPeaks validates integrations:

#### General Validation Checklist

- ✅ Verify access permissions and user scopes
- ✅ Identify unnecessary scopes requested
- ✅ Confirm proper User-Agent header implementation
- ✅ Test successful API request functionality

#### Scope-Specific Requirements

**events:write**
- Test all anticipated event types
- Confirm events display correctly in TrainingPeaks UI

**file:write**
- Validate successful file uploads
- Verify UploadClient configuration accuracy
- Confirm file processing completion
- Check workout display in platform UI

**metrics:read/write**
- Test across all user categories: coaches, premium athletes, basic athletes, trial athletes
- For writes: verify UploadClient settings and all metric types
- Ensure metrics render in TrainingPeaks UI

**workouts:plan**
- Prevent basic athletes from creating/updating future planned workouts

**workouts:read**
- Test functionality across all user types

**workouts:details**
- Restrict basic athlete access to detail endpoints

#### Documentation Requirements

Partners must provide:
- Diagrams showing user interaction flows
- Documentation describing how users interact with the integrated application
- Follow TrainingPeaks branding guidelines (media kit)

### Maintenance & Outages

#### Scheduled Maintenance

- **Sandbox:** Every Saturday 6:00 PM MST
- **Duration:** Several hours
- **Impact:** Database refresh from production

#### Current Status

- No upcoming API changes planned
- No upcoming maintenance downtime scheduled

#### Recent API Changes (Completed)

1. **Workout ID Migration** (May 2023)
   - Changed from Int32 to Int64 format
   - Old v1 endpoints deprecated
   - New workouts began exceeding 32-bit after 2022-11-15

2. **File Upload Transition** (June 2023)
   - Shifted from synchronous to asynchronous processing
   - Legacy v2 endpoints removed

3. **Metrics Endpoint Updates** (June 2023)
   - Removed v1 endpoints
   - DateTime now treated as user-local time (no UTC conversion)
   - Metrics data no longer synced to sandbox

#### Monitoring Recommendations

- Plan integrations around Saturday sandbox refreshes
- Monitor API status page for unexpected changes
- Subscribe to API updates/notifications

---

## Integration for Mealvana

### Use Case: Event-Based Nutrition Planning

Mealvana can integrate with TrainingPeaks to:

1. **Retrieve Upcoming Events**
   - Fetch athlete's next race/event
   - Get event details (type, date, distance)
   - Identify associated workouts

2. **Access Training Data**
   - Pull historical workout data
   - Analyze training patterns
   - Understand athlete's fitness level

3. **Synchronize Nutrition Plans**
   - Push nutrition data back to TrainingPeaks
   - Track daily macros (carbs, protein, fat)
   - Monitor weight and other metrics

### Recommended Integration Flow

#### 1. OAuth Authentication

```typescript
// Step 1: Redirect to TrainingPeaks authorization
const authUrl = `https://oauth.trainingpeaks.com/OAuth/Authorize?` +
  `response_type=code&` +
  `client_id=${CLIENT_ID}&` +
  `scope=athlete:profile events:read nutrition:write&` +
  `redirect_uri=${encodeURIComponent(REDIRECT_URI)}`;

// Step 2: Handle callback and exchange code for token
const tokenResponse = await fetch('https://oauth.trainingpeaks.com/oauth/token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    code: authorizationCode,
    redirect_uri: REDIRECT_URI,
    grant_type: 'authorization_code'
  })
});

const { access_token, refresh_token, expires_in } = await tokenResponse.json();
```

#### 2. Get Athlete Profile

```typescript
const profileResponse = await fetch('https://api.trainingpeaks.com/v1/athlete/profile', {
  headers: {
    'Authorization': `Bearer ${access_token}`,
    'User-Agent': 'Mealvana Endurance v1.0'
  }
});

const profile = await profileResponse.json();
// { Id, FirstName, LastName, Weight, IsPremium, PreferredUnits, ... }
```

#### 3. Get Next Event

```typescript
const eventResponse = await fetch('https://api.trainingpeaks.com/v2/events/next', {
  headers: {
    'Authorization': `Bearer ${access_token}`,
    'User-Agent': 'Mealvana Endurance v1.0'
  }
});

const nextEvent = await eventResponse.json();
// { Id, EventDate, EventType, Name, Goals: [...] }
```

#### 4. Push Nutrition Data

```typescript
const nutritionData = {
  NutritionDate: "2025-11-26T00:00:00",
  Calories: 2500.0,
  Carbohydrates: 320.0,
  Fat: 70.0,
  Protein: 120.0
};

const nutritionResponse = await fetch(
  `https://api.trainingpeaks.com/v1/athletes/${profile.Id}/nutrition`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${access_token}`,
      'Content-Type': 'application/json',
      'User-Agent': 'Mealvana Endurance v1.0'
    },
    body: JSON.stringify(nutritionData)
  }
);
```

#### 5. Get Recent Workouts

```typescript
const today = new Date();
const startDate = new Date(today);
startDate.setDate(startDate.getDate() - 30); // Last 30 days

const workoutsResponse = await fetch(
  `https://api.trainingpeaks.com/v2/workouts/` +
  `${formatDate(startDate)}/${formatDate(today)}`,
  {
    headers: {
      'Authorization': `Bearer ${access_token}`,
      'User-Agent': 'Mealvana Endurance v1.0'
    }
  }
);

const workouts = await workoutsResponse.json();
```

### Required OAuth Scopes

For Mealvana integration:
- `athlete:profile` - Get athlete details, weight, preferences
- `events:read` - Fetch upcoming races/events
- `events:write` - (Optional) Create nutrition-related events
- `nutrition:write` - Push daily nutrition data
- `workouts:read` - (Optional) Analyze training patterns
- `metrics:write` - (Optional) Push weight/HRV data

### Data Mapping

#### TrainingPeaks → Mealvana

| TrainingPeaks | Mealvana Equivalent |
|---------------|---------------------|
| Event | Race/Event |
| EventType | Activity Type |
| EventDate | Race Date |
| Goals[Distance] | Event Distance |
| Weight (kg) | User Weight |
| IsPremium | Feature Access Level |

#### Mealvana → TrainingPeaks

| Mealvana | TrainingPeaks Endpoint |
|----------|------------------------|
| Daily Macros | Nutrition Entry |
| Weight Tracking | Metrics (WeightInKilograms) |
| Race Nutrition Plan | Nutrition Entries (pre-race days) |

### Webhook Integration (Future)

When TrainingPeaks webhooks become fully available:

1. **Subscribe to Events**
   ```typescript
   POST /v1/webhook/subscriptions
   {
     "AthleteId": 123456,
     "EventType": "workout-created",
     "WebhookUrl": "https://api.mealvana.com/webhooks/trainingpeaks"
   }
   ```

2. **Handle Webhook Callbacks**
   - Receive real-time workout updates
   - Trigger nutrition plan adjustments
   - Notify users of changes

### Error Handling Specific to Mealvana

```typescript
async function fetchTrainingPeaksData(endpoint: string, accessToken: string) {
  try {
    const response = await fetch(endpoint, {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'User-Agent': 'Mealvana Endurance v1.0'
      }
    });

    if (response.status === 401) {
      // Token expired, refresh it
      const newToken = await refreshAccessToken();
      return fetchTrainingPeaksData(endpoint, newToken);
    }

    if (response.status === 403) {
      // Basic athlete accessing premium feature
      // Show upgrade prompt or provide degraded experience
      return handleBasicAthleteRestriction();
    }

    if (response.status === 429) {
      // Rate limited
      const retryAfter = response.headers.get('Retry-After');
      await delay(retryAfter ? parseInt(retryAfter) * 1000 : 60000);
      return fetchTrainingPeaksData(endpoint, accessToken);
    }

    if (!response.ok) {
      throw new Error(`TrainingPeaks API error: ${response.status}`);
    }

    return await response.json();
  } catch (error) {
    // Log error and provide fallback
    console.error('TrainingPeaks API error:', error);
    throw error;
  }
}
```

### Storage & Caching Strategy

```typescript
// Cache athlete profile for 24 hours
const PROFILE_CACHE_TTL = 24 * 60 * 60 * 1000;

// Cache events for 1 hour
const EVENTS_CACHE_TTL = 60 * 60 * 1000;

// Store tokens securely
interface StoredTokens {
  access_token: string;
  refresh_token: string;
  expires_at: number;
  athlete_id: number;
}

// Drift database schema
class TrainingPeaksTokens extends Table {
  IntColumn get athleteId => integer()();
  TextColumn get accessToken => text()();
  TextColumn get refreshToken => text()();
  IntColumn get expiresAt => integer()();
  DateTimeColumn get updatedAt => dateTime()();
}
```

### Implementation Checklist

- [ ] Register for TrainingPeaks API access
- [ ] Set up OAuth 2.0 flow in Flutter app
- [ ] Implement token storage (secure, encrypted)
- [ ] Implement token refresh mechanism
- [ ] Create Drift tables for cached data
- [ ] Build UI for TrainingPeaks connection
- [ ] Implement event fetching
- [ ] Implement nutrition data push
- [ ] Add error handling for all API calls
- [ ] Test with both premium and basic athletes
- [ ] Test in sandbox environment
- [ ] Handle edge cases (disconnected athletes, expired tokens)
- [ ] Implement proper User-Agent header
- [ ] Complete pre-production validation
- [ ] Request production credentials
- [ ] Monitor API usage and errors
- [ ] Document integration for users

### Future Enhancements

1. **Two-Way Sync**
   - Pull TrainingPeaks nutrition data into Mealvana
   - Merge with Mealvana's AI-generated plans
   - Detect and resolve conflicts

2. **Workout Analysis**
   - Analyze training patterns
   - Adjust nutrition recommendations based on training load
   - Predict race-day needs based on similar workouts

3. **Coach Integration**
   - If user is coached, respect coach's nutrition guidelines
   - Provide coach visibility into nutrition adherence
   - Allow coach to override AI recommendations

4. **Webhook Implementation**
   - Real-time updates when workouts change
   - Auto-adjust nutrition plans
   - Notify users of relevant changes

---

## API Versioning & Migration

### Workout ID Migration (Completed May 2023)

TrainingPeaks migrated workout identifiers from 32-bit to 64-bit integers.

**Timeline:**
- Existing workout IDs remained 32-bit
- New workout IDs began exceeding 32-bit after November 15, 2022
- All v1 workout endpoints deprecated and removed

**Affected Identifiers:**
- Workout.Id
- WorkoutMeanMaxes.WorkoutId
- WorkoutDetailsData.WorkoutId
- WorkoutTimeInZones.WorkoutId
- TimeInTrainingZones.Id
- AthleteEvent.WorkoutIds
- FileStatus.WorkoutIds

**Migration Path:**
- All endpoints changed from `/v1/` to `/v2/`
- Parameters changed from `{workoutId:int}` to `{workoutId:long}`
- No backward compatibility for v1 endpoints

**Example:**
```
OLD: /v1/workouts/id/{workoutId:int}
NEW: /v2/workouts/id/{workoutId:long}
```

### File Upload Migration (Completed June 2023)

Synchronous file uploads deprecated in favor of asynchronous processing.

**Changes:**
- `/v2/file` (synchronous) removed
- `/v3/file` (asynchronous) is now required
- Must poll `/v3/status/{fileTrackingId}` for completion

---

## WorkoutDay and StartTime Overrides

### Overview

Partners can manage workout date/time in three ways during file uploads:
1. Include values in the file
2. Use local date/time overrides
3. Specify timezone-aware overrides

### DateTime Format Requirements

Dates and times must follow ISO 8601 standards:

**WorkoutDay examples:**
- `"2020-01-31"`
- `"2020-01-31T00:00:00"`
- `"2020-01-31T00:00:00-06:00"`

**StartTime examples:**
- `"2020-01-31T13:59:59"`
- `"2020-01-31T13:59:59-06:00"`

### Local Date/Time Override (No Timezone)

When timezone information is omitted, the information passed in `WorkoutDay` and `StartTime` will be what is displayed in TrainingPeaks UI.

**Example:**
- Athlete timezone: America/Denver (GMT-06)
- Upload values: `"2020-01-31"` and `"2020-01-31T13:14:15"`
- Display: Exactly those values

### Timezone-Aware Override

The system performs conversion logic:
1. Compares provided timezone against athlete's TrainingPeaks timezone
2. Converts time to athlete's local timezone for storage
3. Displays converted local date/time in UI

**Example 1 (UTC+08:00 to GMT-06:00):**
- Input: `"2020-01-31T13:14:15+08:00"`
- Athlete timezone: America/Denver (GMT-06)
- Display: `"2020-01-31" at "23:14:15 (11:14:15 PM)"`

**Example 2 (Matching timezone):**
- Input: `"2020-01-31T13:14:15-06:00"`
- Athlete timezone: America/Denver (GMT-06)
- Display: `"2020-01-31" at "13:14:15 (01:14:15 PM)"`

### FIT File Virtual Activity Flag

For .fit files marked as virtual activities, set the sub sport to `"VirtualActivity"` to exclude GPS data from date/time calculations.

---

## Additional Resources

### Official Links

- **API Access Request:** https://api.trainingpeaks.com/request-access
- **Support Portal:** https://sportsbrands.atlassian.net/servicedesk/customer/portal/2
- **GitHub Wiki:** https://github.com/TrainingPeaks/PartnersAPI/wiki
- **GitHub Repo:** https://github.com/TrainingPeaks/PartnersAPI
- **OAuth Example (Python):** https://github.com/TrainingPeaks/tp-public-api-auth

### Third-Party Integrations

- **Terra API TrainingPeaks Integration:** https://tryterra.co/integrations/trainingpeaks
- **Django AllAuth Provider:** https://docs.allauth.org/en/dev/socialaccount/providers/trainingpeaks.html

### Help Center

- **TrainingPeaks API Help:** https://help.trainingpeaks.com/hc/en-us/articles/234441128-TrainingPeaks-API
- **Data Export:** https://help.trainingpeaks.com/hc/en-us/articles/204985370-Data-Export
- **Structured Workout Sync:** https://help.trainingpeaks.com/hc/en-us/articles/115000325647-Structured-Workout-sync-and-Manual-Export

---

## Research Sources

- [TrainingPeaks PartnersAPI GitHub Wiki](https://github.com/TrainingPeaks/PartnersAPI/wiki)
- [TrainingPeaks - django-allauth](https://docs.allauth.org/en/dev/socialaccount/providers/trainingpeaks.html)
- [An Update on TrainingPeaks Partner API](https://www.trainingpeaks.com/blog/an-update-on-trainingpeaks-partner-api/)
- [GitHub - TrainingPeaks/tp-public-api-auth](https://github.com/TrainingPeaks/tp-public-api-auth)
- [TrainingPeaks API – TrainingPeaks Help Center](https://help.trainingpeaks.com/hc/en-us/articles/234441128-TrainingPeaks-API)
- [TrainingPeaks API Integration - Terra API](https://tryterra.co/integrations/trainingpeaks)
- [TrainingPeaks API | SportsFirst](https://www.sportsfirst.net/sportsapi/trainingpeaks-api)

---

**Document Version:** 1.0
**Last Updated:** November 26, 2025
**Maintained For:** Mealvana Endurance Project
