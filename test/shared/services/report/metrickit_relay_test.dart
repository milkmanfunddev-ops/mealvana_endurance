// Ticket 11 (spec: .scratch/sentry/spec.md § Telemetry that is not an error).
//
// A MetricKit metric payload leaves as one structured log and no event; a
// diagnostic payload leaves as one warning event tagged `metrickit`. Checked
// twice: through `RecordingReport`, and through the real `SentryReport` with
// the SDK transport swapped for an in-memory one. The channel plumbing is
// checked with the test binary messenger.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/report/report_log.dart';
import 'package:mealvana_endurance/shared/services/report/metrickit_relay.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../helpers/fakes/recording_report.dart';

const metricPayload = {
  'appVersion': '1.30.0',
  'timeStampBegin': '2026-10-05 00:00:00 +0000',
  'cpuMetrics': {'cumulativeCPUTime': '120 sec', 'cumulativeCPUInstructions': '9 kiloinstructions'},
  'applicationTimeMetrics': {'cumulativeForegroundTime': '600 sec'},
  'metaData': {'deviceType': 'iPhone15,2', 'osVersion': 'iPhone OS 19.0'},
};

const diagnosticPayload = {
  'timeStampBegin': '2026-10-05 10:00:00 +0000',
  'hangDiagnostics': [
    {
      'hangDuration': '3 sec',
      'callStackTree': {
        'callStacks': [
          {
            'threadAttributed': true,
            'callStackRootFrames': [
              {'binaryName': 'Runner', 'offsetIntoBinaryTextSegment': 1234},
            ],
          },
        ],
      },
    },
  ],
  'cpuExceptionDiagnostics': [],
};

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

class _NullOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('through RecordingReport', () {
    late RecordingReport report;
    late MetricKitRelay relay;

    setUp(() {
      report = RecordingReport();
      relay = MetricKitRelay(report: report);
    });

    test('a metric payload is one info log with flattened attributes', () async {
      await relay.handle(MethodCall('metric', jsonEncode(metricPayload)));

      expect(report.faults, isEmpty);
      expect(report.degradeds, isEmpty);
      expect(report.notes, isEmpty);
      final info = report.calls.where((c) => c.severity == 'info').single;
      expect(info.message, 'MetricKit metric payload');
      expect(info.area, MetricKitRelay.area);
      expect(info.data?['metrickit'], 'metric');
      expect(info.data?['cpuMetrics.cumulativeCPUTime'], '120 sec');
      expect(info.data?['metaData.deviceType'], 'iPhone15,2');
      expect(info.data?['attribute_count'], 7);
    });

    test('a diagnostic payload is one degraded event tagged metrickit', () async {
      await relay.handle(MethodCall('diagnostic', jsonEncode(diagnosticPayload)));

      expect(report.calls.where((c) => c.severity == 'info'), isEmpty);
      final degraded = report.degradeds.single;
      expect(degraded.message, 'MetricKit diagnostic payload');
      expect(degraded.area, MetricKitRelay.area);
      expect(degraded.tags?['metrickit'], 'diagnostic');
      expect(degraded.tags?['diagnostic_kind'], 'hang');
      expect(degraded.error, isA<MetricKitDiagnostic>());
      expect(degraded.extra?['diagnostic_kinds'], ['hang']);
      expect(degraded.extra?['payload'], isA<Map<String, Object?>>());
    });

    test('malformed JSON still leaves as a log, never a throw', () async {
      await relay.handle(const MethodCall('metric', 'not json'));
      final info = report.calls.where((c) => c.severity == 'info').single;
      expect(info.data?['raw'], 'not json');
    });

    test('an unknown method is refused', () {
      expect(
        () => relay.handle(const MethodCall('other', '{}')),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('the attribute cap is honoured', () async {
      final wide = {
        for (var i = 0; i < MetricKitRelay.maxLogAttributes + 50; i++)
          'k$i': i,
      };
      await relay.handle(MethodCall('metric', jsonEncode(wide)));
      final info = report.calls.single;
      // 3 fixed attributes + the cap.
      expect(info.data, hasLength(3 + MetricKitRelay.maxLogAttributes));
      expect(info.data?['attribute_count'], wide.length);
    });
  });

  group('through the SDK transport', () {
    late CapturingTransport transport;
    late MetricKitRelay relay;

    setUp(() async {
      transport = CapturingTransport();
      await Sentry.init((options) {
        options.dsn = 'https://public@sentry.example.com/1';
        options.transport = transport;
        options.enableLogs = true;
        options.environment = 'test';
      });
      relay = MetricKitRelay(
        report: SentryReport(
          analytics: () => const NoopAnalyticsTracker(),
          logStorage: ReportLog(),
          console: false,
          consoleLogger: Logger(
            level: Level.off,
            printer: SimplePrinter(),
            output: _NullOutput(),
          ),
        ),
      );
    });

    tearDown(() async {
      await Sentry.close();
    });

    test('metric payload: a log item and no event', () async {
      await relay.handle(MethodCall('metric', jsonEncode(metricPayload)));
      // captureLog clones the scope asynchronously before it buffers the log,
      // so let that settle before forcing the batcher to flush.
      await Future<void>.delayed(Duration.zero);
      // ignore: invalid_use_of_internal_member
      await Sentry.currentHub.options.telemetryProcessor.flush();
      await Future<void>.delayed(Duration.zero);

      expect(transport.events, isEmpty);
      final logs = await transport.logs();
      expect(logs, hasLength(1));
      expect(logs.single['body'], 'MetricKit metric payload');
      final attributes = logs.single['attributes'] as Map<String, dynamic>;
      expect(attributes['area']['value'], 'metrickit');
      expect(attributes['cpuMetrics.cumulativeCPUTime']['value'], '120 sec');
    });

    test('diagnostic payload: one warning event tagged metrickit', () async {
      await relay.handle(MethodCall('diagnostic', jsonEncode(diagnosticPayload)));
      await Future<void>.delayed(Duration.zero);

      final event = transport.events.single;
      expect(event.level, SentryLevel.warning);
      expect(event.tags?['metrickit'], 'diagnostic');
      expect(event.tags?['severity'], 'degraded');
      expect(event.tags?['area'], 'metrickit');
      expect(event.fingerprint, ['metrickit-diagnostic', 'hang']);
      expect(
        (event.contexts['diagnostic'] as Map?)?['diagnostic_kinds'],
        ['hang'],
      );
    });
  });

  group('channel plumbing', () {
    const channel = MethodChannel(MetricKitRelay.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('start() tells the native side it is ready, then receives', () async {
      final report = RecordingReport();
      final nativeCalls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        nativeCalls.add(call.method);
        return null;
      });

      await MetricKitRelay(report: report).start();
      expect(nativeCalls, ['ready']);

      // Native → Dart, as the Swift flush does.
      await messenger.handlePlatformMessage(
        MetricKitRelay.channelName,
        channel.codec.encodeMethodCall(
          MethodCall('metric', jsonEncode(metricPayload)),
        ),
        (_) {},
      );
      expect(report.calls.single.severity, 'info');
    });

    test('start() survives a host without the reporter', () async {
      // No mock handler: invokeMethod throws MissingPluginException.
      await MetricKitRelay(report: RecordingReport()).start();
    });
  });
}
