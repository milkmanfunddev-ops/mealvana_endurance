import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Sentry session-replay is either fully armed or fully off for a given launch.
/// These are the only two values [resolveReplayOnErrorSampleRate] ever returns —
/// see the file docs below for why the in-between values are a trap.
const double kReplayArmed = 1.0;
const double kReplayOff = 0.0;

/// The share of installs placed in the armed cohort.
///
/// This is a direct battery-vs-visibility dial: the armed fraction is also the
/// fraction of users who pay the recorder's CPU cost. Raise it to see more,
/// lower it to burn less. 0.1 was chosen as the smallest cohort that still
/// surfaces a recurring bug within a few days at our tester count.
const double kReplayArmedCohortFraction = 0.1;

/// Per-install cohort assignment. Bump the suffix to re-roll every install into
/// a fresh cohort (e.g. if 0.1 turns out to be too small to catch anything).
const String _cohortKey = 'sentry_replay_cohort_armed_v1';

/// Resolves `options.replay.onErrorSampleRate` for this launch.
///
/// ## Why this exists (2026-07-16)
///
/// A beta tester reported their phone running hot and draining battery. The
/// cause is Sentry session replay, and the mechanism is not obvious, so it is
/// written down here rather than rediscovered:
///
/// `onErrorSampleRate` reads like a sampling rate. It is not one — not in the
/// way that matters for battery. In sentry-cocoa the gate that decides whether
/// the recorder starts at all is an exact comparison against zero
/// (`SentrySessionReplayIntegration.m`, and note our `sessionSampleRate` is 0
/// so `_startedAsFullSession` is always false):
///
/// ```objc
/// _startedAsFullSession = [self shouldReplayFullSession:_replayOptions.sessionSampleRate];
/// if (!_startedAsFullSession && _replayOptions.onErrorSampleRate == 0) {
///     return;   // recorder never starts
/// }
/// [self runReplayForAvailableWindow];
/// ```
///
/// So ANY non-zero value — 1.0, 0.1, 0.001 — starts the recorder, which then
/// runs continuously for the whole foreground session, capturing frames into a
/// rolling ~30s buffer via a display link. The `onErrorSampleRate` dice-roll
/// happens later, at error time (`sessionReplayShouldCaptureReplayForError`),
/// and only decides whether the already-recorded buffer gets uploaded.
///
/// The consequence is the trap: setting `onErrorSampleRate = 0.1` costs 100% of
/// the battery and throws away 90% of the replays. It is strictly worse than
/// either 1.0 or 0.0.
///
/// This helper therefore samples in Dart instead, per install: an armed install
/// gets 1.0 (identical behaviour to before — the native SDK records and every
/// error ships its 30s video to Sentry), an unarmed install gets 0.0 (recorder
/// never starts, zero idle cost). Sentry still produces the videos; Dart only
/// decides whether to switch the recorder on. At a 10% cohort the cost is ~10%
/// of what it was, for ~10% of the replay coverage — a linear trade, where
/// Sentry's own knob offers none.
///
/// ## Why not just fix the SDK
///
/// The underlying overhead is upstream and unfixed: sentry-cocoa #5263
/// ("Session Replay should use runloop observers") is open, and the maintainer's
/// own description of #6885 is that replay "uses a display link ... this leads
/// to high overhead because even when the UI is not changing session replay is
/// recording a frame". No `sentry_flutter` release resolves it — even the latest
/// (9.24.0) pins sentry-cocoa 8.58.3, and Flutter has never moved to the 9.x
/// line where fixes are landing. Revisit this whole file when it does; if the
/// idle cost goes away, the right answer is to return to a flat 1.0.
///
/// ## Cohort, not coin-flip
///
/// The roll is persisted, so an armed install stays armed. A per-session roll
/// would scatter coverage across users and leave every reproduction half-
/// captured; a stable cohort gives complete session histories for a known
/// subset, which is what actually makes a replay useful when debugging.
///
/// Deliberately NOT wired to internal-vs-external: there is no `isInternal` on
/// [AppConfig] today (only `devModeEnabled` / `appEnvironment`), and inventing
/// one here would be guesswork. If you want full-fidelity video on team devices
/// and a thin sample everywhere else, add that signal and pass a per-cohort
/// [armedFraction] — the shape of this function already supports it.
///
/// [analyticsConsented] short-circuits everything: replay is a rolling recording
/// of the user's screen and rides the same consent gate as Mixpanel. A user who
/// has not consented is never armed and is never even assigned a cohort — see
/// `analytics_consent.dart`.
Future<double> resolveReplayOnErrorSampleRate(
  SharedPreferences prefs, {
  required bool analyticsConsented,
  double armedFraction = kReplayArmedCohortFraction,
  Random? random,
}) async {
  // Fail closed, and assign no cohort. Assigning one here would burn the roll
  // for a user we must not record anyway; leaving it unset means they are rolled
  // fairly if they later consent.
  if (!analyticsConsented) return kReplayOff;

  final existing = prefs.getBool(_cohortKey);
  if (existing != null) return existing ? kReplayArmed : kReplayOff;

  final armed = (random ?? Random()).nextDouble() < armedFraction;
  await prefs.setBool(_cohortKey, armed);
  return armed ? kReplayArmed : kReplayOff;
}
