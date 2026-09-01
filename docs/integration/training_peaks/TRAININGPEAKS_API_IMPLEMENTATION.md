# TrainingPeaks API Integration - Mealvana Endurance

**Client ID:** `mealvana`
**Date:** January 2026

---

## Overview

Mealvana Endurance is a nutrition planning app that syncs with TrainingPeaks to import workouts and athlete data for personalized nutrition recommendations.

**Requested Scopes:** `athlete:profile`, `events:read`, `workouts:read`

---

## User-Agent Header

All requests include the User-Agent header per TrainingPeaks requirements:

```
User-Agent: Mealvana/{version}
```

Example: `Mealvana/1.12.1`

The version is dynamically set from the app's `pubspec.yaml` version.

This header is included on:
- All OAuth requests (token exchange, refresh, deauthorize)
- All API data requests

---

## OAuth Flow

### Authorization URL
```
GET https://oauth.sandbox.trainingpeaks.com/OAuth/Authorize
    ?response_type=code
    &client_id=mealvana
    &scope=athlete:profile events:read workouts:read
    &redirect_uri=com.milkman.mealvanaendurance://callback
    &state={csrf_token}
```

### Token Exchange
```http
POST /oauth/token HTTP/1.1
Host: oauth.sandbox.trainingpeaks.com
Content-Type: application/x-www-form-urlencoded
User-Agent: Mealvana/1.12.1

client_id=mealvana&client_secret={secret}&code={code}&redirect_uri=com.milkman.mealvanaendurance://callback&grant_type=authorization_code
```

### Token Refresh
```http
POST /oauth/token HTTP/1.1
Host: oauth.sandbox.trainingpeaks.com
Content-Type: application/x-www-form-urlencoded
User-Agent: Mealvana/1.12.1

client_id=mealvana&client_secret={secret}&grant_type=refresh_token&refresh_token={refresh_token}
```

---

## API Calls by Scope

### Scope: `athlete:profile`

Retrieve athlete weight and preferences for nutrition calculations.

```http
GET /v1/athlete/profile HTTP/1.1
Host: api.sandbox.trainingpeaks.com
Authorization: Bearer {access_token}
User-Agent: Mealvana/1.12.1
Accept: application/json
```

### Scope: `events:read`

Fetch upcoming races for race-day nutrition planning.

```http
GET /v2/events/next HTTP/1.1
Host: api.sandbox.trainingpeaks.com
Authorization: Bearer {access_token}
User-Agent: Mealvana/1.12.1
Accept: application/json
```

```http
GET /v2/events/2026-01-15 HTTP/1.1
Host: api.sandbox.trainingpeaks.com
Authorization: Bearer {access_token}
User-Agent: Mealvana/1.12.1
Accept: application/json
```

### Scope: `workouts:read`

Import planned workouts for nutrition timing.

```http
GET /v2/workouts/2026-01-06/2026-01-20 HTTP/1.1
Host: api.sandbox.trainingpeaks.com
Authorization: Bearer {access_token}
User-Agent: Mealvana/1.12.1
Accept: application/json
```

---

## Testing Summary

| Scope | Premium Athlete | Basic Athlete |
|-------|-----------------|---------------|
| `athlete:profile` | Pass | Pass |
| `events:read` | Pass | Pass |
| `workouts:read` | Pass | Pass |

- OAuth flow tested successfully in sandbox
- Token refresh tested (1-hour expiration handled)
- User-Agent header verified on all requests

---

## Contact

**Developer:** Lee Martin
**Client ID:** `mealvana`
**Platform:** iOS / Android (Flutter)
