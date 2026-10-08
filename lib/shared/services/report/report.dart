/// `Report`: the one service through which every error, warning and
/// silent-path note leaves the app (glossary: CONTEXT.md § Error reporting;
/// spec: `.scratch/sentry/spec.md`).
///
/// Severity ladder and where each rung goes:
///
/// | Call        | Sentry                                   | Mixpanel          | Console (debug) |
/// |-------------|------------------------------------------|-------------------|-----------------|
/// | `fault`     | event, level `error`                     | `error_reported`  | yes             |
/// | `degraded`  | event, level `warning`                   | `error_reported`  | yes             |
/// | `note`      | breadcrumb; + `warning` event in D9 areas | no                | yes             |
/// | `info`      | structured log                           | no                | yes             |
/// | `debug`     | structured log                           | no                | yes             |
///
/// `fault` downgrades itself to Degraded when the error matches the
/// expected-failure allow-list (`expected_failures.dart`) and drops test-only
/// exceptions outright. Nothing else in `lib/` may import the Sentry SDK except
/// this file and the bootstrap; the source guard test enforces that.
///
/// Some expected outcomes leave no event at all (ticket 41): network weather
/// at a site that already falls back ([ExpectedOutcomes.faultUnlessWeather])
/// and an athlete's own turn in the auth flows ([ExpectedOutcomes.
/// noteExpected]) become breadcrumbs, and each sends one plain
/// [expectedFailureEvent] to Mixpanel so they are still counted.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../analytics/analytics_tracker.dart';
import 'report_log.dart';
import 'expected_failures.dart';

export 'expected_failures.dart' show ExpectedFailure;
export 'report_log.dart';

/// Areas whose Notes are promoted to a warning event (rule D9).
const Set<String> promotedNoteAreas = <String>{
  'startup',
  'push',
  'payments',
  'sync',
};

/// The Mixpanel event name every Fault and Degraded fans out to.
const String errorReportedEvent = 'error_reported';

/// Severity of a report as it left the service. The value is the `severity`
/// tag on the Sentry event and the `severity` property on Mixpanel.
enum ReportSeverity {
  fault('fault'),
  degraded('degraded'),
  note('note');

  const ReportSeverity(this.tag);

  final String tag;
}

/// A Fault raised from a message alone (legacy `logger.error(message)` with no
/// exception object). `toString()` is the message so Sentry groups by it.
class LoggedFault implements Exception {
  const LoggedFault(this.message, {this.context});

  final String message;
  final String? context;

  /// The message with ids, numbers and hex blobs replaced, so one fault
  /// written as `'No plan for event: $eventId'` is one Sentry issue, not one
  /// per event. Used as the event fingerprint unless the caller sets one.
  String get groupingKey => message
      .replaceAll(_uuid, '<id>')
      .replaceAll(_hex, '<hex>')
      .replaceAll(_number, '<n>');

  static final RegExp _uuid = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );
  static final RegExp _hex = RegExp(r'\b[0-9a-fA-F]{16,}\b');
  static final RegExp _number = RegExp(r'\b\d+(\.\d+)?\b');

  @override
  String toString() => message;
}

/// Public interface. `SentryReport` is the real one; `NoopReport` is for tests
/// and consent-off builds.
abstract class Report {
  /// Something broke that should never break. Sentry `error`, unless the
  /// error is an expected failure (then Degraded) or test-only (dropped).
  Future<void> fault(
    Object error, {
    StackTrace? stackTrace,
    String? area,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    String? message,
    List<String>? fingerprint,
  });

  /// An expected but bad condition the app can live with. Sentry `warning`.
  Future<void> degraded(
    Object error, {
    StackTrace? stackTrace,
    String? area,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    String? message,
    List<String>? fingerprint,
  });

  /// A silent path took a branch. Breadcrumb on the next event; promoted to a
  /// `warning` event when [area] is one of [promotedNoteAreas].
  Future<void> note(String message, {String? area, Map<String, dynamic>? data});

  /// Narrative. Sentry structured log, console in debug builds.
  void info(String message, {String? area, Map<String, dynamic>? data});

  /// Developer narrative. Sentry structured log, console in debug builds.
  void debug(String message, {String? area, Map<String, dynamic>? data});

