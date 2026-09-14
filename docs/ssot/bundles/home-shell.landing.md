# Landing record + attestation — home-shell@v1 (CLOSED)

The close-out record for the shipped bundle. Companion to
[`../runs/2026-09-08-home-shell-landing.md`](../runs/2026-09-08-home-shell-landing.md) (the
landing note — done_when accounting, handoff corrections, open threads); this file adds the
formal attestation and freezes the accounting the attestation covers.

## Target

- **Bundle:** `home-shell@v1` (frozen 2026-09-06 @ `2744985`), shipped **as amended** =
  `home-shell@v1.1` (@ `5dc1b82`, the landing commit): liquid-bubble ratification (tab-bar.md
  Q1 + transit), §Materials sheet/tab-bar chains + top-fade generalization, pinned-block
  ruling #4, gesture-manifest pins filled.
- **Landing:** qa `5dc1b82` ("land: home-shell@v1 close-out"), `qa/home-shell` → `main`
  fast-forward, 23 commits.
- **App implementation:** `release/1.26.0` (app `8859e86f`), **on TestFlight** — cut
  deliberately from the pre-Vana develop base (Xuan's ruling: the release carries zero
  meal-planning code; Vana ships separately ~2 weeks out, from develop).
- Point re-tag in force for the dashboard family: `daily-macros-dashboard@v3.2`.

## done_when accounting (attested state; detail in the landing note)

| Item (bundles/home-shell.yaml, verbatim) | Status at attestation |
|---|---|
| 21 gesture tests green | ✅ **green locally** (app `test/features/home_shell/`, 38 incl. regressions) — CI half OPEN, see the exception |
| 11 goldens green | ✅ **green locally**, blessed with the 0.5 % cross-host comparator — same CI caveat |
| no TBD pin in home-shell.gestures.yaml | ✅ (remaining "TBD" strings are the header's harness-co-evolution commentary only) |
| mirror re-synced | ✅ app `docs/ssot` @ the landing; `SSOT_SOURCE.txt` pinned to main + tag |
| /design-sync run | ✅ 2026-09-07 — twin @ 51 components (GlassSurface/DateHeader/CalendarSheet new; TabBar → glass contract; ViewTabs/WeekStrip retired) |

Beyond the manifest: full local Patrol 23/23; Tier-1 device sweep + Android-emulator pass
(review board `0553d0a2`); liquid-bubble intake RESOLVED (Xuan 2026-09-07).

## ATTESTATION — GIVEN 2026-09-08 (Xuan, in-session)

Xuan attests `home-shell@v1` (as amended, `@v1.1`) implemented and shipped: `release/1.26.0`
live-verified on TestFlight against the accounting above.

**Exception, recorded explicitly rather than waited on (Xuan's call, 2026-09-08):** the two
"green in CI" items are evidenced **locally only** — Lee's M1 runner (`tests-selfhosted`) was
offline throughout the implementation and landing; the evidence is the local runs (23/23
Patrol, full suites, goldens under the cross-host comparator). **CI re-verification is owed
when the runner returns** and is tracked as `HS-D1` in
[`home-shell.deferred.md`](home-shell.deferred.md). If the CI run diverges from the local
result, that divergence is a NEW finding against this record — the attestation stands on the
local evidence it names, no more.

## Open threads at close

Carried in [`home-shell.deferred.md`](home-shell.deferred.md) (HS-D1…HS-D5), sourced from the
landing note — the ledger is the live copy; this record does not restate it.
