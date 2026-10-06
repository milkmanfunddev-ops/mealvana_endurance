import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/settings/application/report_pipeline_probe.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/debug_screen.dart';
import 'package:mealvana_endurance/shared/services/report/report_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/fakes/recording_report.dart';
import '../../../../helpers/widget_test_harness.dart';

void main() {
  late RecordingReport report;
  late int edgeCalls;

  setUp(() {
    report = RecordingReport();
    edgeCalls = 0;
    ReportLog().clear();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final probe = ReportPipelineProbe(
      report: report,
      invokeEdgeWithBadPayload: () async {
        edgeCalls++;
        throw const FunctionException(status: 400);
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reportPipelineProbeProvider.overrideWithValue(probe)],
        child: wrapForTest(const DebugScreen()),
      ),
    );
    await tester.pump();
    // The section starts collapsed.
    await tester.tap(find.byKey(const Key('probe_section')));
    await tester.pumpAndSettle();
  }

  Future<void> tapProbe(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
  }

  testWidgets('the four pipeline probes and the crash button are present', (
    tester,
  ) async {
    await pumpScreen(tester);

    for (final key in [
      'probe_fault',
      'probe_degraded',
      'probe_note_then_fault',
      'probe_edge',
      'probe_crash',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('each probe button sends its report class through Report', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tapProbe(tester, 'probe_fault');
    expect(report.faults, hasLength(1));
    expect(
      find.textContaining('Fault: sent as a Sentry error.'),
      findsOneWidget,
    );

    await tapProbe(tester, 'probe_degraded');
    expect(report.degradeds, hasLength(1));

    await tapProbe(tester, 'probe_note_then_fault');
    expect(report.notes, hasLength(1));
    expect(report.faults, hasLength(2));

    await tapProbe(tester, 'probe_edge');
    expect(edgeCalls, 1);
    expect(find.textContaining('edge-dev'), findsOneWidget);
    // The refusal is the expected path: a Note, no app-side event.
    expect(report.notes, hasLength(2));
    expect(report.faults, hasLength(2));
    expect(report.degradeds, hasLength(1));
  });
}
