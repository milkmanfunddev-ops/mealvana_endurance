# 32-006 · First TrainingPeaks sync on a token minted 30 s earlier logs TokenExpiredException for athlete metrics, and the card keeps 'Last synced: Sep 28'

- kind: bug
- status: triaged
- ticket: 32
- run: w3-20261008T1256Z
- screen: Connected Apps
- decision: fix ticket 47 (Connected Apps disconnect/reconnect)

**Steps.**
1. Reconnect TrainingPeaks (sandbox OAuth, `lee.tri`), Allow, Keep Sharing.
2. Tap Sync Now on the TrainingPeaks card at once.

**Expected.**
A fresh token reads the athlete's metrics; the card's "Last synced" changes to now when the sync ends.

**Actual.**
13:29:17Z: `TokenExpiredException[training_peaks]: Access token expired or invalid` from
`TrainingPeaksApiClient.getAthleteMetrics`, "metrics fetch failed; sync continues", and an
`error_reported severity: degraded, area: training_peaks` event, on a token the server row says expires at
14:28:55Z. The sync then finished ("Synced!", `last_sync_status success`, `last_sync_at 13:29:18`), imported
one event ("IM NC 70.3") and 0 workouts. The card kept "Last synced: Sep 28 at 1:16 PM" until the screen was
left and re-entered, then read "Just now". Unverified: whether the sandbox account lacks the metrics scope
(which would make this a wrong error type rather than an expired token).

**Evidence.**
- runs/32/m13-after-tp-sync-now.png "Synced!" with the old last-synced date
- runs/32/m14-connected-apps-reentered.png "Just now" after re-entry
- runs/32/db-integrations-after-tp-reconnect.txt the live row and its expiry
- runs/32/console-redacted.log 08:29:17 TokenExpiredException + error_reported

**Decision quote.**
> 

**Triage.**
