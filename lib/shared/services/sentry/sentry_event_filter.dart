import 'package:sentry_flutter/sentry_flutter.dart';

/// Returns `true` when [event] is known low-signal noise that should be dropped
/// in `beforeSend` rather than shipped to Sentry.
///
/// Centralised so every flavour entrypoint (main / main_dev / main_prod /
/// main_web) filters identically. Categories dropped:
/// - Offline / DNS lookup failures (the device simply has no connectivity).
/// - Transient TLS / connection resets (not actionable, retried by callers).
/// - Sockets torn down mid-request by app backgrounding/suspension.
/// - User-cancelled social sign-ins (expected user action, not an error).
/// - Expected user-input errors (e.g. a mistyped login password).
/// - Debug-only Flutter assertions that never fire in release builds.
/// - Test-runner failures leaking from integration/Patrol runs.
///
/// See the 2026-07-01 and 2026-07-11 Sentry audits for the originating issue
/// IDs (search this file's git history / MEALVANA-ENDURANCE-DEV-* shortIds).
bool isSentryNoise(SentryEvent event) {
  final buffer = StringBuffer();

  final throwable = event.throwable;
  if (throwable != null) buffer.write(throwable.toString());

  final message = event.message?.formatted;
  if (message != null) buffer.write(message);

  for (final exception in event.exceptions ?? const <SentryException>[]) {
    if (exception.type != null) buffer.write(exception.type);
    if (exception.value != null) buffer.write(exception.value);
  }

  final text = buffer.toString();
  if (text.isEmpty) return false;

  for (final needle in _noiseNeedles) {
    if (text.contains(needle)) return true;
  }
  return false;
}

const List<String> _noiseNeedles = <String>[
  // --- Offline / DNS lookup failures (device has no connectivity) ---
  'Failed host lookup',
  'nodename nor servname provided',
  'errno = 8',
  'SocketException',
  // --- Transient TLS / connection resets (not actionable) ---
  'HandshakeException',
  'Connection terminated during handshake',
  'Connection closed before full header',
  'TimeoutException',
  // 2026-07-11 audit (DEV-4W): `http.ClientException` wraps a plain
  // `Future.timeout()` as "Operation timed out" — does NOT contain the
  // string "TimeoutException", so it needs its own needle.
  'Operation timed out',
  // 2026-07-11 audit (DEV-5N): HttpException during response-body streaming
  // phrases the same connection-drop as "Connection closed while receiving
  // data" — distinct string from the header-phase "before full header" needle
  // above, so both must be listed.
  'Connection closed while receiving data',
  // 2026-07-11 audit (DEV-5M, DEV-5B): OS tears down the socket out from
  // under an in-flight request when the app is backgrounded/suspended
  // (auth token refresh, edge-function calls). Not actionable, not a bug.
  'Bad file descriptor',
  // --- User-cancelled sign-in (expected user action, not an error) ---
  'Sign-In was cancelled',
  'Sign-In cancelled',
  'SignInWithAppleAuthorizationException',
  'AuthorizationErrorCode.unknown',
  // --- User input errors (expected, not actionable) ---
  // 2026-07-11 audit (DEV-5Q): mistyped password on manual login. Supabase
  // reports this as AuthApiException(code: invalid_credentials); it's a user
  // mistake, not an app bug.
  'Invalid login credentials',
  // --- Debug-only Flutter assertions (never fire in release builds) ---
  'ink splashes may be invisible',
  // --- Benign Flutter-web engine DOM teardown races (navigation/hot restart) ---
  "reading 'removeChild'",
  "reading 'insertBefore'",
  // --- Test-runner failures leaking from integration/Patrol runs ---
  'TestFailure',
  'matching candidate',
  'could not find any matching widgets',
  'Required widget not found',
];
