// A dashboard wait is an event only past its threshold (develop-2026-10
// ticket 22, 01-006). After every signup the dashboard showed "computing"
// for 756-877 ms and sent two warning events; that sequence now sends none.
// Fake time: the test's fake timers fire the stuck timer, and the
// telemetry's clock moves with them.
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/macro_dashboard/application/dashboard_transient_telemetry.dart';

import '../../../helpers/fakes/recording_report.dart';

void main() {
  late RecordingReport report;
  late DateTime fakeNow;

  setUp(() {
    DashboardTransientTelemetry.debugReset();
    report = RecordingReport();
    DashboardTransientTelemetry.reportOverride = report;
    fakeNow = DateTime(2026, 10, 7, 6, 11);
    DashboardTransientTelemetry.now = () => fakeNow;
  });

  tearDown(DashboardTransientTelemetry.debugReset);

  void observe({
    String userId = 'u1',
    String dateKey = '2026-10-07',
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

  /// Moves the telemetry's clock and the fake timers together.
  Future<void> wait(WidgetTester tester, Duration d) async {
    fakeNow = fakeNow.add(d);
    await tester.pump(d);
  }

  List<RecordedReport> events() => report.degradeds;

  testWidgets('the observed signup sequence (computing, targets at 876 ms) '
      'sends no event', (tester) async {
    observe(hasTargets: false, calculating: true);
    await wait(tester, const Duration(milliseconds: 876));
    observe(hasTargets: true);
    await wait(tester, DashboardTransientTelemetry.transientThreshold);

    expect(events(), isEmpty);
    expect(report.faults, isEmpty);
  });

  testWidgets('computing stuck past the threshold sends one event when the '
      'timer fires and one when it resolves', (tester) async {
    observe(hasTargets: false, calculating: true);
    await wait(tester, const Duration(seconds: 9));
    expect(events(), isEmpty);

    await wait(tester, const Duration(seconds: 1));
    expect(events(), hasLength(1));
    expect(events().single.message, 'Dashboard shown without targets');
    expect(events().single.area, 'macro_dashboard');
    expect(events().single.tags?['reason'], 'computing');
    expect(events().single.extra?['open_ms'], 10000);

    await wait(tester, const Duration(seconds: 5));
    observe(hasTargets: true);
    expect(events(), hasLength(2));
    expect(events().last.message, 'Dashboard targets transient resolved');
    expect(events().last.extra?['duration_ms'], 15000);
  });

  testWidgets('reason error is an event at once', (tester) async {
    observe(hasTargets: false, calculationError: 'edge fn rejected input');

    expect(events(), hasLength(1));
    expect(events().single.tags?['reason'], 'error');
    expect(
      events().single.extra?['calculation_error'],
      'edge fn rejected input',
    );
  });

  testWidgets('provider rebuilds start one timer and send one stuck event', (
    tester,
  ) async {
    for (var i = 0; i < 5; i++) {
      observe(hasTargets: false, calculating: true);
    }
    await wait(tester, DashboardTransientTelemetry.transientThreshold);
    expect(events(), hasLength(1));
    DashboardTransientTelemetry.debugReset();
  });

  testWidgets('rendering with targets from the start reports nothing', (
    tester,
  ) async {
    observe(hasTargets: true);
    observe(hasTargets: true);
    expect(report.calls, isEmpty);
  });

  testWidgets('empty is a wait like computing', (tester) async {
    observe(hasTargets: false);
    await wait(tester, const Duration(seconds: 2));
    observe(hasTargets: true);
    expect(events(), isEmpty);
  });

  testWidgets('episodes are independent per user and day', (tester) async {
    observe(userId: 'u1', hasTargets: false, calculating: true);
    observe(userId: 'u2', hasTargets: false, calculating: true);
    await wait(tester, const Duration(seconds: 1));
    observe(userId: 'u1', hasTargets: true);
    await wait(tester, DashboardTransientTelemetry.transientThreshold);

    // u1 resolved under the threshold; u2 stuck.
    expect(events(), hasLength(1));
    expect(events().single.message, 'Dashboard shown without targets');
    DashboardTransientTelemetry.debugReset();
  });
}
