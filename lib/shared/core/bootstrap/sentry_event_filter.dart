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

  final expected =
      classifyExpectedFailure(text) ??
      (_isHandledWeatherRequestFailure(event)
          ? ExpectedFailure.handledFallback
          : null);
  if (expected != null && _isErrorOrUnset(event.level)) {
    // One event is never both: a downgraded event is Degraded, whatever
    // Report tagged before the SDK unwrapped an exception chain it did not see.
    event.level = SentryLevel.warning;
    event.tags = {
      ...?event.tags,
      'expected_failure': expected.tag,
      'severity': 'degraded',
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

/// True for SDK-reported HTTP failures against `get-weather-forecast`, whose
/// caller already substitutes a default forecast.
///
/// Weather is decorative and already degrades to a default forecast in
/// `WeatherService.getWeatherForecast`'s catch. The events still reach Sentry
/// because the SDK's HTTP integration reports the failed request itself
/// (`mechanism: SentryHttpClient`) before app code ever sees it, which is why
/// 546s from get-weather-forecast show up despite the graceful fallback
/// (MEALVANA-ENDURANCE-AH / DEV-5D / DEV-5C). Scoped to this one endpoint on
/// purpose: a blanket SentryHttpClientError downgrade would also hide the 500s
/// and 502s from edge functions that do NOT degrade gracefully.
///
/// NOTE: 546 is a Supabase Edge *worker limit* — the function was killed for
/// exceeding memory/CPU. Downgrading the client report does not fix the
/// server; get-weather-forecast still needs a timeout on its upstream call.
bool _isHandledWeatherRequestFailure(SentryEvent event) {
  final url = event.request?.url;
  if (url == null || !url.contains('get-weather-forecast')) return false;

  // Only the SDK's own HTTP-layer report. A real exception thrown from our
  // code that happens to mention this endpoint should still come through.
  return (event.throwable?.toString() ?? '').contains(
        'SentryHttpClientError',
      ) ||
      (event.exceptions ?? const <SentryException>[]).any(
        (e) => (e.type ?? '').contains('SentryHttpClientError'),
      );
}
