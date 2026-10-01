import 'package:shared_preferences/shared_preferences.dart';

/// A black-box recorder for the cold-start notification path.
///
/// WHY THIS EXISTS. The killed-app deep link has failed three device rounds and
/// produced ZERO diagnostic lines, because the only build that can relaunch
/// standalone from a tap on hardware is `--release`, and in release `print()`
/// reaches neither an attached console nor `flutter logs`. The bug is therefore
/// only observable where we cannot watch it. The simulator cannot stand in
/// either: it delivers the notification fine, but tapping one through automated
/// UI is unreliable, so the launch-by-tap case never happens there.
///
/// So the app records its own launch and keeps the tape. Every cold start
/// appends to an in-memory trail that is persisted as it grows; on the next
/// launch the previous tape is available for printing, and in dev builds the
/// CURRENT tape is shown on screen a few seconds in, so the verdict can be read
/// on the device with nothing attached.
///
/// This is the DI-25 lesson a third time: a path whose only evidence is a
/// notification that may or may not appear needs to write down what it did.
class LaunchTrail {
  LaunchTrail._();

  static const _currentKey = 'launch_trail_current';
  static const _previousKey = 'launch_trail_previous';

  static final List<String> _events = [];
  static SharedPreferences? _prefs;
  static String? _previous;

  /// Native-side observations, written by AppDelegate into the same UserDefaults
  /// store (shared_preferences prefixes keys with "flutter.").
  ///
  /// Some of these are written DURING a session, not at launch — a foreground
  /// delivery or a backgrounded tap — so they are re-read on resume by
  /// [pullNative], not only once by [begin].
  static const _nativeKeys = [
    'ios_launch_options',
    'ios_delegate_at_launch',
    'ios_delegate_after_delay',
    'ios_legacy_launch_class',
    'ios_legacy_launch_userinfo',
    'ios_legacy_launch_payload',
    'ios_un_response_payload',
    'ios_legacy_resume_payload',
    'ios_un_willpresent',
  ];

  /// The last value taped for each native key, so a resume only adds a line
  /// when something actually changed.
  static final Map<String, String> _nativeSeen = {};

  /// Roll the last tape aside and start a fresh one. Call once, early.
  ///
  /// Events recorded before this runs are not lost: they buffer in memory and
  /// are written by the first [add] after prefs arrive.
  static Future<void> begin() async {
    if (_prefs != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _previous = prefs.getString(_currentKey);
      if (_previous != null && _previous!.isNotEmpty) {
        await prefs.setString(_previousKey, _previous!);
      }
      _prefs = prefs;

      for (final k in _nativeKeys) {
        final v = prefs.getString(k);
        if (v != null) {
          _nativeSeen[k] = v;
          _events.insert(0, 'native $k=$v');
        }
      }
      _persist();
    } catch (_) {
      // A recorder that breaks the app it is recording is worse than no
      // recorder. Memory-only from here.
    }
  }

  /// Re-read the native keys and tape anything that changed since last look.
  ///
  /// WHY A SECOND READ EXISTS. [begin] runs once, at launch. But a notification
  /// that arrives while the app is already open — a foreground delivery, or a
  /// backgrounded tap — is written by AppDelegate AFTER that read, so a
  /// launch-only read can never show it. This is called on resume, just before
  /// the trail dialog, so the dev build can see what the OS did while it was
  /// away.
  static void pullNative() {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      for (final k in _nativeKeys) {
        final v = prefs.getString(k);
        if (v == null || v.isEmpty) continue;
        if (_nativeSeen[k] == v) continue;
        _nativeSeen[k] = v;
        add('native $k=$v');
      }
    } catch (_) {
      /* best effort — a recorder must not break what it records */
    }
  }

  /// Append one line to this launch's tape.
  static void add(String line) {
    final t = DateTime.now().toIso8601String();
    _events.add('${t.substring(11, 23)} $line');
    // ignore: avoid_print
    print('[LAUNCH] $line');
    _persist();
  }

  static void _persist() {
    final prefs = _prefs;
    if (prefs == null || _events.isEmpty) return;
    try {
      prefs.setString(_currentKey, _events.join('\n'));
    } catch (_) {
      /* best effort */
    }
  }

  /// This launch's tape, newest last.
  static String get text => _events.join('\n');

  /// The tape from the launch before this one — the one that mattered, when
  /// the interesting launch was the one nobody could watch.
  static String? get previous => _previous;

  static bool get isEmpty => _events.isEmpty;

  /// Whether this tape has anything to do with a NOTIFICATION.
  ///
  /// Gates the dev-only on-screen dialog. Without this it fired on every dev
  /// launch, because AppDelegate's instrumentation always writes at least
  /// `ios_launch_options`, so the tape is never empty on iOS. A modal
  /// AlertDialog four seconds into every launch is not just noise: it put a
  /// modal route over the login screen and made the log-in button
  /// non-hit-testable, which failed every authenticating Patrol flow
  /// (integration gate, 2026-10-01). The iOS keyboard cannot do that — it is
  /// not a Flutter widget — but a modal route can, and did.
  ///
  /// So the dialog now appears only for the case it was built for: a launch or
  /// resume that actually carried a notification. An ordinary launch records
  /// its tape silently and shows nothing.
  static bool get hasNotificationEvidence {
    final tape = text;
    return tape.contains('payload=') ||
        tape.contains('willpresent') ||
        tape.contains('routing id=') ||
        tape.contains('HELD ') ||
        tape.contains('REPLAY ') ||
        tape.contains('navigated(');
  }

  /// How many lines the tape holds — used to tell "nothing new since I last
  /// looked" from "a tap just added lines".
  static int get length => _events.length;
}