  /// A plain breadcrumb with no severity meaning.
  void breadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
  });

  /// Identity for every following event: Supabase user id as the Sentry
  /// user, with `role` (`athlete` or `coach`) and `device_id` as searchable
  /// tags. Never an email.
  Future<void> setUser(String id, {String? role, String? deviceId});

  Future<void> clearUser();

  /// Whether reports leave the device at all.
  bool get isEnabled;
}

/// The real service. Talks to Sentry through a [Hub] (the SDK's static hub by
/// default; an isolated one in tests), fans Faults and Degradeds out to the
/// analytics tracker, and mirrors everything into the dev debug screen's log.
class SentryReport implements Report {
  SentryReport({
    required AnalyticsTracker Function() analytics,
    Hub? hub,
    ReportLog? logStorage,
    bool? console,
    Logger? consoleLogger,
  }) : _analytics = analytics,
       _hub = hub ?? HubAdapter(),
       _logStorage = logStorage ?? ReportLog(),
       _console = console ?? kDebugMode,
       _consoleLogger = consoleLogger ?? _defaultConsoleLogger();

  final AnalyticsTracker Function() _analytics;
  final Hub _hub;
  final ReportLog _logStorage;
  final bool _console;
  final Logger _consoleLogger;

  /// Zone marker set while the Mixpanel fan-out runs. The analytics tracker
  /// reports its own failures through `Report`, which lands back here;
  /// a Fault raised anywhere under that call, including after its awaits, is
  /// still captured to Sentry but is not fanned out again, so the two can
  /// never chase each other. A zone value survives async gaps; a flag on the
  /// instance did not (the nested Fault reached fan-out after the flag reset).
  static const Symbol _fanOutZone = #mealvanaReportFanOut;

  /// Error objects already captured this process, by identity. A repository
  /// that Faults and rethrows, the controller that catches it, and the
  /// Riverpod observer all see the same object; only the first capture becomes
  /// an event, the rest leave a breadcrumb. Primitives (a thrown `String`)
  /// cannot be Expando keys and are never deduped.
  static final Expando<bool> _captured = Expando<bool>('report captured');

  static bool _canMark(Object error) =>
      error is! num && error is! String && error is! bool && error is! Record;

  /// Whether [error] has already been captured by any `SentryReport`.
  static bool wasReported(Object error) =>
      _canMark(error) && _captured[error] == true;

  /// Records that [error] has been captured (by this service or a caller
  /// that reported it another way, such as the Riverpod observer).
  static void markReported(Object error) {
    if (_canMark(error)) _captured[error] = true;
  }

  /// The instance code with no injection point reaches for (domain-adjacent
  /// static helpers, widgets without a `ref`, the bootstrap before the
  /// provider graph exists). Set by [reportProvider]; falls back to a
  /// Sentry-only instance so nothing is lost before the provider builds.
  static Report global = SentryReport(
    analytics: () => const NoopAnalyticsTracker(),
  );

  static Logger _defaultConsoleLogger() {
    const verboseLogs = bool.fromEnvironment('VERBOSE_APP_LOGS');
    return Logger(
      level: verboseLogs ? Level.debug : Level.warning,
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 4,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
    );
  }

  @override
  bool get isEnabled => _hub.isEnabled;

  @override
  Future<void> fault(
    Object error, {
    StackTrace? stackTrace,
    String? area,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    String? message,
    List<String>? fingerprint,
  }) {
    final text = describeThrowable(error);
    if (isTestOnlyFailure(text)) return Future.value();

    final expected = classifyExpectedFailure(text);
    return _capture(
      error,
      severity: expected == null
          ? ReportSeverity.fault
          : ReportSeverity.degraded,
      expected: expected,
      stackTrace: stackTrace,
      area: area,
      tags: tags,
      extra: extra,
      message: message,
      fingerprint: fingerprint,
    );
  }

  @override
  Future<void> degraded(
    Object error, {
    StackTrace? stackTrace,
    String? area,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    String? message,
    List<String>? fingerprint,
  }) {
    final text = describeThrowable(error);
    if (isTestOnlyFailure(text)) return Future.value();

    return _capture(
      error,
      severity: ReportSeverity.degraded,
      expected: classifyExpectedFailure(text),
      stackTrace: stackTrace,
      area: area,
      tags: tags,
      extra: extra,
      message: message,
      fingerprint: fingerprint,
    );
  }

