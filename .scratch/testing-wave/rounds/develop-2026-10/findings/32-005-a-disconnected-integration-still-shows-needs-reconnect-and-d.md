# 32-005 · A disconnected integration still shows 'needs reconnect', and disconnecting TrainingPeaks first retries the dead refresh token

- kind: bug
- status: closed
- ticket: 32
- run: w3-20261008T1256Z
- screen: Connected Apps
- decision: fix ticket 47 (Connected Apps disconnect/reconnect)

**Steps.**
1. test@test.com, with TrainingPeaks and V.O2 rows at `last_sync_status = requires_reauth`.
2. Settings → Connected Apps; long-press V.O2's Reconnect pill → Disconnect (the hide default). Same for TrainingPeaks.
3. Leave the screen and come back.

**Expected.**
A disconnected provider shows as not connected (a Connect button, no reconnect warning). Disconnecting
makes no call to the provider.

**Actual.**
Both rows go to `is_active false`, `token_expires_at null`, but keep `last_sync_status requires_reauth`, and
both cards keep the needs-reconnect state with a Reconnect pill (name and last-synced gone), also after
re-entering the screen. Cause from code: `Integration.needsReconnect` is `lastSyncStatus ==
requiresReauthStatus` (`lib/features/integrations/domain/integration.dart:93`) and ignores `isActive`; the
controller passes it through (`connect_training_controller.dart:470-475`).
The TrainingPeaks disconnect (13:27:00Z) first ran a token refresh with the dead token: `TrainingPeaksApiException:
Token refresh failed (status: 400)` from `TrainingPeaksOAuthService.refreshTokenIfNeeded`, and sent an
`error_reported severity: degraded` event, one second before `integration_disconnected`.
Also seen, for the lead: `integration_disconnected` and other integration analytics carry `device_id:
607f9dd5-…`, which is the user id.

**Evidence.**
- runs/32/m04-vo2-card-10s.png V.O2 card after Disconnect
- runs/32/m06-after-tp-disconnect.png both cards after both disconnects
- runs/32/m14-connected-apps-reentered.png V.O2 after re-entering
- runs/32/db-integrations-after-vo2-disconnect.txt row after V.O2 disconnect
- runs/32/db-integrations-after-tp-disconnect.txt rows after TP disconnect
- runs/32/console-redacted.log 08:27:01 refresh failure + error_reported before `integration_disconnected`

**Decision quote.**
> 

**Triage.**
