import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/notification_service.dart';
import '../../content/application/content_service.dart';
import '../../content/domain/content_keys.dart';
import '../domain/entitlement.dart';
import '../domain/trial_reminder.dart';

part 'trial_reminder_service.g.dart';

/// The clock the reminder is timed against. A provider so tests can pin it;
/// the app never overrides it.
@riverpod
DateTime Function() trialReminderClock(Ref ref) => DateTime.now;

@riverpod
TrialReminderService trialReminderService(Ref ref) => TrialReminderService(
  content: ref.watch(contentServiceProvider),
  scheduler: ref.watch(localNotificationSchedulerProvider),
  now: ref.watch(trialReminderClockProvider),
);

/// Sets the day-five reminder when a purchase starts the free week (mp-456):
/// one local notification at 10:00 two days before the trial ends, saying
/// the trial ends in two days, the store's price after it, and that the
/// athlete can cancel any time. Its tap opens the store's subscription page
/// ([TrialReminder.payload]). The text comes from the content system.
///
/// Cancelling it when the trial will not renew is the status provider's job
/// (it sees RevenueCat's answer on every app open), through the same slot.
class TrialReminderService {
  TrialReminderService({
    required ContentService content,
    required LocalNotificationScheduler scheduler,
    required DateTime Function() now,
  }) : _content = content,
       _scheduler = scheduler,
       _now = now;

  final ContentService _content;
  final LocalNotificationScheduler _scheduler;
  final DateTime Function() _now;

  /// Schedule the reminder for the purchase of [pkg] that RevenueCat now
  /// reports as [status]. Returns when it fires, or null when nothing was
  /// scheduled: no trial (or one already cancelled), no end date, a fire
  /// time already past, or notifications off for the app.
  Future<DateTime?> scheduleFor({
    required SubscriptionStatus status,
    required Package pkg,
  }) async {
    if (!status.active || !status.isTrial || !status.willRenew) return null;
    final end = status.expiresAt;
    if (end == null) return null;
    final when = TrialReminder.fireTimeFor(end, now: _now());
    if (when == null) return null;

    final bodyKey = _isAnnual(pkg)
        ? ContentKeys.paywallTrialReminderBodyAnnual
        : ContentKeys.paywallTrialReminderBodyMonthly;
    final scheduled = await _scheduler.scheduleOnce(
      id: TrialReminder.notificationId,
      when: when,
      title: _content.getValue(ContentKeys.paywallTrialReminderTitle),
      body: ContentKeys.format(_content.getValue(bodyKey), {
        'price': pkg.storeProduct.priceString,
      }),
      payload: TrialReminder.payload,
    );
    return scheduled ? when : null;
  }

  static bool _isAnnual(Package pkg) =>
      pkg.packageType == PackageType.annual ||
      pkg.storeProduct.subscriptionPeriod == 'P1Y';
}
