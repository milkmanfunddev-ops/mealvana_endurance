# 99: FinalSurge completion marks the workout done

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Lee's ruling on 29-002 (2026-09-25): build it now. FinalSurge now sends `WorkoutCompleted: true` with `ActualTime` and `ActualDistanceMeters` (seen on the dev account 09-24; payloads in `runs/29/console-redacted.log` lines 15993-16068). Today the app uses the actuals as fallbacks for the planned fields, so an 8 mi plan reads 8 mi although 3.5 mi was run, and the card stays Planned.
1. A completed FinalSurge workout is stored as completed: `status`, `completed_at`, `actual_*`, and a completion type that says it came from the provider. The card shows done with the measured values, as integrations-data-display.md describes for a verified completion.
2. Planned fields keep the planned values. Actuals never fill them.
3. `WorkoutDate` is naive local (`2026-09-24T00:00:00`); keep the naive-local-day rules (never string-match `time_window`, `scheduled_date_time` is local-naive).
4. Write the behaviour down for Xuan. `docs/ssot/spec/integrations/final-surge.md` is mirrored from the QA repo, so never edit it; add `docs/ssot/spec/integrations/final-surge-completion.PROPOSED.md` with status "PROPOSED … authored app-side, awaiting Xuan", citing FS-2.1 and M-1.3.

**Findings:** 29-002. Retest ticket 100 closes it.

**Decisions:** FS-2.1 and M-1.3 in `docs/ssot/spec/integrations/` (read both first). Lee's ruling above overrides "never observed" until Xuan rules. No page writes.

**Touches:** lib/features/integrations/application/final_surge_transformer.dart, final_surge_sync_service.dart, change_detection_service.dart if it decides status, the Drift activity model only if a field is missing (then codegen and a schema bump), docs/ssot/spec/integrations/final-surge-completion.PROPOSED.md

- [ ] Transformer tests fed the two real payloads from runs/29 (producer-shaped, never the engine's own output): completed with actuals, planned fields untouched.
- [ ] A seam test through the real sync path: a completed payload marks the stored activity completed with actuals, and a later payload without completion does not undo it.
- [ ] `flutter analyze` clean; codegen if the schema changed.

Next: /implement-lee testing-wave
