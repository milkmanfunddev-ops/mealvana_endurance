# TrainingPeaks Comment API Discovery Results

**Date**: 2026-03-01
**Environment**: Production (`api.trainingpeaks.com`)
**Method**: Endpoint probing (unauthenticated - testing for 401 vs 404)

## Methodology

Since simulator refresh tokens were stale, we probed all candidate endpoints without auth to determine which exist (401 = requires auth = exists) vs which don't (404 = not found).

This is reliable because TP's API returns:
- **401** for valid endpoints that need auth
- **404** for nonexistent endpoints (returns IIS error page)
- **411** for endpoints that exist but got no Content-Length (without body)

We tested with and without request bodies to eliminate false positives.

## Results

### Comment Endpoints

| Method | Endpoint Pattern | No Body | With Body | Verdict |
|--------|-----------------|---------|-----------|---------|
| POST | `/v2/workouts/{athlete}/id/{workout}/comment` | - | - | **EXISTS** (documented, confirmed working) |
| GET | `/v2/workouts/{athlete}/id/{workout}/comment` | 401 | 401 | **EXISTS** - returns comment list when authed |
| GET | `/v2/workouts/{athlete}/id/{workout}/comments` | 404 | - | Does NOT exist |
| GET | `/v1/workouts/{workout}/comments` | 404 | - | Does NOT exist |
| GET | `/v2/workouts/{workout}/comments` | 404 | - | Does NOT exist |
| GET | `/v3/workouts/{workout}/comments` | 404 | - | Does NOT exist |
| PUT | `/v2/workouts/{athlete}/id/{workout}/comment/{id}` | 411 | 404 | Does NOT exist (411 was IIS, not the API) |
| PUT | `/v2/workouts/{athlete}/id/{workout}/comments/{id}` | 411 | 404 | Does NOT exist |
| PATCH | `/v2/workouts/{athlete}/id/{workout}/comment/{id}` | - | 404 | Does NOT exist |
| DELETE | `/v2/workouts/{athlete}/id/{workout}/comment/{id}` | 404 | 404 | Does NOT exist |
| DELETE | `/v2/workouts/{athlete}/id/{workout}/comments/{id}` | 404 | - | Does NOT exist |
| DELETE | `/v1/workouts/{workout}/comments/{id}` | 404 | - | Does NOT exist |

### Workout Plan Endpoint (for Description approach)

| Method | Endpoint | Status | Verdict |
|--------|----------|--------|---------|
| PUT | `/v2/workouts/plan/{workoutId}` | 411 (no body) | **EXISTS** - can update planned workouts |

## Summary

### Comment CRUD Capabilities

| Operation | Available? | Endpoint |
|-----------|-----------|----------|
| **Create** | YES | `POST /v2/workouts/{athlete}/id/{workout}/comment` |
| **Read** | YES (likely) | `GET /v2/workouts/{athlete}/id/{workout}/comment` |
| **Update** | **NO** | No PUT/PATCH endpoint exists |
| **Delete** | **NO** | No DELETE endpoint exists |

### Implications

Comments are **append-only**. Once posted, they cannot be edited or removed via the API. This makes comments unsuitable for nutrition plans that change, because:
1. Updated plans would leave stale old comments
2. Deleted plans would leave orphaned comments
3. Re-syncing would create duplicate comments

## Recommendation

**Use the Description field approach** (delimited block appended to workout description).

The Description field gives us full CRUD via `PUT /v2/workouts/plan/{workoutId}`:
- **Create**: Append `[Mealvana Fuel Plan]` block to existing description
- **Read**: GET the workout, parse our block from the description
- **Update**: Read, find our block by delimiters, replace content, PUT back
- **Delete**: Read, strip our block, PUT back with clean description

## Authenticated Testing (Deferred)

Full authenticated testing (POST a real comment, GET to read it back, test Description PUT/revert) requires a fresh TP access token. The script at `tool/tp_comment_discovery.dart` is ready to run once a fresh refresh token is available. This would confirm:
1. What the GET comment response looks like (JSON structure, comment IDs)
2. That Description PUT actually works end-to-end
3. Whether comment IDs are returned on POST (useful for tracking even if we can't delete)

To get a fresh token: run the app, trigger any TP sync, then run:
```bash
dart run tool/tp_comment_discovery.dart <fresh_refresh_token>
```
