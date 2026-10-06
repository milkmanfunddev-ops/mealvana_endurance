import '../../../shared/services/report/report.dart';
import '../data/vana_exceptions.dart';

/// How a failed Vana operation leaves the app.
///
/// Spec ruling (`.scratch/sentry/spec.md` § Testing Decisions, item 10):
/// unauthenticated and pro-required are Degraded, not Fault. Offline,
/// rate-limited and needs-connection are the other expected outcomes of a
/// remote-ack action; everything else is the server or the app breaking.
extension VanaFailureReport on Report {
  /// The device was offline before a remote-ack [operation] was sent and the
  /// athlete was told. A silent-path branch, so a Note (rule D9).
  Future<void> vanaNeedsConnection(String operation) => note(
    '$operation needs a connection; athlete told',
    area: 'meal_planning',
    data: {'operation': operation},
  );

  /// [operation] is the `UiAction.type` or screen action that failed.
  Future<void> vanaFailure(
    Object error,
    StackTrace stackTrace, {
    required String operation,
  }) {
    final expected = switch (error) {
      NeedsConnectionException() ||
      VanaUnauthenticatedException() ||
      ProRequiredException() ||
      VanaRateLimitedException() ||
      VanaOfflineException() => true,
      _ => false,
    };
    if (expected) {
      return degraded(
        error,
        stackTrace: stackTrace,
        area: 'meal_planning',
        message: '$operation did not complete (${error.runtimeType})',
        extra: {'operation': operation},
      );
    }
    return fault(
      error,
      stackTrace: stackTrace,
      area: 'meal_planning',
      message: '$operation failed',
      extra: {'operation': operation},
    );
  }
}