  Future<void> _capture(
    Object error, {
    required ReportSeverity severity,
    required ExpectedFailure? expected,
    StackTrace? stackTrace,
    String? area,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    String? message,
    List<String>? fingerprint,
  }) async {
    final String? normalisedArea = _normaliseArea(area);
    if (wasReported(error)) {
      _hub.addBreadcrumb(
        Breadcrumb(
          message: 'Report: already captured upstream, not re-sent',
          category: 'report',
          level: SentryLevel.info,
          data: {
            'error_type': error.runtimeType.toString(),
            if (normalisedArea != null) 'area': normalisedArea,
            if (message != null) 'message': message,
          },
        ),
      );
      return;
    }
    markReported(error);
    final level = severity == ReportSeverity.fault
        ? SentryLevel.error
        : SentryLevel.warning;
    final exceptionType = error.runtimeType.toString();

    _mirror(
      level: level,
      message: message ?? error.toString(),
      area: normalisedArea,
      data: extra,
      error: error,
      stackTrace: stackTrace,
    );

    SentryId eventId = SentryId.empty();
    try {
      eventId = await _hub.captureException(
        error,
        stackTrace: stackTrace,
        message: message == null ? null : SentryMessage(message),
        withScope: (scope) async {
          scope.level = level;
          await scope.setTag('severity', severity.tag);
          if (normalisedArea != null) {
            await scope.setTag('area', normalisedArea);
          }
          if (expected != null) {
            await scope.setTag('expected_failure', expected.tag);
          }
          if (tags != null) {
            for (final entry in tags.entries) {
              await scope.setTag(entry.key, entry.value);
            }
          }
          if (extra != null && extra.isNotEmpty) {
            await scope.setContexts('diagnostic', extra);
          }
          if (fingerprint != null) {
            scope.fingerprint = fingerprint;
          } else if (error is LoggedFault) {
            scope.fingerprint = ['logged-fault', error.groupingKey];
          }
        },
      );
    } catch (sdkError) {
      _captureFailed(sdkError);
    }

    await _fanOut(
      severity: severity,
      area: normalisedArea,
      exceptionType: exceptionType,
      eventId: eventId,
    );
  }

  /// The reporter must never take the app down with it. When the SDK itself
  /// throws, the breadcrumb rides the next event that does get through and
  /// the debug log keeps it on device (rule D9: a prod-readable trail, not
  /// only the debug console).
  void _captureFailed(Object sdkError) {
    _mirror(
      level: SentryLevel.error,
      message: 'Report: Sentry capture failed',
      area: 'report',
      error: sdkError,
    );
    try {
      _hub.addBreadcrumb(
        Breadcrumb(
          message: 'Report: Sentry capture failed',
          category: 'report',
          level: SentryLevel.error,
          data: {'error': sdkError.toString()},
        ),
      );
    } catch (_) {
      // Nothing left to write to.
    }
  }

  Future<void> _fanOut({
    required ReportSeverity severity,
    required String? area,
    required String exceptionType,
    required SentryId eventId,
  }) async {
    if (Zone.current[_fanOutZone] == true) return;
    try {
      await runZoned(
        () => _analytics().track(
          errorReportedEvent,
          properties: <String, dynamic>{
            'severity': severity.tag,
            'area': area ?? 'unknown',
            'exception_type': exceptionType,
            if (eventId != SentryId.empty())
              'sentry_event_id': eventId.toString(),
          },
        ),
        zoneValues: {_fanOutZone: true},
      );
    } catch (analyticsError) {
      _mirror(
        level: SentryLevel.warning,
        message: 'Report: analytics fan-out failed',
        area: 'report',
        error: analyticsError,
      );
    }
  }

