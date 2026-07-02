import 'package:sentry_flutter/sentry_flutter.dart';

/// Returns `true` when [event] is known low-signal noise that should be dropped
/// in `beforeSend` rather than shipped to Sentry.
///
/// Centralised so every flavour entrypoint (main / main_dev / main_prod /
/// main_web) filters identically. Categories dropped:
/// - Offline / DNS lookup failures (the device simply has no connectivity).
/// - Transient TLS / connection resets (not actionable, retried by callers).
/// - User-cancelled social sign-ins (expected user action, not an error).
/// - Debug-only Flutter assertions that never fire in release builds.
/// - Test-runner failures leaking from integration/Patrol runs.
///
/// See the 2026-07-01 Sentry audit for the originating issue IDs.
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
  // --- User-cancelled sign-in (expected user action, not an error) ---
  'Sign-In was cancelled',
  'Sign-In cancelled',
  'SignInWithAppleAuthorizationException',
  'AuthorizationErrorCode.unknown',
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
