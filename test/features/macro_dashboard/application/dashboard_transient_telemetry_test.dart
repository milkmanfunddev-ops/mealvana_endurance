import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/macro_dashboard/application/dashboard_transient_telemetry.dart';

import '../../../helpers/fakes/recording_report.dart';

void main() {
  late RecordingReport report;

  setUp(() {
    DashboardTransientTelemetry.debugReset();
    report = RecordingReport();
    DashboardTransientTelemetry.reportOverride = report;
  });

  tearDown(DashboardTransientTelemetry.debugReset);

  void observe({
    String userId = 'u1',
    String dateKey = '2026-09-15',
    required bool hasTargets,
    bool calculating = false,
    String? calculationError,
  }) {
    DashboardTransientTelemetry.observe(
      userId: userId,
      dateKey: dateKey,
      hasTargets: hasTargets,
      calculating: calculating,
      calculationError: calculationError,
    );
  }

  List<RecordedReport> captured() => report.degradeds;

  test('no-targets-while-computing fires one warning with reason=computing', () {
    observe(hasTargets: false, calculating: true);

    expect(captured(), hasLength(1));
    expect(captured().single.message, 'Dashboard shown without targets');
    expect(captured().single.area, 'macro_dashboard');
    expect(captured().single.tags?['reason'], 'computing');
    expect(captured().single.extra?['reason'], 'computing');
    expect(report.faults, isEmpty);
  });

  test('provider rebuilds do not spam duplicate shown events', () {
    for (var i = 0; i < 5; i++) {
      observe(hasTargets: false, calculating: true);
    }
    expect(captured(), hasLength(1));
  });

  test('targets arriving closes the episode with a duration', () {
    observe(hasTargets: false, calculating: true);
    observe(hasTargets: true);

    expect(captured(), hasLength(2));
    expect(captured().last.message, 'Dashboard targets transient resolved');
    // Degraded (warning) on purpose: these are real findings and stay events
    // (ticket 11); release beforeSend drops info-level events.
    expect(captured().last.extra?['duration_ms'], isA<int>());
    expect(captured().last.extra?['duration_ms'] as int, greaterThanOrEqualTo(0));
  });

  test('rendering with targets from the start reports nothing', () {
    observe(hasTargets: true);
    observe(hasTargets: true);
    expect(report.calls, isEmpty);
  });

  test('error and empty states are bucketed by reason', () {
    observe(hasTargets: false, calculationError: 'edge fn rejected input');
    observe(dateKey: '2026-09-16', hasTargets: false);

    expect(captured(), hasLength(2));
    expect(captured().first.tags?['reason'], 'error');
    expect(captured().first.extra?['calculation_error'], 'edge fn rejected input');
    expect(captured().last.tags?['reason'], 'empty');
  });

  test('episodes are independent per user and day', () {
    observe(userId: 'u1', hasTargets: false, calculating: true);
    observe(userId: 'u2', hasTargets: false, calculating: true);
    observe(userId: 'u1', hasTargets: true);

    // u1 shown + u2 shown + u1 resolved; u2 still open.
    expect(captured(), hasLength(3));
    expect(
      captured().where((c) => c.message == 'Dashboard targets transient resolved'),
      hasLength(1),
    );
  });
}
