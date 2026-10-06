// Ticket 11 (spec: .scratch/sentry/spec.md § Telemetry that is not an error).
//
// Drives `PerformanceTelemetry` with the SDK's transport swapped for an
// in-memory one: a step below the 10 s ceiling is a span and a measurement,
// never an event; a step over the ceiling is exactly one warning event per step,
// fingerprinted by step name; a step inside a bound transaction lands on it
// as a child span.
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/debug_log_storage.dart';
import 'package:mealvana_endurance/shared/services/report/performance_telemetry.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../helpers/fakes/recording_report.dart';

class CapturingTransport implements Transport {
  final List<SentryEnvelope> envelopes = [];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return envelope.header.eventId;
  }

  Iterable<SentryEnvelopeItem> get _items => envelopes.expand((e) => e.items);

  List<SentryEvent> get events => _items
      .where((i) => i.header.type == 'event')
      .map((i) => i.originalObject)
      .whereType<SentryEvent>()
      .toList();

  List<SentryTransaction> get transactions => _items
      .where((i) => i.header.type == 'transaction')
      .map((i) => i.originalObject)
      .whereType<SentryTransaction>()
      .toList();
}

class _NullOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}

void main() {
  late CapturingTransport transport;
  late SentryReport report;

  setUp(() async {
    transport = CapturingTransport();
    await Sentry.init((options) {
      options.dsn = 'https://public@sentry.example.com/1';
      options.transport = transport;
      options.tracesSampleRate = 1.0;
      options.environment = 'test';
    });
    report = SentryReport(
      analytics: () => const NoopAnalyticsTracker(),
      logStorage: DebugLogStorage(),
      console: false,
      consoleLogger: Logger(
        level: Level.off,
        printer: SimplePrinter(),
        output: _NullOutput(),
      ),
    );
    PerformanceTelemetry.debugReset();
    PerformanceTelemetry.reportOverride = report;
  });

  tearDown(() async {
    PerformanceTelemetry.debugReset();
    await Sentry.close();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('ceiling boundary', () {
    test('9.999 s: a span and a measurement, no event', () async {
      PerformanceTelemetry.recordDuration(
        'startup.version_check',
        const Duration(milliseconds: 9999),
      );
      await settle();

      expect(transport.events, isEmpty);
      final tx = transport.transactions.single;
      expect(tx.transaction, 'startup.version_check');
      expect(
        tx.contexts.trace?.operation,
        PerformanceTelemetry.spanOperation,
      );
      final measurement = tx.measurements['startup.version_check']!;
      expect(measurement.value, 9999);
      expect(measurement.unit, DurationSentryMeasurementUnit.milliSecond);
    });

    test('10 s: exactly one warning event per step, grouped by step', () async {
      PerformanceTelemetry.recordDuration(
        'startup.version_check',
        const Duration(seconds: 10, milliseconds: 1),
      );
      PerformanceTelemetry.recordDuration(
        'startup.version_check',
        const Duration(seconds: 12),
      );
      PerformanceTelemetry.recordDuration(
        'startup.load_user',
        const Duration(seconds: 11),
      );
      await settle();

      final events = transport.events;
      expect(events, hasLength(2));
      final first = events.firstWhere(
        (e) => e.tags?['operation'] == 'startup.version_check',
      );
      expect(first.level, SentryLevel.warning);
      expect(first.message?.formatted, 'Slow operation: startup.version_check');
      expect(first.tags?['severity'], 'degraded');
      expect(first.tags?['area'], 'performance');
      expect(first.fingerprint, ['slow-operation', 'startup.version_check']);
      expect(
        (first.contexts['diagnostic'] as Map?)?['duration_ms'],
        10001,
      );
      // Every step still produced its span.
      expect(transport.transactions, hasLength(3));
    });

    test('the boundary through RecordingReport', () async {
      final recording = RecordingReport();
      PerformanceTelemetry.reportOverride = recording;

      PerformanceTelemetry.recordDuration(
        'startup.a',
        const Duration(milliseconds: 9999),
      );
      expect(recording.degradeds, isEmpty);

      PerformanceTelemetry.recordDuration(
        'startup.a',
        const Duration(milliseconds: 10001),
      );
      await settle();
      expect(recording.degradeds, hasLength(1));
      expect(recording.degradeds.single.error, isA<SlowOperation>());
      expect(recording.degradeds.single.tags?['operation'], 'startup.a');
      expect(recording.faults, isEmpty);
    });
  });

  group('span emission', () {
    test('a step inside a bound transaction is a child span on it', () async {
      final tx = Sentry.startTransaction(
        '/',
        'ui.load',
        bindToScope: true,
      );
      await PerformanceTelemetry.measure(
        'startup.load_user',
        () async => 'user',
      );
      PerformanceTelemetry.recordDuration(
        'startup.sync',
        const Duration(milliseconds: 2500),
      );
      await tx.finish();
      await settle();

      // No standalone transactions: both steps rode the bound one.
      final sent = transport.transactions.single;
      expect(sent.transaction, '/');
      final steps = sent.spans
          .where((s) => s.context.operation == PerformanceTelemetry.spanOperation)
          .map((s) => s.context.description)
          .toList();
      expect(steps, containsAll(['startup.load_user', 'startup.sync']));
      final sync = sent.spans.firstWhere(
        (s) => s.context.description == 'startup.sync',
      );
      expect(sync.data['duration_ms'], 2500);
      // Back-dated 2.5 s, which is before the transaction began: the SDK
      // refuses such a child, so the start is clamped to the parent's.
      expect(sync.startTimestamp.isBefore(sent.startTimestamp), isFalse);
      expect(sync.endTimestamp, isNotNull);
      expect(sent.measurements['startup.sync']!.value, 2500);
      expect(transport.events, isEmpty);
    });

    test('measurement names keep letters, digits, dot and underscore', () {
      expect(
        PerformanceTelemetry.measurementName('dashboard.integration-sync/x y'),
        'dashboard.integration_sync_x_y',
      );
    });
  });
}