  @override
  Future<void> note(
    String message, {
    String? area,
    Map<String, dynamic>? data,
  }) async {
    final String? normalised = _normaliseArea(area);
    _mirror(
      level: SentryLevel.info,
      message: message,
      area: normalised,
      data: data,
    );

    _hub.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: normalised == null ? 'note' : 'note.$normalised',
        level: SentryLevel.info,
        data: data,
      ),
    );

    if (normalised != null && promotedNoteAreas.contains(normalised)) {
      try {
        await _hub.captureMessage(
          message,
          level: SentryLevel.warning,
          withScope: (scope) async {
            scope.level = SentryLevel.warning;
            await scope.setTag('severity', ReportSeverity.note.tag);
            await scope.setTag('area', normalised);
            await scope.setTag('promoted', 'true');
            if (data != null && data.isNotEmpty) {
              await scope.setContexts('diagnostic', data);
            }
          },
        );
      } catch (sdkError) {
        _captureFailed(sdkError);
      }
    }
  }

  @override
  void info(String message, {String? area, Map<String, dynamic>? data}) {
    final normalised = _normaliseArea(area);
    _mirror(
      level: SentryLevel.info,
      message: message,
      area: normalised,
      data: data,
    );
    _toSentryLog(SentryLogLevel.info, message, normalised, data);
  }

  @override
  void debug(String message, {String? area, Map<String, dynamic>? data}) {
    final normalised = _normaliseArea(area);
    _mirror(
      level: SentryLevel.debug,
      message: message,
      area: normalised,
      data: data,
    );
    _toSentryLog(SentryLogLevel.debug, message, normalised, data);
  }

  @override
  void breadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
  }) {
    _hub.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        level: SentryLevel.info,
        data: data,
      ),
    );
  }

  @override
  Future<void> setUser(String id, {String? role, String? deviceId}) async {
    await _hub.configureScope((scope) async {
      await scope.setUser(SentryUser(id: id));
      if (role != null) await scope.setTag('role', role);
      if (deviceId != null) await scope.setTag('device_id', deviceId);
    });
  }

  @override
  Future<void> clearUser() async {
    await _hub.configureScope((scope) async {
      await scope.setUser(null);
      await scope.removeTag('role');
      await scope.removeTag('device_id');
    });
  }

  // --- sinks ---------------------------------------------------------------

  void _toSentryLog(
    SentryLogLevel level,
    String message,
    String? area,
    Map<String, dynamic>? data,
  ) {
    if (!_hub.isEnabled) return;
    final attributes = <String, SentryAttribute>{
      if (area != null) 'area': SentryAttribute.string(area),
      if (data != null)
        for (final entry in data.entries) entry.key: _attribute(entry.value),
    };
    try {
      // `Sentry.logger` is the SDK's structured-log entry point; it routes to
      // the current hub, which in tests is the one `Sentry.init` built.
      final logger = Sentry.logger;
      switch (level) {
        case SentryLogLevel.debug:
          logger.debug(message, attributes: attributes);
        case SentryLogLevel.info:
          logger.info(message, attributes: attributes);
        default:
          logger.info(message, attributes: attributes);
      }
    } catch (_) {
      // Structured logs are narrative; losing one is not worth a Fault.
    }
  }

  static SentryAttribute _attribute(Object? value) => switch (value) {
    bool v => SentryAttribute.bool(v),
    int v => SentryAttribute.int(v),
    double v => SentryAttribute.double(v),
    _ => SentryAttribute.string(value.toString()),
  };

  /// Legacy callers pass `context: 'SYNC'`; the area vocabulary is lower
  /// case (`promotedNoteAreas`), so one spelling per area in Sentry.
  static String? _normaliseArea(String? area) => area?.toLowerCase();

  /// Console in debug builds and the dev debug screen's log, together.
  void _mirror({
    required SentryLevel level,
    required String message,
    String? area,
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final storageLevel = switch (level) {
      SentryLevel.fatal => ReportLogLevel.fatal,
      SentryLevel.error => ReportLogLevel.error,
      SentryLevel.warning => ReportLogLevel.warning,
      SentryLevel.info => ReportLogLevel.info,
      _ => ReportLogLevel.debug,
    };
    try {
      _logStorage.addLog(
        ReportLogEntry(
          timestamp: DateTime.now(),
          level: storageLevel,
          message: message,
          context: area,
          data: data,
          error: error,
        ),
      );
    } catch (_) {
      // The debug screen's log is a dev convenience only.
    }

    if (!_console) return;
    final body = area == null ? message : '[$area] $message';
    final payload = data == null || data.isEmpty ? body : '$body\nData: $data';
    final consoleLevel = switch (level) {
      SentryLevel.fatal => Level.fatal,
      SentryLevel.error => Level.error,
      SentryLevel.warning => Level.warning,
      SentryLevel.info => Level.info,
      _ => Level.debug,
    };
    try {
      _consoleLogger.log(
        consoleLevel,
        payload,
        error: error,
        stackTrace: consoleLevel.index >= Level.warning.index
            ? stackTrace
            : null,
      );
    } catch (_) {
      // Console is best-effort; never recurse into Report from here.
    }
  }
}

