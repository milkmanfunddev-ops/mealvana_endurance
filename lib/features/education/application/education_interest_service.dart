import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/report/report.dart';

part 'education_interest_service.g.dart';

@riverpod
EducationInterestService educationInterestService(Ref ref) {
  return EducationInterestService(
    analytics: ref.read(appExternalDepsProvider).analytics,
    report: ref.read(reportProvider),
  );
}

/// Records interest in a Learn "Coming Soon" card (testing-wave 117-006):
/// the one analytics event a Notify Me tap sends. Kept out of the widget so
/// analytics live in the application layer.
class EducationInterestService {
  const EducationInterestService({
    required AnalyticsTracker analytics,
    required Report report,
  }) : _analytics = analytics,
       _report = report;

  final AnalyticsTracker _analytics;
  final Report _report;

  /// The event a Notify Me tap records, with the card's title as `card`.
  static const String notifyEvent = 'education_notify_me_tapped';

  /// Sends [notifyEvent] for [card]. Never throws: analytics never blocks
  /// the confirmation, and a failure is reported (D9).
  Future<void> recordNotifyMe(String card) async {
    try {
      await _analytics.track(notifyEvent, properties: {'card': card});
    } catch (e, stackTrace) {
      await _report.degraded(
        e,
        stackTrace: stackTrace,
        area: 'education',
        message: 'Learn Notify Me analytics event failed',
      );
    }
  }
}
