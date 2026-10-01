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

      // Native-side observations, written by AppDelegate into the same
      // UserDefaults store (shared_preferences prefixes keys with "flutter.").
      // These answer whether our delegate assignment actually TOOK and whether
      // anything re-claimed it afterwards — the theory-free version of the
      // question four candidates have now failed to settle.
      for (final k in const [
        'ios_launch_options',
        'ios_delegate_at_launch',
        'ios_delegate_after_delay',
      ]) {
        final v = prefs.getString(k);
        if (v != null) _events.insert(0, 'native $k=$v');
      }
      _persist();
    } catch (_) {
      // A recorder that breaks the app it is recording is worse than no
      // recorder. Memory-only from here.
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
}