/// Same interface, emits nothing. For tests and consent-off builds.
class NoopReport implements Report {
  const NoopReport();

  @override
  Future<void> fault(
    Object error, {
    StackTrace? stackTrace,
    String? area,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    String? message,
    List<String>? fingerprint,
  }) async {}

  @override
  Future<void> degraded(
    Object error, {
    StackTrace? stackTrace,
    String? area,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    String? message,
    List<String>? fingerprint,
  }) async {}

  @override
  Future<void> note(
    String message, {
    String? area,
    Map<String, dynamic>? data,
  }) async {}

  @override
  void info(String message, {String? area, Map<String, dynamic>? data}) {}

  @override
  void debug(String message, {String? area, Map<String, dynamic>? data}) {}

  @override
  void breadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
  }) {}

  @override
  Future<void> setUser(String id, {String? role, String? deviceId}) async {}

  @override
  Future<void> clearUser() async {}

  @override
  bool get isEnabled => false;
}

/// The app's `Report`. Analytics is looked up lazily so that the analytics
/// tracker may itself report through `Report` without a provider cycle.
///
/// Building it also points [SentryReport.global] at this instance, so code
/// with no injection point reports through the same hub and analytics.
final Provider<Report> reportProvider = Provider<Report>((ref) {
  final report = SentryReport(
    analytics: () => ref.read(analyticsTrackerProvider),
  );
  SentryReport.global = report;
  return report;
});

/// The app's `Report` from a provider's [Ref], safe to reach after an `await`
/// (ticket 18). Once the provider is disposed, `ref.read` throws
/// `UnmountedRefException`, which inside a `catch` would replace the error
/// being reported; this falls back to [SentryReport.global], which
/// [reportProvider] points at the same instance.
extension ReportRef on Ref {
  Report get report => mounted ? read(reportProvider) : SentryReport.global;
}

/// The Mixpanel event an expected failure sends in place of a Sentry event
/// (develop-2026-10 ticket 41, Lee 2026-10-08: "keep the counts"). Plain
/// analytics, never `error_reported`: `{area, reason}`, where `reason` is the
/// weather tag ([ExpectedFailure.tag]) or the auth outcome's name.
const String expectedFailureEvent = 'expected_failure';

/// The weather an [ExpectedOutcomes.faultUnlessWeather] site turns into a
/// breadcrumb: the device is offline, slow, or lost its connection.
const Set<ExpectedFailure> networkWeather = <ExpectedFailure>{
  ExpectedFailure.offline,
  ExpectedFailure.timeout,
  ExpectedFailure.handshake,
  ExpectedFailure.connectionReset,
};

/// Where [expectedFailureEvent] goes when a site has no tracker in hand.
///
/// The version check and the region lookup run before consent is resolved
/// and before Mixpanel starts, and reading the tracker there would read
/// consent before the region is known (`app_startup_provider.dart`, step 0a).
/// So a count with no tracker is held here until the app attaches its
/// consent-gated tracker after analytics starts
/// (`AppStartupService._initializeAnalytics`), then sent; later ones go
/// straight to it. With no consent the tracker is a no-op and nothing leaves.
abstract final class ExpectedFailureCounts {
  static AnalyticsTracker? Function()? _sink;
  static final List<({String area, String reason})> _pending = [];

  /// Most counts held before analytics starts; one launch never gets near.
  static const int maxPending = 50;

  /// Counts waiting for [attach].
  static List<({String area, String reason})> get pending =>
      List.unmodifiable(_pending);

