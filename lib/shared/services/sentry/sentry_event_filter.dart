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
/// Returns `true` when [event] is a device diagnostic that must survive the
/// `beforeSend` level filter.
///
/// MetricKit payloads are captured at *info* level on purpose — see
/// `MetricKitReporter.forward` in `ios/Runner/MetricKitReporter.swift`, which
/// calls `scope.setLevel(.info)` so hang reports never page anyone. But every
/// flavour's `beforeSend` drops all info events in release builds, so the
/// highest-value real-device signal we have — `MXDiagnosticPayload` hang and
/// CPU-exception reports, carrying native call stacks — was captured and then
/// silently thrown away in production. Diagnostics are therefore exempt from
/// the level drop.
///
/// Exempt from the *level* filter only: diagnostics still go through
/// [isSentryNoise] like everything else.
///
/// Keyed on the `metrickit` tag that `MetricKitReporter` sets on every payload
/// it forwards. If that tag is ever renamed, rename it here too or prod goes
/// blind again — silently, because dropped events leave no trace.
bool isDiagnosticEvent(SentryEvent event) =>
    event.tags?.containsKey('metrickit') ?? false;

bool isSentryNoise(SentryEvent event) {
  // Weather is decorative and already degrades to a default forecast in
  // WeatherService.getWeatherForecast's catch. The events still reach Sentry
  // because the SDK's HTTP integration reports the failed request itself
  // (`mechanism: SentryHttpClient`) before app code ever sees it — which is
  // why 546s from get-weather-forecast show up despite the graceful fallback
  // (MEALVANA-ENDURANCE-AH / DEV-5D / DEV-5C).
  //
  // Scoped to this one endpoint on purpose: a blanket SentryHttpClientError
  // drop would also hide the 500s and 502s from edge functions that do NOT
  // degrade gracefully, and those are real.
  //
  // NOTE: 546 is a Supabase Edge *worker limit* — the function was killed for
  // exceeding memory/CPU. Filtering the client noise does not fix the server;
  // get-weather-forecast still needs a timeout on its upstream call.
  if (_isHandledWeatherRequestFailure(event)) return true;

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

/// True for SDK-reported HTTP failures against `get-weather-forecast`, whose
/// caller already substitutes a default forecast.
bool _isHandledWeatherRequestFailure(SentryEvent event) {
  final url = event.request?.url;
  if (url == null || !url.contains('get-weather-forecast')) return false;

  // Only drop the SDK's own HTTP-layer report. A real exception thrown from
  // our code that happens to mention this endpoint should still come through.
  final isHttpClientReport =
      (event.throwable?.toString() ?? '').contains('SentryHttpClientError') ||
      (event.exceptions ?? const <SentryException>[]).any(
        (e) => (e.type ?? '').contains('SentryHttpClientError'),
      );
  return isHttpClientReport;
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
