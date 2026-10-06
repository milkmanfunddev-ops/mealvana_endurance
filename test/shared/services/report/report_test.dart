// Service seam for `Report` (spec: .scratch/sentry/spec.md § Testing, seam 1).
//
// Drives the real `SentryReport` through its public API with the SDK's
// transport swapped for an in-memory one and a fake analytics tracker, then
// asserts what left: envelope level, tags, user, breadcrumbs, allow-list
// downgrades, Note promotion by area, the Mixpanel event, and that `NoopReport`
// emits nothing.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/debug_log_storage.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

/// Collects every envelope the SDK would have sent.
class CapturingTransport implements Transport {
  final List<SentryEnvelope> envelopes = [];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return envelope.header.eventId;
  }

  List<SentryEvent> get events => envelopes
      .expand((e) => e.items)
      .where((i) => i.header.type == 'event')
      .map((i) => i.originalObject)
      .whereType<SentryEvent>()
      .toList();

  Future<List<Map<String, dynamic>>> logs() async {
    final out = <Map<String, dynamic>>[];
    for (final item in envelopes.expand((e) => e.items)) {
      if (item.header.type != 'log') continue;
      final bytes = await item.dataFactory();
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      out.addAll((json['items'] as List).cast<Map<String, dynamic>>());
    }
    return out;
  }
}

class FakeAnalytics extends NoopAnalyticsTracker {
  const FakeAnalytics(this.tracked);

  final List<({String name, Map<String, dynamic> properties})> tracked;

  @override
  Future<void> track(
    String eventName, {
    Map<String, dynamic>? properties,
  }) async {
    tracked.add((name: eventName, properties: properties ?? const {}));
  }
}

class ThrowingAnalytics extends NoopAnalyticsTracker {
  const ThrowingAnalytics();

  @override
  Future<void> track(String eventName, {Map<String, dynamic>? properties}) =>
      throw StateError('mixpanel down');
}

/// Behaves like `MixpanelAnalyticsTracker`: when the SDK call fails it logs
/// the failure through the logger alias, which lands back in Report.
class ReentrantAnalytics extends NoopAnalyticsTracker {
  ReentrantAnalytics(this.logger);

  final AppLogger logger;
  int calls = 0;

  @override
  Future<void> track(
    String eventName, {
    Map<String, dynamic>? properties,
  }) async {
    calls++;
    logger.error('Failed to track $eventName', error: StateError('down'));
  }
}

class _ExpiredSession implements Exception {
  @override
  String toString() => 'AuthApiException: refresh_token_not_found';
}