  /// Sends the held counts through [sink] and routes later ones to it.
  static Future<void> attach(AnalyticsTracker? Function() sink) async {
    _sink = sink;
    final held = List.of(_pending);
    _pending.clear();
    for (final count in held) {
      await trackExpectedFailure(
        null,
        area: count.area,
        reason: count.reason,
      );
    }
  }

  static void _hold(String area, String reason, Report? report) {
    if (_pending.length >= maxPending) {
      (report ?? SentryReport.global).breadcrumb(
        'expected_failure not counted: buffer full',
        category: '$area.expected',
        data: <String, dynamic>{'reason': reason},
      );
      return;
    }
    _pending.add((area: area, reason: reason));
  }

  @visibleForTesting
  static void debugReset() {
    _sink = null;
    _pending.clear();
  }
}

/// Sends [expectedFailureEvent] through [analytics], or through the app's
/// attached tracker when [analytics] is null ([ExpectedFailureCounts]). A
/// tracker that throws must not turn an expected outcome into a crash; the
/// lost count is written down as a breadcrumb through [report] (D9).
Future<void> trackExpectedFailure(
  AnalyticsTracker? analytics, {
  required String area,
  required String reason,
  Report? report,
}) async {
  AnalyticsTracker? tracker = analytics;
  try {
    tracker ??= ExpectedFailureCounts._sink?.call();
  } catch (_) {
    tracker = null;
  }
  if (tracker == null) {
    ExpectedFailureCounts._hold(area, reason, report);
    return;
  }
  try {
    await tracker.track(
      expectedFailureEvent,
      properties: <String, dynamic>{'area': area, 'reason': reason},
    );
  } catch (error) {
    (report ?? SentryReport.global).breadcrumb(
      'expected_failure not tracked',
      category: '$area.expected',
      data: <String, dynamic>{'reason': reason, 'error': error.toString()},
    );
  }
}

/// Expected outcomes as breadcrumbs plus one plain count (ticket 41). An
/// extension, so `SentryReport`, `NoopReport` and the test fakes all have it
/// with no change to the interface.
extension ExpectedOutcomes on Report {
  /// [fault], unless [error] is network weather ([networkWeather]): then a
  /// breadcrumb in category `<area>.weather`, one [expectedFailureEvent]
  /// (through [analytics], or held for the app's tracker when null; see
  /// [ExpectedFailureCounts]), and no Sentry event. Returns the weather it saw, or
  /// null when it faulted, so a startup site can also write its LaunchTrail
  /// line.
  Future<ExpectedFailure?> faultUnlessWeather(
    Object error, {
    StackTrace? stackTrace,
    required String area,
    required String message,
    Map<String, dynamic>? data,
    AnalyticsTracker? analytics,
  }) async {
    final weather = classifyExpectedFailure(describeThrowable(error));
    if (weather == null || !networkWeather.contains(weather)) {
      await fault(
        error,
        stackTrace: stackTrace,
        area: area,
        message: message,
        extra: data,
      );
      return null;
    }
    breadcrumb(
      message,
      category: '$area.weather',
      data: <String, dynamic>{
        'expected_failure': weather.tag,
        'error': error.runtimeType.toString(),
        ...?data,
      },
    );
    await trackExpectedFailure(
      analytics,
      area: area,
      reason: weather.tag,
      report: this,
    );
    return weather;
  }

  /// An expected turn the athlete took (a cancel, a wrong password, an
  /// address that already has an account): a [note] in [area] and one
  /// [expectedFailureEvent] with [reason]. Only for areas that are not in
  /// [promotedNoteAreas]; a promoted area would make the note a warning
  /// event, so those sites write a [breadcrumb] and call
  /// [trackExpectedFailure] themselves.
  Future<void> noteExpected(
    String message, {
    required String area,
    required String reason,
    AnalyticsTracker? analytics,
    Map<String, dynamic>? data,
  }) async {
    assert(
      !promotedNoteAreas.contains(area),
      'noteExpected in promoted area $area would send a warning event',
    );
    await note(
      message,
      area: area,
      data: <String, dynamic>{'expected_failure': reason, ...?data},
    );
    await trackExpectedFailure(
      analytics,
      area: area,
      reason: reason,
      report: this,
    );
  }
}
