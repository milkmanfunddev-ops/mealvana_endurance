# Garmin — Sample Payloads

Sample JSON bodies for the Garmin Connect Developer Program APIs. Identifiers are redacted as
placeholders (`<USER_ID>`, `<USER_ACCESS_TOKEN>`); `summaryId`/timestamps are illustrative.

- **push** examples are full webhook bodies Garmin POSTs to a partner endpoint (data inline).
- **ping** examples carry only `callbackURL` pointers to GET.
- Field models: [`../activity-data.md`](../activity-data.md), [`../health-data.md`](../health-data.md),
  [`../training-courses-womens.md`](../training-courses-womens.md).

Provenance: files are captured/representative payloads unless marked _(spec-derived)_, meaning the
body was constructed from the vendor specification (Training, Courses, and Women's Health APIs have
no captured payloads on file).

## Activity API

| File | Contents |
|---|---|
| [`push-activity-run.json`](push-activity-run.json) | Running activity summary push. |
| [`push-activity-bike.json`](push-activity-bike.json) | Cycling activity summary push. |
| [`push-activity-swim.json`](push-activity-swim.json) | Swimming activity summary push. |
| [`push-activity-multisport.json`](push-activity-multisport.json) | Multisport parent + child legs. |
| [`push-activity-other-sport.json`](push-activity-other-sport.json) | Non-endurance activity type. |
| [`push-activity-zero-distance.json`](push-activity-zero-distance.json) | Valid `distanceInMeters: 0` activity. |
| [`push-activity-detail.json`](push-activity-detail.json) | `activityDetails` with samples + laps. |
| [`push-manually-updated-activity.json`](push-manually-updated-activity.json) | `manuallyUpdatedActivities` push. |

## Health API

| File | Contents |
|---|---|
| [`health-dailies.json`](health-dailies.json) | Daily wellness summary. |
| [`health-epochs-and-user-metrics.json`](health-epochs-and-user-metrics.json) | Epoch slices + user metrics (VO2max/fitness age). |
| [`health-sleep.json`](health-sleep.json) | Sleep summary. |
| [`health-body-composition.json`](health-body-composition.json) | Body composition. |
| [`health-stress-detail.json`](health-stress-detail.json) | Stress + Body Battery timeline. |

## Delivery & lifecycle

| File | Contents |
|---|---|
| [`ping-notification.json`](ping-notification.json) | Ping bodies (callback URLs, no data). |
| [`deregistration-and-permissions.json`](deregistration-and-permissions.json) | Deregistration body + user-permission-change body. |

## Training API _(spec-derived)_

| File | Contents |
|---|---|
| [`training-workout-single.json`](training-workout-single.json) | Single-sport workout create body. |
| [`training-workout-multisport.json`](training-workout-multisport.json) | Multisport workout create body. |
| [`training-schedule.json`](training-schedule.json) | Workout schedule body. |

## Courses API _(spec-derived)_

| File | Contents |
|---|---|
| [`course.json`](course.json) | Course create body (geo-points + course point). |

## Women's Health API _(spec-derived)_

| File | Contents |
|---|---|
| [`womens-mct.json`](womens-mct.json) | MCT summary (non-pregnant). |
| [`womens-mct-pregnancy.json`](womens-mct-pregnancy.json) | MCT summary with pregnancy snapshot. |
