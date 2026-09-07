/// A cookable duration found in a method step.
class StepTimer {
  const StepTimer({
    required this.label,
    required this.seconds,
    required this.index,
  });

  /// The matched text, e.g. `"10-12 mins"`.
  final String label;
  final int seconds;

  /// Offset of the match in the step text.
  final int index;

  Duration get duration => Duration(seconds: seconds);

  @override
  bool operator ==(Object other) =>
      other is StepTimer &&
      other.label == label &&
      other.seconds == seconds &&
      other.index == index;

  @override
  int get hashCode => Object.hash(label, seconds, index);

  @override
  String toString() => 'StepTimer($label, ${seconds}s @ $index)';
}

/// Timers parsed from cooking-mode step text. Port of `findDurations` /
/// `clock` in the prototype's `routes/food.cook_.$id.tsx`.
class CookingStepTimers {
  const CookingStepTimers._();

  static final RegExp _re = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:(?:–|—|-|to)\s*(\d+(?:\.\d+)?)\s*)?(seconds?|secs?|minutes?|mins?|hours?|hrs?)\b',
    caseSensitive: false,
  );

  static const Map<String, int> _unitSeconds = {
    'sec': 1,
    'second': 1,
    'min': 60,
    'minute': 60,
    'hr': 3600,
    'hour': 3600,
  };

  static const int minSeconds = 5;
  static const int maxSeconds = 12 * 3600;
  static const int maxPerStep = 3;

  /// Pull cookable durations out of a step: "5 minutes", "10-12 mins",
  /// "about 1 hour", "90 seconds".
  ///
  /// A range takes the upper bound — better to check early than to walk away
  /// from an under-timer. Durations outside 5 s–12 h are ignored, duplicates
  /// (same seconds) are collapsed to the first, and at most three are
  /// returned per step.
  static List<StepTimer> findDurations(String text) {
    final out = <StepTimer>[];
    for (final m in _re.allMatches(text)) {
      var unit = m.group(3)!.toLowerCase();
      unit = unit.replaceFirst(RegExp(r's$'), '');
      unit = unit.replaceFirst(RegExp(r'^secs?$'), 'sec');
      unit = unit.replaceFirst(RegExp(r'^mins?$'), 'min');
      unit = unit.replaceFirst(RegExp(r'^hrs?$'), 'hr');
      final per =
          _unitSeconds[unit] ??
          _unitSeconds[unit.substring(0, unit.length < 3 ? unit.length : 3)];
      if (per == null) continue;
      final hi = double.tryParse(m.group(2) ?? m.group(1)!);
      // 600 hours of anything is a parse error.
      if (hi == null || !hi.isFinite || hi <= 0 || hi > 600) continue;
      final seconds = _jsRound(hi * per);
      if (seconds < minSeconds || seconds > maxSeconds) continue;
      out.add(
        StepTimer(label: m.group(0)!.trim(), seconds: seconds, index: m.start),
      );
    }
    final seen = <int>{};
    final unique = [
      for (final d in out)
        if (seen.add(d.seconds)) d,
    ];
    return unique.length > maxPerStep ? unique.sublist(0, maxPerStep) : unique;
  }

  /// `m:ss`, or `h:mm:ss` once there is an hour component.
  static String clock(int seconds) {
    final n = seconds < 0 ? 0 : seconds;
    final h = n ~/ 3600;
    final m = (n % 3600) ~/ 60;
    final s = n % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
  }

  /// `Math.round` semantics (halves toward +∞) so the port stays exact.
  static int _jsRound(double v) => (v + 0.5).floor();
}
