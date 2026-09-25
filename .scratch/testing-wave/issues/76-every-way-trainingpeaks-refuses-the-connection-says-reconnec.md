# 76: Every way TrainingPeaks refuses the connection says Reconnect

**Status:** in-progress (wave 24, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Finish ticket 64. A TrainingPeaks data call that answers 401 right after a refresh marks the connection `requires_reauth` (Connected Apps shows Reconnect). A network error thrown during the token refresh is an ordinary, retryable `error` and never escapes `syncWorkouts`/the event sync.

**Findings:** 64-001 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/integrations/application/training_peaks_sync_service.dart, lib/features/integrations/data/training_peaks_api_client.dart

- [ ] A seam test: a data call answering 401 after a refresh stores `requires_reauth`.
- [ ] A seam test: a refresh throwing a SocketException stores `error` and the sync returns normally.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
