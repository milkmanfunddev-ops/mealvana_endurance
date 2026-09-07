/// Typed errors for the Vana edge functions (`vana-chat`, `vana-action`,
/// and `jade-chat`, which shares the transport).
///
/// Pre-stream / action HTTP statuses map as (contract 02 §5, 03-backend):
///   401 → [VanaUnauthenticatedException]
///   402 → `InsufficientCreditsException` (jade-chat only; the credits
///          feature owns that type)
///   403 `pro_required` → [ProRequiredException]
///   429 `rate_limited` → [VanaRateLimitedException]
///   anything else non-2xx → [VanaServerException]
///   socket / DNS failure → [VanaOfflineException]
///
/// The presentation layer maps each to a content key; nothing here carries
/// user-facing copy.
library;

/// Base for every Vana transport error so callers can catch one type.
sealed class VanaException implements Exception {
  const VanaException();
}

/// No Supabase session, or the server answered 401.
class VanaUnauthenticatedException extends VanaException {
  const VanaUnauthenticatedException([this.message = 'unauthenticated']);

  final String message;

  @override
  String toString() => 'VanaUnauthenticatedException: $message';
}

/// 403 `{error:'pro_required'}` — the user is not entitled to Pro. The UI
/// routes to `/pro`.
class ProRequiredException extends VanaException {
  const ProRequiredException([this.reason = 'pro_required']);

  /// The server's `error` field (`pro_required`, or a more specific reason).
  final String reason;

  @override
  String toString() => 'ProRequiredException: $reason';
}

/// 429 `{error:'rate_limited', retry_after_seconds}`.
class VanaRateLimitedException extends VanaException {
  const VanaRateLimitedException({required this.retryAfterSeconds});

  /// Seconds until the bucket refills; the UI says "Give me N seconds".
  final int retryAfterSeconds;

  @override
  String toString() =>
      'VanaRateLimitedException(retryAfterSeconds: $retryAfterSeconds)';
}

/// The device appears to be offline or the connection was refused.
class VanaOfflineException extends VanaException {
  const VanaOfflineException(this.cause);

  final Object cause;

  @override
  String toString() => 'VanaOfflineException: $cause';
}

/// Any other non-2xx response (400 invalid_body, 500, …).
class VanaServerException extends VanaException {
  const VanaServerException(this.statusCode, this.body, {this.error});

  final int statusCode;

  /// Raw response body (for logs).
  final String body;

  /// The server's `error` field when the body was `{error: ...}` JSON.
  final String? error;

  @override
  String toString() => 'VanaServerException($statusCode): ${error ?? body}';
}

/// Thrown by remote-ack controller operations (`pick_meals`, `swap_meal`,
/// `confirm_plan`, `new_plan`, `log_from_plan`, `plan_day`) when the device
/// is offline, before anything is sent. Local-first operations never throw
/// this — they write Drift and replay later.
class NeedsConnectionException extends VanaException {
  const NeedsConnectionException(this.operation);

  /// The `UiAction.type` that needed a connection.
  final String operation;

  @override
  String toString() => 'NeedsConnectionException($operation)';
}
