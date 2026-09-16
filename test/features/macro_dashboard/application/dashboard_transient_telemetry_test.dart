import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/macro_dashboard/application/dashboard_transient_telemetry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  final captured = <({String message, SentryLevel level, Map<String, Object?> data})>[];

  setUp(() {
    DashboardTransientTelemetry.debugReset();
    captured.clear();
    DashboardTransientTelemetry.debugCaptureOverride = (message, level, data) =>
        captured.add((message: message, level: level, data: data));
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

  test('no-targets-while-computing fires one warning with reason=computing', () {
    observe(hasTargets: false, calculating: true);

    expect(captured, hasLength(1));
    expect(captured.single.message, 'Dashboard shown without targets');
    expect(captured.single.level, SentryLevel.warning);
    expect(captured.single.data['reason'], 'computing');
  });

  test('provider rebuilds do not spam duplicate shown events', () {
    for (var i = 0; i < 5; i++) {
      observe(hasTargets: false, calculating: true);
    }
    expect(captured, hasLength(1));
  });

  test('targets arriving closes the episode with a duration', () {
    observe(hasTargets: false, calculating: true);
    observe(hasTargets: true);

    expect(captured, hasLength(2));
    expect(captured.last.message, 'Dashboard targets transient resolved');
    // Warning on purpose: release beforeSend drops info-level events — the
    // patch-#1 info-level resolved event never reached prod Sentry.
    expect(captured.last.level, SentryLevel.warning);
    expect(captured.last.data['duration_ms'], isA<int>());
    expect(captured.last.data['duration_ms'] as int, greaterThanOrEqualTo(0));
  });

  test('rendering with targets from the start reports nothing', () {
    observe(hasTargets: true);
    observe(hasTargets: true);
    expect(captured, isEmpty);
  });

  test('error and empty states are bucketed by reason', () {
    observe(hasTargets: false, calculationError: 'edge fn rejected input');
    observe(dateKey: '2026-09-16', hasTargets: false);

    expect(captured, hasLength(2));
    expect(captured.first.data['reason'], 'error');
    expect(captured.first.data['calculation_error'], 'edge fn rejected input');
    expect(captured.last.data['reason'], 'empty');
  });

  test('episodes are independent per user and day', () {
    observe(userId: 'u1', hasTargets: false, calculating: true);
    observe(userId: 'u2', hasTargets: false, calculating: true);
    observe(userId: 'u1', hasTargets: true);

    // u1 shown + u2 shown + u1 resolved; u2 still open.
    expect(captured, hasLength(3));
    expect(
      captured.where((c) => c.message == 'Dashboard targets transient resolved'),
      hasLength(1),
    );
  });
}
