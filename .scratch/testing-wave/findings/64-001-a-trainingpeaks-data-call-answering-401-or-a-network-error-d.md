# 64-001 · A TrainingPeaks data call answering 401, or a network error during refresh, is not marked as needing reconnection

- kind: bug
- status: closed
- ticket: 64
- run: w22-20260925T1215Z
- screen: Settings → Connected Apps (TrainingPeaks)
- decision: 

**Steps.**
1. With a TrainingPeaks connection whose access token the API refuses on a data call (401), run a sync.
2. Separately, make the token refresh throw a network error (no HTTP answer).

**Expected.**
A data call answering 401 after a fresh refresh, and a refresh that the API refuses, mark the connection as needing reconnection (`requires_reauth`), so Connected Apps shows Reconnect. A network error is an ordinary, retryable error and never escapes the sync.

**Actual.**
Ticket 64's agent reported both as out of its scope: a data call answering 401 still stores `error` "Token expired. Please reconnect." rather than `requires_reauth`, and a network exception thrown during refresh escapes `syncWorkouts`. Code read in wave 22.

**Evidence.**
- lib/features/integrations/application/training_peaks_sync_service.dart
- lib/features/integrations/data/training_peaks_api_client.dart

**Decision quote.**
> 

**Triage.**
Fix ticket 76 (filed by the wave lead from wave 22's review, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 118 when 93 was split (Lee, 2026-09-25).

Run by retest ticket 118 (run w36-20260926T0031Z, build 72d3723e): the 401-after-a-fresh-refresh leg could not be caused on dev while the refresh itself is refused; it is covered by the seam tests in test/features/integrations/tp_refresh_requires_reconnect_seam_test.dart ("a data call TP answers 401"). The network-error leg ran: caught, no unhandled exception, not marked requires_reauth, but it overwrites a local requires_reauth with error: new bug Finding 118-002. Closed by the wave 36 lead.
