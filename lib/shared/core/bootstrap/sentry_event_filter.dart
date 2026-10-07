import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../services/report/expected_failures.dart';

/// The one `beforeSend` every flavour entry point installs.
///
/// Three rules, in order:
/// 1. Test-runner failures leaking from integration/Patrol runs are dropped.
/// 2. Expected failures (the allow-list in `expected_failures.dart`) that
///    reached the SDK without going through `Report` (SDK-reported HTTP
///    failures, uncaught throws) are downgraded to `warning` and tagged
///    `expected_failure`, never dropped: Lee counts them.
/// 3. In release builds, debug and info events are dropped, except device
///    diagnostics (see [isDiagnosticEvent]). Structured logs are not events
///    and are untouched by this.
SentryEvent? filterSentryEvent(SentryEvent event, {bool? debugBuild}) {
  final text = describeEvent(event);

  if (isTestOnlyFailure(text)) return null;

  final httpFailure = classifyHandledHttpFailure(event);
  final expected = classifyExpectedFailure(text) ?? httpFailure;
  if (expected != null && _isErrorOrUnset(event.level)) {
    // One event is never both: a downgraded event is Degraded, whatever
    // Report tagged before the SDK unwrapped an exception chain it did not see.
    final endpoint = httpFailure == null ? null : _endpointName(event);
    event.level = SentryLevel.warning;
    event.tags = {
      ...?event.tags,
      'expected_failure': expected.tag,
      'severity': 'degraded',
      // Names the endpoint (edge function or table) the reason is about.
      if (endpoint != null) 'http_endpoint': endpoint,
    };
  }

  final isDebugBuild = debugBuild ?? kDebugMode;
  if (!isDebugBuild &&
      !isDiagnosticEvent(event) &&
      (event.level == SentryLevel.debug || event.level == SentryLevel.info)) {
    return null;
  }

  return event;
}

/// An unset level is sent as `error` by Sentry, so it counts as one here.
bool _isErrorOrUnset(SentryLevel? level) =>
    level == null || level == SentryLevel.error || level == SentryLevel.fatal;

/// Returns `true` when [event] is a device diagnostic that must survive the
/// `beforeSend` level filter.
///
/// MetricKit diagnostic payloads (`MXDiagnosticPayload` hang and
/// CPU-exception reports, carrying native call stacks) arrive through
/// `MetricKitRelay` as `Report.degraded` warning events tagged `metrickit`
/// (ticket 11). Until 2026-10-06 they were captured natively at *info* level
/// and every flavour's `beforeSend` dropped them in release builds, so the
/// highest-value real-device signal we have was captured and then silently
/// thrown away in production. The exemption stays so the tag, not the level,
/// decides. Metric payloads are structured logs now and never reach this
/// filter.
///
/// Keyed on the `metrickit` tag `MetricKitRelay` sets on every diagnostic.
/// If that tag is ever renamed, rename it here too or prod goes blind again —
/// silently, because dropped events leave no trace.
bool isDiagnosticEvent(SentryEvent event) =>
    event.tags?.containsKey('metrickit') ?? false;

/// Everything the needles are matched against: throwable, message and every
/// exception's type and value.
String describeEvent(SentryEvent event) {
  final buffer = StringBuffer();

  final throwable = event.throwable;
  if (throwable != null) {
    buffer
      ..write(throwable.runtimeType)
      ..write(' ')
      ..write(throwable.toString());
  }

  final message = event.message?.formatted;
  if (message != null) buffer.write(message);

  for (final exception in event.exceptions ?? const <SentryException>[]) {
    if (exception.type != null) buffer.write(exception.type);
    if (exception.value != null) buffer.write(exception.value);
  }

  return buffer.toString();
}

/// Classifies an HTTP failure the SDK's own HTTP layer reported
/// (`SentryHttpClientError`, `mechanism: SentryHttpClient`) as expected, or
/// `null` when it stays a Fault.
///
/// These events are captured before app code ever sees the response, so a
/// caller that already degrades cannot downgrade them itself. The rules are
/// scoped per endpoint and status on purpose: a blanket SentryHttpClientError
/// downgrade would also hide the 500s from edge functions that do NOT degrade
/// (ticket 19).
///
/// - `get-weather-forecast`, any status: the caller substitutes a default
///   forecast (MEALVANA-ENDURANCE-AH / DEV-5D / DEV-5C). Its 546 is a Supabase
///   worker limit; the server still owes a timeout on its upstream call.
/// - 502 from `garmin-backfill` or `kroger`: the function's upstream (Garmin's
///   backfill API, Kroger) failed and the function said so. Since ticket 19
///   garmin-backfill answers 502 only for a real Garmin outage (a dead token is
///   409, a Garmin throttle 429), and the app retries the backfill next
///   session. Kroger's `kroger_unavailable` shows its own message.
///   (MEALVANA-ENDURANCE-AA / AB, DEV-5P / DEV-9M / DEV-8H.)
/// - 504 from the Supabase project host on PostgREST (`/rest/v1`) or GoTrue
///   (`/auth/v1`): a gateway timeout. Edge functions (`/functions/v1`) are
///   deliberately NOT covered: a 504 there is our own handler running past the
///   platform limit, which stays a Fault. Prod logs showed
///   Supabase's gateway (5 s blips on 2026-09-14, a row-lock pile-up on
///   `users` on 2026-09-20) and 504s that never reached Supabase at all (an
///   athlete's network on 2026-09-25). (B5, BM, C0, C1, C3, C4.)
ExpectedFailure? classifyHandledHttpFailure(SentryEvent event) {
  if (!_isSdkHttpFailure(event)) return null;
  final url = event.request?.url;
  if (url == null) return null;

  if (url.contains('get-weather-forecast')) {
    return ExpectedFailure.handledFallback;
  }

  final status = _statusCode(event);
  if (status == 502 && url.contains('/functions/v1/garmin-backfill')) {
    return ExpectedFailure.upstreamUnavailable;
  }
  if (status == 504 &&
      _isSupabaseHost(url) &&
      (url.contains('/rest/v1/') || url.contains('/auth/v1/'))) {
    return ExpectedFailure.gatewayTimeout;
  }
  return null;
}

/// Only the SDK's own HTTP-layer report. A real exception thrown from our
/// code that happens to mention an endpoint still comes through.
bool _isSdkHttpFailure(SentryEvent event) =>
    (event.throwable?.toString() ?? '').contains('SentryHttpClientError') ||
    (event.exceptions ?? const <SentryException>[]).any(
      (e) => (e.type ?? '').contains('SentryHttpClientError'),
    );

final RegExp _statusInMessage = RegExp(r'status code: (\d{3})');

/// The response status: the response context when the SDK attached one, else
/// the number in "HTTP Client Error with status code: NNN".
int? _statusCode(SentryEvent event) {
  final fromContext = event.contexts.response?.statusCode;
  if (fromContext != null) return fromContext;
  final match = _statusInMessage.firstMatch(describeEvent(event));
  return match == null ? null : int.tryParse(match.group(1)!);
}

bool _isSupabaseHost(String url) =>
    (Uri.tryParse(url)?.host ?? '').endsWith('.supabase.co');

/// `garmin-backfill` for `/functions/v1/garmin-backfill`, `users` for
/// `/rest/v1/users`, `token` for `/auth/v1/token`.
String? _endpointName(SentryEvent event) {
  final url = event.request?.url;
  if (url == null) return null;
  final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
  return segments.isEmpty ? null : segments.last;
}
