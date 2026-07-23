# Sentry Integration Guide (Repo Truth)

## Current State (Repo Truth)
- Sentry is initialized at app entrypoints and used through provider-backed dependencies.
- Feature code accesses reporting through injected external deps (`appExternalDepsProvider`).
- The current integration pattern is `SentryReporter`-based, not a monolithic legacy service.

## Source of Truth
- Reporter interface/implementation: `lib/shared/services/sentry/sentry_reporter.dart`
- Session-replay cohort sampler: `lib/shared/services/sentry/sentry_replay_sampling.dart`
- MetricKit → Sentry bridge (native): `ios/Runner/MetricKitReporter.swift`
- External dependency wiring: `lib/shared/services/app_external_deps.dart`
- App entrypoints — all four configure Sentry, and the three mobile ones must be
  kept in sync (replay sampling, `beforeSend` filter, consent gate):
  - `lib/main.dart`
  - `lib/main_dev.dart`
  - `lib/main_prod.dart`
  - `lib/main_web.dart` (replay disabled outright on web for performance)

## Session Replay — why it is sampled to a 10% cohort (2026-07-16)

**Do not set `onErrorSampleRate` to a fractional value. It does not mean what it
looks like it means.**

A beta tester reported their phone running hot and draining battery on both the
dev and prod TestFlight builds. The cause was session replay, armed at
`onErrorSampleRate = 1.0` for every release install.

### The mechanism

`onErrorSampleRate` reads like a sampling rate, but the gate deciding whether
sentry-cocoa's recorder starts is an exact comparison against zero
(`SentrySessionReplayIntegration.m`; our `sessionSampleRate` is `0`, so
`_startedAsFullSession` is always false):

```objc
_startedAsFullSession = [self shouldReplayFullSession:_replayOptions.sessionSampleRate];
if (!_startedAsFullSession && _replayOptions.onErrorSampleRate == 0) {
    return;   // recorder never starts
}
[self runReplayForAvailableWindow];
```

Any non-zero value starts the recorder, which then runs **continuously for the
whole foreground session**, capturing frames into a rolling ~30s buffer via a
display link. That is inherent to the feature — you cannot have the 30 seconds
*before* a crash without recording the whole time. The `onErrorSampleRate`
dice-roll happens later, at error time (`sessionReplayShouldCaptureReplayForError`),
and only decides whether the already-recorded buffer is uploaded.

So the trap: `onErrorSampleRate = 0.1` costs **100% of the battery** and discards
**90% of the replays**. It is strictly worse than either `1.0` or `0.0`.

Sentry's published iOS overhead is CPU 4% → 13% on an iPhone 14 Pro (a CPU
figure, not a battery figure; the heat follows from the CPU never idling). It
pauses on `UIApplicationDidEnterBackgroundNotification`, so this is foreground
burn only — it is not background activity.

### Measured, not assumed (2026-07-16)

A/B on the iPhone 17 Pro simulator, dev flavor, same build, arm forced via
`--dart-define` and verified live before each measurement. 20 idle CPU samples
per arm over ~60s, app untouched:

| Arm | mean | median | p90 | replay frames on-CPU |
|---|---|---|---|---|
| replay **off** | **2.71%** | 2.65% | 3.50% | **0** |
| replay **armed** | **5.16%** | 4.30% | 6.00% | `takeScreenshot` ×7, `newFrame` ×9 |

**~1.9x idle CPU** (+2.45 points mean). Mann-Whitney U, z=4.84, p<0.05;
P(armed sample > off sample) = 0.948.

`sample` on the idle armed process caught the mechanism directly:

```
CA::Display::DisplayLink::dispatch_deferred_display_links(...)   (QuartzCore)
  └─ CA::Display::DisplayLinkItem::dispatch_(...)
      └─ @objc SentrySessionReplay.newFrame(_:)
          └─ SentrySessionReplay.takeScreenshot()
              └─ SentryOnDemandReplay.addFrameAsync(timestamp:image:forScreen:)
```

A display link driving `takeScreenshot()` on an app doing nothing — exactly the
maintainer's description in #6885. The off arm shows **zero** such frames,
confirming `onErrorSampleRate = 0` really does prevent the recorder starting.

**Caveats, so nobody over-reads this.** Debug build (release/profile are not
supported on the iOS simulator), so absolute numbers are not
release-representative — the Flutter screenshot path is JIT here and likely
overstates cost, while the native display link and encode are the same. The
simulator has no real battery, no thermals, and no ProMotion panel, so the
display-link cost may be *understated* versus a real 120Hz device where it also
prevents the display idling. Direction and mechanism are solid; the exact
multiplier on a real phone is not. Confirming that is what MetricKit is for.

### What we do instead

`resolveReplayOnErrorSampleRate` samples in Dart, per install, and returns only
`1.0` or `0.0`:

- **Armed install** → identical behaviour to before. The native SDK records and
  every error ships its 30s video to Sentry. Dart does not touch the video
  pipeline; it only decides whether to switch the recorder on.
