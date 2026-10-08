/// Learn's Notify Me event (117-006) is sent by the application layer, not
/// the card widget. Same event and payload; a failing tracker is reported
/// (D9) and never thrown at the confirmation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/education/application/education_interest_service.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalyticsTracker extends Mock implements AnalyticsTracker {}

class _MockReport extends Mock implements Report {}

void main() {
  late _MockAnalyticsTracker analytics;
  late _MockReport report;
  late EducationInterestService service;

  setUp(() {
    analytics = _MockAnalyticsTracker();
    report = _MockReport();
    when(
      () => report.degraded(
        any(),
        stackTrace: any(named: 'stackTrace'),
        area: any(named: 'area'),
        message: any(named: 'message'),
      ),
    ).thenAnswer((_) async {});
    service = EducationInterestService(analytics: analytics, report: report);
  });

  test('sends education_notify_me_tapped with the card title', () async {
    when(
      () => analytics.track(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    await service.recordNotifyMe('Premium Video Library');

    verify(
      () => analytics.track(
        'education_notify_me_tapped',
        properties: {'card': 'Premium Video Library'},
      ),
    ).called(1);
  });

  test('a failing tracker is reported, not thrown', () async {
    when(
      () => analytics.track(any(), properties: any(named: 'properties')),
    ).thenThrow(StateError('mixpanel down'));

    await service.recordNotifyMe('Courses');

    verify(
      () => report.degraded(
        any(that: isA<StateError>()),
        stackTrace: any(named: 'stackTrace'),
        area: 'education',
        message: 'Learn Notify Me analytics event failed',
      ),
    ).called(1);
  });
}
