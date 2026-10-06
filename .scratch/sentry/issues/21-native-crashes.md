# 21: Native crashes

**What to build:** MEALVANA-ENDURANCE-BP (SIGSEGV), C2 (SIGBUS), B7 (watchdog termination), CR (outlined function). With symbols uploaded, read the native frames, find the cause (memory, a plugin, a view hierarchy), and fix or file upstream.

**Blocked by:** 10 Contract; 14 Symbols in release builds

**Status:** done except the device check (see Owed)

- [x] Each crash symbolicated and attributed (CR is fully symbolicated; BP and C2 cannot be, because the crashing PC is outside every loaded module; watchdog events carry no stack by design)
- [x] Fix landed or upstream issue linked with a mitigation (CR: in-app gate + upstream link; others: no app-code cause, upstream links below)
- [ ] Issues resolved or marked with the upstream link in Sentry (lead, after merge; table below)

## How this was read (2026-10-06)

Every event of every issue was pulled (`/issues/<id>/events/?full=true`, paginated) and read for
device, OS, release, frames against the debug-image list, registers, breadcrumbs and tags. Sentry
keeps 3 of BP's 5 events, 3 of B7's 4 and 11 of DEV-7D's 13; the rest are past retention.
Neighbouring events from the same install were found with the org events endpoint
(`device:` / `user.id:` queries). Raw JSON and scripts: `<scratchpad>/21/`.

Debug files: prod `mealvana-endurance` holds `libapp.so`, `libflutter.so`, `libdartjni.so` (arm,
arm64, x86_64) for Android 1.29.0+148 and the Runner/Flutter/App dSYMs for iOS 1.29.0+147
(uploaded 2026-10-01, by the pre-ticket-14 config). BP's latest event lists
`libapp.so` x86_64 `553fdd7a` and `libflutter.so` x86_64 `610f1fb5` as loaded images, and both
are uploaded. Nothing is missing: the frames are unsymbolicated because they do not fall in any
image, so no upload or Codemagic artefact would change them, and reprocessing was not attempted.
The dev project holds no debug files; the only dev issue here is a watchdog event, which has no
frames.

Two outside sources were also checked:
- App Store Connect `perfPowerMetrics` for the prod app returns empty (too few users for Xcode
  Organizer metrics).
- The MetricKit metric payloads relayed to Sentry (MEALVANA-ENDURANCE-AN, attachment
  `metrickit-metric.json`). 292 unique payloads cover 1.23.3 to 1.29.0, including 1.26.0+109,
  1.27.0+111 and 1.27.1+142. Their `applicationExitMetrics.foregroundExitData` contains only
  `cumulativeNormalAppExitCount`. Foreground memory-limit, watchdog, bad-access and
  illegal-instruction exits are all zero. Background exits are memory-pressure reclaims, which is
  normal iOS behaviour.

## Per crash