void main() {
  late CapturingTransport transport;
  late List<({String name, Map<String, dynamic> properties})> tracked;
  late DebugLogStorage storage;
  late SentryReport report;

  Logger quietConsole() =>
      Logger(level: Level.off, printer: SimplePrinter(), output: _NullOutput());

  setUp(() async {
    transport = CapturingTransport();
    tracked = [];
    storage = DebugLogStorage()..clear();
    await Sentry.init((options) {
      options.dsn = 'https://public@sentry.example.com/1';
      options.transport = transport;
      options.enableLogs = true;
      options.environment = 'test';
    });
    report = SentryReport(
      analytics: () => FakeAnalytics(tracked),
      logStorage: storage,
      console: false,
      consoleLogger: quietConsole(),
    );
  });

  tearDown(() async {
    await Sentry.close();
  });

  group('fault', () {
    test('arrives as a Sentry error with severity, area and tags', () async {
      await report.fault(
        StateError('plan missing'),
        stackTrace: StackTrace.current,
        area: 'nutrition_plan',
        tags: {'plan_id': 'p1'},
        extra: {'day': 3},
      );

      final event = transport.events.single;
      expect(event.level, SentryLevel.error);
      expect(event.tags, containsPair('severity', 'fault'));
      expect(event.tags, containsPair('area', 'nutrition_plan'));
      expect(event.tags, containsPair('plan_id', 'p1'));
      expect(event.tags, isNot(contains('expected_failure')));
      expect(event.contexts['diagnostic'], {'day': 3});
      expect(event.throwable, isA<StateError>());
    });

    test('downgrades an allow-listed exception type to a warning', () async {
      await report.fault(
        const SocketException("Failed host lookup: 'x.supabase.co'"),
        area: 'sync',
      );

      final event = transport.events.single;
      expect(event.level, SentryLevel.warning);
      expect(event.tags, containsPair('severity', 'degraded'));
      expect(event.tags, containsPair('expected_failure', 'offline'));
    });

    test('downgrades on message pattern, not only type', () async {
      await report.fault(_ExpiredSession(), area: 'auth');
      final event = transport.events.single;
      expect(event.level, SentryLevel.warning);
      expect(event.tags, containsPair('expected_failure', 'expired_session'));
    });

    test('downgrades timeouts, handshakes, cancelled sign-in, '
        'invalid credentials, cancelled purchase, account-not-found', () async {
      final samples = <Object, String>{
        TimeoutException('after 30s'): 'timeout',
        const HandshakeException('Connection terminated during handshake'):
            'handshake',
        Exception('Sign-In was cancelled'): 'cancelled_sign_in',
        Exception('AuthApiException: Invalid login credentials'):
            'invalid_credentials',
        Exception('PurchasesErrorCode.purchaseCancelledError'):
            'cancelled_purchase',
        Exception('OAuthAccountNotFoundException: apple'): 'account_not_found',
        Exception('PurchasesErrorCode.networkError'): 'store_network',
      };
      for (final entry in samples.entries) {
        await report.fault(entry.key);
      }
      final events = transport.events;
      expect(events, hasLength(samples.length));
      for (final event in events) {
        expect(event.level, SentryLevel.warning, reason: '${event.throwable}');
      }
      expect(
        events.map((e) => e.tags!['expected_failure']),
        containsAll(samples.values),
      );
    });

    test('drops test-only failures entirely', () async {
      await report.fault(Exception('TestFailure: Expected: exactly one'));
      await report.fault(Exception('could not find any matching widgets'));
      expect(transport.events, isEmpty);
      expect(tracked, isEmpty);
    });

    test('fans out one error_reported with no message text', () async {
      await report.fault(StateError('secret athlete text'), area: 'payments');

      final event = transport.events.single;
      final hit = tracked.single;
      expect(hit.name, 'error_reported');
      expect(hit.properties, {
        'severity': 'fault',
        'area': 'payments',
        'exception_type': 'StateError',
        'sentry_event_id': event.eventId.toString(),
      });
      expect(hit.properties.values.join(), isNot(contains('secret')));
    });

    test('a downgraded fault reports severity degraded to Mixpanel', () async {
      await report.fault(TimeoutException('slow'), area: 'sync');
      expect(tracked.single.properties['severity'], 'degraded');
    });

    test('survives an analytics tracker that throws', () async {
      final r = SentryReport(
        analytics: () => const ThrowingAnalytics(),
        logStorage: storage,
        console: false,
        consoleLogger: quietConsole(),
      );
      await r.fault(StateError('boom'));
      expect(transport.events, hasLength(1));
    });

    test(
      'a tracker that logs its failure through Report cannot loop',
      () async {
        late final ReentrantAnalytics analytics;
        final r = SentryReport(
          analytics: () => analytics,
          logStorage: storage,
          console: false,
          consoleLogger: quietConsole(),
        );
        analytics = ReentrantAnalytics(PrettyAppLogger(report: r));

        await r.fault(StateError('first'));
        await Future<void>.delayed(Duration.zero);

        expect(analytics.calls, 1);
        // The original Fault and the tracker's own Fault both reach Sentry.
        expect(transport.events, hasLength(2));
      },
    );

    test(
      'lower-cases a legacy upper-case area so one spelling reaches Sentry',
      () async {
        await report.fault(StateError('x'), area: 'NUTRITION_PLAN');
        expect(
          transport.events.single.tags,
          containsPair('area', 'nutrition_plan'),
        );
        expect(tracked.single.properties['area'], 'nutrition_plan');
      },
    );

    test('mirrors into the debug screen log at error level', () async {
      await report.fault(StateError('boom'), area: 'startup');
      final entry = storage.getLogs().single;
      expect(entry.level, LogLevel.error);
      expect(entry.context, 'startup');
      expect(entry.error, isA<StateError>());
    });

    test('a LoggedFault groups on its message', () async {
      await report.fault(const LoggedFault('Plan generation returned null'));
      final event = transport.events.single;
      expect(event.level, SentryLevel.error);
      expect(event.throwable.toString(), 'Plan generation returned null');
    });
  });

  group('degraded', () {
    test('arrives as a warning and fans out', () async {
      await report.degraded(Exception('offline, will retry'), area: 'sync');
      final event = transport.events.single;
      expect(event.level, SentryLevel.warning);
      expect(event.tags, containsPair('severity', 'degraded'));
      expect(tracked.single.properties['severity'], 'degraded');
    });

    test('still tags the allow-list reason when one matches', () async {
      await report.degraded(TimeoutException('x'));
      expect(
        transport.events.single.tags,
        containsPair('expected_failure', 'timeout'),
      );
    });

    test('drops test-only failures', () async {
      await report.degraded(Exception('Required widget not found'));
      expect(transport.events, isEmpty);
    });
  });

  group('note', () {
    test('is a breadcrumb on the next event, not an event', () async {
      await report.note('skipped weather: no location', area: 'weather');
      expect(transport.events, isEmpty);

      await report.fault(StateError('later'));
      final event = transport.events.single;
      final crumb = event.breadcrumbs!.single;
      expect(crumb.message, 'skipped weather: no location');
      expect(crumb.category, 'note.weather');
    });

    test('is promoted to a warning event in the four D9 areas', () async {
      for (final area in ['startup', 'push', 'payments', 'sync']) {
        await report.note('bailed: $area', area: area, data: {'k': 1});
      }
      final events = transport.events;
      expect(events, hasLength(4));
      for (final event in events) {
        expect(event.level, SentryLevel.warning);
        expect(event.tags, containsPair('severity', 'note'));
        expect(event.tags, containsPair('promoted', 'true'));
        expect(event.contexts['diagnostic'], {'k': 1});
      }
      expect(
        events.map((e) => e.tags!['area']),
        containsAll(['startup', 'push', 'payments', 'sync']),
      );
      // Notes are not Faults or Degradeds: no Mixpanel fan-out.
      expect(tracked, isEmpty);
    });

    test('is not promoted outside those areas or with no area', () async {
      await report.note('x', area: 'meals');
      await report.note('y');
      expect(transport.events, isEmpty);
    });
  });

  group('info and debug', () {
    test('arrive as Sentry structured logs with attributes', () async {
      report.info('plan refreshed', area: 'plan', data: {'count': 2});
      report.debug('cache hit', data: {'hot': true});
      // captureLog clones the scope asynchronously before it buffers the log,
      // so let that settle before forcing the batcher to flush.
      await Future<void>.delayed(Duration.zero);
      // ignore: invalid_use_of_internal_member
      await Sentry.currentHub.options.telemetryProcessor.flush();
      await Future<void>.delayed(Duration.zero);

      final logs = await transport.logs();
      expect(logs, hasLength(2));
      final info = logs.firstWhere((l) => l['body'] == 'plan refreshed');
      expect(info['level'], 'info');
      expect(info['attributes']['area']['value'], 'plan');
      expect(info['attributes']['count']['value'], 2);
      final debug = logs.firstWhere((l) => l['body'] == 'cache hit');
      expect(debug['level'], 'debug');
      expect(debug['attributes']['hot']['value'], true);
      expect(transport.events, isEmpty);
      expect(tracked, isEmpty);
    });

    test('mirror into the debug screen log', () {
      report.info('a', area: 'x');
      report.debug('b');
      final levels = storage.getLogs().map((e) => e.level).toList();
      expect(levels, containsAll([LogLevel.info, LogLevel.debug]));
    });
  });

  group('user and breadcrumbs', () {
    test('setUser puts the id and role on every following event', () async {
      await report.setUser('user-123', role: 'coach');
      await report.fault(StateError('x'));
      final event = transport.events.single;
      expect(event.user?.id, 'user-123');
      expect(event.user?.email, isNull);
      expect(event.tags, containsPair('role', 'coach'));
    });

    test('setUser carries the device id as a searchable tag', () async {
      await report.setUser('user-123', role: 'athlete', deviceId: 'dev-9');
      await report.fault(StateError('x'));
      final event = transport.events.single;
      expect(event.tags, containsPair('device_id', 'dev-9'));
      expect(event.user?.id, 'user-123');
    });

    test('clearUser removes the device id too', () async {
      await report.setUser('user-123', role: 'athlete', deviceId: 'dev-9');
      await report.clearUser();
      await report.fault(StateError('x'));
      expect(transport.events.single.tags, isNot(contains('device_id')));
    });

    test('clearUser removes both', () async {
      await report.setUser('user-123', role: 'athlete');
      await report.clearUser();
      await report.fault(StateError('x'));
      final event = transport.events.single;
      expect(event.user?.id, isNull);
      expect(event.tags, isNot(contains('role')));
    });

    test('breadcrumb rides the next event', () async {
      report.breadcrumb('tapped save', category: 'ui', data: {'screen': 's'});
      await report.fault(StateError('x'));
      final crumb = transport.events.single.breadcrumbs!.single;
      expect(crumb.message, 'tapped save');
      expect(crumb.category, 'ui');
      expect(crumb.data, {'screen': 's'});
    });
  });

  group('NoopReport', () {
    test('emits nothing anywhere', () async {
      const noop = NoopReport();
      await noop.fault(StateError('x'), area: 'startup');
      await noop.degraded(StateError('x'));
      await noop.note('n', area: 'push');
      noop.info('i');
      noop.debug('d');
      noop.breadcrumb('b');
      await noop.setUser('u', role: 'athlete');
      await noop.clearUser();
      // ignore: invalid_use_of_internal_member
      await Sentry.currentHub.options.telemetryProcessor.flush();
      expect(transport.envelopes, isEmpty);
      expect(tracked, isEmpty);
      expect(storage.getLogs(), isEmpty);
      expect(noop.isEnabled, isFalse);
    });
  });

  test('isEnabled follows the hub', () {
    expect(report.isEnabled, isTrue);
  });

  group('legacy aliases route through Report', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          analyticsTrackerProvider.overrideWithValue(FakeAnalytics(tracked)),
        ],
      );
      addTearDown(container.dispose);
    });

    test('the provider graph builds without a cycle and shares one Report', () {
      final r = container.read(reportProvider);
      container.read(appLoggerProvider);
      container.read(sentryReporterProvider);
      expect(r, isA<SentryReport>());
      expect(SentryReport.global, same(r));
    });

    test('logger.error is a Fault, logger.warning is Degraded', () async {
      final logger = container.read(appLoggerProvider);
      logger.error('plan save failed', context: 'PLAN', error: StateError('x'));
      logger.warning('offline', context: 'SYNC');
      await Future<void>.delayed(Duration.zero);

      final events = transport.events;
      expect(events, hasLength(2));
      final fault = events.firstWhere((e) => e.level == SentryLevel.error);
      expect(fault.tags, containsPair('area', 'plan'));
      expect(fault.message?.formatted, 'plan save failed');
      final degraded = events.firstWhere((e) => e.level == SentryLevel.warning);
      expect(degraded.throwable, isA<LoggedFault>());
      expect(degraded.throwable.toString(), 'offline');
      expect(tracked, hasLength(2));
    });

    test('logger.info and debug are logs, not events', () async {
      final logger = container.read(appLoggerProvider);
      logger.info('hello', context: 'X');
      logger.debug('world');
      await Future<void>.delayed(Duration.zero);
      // ignore: invalid_use_of_internal_member
      await Sentry.currentHub.options.telemetryProcessor.flush();
      await Future<void>.delayed(Duration.zero);
      expect(transport.events, isEmpty);
      expect(await transport.logs(), hasLength(2));
    });

    test('SentryReporter: network is Degraded, database is a Fault, '
        'captureMessage keeps its fingerprint', () async {
      final sentry = container.read(sentryReporterProvider);
      await sentry.reportNetworkError(
        Exception('500'),
        url: 'https://x/fn',
        statusCode: 500,
      );
      await sentry.reportDatabaseError(
        StateError('bad row'),
        operation: 'insert',
        table: 'meals',
      );
      await sentry.captureMessage(
        'sweep stale',
        level: SentryLevel.warning,
        fingerprint: const ['raw_retention_sweep_stale'],
      );

      final events = transport.events;
      expect(events, hasLength(3));
      final network = events.firstWhere((e) => e.tags?['area'] == 'network');
      expect(network.level, SentryLevel.warning);
      expect(network.tags, containsPair('status_code', '500'));
      final db = events.firstWhere((e) => e.tags?['area'] == 'database');
      expect(db.level, SentryLevel.error);
      expect(db.tags, containsPair('table', 'meals'));
      final msg = events.firstWhere(
        (e) => e.throwable.toString() == 'sweep stale',
      );
      expect(msg.fingerprint, ['raw_retention_sweep_stale']);
    });

    test(
      'SentryReporter user context and breadcrumbs reach the event',
      () async {
        final sentry = container.read(sentryReporterProvider);
        await sentry.setUserContext(deviceId: 'dev-1', appVersion: '1.0');
        sentry.addBreadcrumb(message: 'opened plan', category: 'nav');
        await sentry.reportCriticalError(StateError('x'), context: 'PLAN');
        final event = transport.events.single;
        expect(event.user?.id, 'dev-1');
        expect(event.breadcrumbs!.single.message, 'opened plan');
        expect(event.tags, containsPair('area', 'plan'));
        await sentry.clearUserContext();
      },
    );

    test(
      'the default global Report reports before any provider builds',
      () async {
        SentryReport.global = SentryReport(
          analytics: () => const NoopAnalyticsTracker(),
          logStorage: storage,
          console: false,
          consoleLogger: quietConsole(),
        );
        DebugLogger.error('early', error: StateError('x'));
        await Future<void>.delayed(Duration.zero);
        expect(transport.events.single.level, SentryLevel.error);
      },
    );

    test('DebugLogger statics go through the global Report', () async {
      container.read(reportProvider);
      DebugLogger.error('sync bailed', error: StateError('x'));
      DebugLogger.warning('skipped step');
      await Future<void>.delayed(Duration.zero);
      final events = transport.events;
      expect(
        events.map((e) => e.level),
        containsAll([SentryLevel.error, SentryLevel.warning]),
      );
    });
  });
}

class _NullOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}
