/// Typed errors for the Vana edge functions (`vana-chat`, `vana-action`,
/// and `jade-chat`, which shares the transport).
///
/// Pre-stream / action HTTP statuses map as (contract 02 §5, 03-backend):
///   401 → [VanaUnauthenticatedException]
///   402 → `InsufficientCreditsException` (jade-chat only; the credits
///          feature owns that type)
///   403 `pro_required` → [ProRequiredException]
///   429 `rate_limited` → [VanaRateLimitedException]
///   any status with `{error:'ai_unavailable'}` → [VanaUnavailableException]
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

/// 403 `{error:'pro_required'}` — the server's entitlement record says no.
/// The UI warns and refreshes the subscription status; the router owns the
/// paywall (ticket 19).
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

/// The AI Gateway refused US, not the athlete: our key's monthly budget
/// hard-stopped, or the key is missing / revoked / forbidden (mp-437).
///
/// The server sends `{error:'ai_unavailable'}` (503 on a unary call, `code`
/// on the NDJSON error line). It is deliberately NOT a 402: the athlete's own
/// budget is fine, so the top-up sheet would be a lie. The UI says "Vana is
/// unavailable right now" (`ContentKeys.mpAiUnavailable`) and nothing else.
///
/// Recognised by its wire code rather than its status, so a gateway 402 that
/// ever leaked through as our status could still never reach the top-up sheet.
class VanaUnavailableException extends VanaException {
  const VanaUnavailableException();

  /// The wire code, one string shared with the server
  /// (`supabase/functions/_shared/ai/gateway_error.ts`).
  static const String code = 'ai_unavailable';

  @override
  String toString() => 'VanaUnavailableException($code)';
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

/// The `meal-photo` function refused a Tester's photo change, and why.
///
/// [code] is the function's own (`not_tester`, `not_an_image`, `invalid_input`,
/// `meal_not_found`, `server_error`); `mealPhotoMessageKey` maps each to a
/// content key. Nothing here carries user-facing copy.
///
/// Lives here rather than beside the repository because [VanaException] is
/// sealed: one base, so a caller can catch every edge-function refusal at once.
class MealPhotoException extends VanaException {
  const MealPhotoException(this.code);

  final String code;

  @override
  String toString() => 'MealPhotoException($code)';
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
