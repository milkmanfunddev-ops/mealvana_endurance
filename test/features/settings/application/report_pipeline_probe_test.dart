import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/settings/application/report_pipeline_probe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/fakes/recording_report.dart';

void main() {
  late RecordingReport report;

  setUp(() => report = RecordingReport());

  ReportPipelineProbe probe({Future<void> Function()? invokeEdge}) =>
      ReportPipelineProbe(
        report: report,
        invokeEdgeWithBadPayload: invokeEdge ?? () async {},
      );

  test(
    'fault() reports one Fault in the debug area, tagged as the probe',
    () async {
      await probe().fault();

      expect(report.faults, hasLength(1));
      final call = report.faults.single;
      expect(call.area, ReportPipelineProbe.area);
      expect(call.error, isA<ReportProbeFault>());
      expect(call.tags, containsPair('probe', 'fault'));
      expect(report.degradeds, isEmpty);
      expect(report.notes, isEmpty);
    },
  );

  test('degraded() reports one Degraded in the debug area', () async {
    await probe().degraded();

    expect(report.degradeds, hasLength(1));
    final call = report.degradeds.single;
    expect(call.area, ReportPipelineProbe.area);
    expect(call.error, isA<ReportProbeDegraded>());
    expect(call.tags, containsPair('probe', 'degraded'));
    expect(report.faults, isEmpty);
  });

  test('noteThenFault() leaves the Note before the Fault', () async {
    await probe().noteThenFault();

    final severities = report.calls.map((c) => c.severity).toList();
    expect(severities, ['note', 'fault']);
    expect(report.notes.single.area, ReportPipelineProbe.area);
    expect(report.notes.single.data, containsPair('probe', 'note'));
    expect(report.faults.single.tags, containsPair('probe', 'note_then_fault'));
  });

  test(
    'edgeBadPayload() expects the 4xx refusal and records only a Note',
    () async {
      final outcome = await probe(
        invokeEdge: () async => throw const FunctionException(
          status: 400,
          reasonPhrase: 'Bad Request',
        ),
      ).edgeBadPayload();

      expect(outcome.kind, EdgeProbeKind.refused);
      expect(outcome.status, 400);
      expect(report.faults, isEmpty);
      expect(report.degradeds, isEmpty);
      expect(report.notes.single.data, containsPair('status', 400));
    },
  );

  test('edgeBadPayload() treats a 2xx answer as no event sent', () async {
    final outcome = await probe().edgeBadPayload();

    expect(outcome.kind, EdgeProbeKind.accepted);
    expect(outcome.status, isNull);
    expect(report.calls, isEmpty);
  });

  test('edgeBadPayload() reports a transport failure as Degraded', () async {
    final outcome = await probe(
      invokeEdge: () async => throw StateError('offline'),
    ).edgeBadPayload();

    expect(outcome.kind, EdgeProbeKind.unreachable);
    expect(report.degradeds.single.area, ReportPipelineProbe.area);
  });
}
