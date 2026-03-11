import 'dart:async';

/// A reusable debouncer that delays execution until a pause in calls.
///
/// Consolidates the Timer-based debounce pattern used across the codebase.
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 500)});

  final Duration duration;
  Timer? _timer;

  /// Runs [action] after [duration] of inactivity, cancelling any pending call.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Cancels any pending debounced action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Whether a debounced action is currently pending.
  bool get isPending => _timer?.isActive ?? false;

  /// Cancels the timer and releases resources. Call from [State.dispose].
  void dispose() {
    cancel();
  }
}
