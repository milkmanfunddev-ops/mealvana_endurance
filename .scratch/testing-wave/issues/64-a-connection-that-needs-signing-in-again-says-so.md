# 64: A connection that needs signing in again says so

**Status:** in-progress (wave 22, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** When a TrainingPeaks or V.O2 token refresh fails for good (400, or "Please reconnect"), the connection is marked as needing reconnection and the athlete sees it where connections are shown (Settings integrations), with a Reconnect action. Nothing opens as if the connection worked.

**Findings:** 21-004 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/integrations/application/training_peaks_sync_service.dart, lib/features/integrations/application/training_peaks_oauth_service.dart, lib/features/integrations/data/training_peaks_api_client.dart

- [x] A seam test: a refresh answering 400 marks the connection as needing reconnection.
- [x] A widget test: the integrations screen shows Reconnect for it.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
