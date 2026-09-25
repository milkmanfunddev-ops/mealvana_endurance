# Run record — data-integrations@v1 implementation (app side)

Pinned target: tag `data-integrations@v1` (284566f). App branch:
`feature/data-integration` (base release/1.26.0 + the 5 OTA-fix
cherry-picks; Vana renumbered to Drift v21 on develop first).

## Conformance counts (before → after)

| Suite | Before | After |
|---|---|---|
| matching vectors, matcher tier | 16/41 (legacy pipeline, MANDATORY red-first run — greens were the deliberately-preserved tombstone/skipped/day-wide behaviors) | **41/41 TS** (`matcher.test.ts`) + **41/41 Dart twin** (`match_decider_vectors_test.dart`) |
| session-demand incl. 9 f4a-* rows | f4a rows unrunnable (comparator lacked legs/estimateFlag; `?? 11`-era pricing) | **38/38 deno** (`vectors.conformance.test.ts`, comparator gained legs/dominantSport/estimateFlag) + Dart twin parity over the same kcal rows |
| design goldens manifests | 0/3 realized | **3/3** green app suites (workout-card-states 6, ftp-source-provenance 9, tp-writeback-consent 9) |
| wide app suite | — | 3733+ green; sole red = pre-existing pr-validation contract test (red on develop too; predates the bundle) |

## Notes
- Red-first evidence + per-vector table: app runbook
  `../ops/docs/deploys/2026-09-data-integration.md` §Stage B.
- Decision/executor split: vectors pin DECISIONS; write-time effects
  (23505, atomic races) live in executors — surfaced by the red run's
  `skipped-t1-unreachable-for-other` (legacy: duplicate/noop at write).
- M-1.2 t3 revert-rebind: decision green both twins; client rebind
  EXECUTOR deliberately gated on Xuan's §7 FS completed-workout probe.
- Engine bumped v6.0.0 → v6.1.0 (F4a) in place per playbook §6; client
  algorithm-version floor raised with it.
- Stage E (sim charter walk, dev): COMPLETE 2026-09-11 evening. Green live:
  DI-DEV-1 measured-pair-only card, D-1b dotted planned border, Q-INT2
  disconnect end-to-end (hide + DI-9 token clear + engine demand drop),
  D-2/D-2b/D-2c chips on live surfaces. Four seams found + fixed + pinned
  (app 3e5d11db) — see intake findings 5; three pre-existing defects filed
  to ops (intake findings 6). Not walked live (pinned by suites instead):
  brick card, mark-done upgrade, no-history pace fallback, OAuth revive.
- Post-Stage-E addendum: Xuan pulled the FTP/CSS persistence defect into the
  bundle — fixed in app bd6e509d (8 users columns in unreleased v20, DAO
  wired, guard re-pinned, DAO round-trip test). Live-verified incl. dev
  server twin (cycling_ftp_watts=250). D-2 manual-wins is now durable.

## Land-bundle gate (2026-09-13)
- Conformance gate GREEN across all 3 slices via qa/conformance/run_dart.sh:
  matching (42, matcher-tier twin: Dart mirror + TS matcher over the mirrored
  41 vectors), session-demand-f4a (9 f4a rows), integrations-data-display
  (24, three D-2 golden suites). Two runner arms were MISSING (manifest note
  admitted the matcher-tier runner was "to build") and were added in
  conformance/run_dart.sh (commit eb6f341) — NOTE: post-tag infra, must reach
  qa main separately from the data-integrations@v1 tag merge.
- Dev-verification evidence (land-bundle Step 2b): Patrol 7/7 green on the
  dedicated patrol-runner sim across the bundle-relevant flows
  (settings_persist, integrations_connect, brick_plan, activities_crud,
  events_crud) + the earlier Stage E sim charter walk + live Garmin/TP/FS API
  probes + FTP-persistence server round-trip. (First patrol attempt on the
  in-use iPhone 17 sim failed to EXECUTE — xcodebuild 65, 0 tests, no crash —
  a sim-conflict infra issue, not a bundle failure; the dedicated sim ran clean.)