### MEALVANA-ENDURANCE-CR: SIGSEGV in `OUTLINED_FUNCTION_7962` (1 event, 2026-09-26)
- **Device:** "Pixel 6 Pro" that is really an emulator: OS build `sdk_phone_arm64-eng 12 … test-keys`, `isSideLoaded: true`, battery 100 and charging, anonymous user. The LicenseActivity covering MainActivity is most likely Google Play's integrity license check, which shows when an app is sideloaded.
- **Release:** 1.28.0+146, Flutter 3.47.5 (from the same release's Dart events), sentry_flutter 9.6.0 (from `pubspec.lock` at 1.28.0).
- **Symbolicated:** yes, all 75 frames (`base.apk` → libflutter `bb96f2c3`, found).
- **Attribution:** a Flutter engine bug (Impeller OpenGLES backend), triggered by the Sentry SDK's screenshot recorder while the app was in the background.
- **Evidence:** the crashing raster-thread stack is `Picture::DoRasterizeToImage → Rasterizer::MakeImpellerSnapshot → DoMakeRasterSnapshot → AndroidSurfaceGLImpeller::CreateSnapshotSurface → GPUSurfaceGLImpeller → AiksContext → ContentContext → BlitPassGLES::EncodeCommands → ReactorGLES::FlushOps → BlitCopyBufferToTextureCommandGLES::Encode → OUTLINED_FUNCTION_7962`. `Picture.toImage` has no caller in `lib/`. The only callers in our dependency set are sentry_flutter's `ScreenshotRecorder` (`recorder.dart:245`), used for both error screenshots and session replay. Page transitions are not the source: the Android default, FadeForwards, does not snapshot. Breadcrumbs show `MainActivity stopped` and `saveInstanceState` at 06:17:36.5, then startup finished at 06:17:37.44, and the crash came 30 ms later. With no onscreen surface, the engine builds an offscreen GLES snapshot surface. That exact path is filed upstream as a 3.44.6 → 3.47.5 regression.
- **Upstream:** https://github.com/flutter/flutter/issues/193899 (open, same 16-frame stack). Related: https://github.com/flutter/flutter/issues/192365 (open, GLES use-after-free flushed by a later `Picture.toImage`). Sentry side: https://github.com/getsentry/sentry-dart/issues/3923 (open) covers in-flight replay captures that outlive the surface. PR https://github.com/getsentry/sentry-dart/pull/3935 (merged, in 9.30.1, which this branch now uses since ticket 02) awaits in-flight captures on stop, and 9.30.1's replay scheduler skips captures while the app is not resumed.

### MEALVANA-ENDURANCE-BP: SIGSEGV (5 events, 3 kept; 1.26.0+110, 1.27.0+141, 1.29.0+148)
- **Device:** "OnePlus8Pro", Android 11 `QKR1.191246.002`, the same identical device in every event: total memory 4382818304, battery 85 and charging, `user: anonymous`, installer `com.android.vending`. It is an x86_64 emulator, not a phone. The loaded images are `split_config.x86_64.apk`, `libEGL/GLESv2_swiftshader.so`, `libndk_translation.so`, `vulkan.pastel.so` and `mapper@4.0-impl.minigbm.so`. Each crash lands within minutes of a new Android build, next to other anonymous events from the same emulator (`webAuthenticationOptions` errors from Apple sign-in on Android, robot-style taps), so this is Google Play's pre-launch report crawler.
- **Symbolicated:** no, and no debug file can change that. One frame per event, at PC `0x73e19d03c7fd` / `0x740b371d86c8` / `0x7e3e55aaba68`, outside every one of the 274 loaded images (each sits about 0x1d08xxxxx above `libart.so`, which points at anonymous executable memory such as a JIT code cache). The x86_64 `libapp.so` and `libflutter.so` for 1.29.0+148 are uploaded and appear in the image list, but the PC is not inside either.
- **Attribution:** test-device runtime (JIT'd code on the pre-launch emulator: ART JIT or SwiftShader's shader JIT). The PC is not in our code and not in any plugin `.so`. No real-user device has hit it.
- **Evidence:** above. Breadcrumbs differ every time (Settings screen, startup's deferred RevenueCat step, the plan tab), so no app screen correlates.
- **Upstream:** none filed or found. Searches: `gh search issues "pre-launch" -R getsentry/sentry-java` and `"unknown_image SIGSEGV x86_64 emulator" --owner getsentry`, both with nothing relevant.

### MEALVANA-ENDURANCE-C2: SIGBUS (1 event, 2026-09-13, 1.26.0+110)
- **Device:** the same "OnePlus8Pro" x86_64 pre-launch emulator as BP (same OS build, memory, battery and installer).
- **Symbolicated:** no. One frame at PC `0x0`, and every register is 0 except `sp`. The register set is 32-bit ARM (`r0`–`r10`, `fp`, `ip`, `lr`), so the faulting thread was ARM code running under `libndk_translation` on the x86_64 emulator.
- **Attribution:** the test device's binary translator. Not our code.
- **Evidence:** above. Breadcrumbs show a normal dashboard load (daily_macros week calculation, six 201 POSTs) up to 5 s before the crash.
- **Upstream:** none. The translator is Google's closed emulator component.

### MEALVANA-ENDURANCE-B7: WatchdogTermination (4 events, 3 kept, 3 installs)
- **Devices / releases:** iPhone17,2, iOS 26.6.1, 1.26.0+109 (2026-09-08 00:41 UTC); no device context, 1.27.0+111 (2026-09-21 02:39); no device context, 1.27.1+142 (2026-09-22 16:31). sentry-cocoa 8.52.1.
- **Symbolicated:** not applicable. A watchdog-termination event is a heuristic written on the next launch and carries no stack.
- **Attribution:** a heuristic false positive. It is not memory pressure and not a main-thread hang.
- **Evidence:**
  - Each event holds only 1–2 native breadcrumbs ("Breadcrumb Tracking" started, then `connectivity: wifi` or `app.lifecycle: foreground` 0.1–0.3 s later) and no Dart breadcrumb at all. The previous run ended before the Dart startup flow logged anything.
  - No event in B7 or DEV-7D carries a memory-warning breadcrumb.
  - `in_foreground: true` proves nothing: sentry-cocoa sets it on every watchdog event (cocoa changelog, #4953).
  - None of the three installs ever sent another event.
  - Two of the three line up with TestFlight beta review: build 109 was submitted at 2026-09-08 00:37 UTC (event 4 min later), and build 142 at 2026-09-22 16:17 UTC (event 14 min later). App Store Connect `betaAppReviewSubmissions` has both submissions.
  - Build 111 was a TestFlight-only build (1.27.0 shipped as 113).
  - MetricKit shows zero foreground watchdog or memory-limit exits for these same builds.
- **Upstream:** sentry-cocoa's classifier is "abnormal exit while active", and it cannot tell a review or test harness kill from a real watchdog kill. The V2 tracker, which classifies terminations by observed hangs (`options.experimental.enableWatchdogTerminationsV2`, sentry-cocoa 9.5.0, PR #7464), is not reachable: sentry_flutter 9.30.1 pins `Sentry/HybridSDK 8.58.4`, and the Cocoa 9.x bump PRs were closed unmerged (e.g. https://github.com/getsentry/sentry-dart/pull/3743). Search used: https://github.com/getsentry/sentry-cocoa/issues?q=watchdog+false+positive (closest: #5794, update false positives, closed).

### MEALVANA-ENDURANCE-DEV-7D: WatchdogTermination (13 events, 11 kept, dev project)
- **Devices / releases:** nine are iPhone14,8 (iPhone 14 Plus, America/Chicago, the same phone that sends Lee's prod MetricKit payloads). Seven are on 1.25.0+1, all on 2026-09-07 within 13 h; two are on 1.28.0+5 (09-30, 10-01). One is iPhone17,2 on 1.23.0+121.
- **Symbolicated:** not applicable (no stack).
- **Attribution:** local development installs ended by the IDE or a reinstall. Not memory.
- **Evidence:**
  - Dev TestFlight builds are numbered 125–139 (App Store Connect, dev app 6756683509). Build numbers `+1` and `+5` are pubspec's own, meaning `flutter run` / Xcode installs, not TestFlight.
  - Seven "watchdog" events on one phone in one day is a run-stop-run cycle. A release or profile run has no debugger attached, so a stop (SIGKILL) or reinstall over the same version looks to sentry-cocoa like an abnormal foreground exit.
  - The sessions show ordinary activity up to the end (daily_macros upserts, navigation, orientation changes, a token refresh) and no memory-warning breadcrumb.
  - The 1.23.0+121 event has the same 2-breadcrumb shape as B7.
- **Upstream:** same as B7.

## Fix or mitigation

- **CR, in our code:** `options.beforeCaptureScreenshot = foregroundOnlyScreenshots()` in
  `lib/shared/core/bootstrap/bootstrap.dart`. The new gate is in
  `lib/shared/core/bootstrap/sentry_screenshot_gate.dart`. It allows a capture only while the app
  is `resumed`, or before the first lifecycle message (startup), and keeps the SDK's 2 s debounce,
  because a set callback overrules the SDK's own decision. This closes the background
  `Picture.toImage` that reached `CreateSnapshotSurface`. Session replay's background captures are
  covered by sentry_flutter 9.30.1 (already on this branch since ticket 02). An app in the
  background has nothing worth a screenshot anyway.
- **Test:** `test/shared/core/bootstrap/sentry_screenshot_gate_test.dart`, 9 cases. Resumed and
  `null` allow; inactive, hidden, paused and detached refuse; a debounced request is refused; the
  state is read at capture time; and the bootstrap installs the gate. It was red before: the file
  did not compile without the gate, and with the gate but without the bootstrap line, the wiring
  case fails (checked by removing the line). Green after.
- **Docs:** `docs/technical/sentry-integration.md`, under the replay section, says screenshots are
  foreground-only and why.
- **BP, C2, B7, DEV-7D:** no code change. None of them traces to app code, so there is nothing
  to fix.

Verification: `dart analyze` clean on the three changed Dart files. The new test file passes, and
`flutter test test/shared/source_guard` passes (20). No full suite, no build.

## Owed

- **Device check (not run):** the CR path needs an Android device or emulator on the Impeller
  GLES backend, built with Flutter 3.47.x. Put the app in the background, raise an error event,
  and confirm Sentry logs "skipping capture" and the process survives. Agents do not run
  `flutter build`, and the local toolchain is Flutter 3.44.4, which predates the regression.
- **Lee's decision, Codemagic Flutter version:** every workflow uses `flutter: stable`, which
  moved 1.26 → 1.29 across 3.47.2 → 3.47.5. flutter#193899 reports 3.44.6 as clean. Pinning would
  protect any future `toImage` caller, but it is a build-config change across all lanes, so it was
  not done here.
- **Lee's decision, pre-launch noise:** BP and C2 will recur on every Play upload. Native Android
  events bypass the Dart `beforeSend`. The options are a Sentry inbound filter or alert rule
  excluding `device:OnePlus8Pro os.build:QKR1.191246.002` and `os.build:*test-keys*`, or archiving
  the issues.
- **Watchdog:** when sentry_flutter ships Cocoa ≥ 9.5, turn on
  `enableWatchdogTerminationsV2`. Until then, MetricKit `foregroundExitData` (relayed since
  1.28.0) is the real signal for memory and watchdog kills, and it reads zero.
- Ticket 14 note: the 1.29.0 debug files above were uploaded by the old config into the prod
  project. They are the reason CR and the 1.29 Android images resolve, and they say nothing about
  the new per-flavor step.

## Sentry resolution

| Issue | Action | Comment for Sentry |
|---|---|---|
| MEALVANA-ENDURANCE-CR | resolve (in next release) | Impeller GLES crash in BlitCopyBufferToTextureCommandGLES during a background Picture.toImage from the Sentry screenshot recorder. Screenshots are now foreground-only (ticket 21, <sha>), and replay skips background captures in sentry_flutter 9.30.1. Engine bug upstream: https://github.com/flutter/flutter/issues/193899 |
| MEALVANA-ENDURANCE-BP | leave-open: Play pre-launch emulator | x86_64 pre-launch emulator ("OnePlus8Pro", SwiftShader + ndk_translation), PC outside every loaded module (JIT memory), never on a real device. Not app code. Archive or filter (ticket 21) |
| MEALVANA-ENDURANCE-C2 | leave-open: Play pre-launch emulator | Same pre-launch emulator. PC 0x0 on an ARM thread under libndk_translation. Not app code. Archive or filter (ticket 21) |
| MEALVANA-ENDURANCE-B7 | leave-open: upstream https://github.com/getsentry/sentry-dart/pull/3743 | Heuristic false positive. 2 of 3 events within 15 min of a TestFlight beta-review submission. No memory warnings; MetricKit shows 0 foreground watchdog or memory exits for these builds. Needs Cocoa 9.5 watchdog V2, not reachable from sentry_flutter 9.30.1 (ticket 21) |
| MEALVANA-ENDURANCE-DEV-7D | leave-open: dev-only false positive | Local flutter run / Xcode installs (build +1/+5) on Lee's iPhone 14 Plus, stopped by the IDE. Not memory (ticket 21) |
