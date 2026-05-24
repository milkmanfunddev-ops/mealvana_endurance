/// Unit tests for the Formula Kit pin-outcome analytics extension methods
/// added in PR 2 substep 7. Verifies event names, payload keys, and that the
/// snake_case wire shape is preserved end-to-end (no enum names leaking into
/// the `reason` field, optional `sub_phase` omitted when null, etc.).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_events.dart';

import '../../../helpers/fakes/recording_analytics_tracker.dart';

void main() {
  group('trackPlanUsedPin', () {
    test('emits plan_used_pin with snake_case payload', () async {
      final tracker = RecordingAnalyticsTracker();
      await tracker.trackPlanUsedPin(
        deviceId: 'device-1',
        activityId: 'act-42',
        templateId: 'tpl-abc',
        templateName: 'Bagel + Jam',
        phase: 'before',
        subPhase: 'meal',
        pinSetSize: 3,
      );

      expect(tracker.events.length, 1);
      final event = tracker.events.single;
      expect(event.name, 'plan_used_pin');
      final props = event.properties!;
      expect(props['device_id'], 'device-1');
      expect(props['activity_id'], 'act-42');
      expect(props['template_id'], 'tpl-abc');
      expect(props['template_name'], 'Bagel + Jam');
      expect(props['phase'], 'before');
      expect(props['sub_phase'], 'meal');
      expect(props['pin_set_size'], 3);
      expect(props['timestamp'], isA<String>());
    });

    test('omits sub_phase key when null (During section)', () async {
      final tracker = RecordingAnalyticsTracker();
      await tracker.trackPlanUsedPin(
        deviceId: 'device-1',
        activityId: 'act-42',
        templateId: 'tpl-during',
        templateName: 'Energy Chews',
        phase: 'during',
        subPhase: null,
        pinSetSize: 1,
      );

      final props = tracker.events.single.properties!;
      expect(props.containsKey('sub_phase'), isFalse);
    });
  });

  group('trackPlanPinFallthrough', () {
    test('emits plan_pin_fallthrough with wire-value reason', () async {
      final tracker = RecordingAnalyticsTracker();
      await tracker.trackPlanPinFallthrough(
        deviceId: 'device-1',
        activityId: 'act-42',
        phase: 'before',
        subPhase: 'snack',
        reason: 'no_pin_for_scope',
        pinSetSize: 0,
      );

      expect(tracker.events.length, 1);
      final event = tracker.events.single;
      expect(event.name, 'plan_pin_fallthrough');
      final props = event.properties!;
      expect(props['device_id'], 'device-1');
      expect(props['activity_id'], 'act-42');
      expect(props['phase'], 'before');
      expect(props['sub_phase'], 'snack');
      // Wire value, not the enum's Dart name — server can add new reasons
      // without a client release.
      expect(props['reason'], 'no_pin_for_scope');
      expect(props['pin_set_size'], 0);
      expect(props['timestamp'], isA<String>());
    });

    test('omits sub_phase key when null', () async {
      final tracker = RecordingAnalyticsTracker();
      await tracker.trackPlanPinFallthrough(
        deviceId: 'device-1',
        activityId: 'act-42',
        phase: 'during',
        subPhase: null,
        reason: 'no_pin_for_scope',
        pinSetSize: 0,
      );

      final props = tracker.events.single.properties!;
      expect(props.containsKey('sub_phase'), isFalse);
    });
  });
}