- **Unarmed install** → recorder never starts, zero idle cost.

At `kReplayArmedCohortFraction = 0.1` the cost is ~10% of what it was for ~10% of
the coverage — a linear trade. Sentry's own knob offers none.

The roll is **persisted per install**, not per session: an armed install stays
armed, giving complete session histories for a stable subset rather than a
scatter of half-captured reproductions.

Unarmed installs still get a still screenshot of the error moment
(`attachScreenshot = true`, captured on demand at zero idle cost), the stack
trace, and 100 breadcrumbs.

### Constraints and levers

- Gated on analytics consent, same as Mixpanel — replay is a rolling recording of
  the user's screen. Unconsented users are never armed and are never assigned a
  cohort (so a later grant still rolls fairly). See
  `lib/shared/services/privacy/analytics_consent.dart`.
- Disabled outright in debug (avoids 200+ lines of codec logs) and on web.
- To re-roll the whole fleet into fresh cohorts, bump the `_cohortKey` suffix.
- **Shorebird-patchable**: this is pure Dart, so the cohort fraction can be
  changed on an already-shipped binary without a new build.

### When to revisit

The overhead is upstream and unfixed. Revisit this whole file if that changes —
if the idle cost goes away, the right answer is to return to a flat `1.0`.

- [sentry-cocoa#5263](https://github.com/getsentry/sentry-cocoa/issues/5263) —
  "Session Replay should use runloop observers". **Open** (reopened).
- [sentry-cocoa#6885](https://github.com/getsentry/sentry-cocoa/issues/6885) —
  closed as a duplicate of #5263. Maintainer: session replay *"uses a display
  link ... this leads to high overhead because even when the UI is not changing
  session replay is recording a frame"*.
- No `sentry_flutter` release fixes this. Even the latest (9.24.0) pins
  sentry-cocoa **8.58.3**; Flutter has never moved to the 9.x line where fixes
  are landing. We pin `sentry_flutter ^9.6.0` → cocoa **8.52.1**. Upgrading
  within 9.x is worth doing on general principle but does **not** resolve this.

## Real-device CPU/battery via MetricKit (2026-07-17)

We cannot measure CPU/battery on a tester's phone directly — the simulator
can't, and Xcode Organizer's battery pane needs App Store scale, not TestFlight.
`ios/Runner/MetricKitReporter.swift` closes that gap by subscribing to Apple's
MetricKit and forwarding each payload into the Sentry pipeline we already have.

- **What it is**: a native `MXMetricManagerSubscriber` registered in
  `AppDelegate.didFinishLaunchingWithOptions`. No Dart, no new backend, no table.
- **Where the data shows up**: Sentry, as `info` events tagged
  `metrickit:metric` (daily CPU time / foreground time) and
  `metrickit:diagnostic` (CPU exceptions, hangs — each with a device call
  stack). Filter the issue stream by the `metrickit` tag.
- **Cost**: none worth measuring. MetricKit is passive — iOS already collects
  this for the system battery screen; we only read it. No polling, no display
  link. Metric payloads arrive ≤once/24h; diagnostics immediately (iOS 15+).
- **Constraints**:
  - Real devices only. The simulator never delivers payloads, so this cannot be
    smoke-tested locally — verify by watching Sentry for `metrickit`-tagged
    events ~24h after a TestFlight build lands.
  - Native, so it ships in a real build and **cannot** be Shorebird-patched
    (unlike the replay fix).
  - Not consent-gated, matching the crash/performance-reporting policy: it is
    stability/perf data about our own code, `sendDefaultPii` stays false.
- **Adding the file to the Xcode target**: `MetricKitReporter.swift` is wired
  into `Runner.xcodeproj/project.pbxproj` by hand (four entries mirroring
  `AppDelegate.swift`). A new native file that compiles locally but is missing
  from the target fails only at the *build* step with "Cannot find X in scope" —
  if you add native files, add them to the target too.

## Runbook / Commands
- Find Sentry usage in app code:
```bash
rg -n "Sentry|sentry|SentryReporter|appExternalDepsProvider" lib -S
```
- Validate web entrypoint Sentry wiring:
```bash
rg -n "SentryFlutter\.init|SentryWidget|sentryNavigatorKey" lib/main_web.dart
```

## Verification Checklist
- New error reporting calls use injected `SentryReporter` from external deps.
- App entrypoints initialize Sentry before major app logic.
- Sensitive data filtering remains in Sentry options/hooks where applicable.
- `onErrorSampleRate` is only ever `1.0` or `0.0` — never a fractional value.
  Guarded by `test/shared/services/sentry/sentry_replay_sampling_test.dart`.

## Related Docs
- `/docs/technical/README.md`
- `/docs/deployment/README.md`

## Deprecated/Legacy Notes
- Legacy `SentryService` examples may exist in historical docs; prefer current `SentryReporter` pattern.
