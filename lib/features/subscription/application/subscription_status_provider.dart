import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/notification_service.dart';
import '../data/subscription_service.dart';
import '../data/user_entitlements_repository.dart';
import '../domain/entitlement.dart';
import '../domain/trial_reminder.dart';

part 'subscription_status_provider.g.dart';

/// How long the gate waits for RevenueCat before an unknown entitlement
/// counts as locked (mp-284: "no cache and no answer within a couple of
/// seconds"). A provider so tests can shorten it; the app never overrides it.
@Riverpod(keepAlive: true)
Duration entitlementAnswerTimeout(Ref ref) => const Duration(seconds: 2);

/// Auth identity as a rebuild signal — see [creditsAuthUserId] for the
/// precedent. A session appearing, changing or ending rebuilds the status.
@Riverpod(keepAlive: true)
Stream<String?> subscriptionAuthUserId(Ref ref) {
  return ref.watch(userEntitlementsRepositoryProvider).authUserIdChanges;
}

/// The current user's subscription status, from RevenueCat and nothing else
/// (mp-279, mp-284).
///
/// Exposed as `subscriptionStatusProvider`. keepAlive because the router
/// redirect and the paywall read it independently and the answer must
/// survive between them; the CustomerInfo listener it owns must also outlive
/// any single widget.
///
/// The rule:
/// 1. The SDK's cached entitlement is the answer whenever there is one,
///    online or not — `getCustomerInfo` serves the cache at once.
/// 2. No cache and no answer within [entitlementAnswerTimeoutProvider]
///    counts as locked ([SubscriptionStatus.none]).
/// 3. RevenueCat refreshes in the background; the listener pushes the new
///    status and the gate reacts.
/// 4. A cache that belongs to another RevenueCat identity than the signed-in
///    user is not an answer: locked until `logIn` has moved the identity.
///
/// Every answer it takes also settles the day-five reminder (mp-456 §4): an
/// active trial that will not renew cancels it. That covers the app open
/// (build) and the background refresh that follows a stale cache (the push).
/// Sign-out and account deletion cancel it too, so it never reaches the next
/// account on the phone.
///
/// **[build] never throws.** A keepAlive provider whose first build errors
/// would leave `.future` uncompleted for anyone awaiting it (the router
/// redirect, the paywall after a purchase); anything unexpected degrades to
/// locked rather than an [AsyncError].
@Riverpod(keepAlive: true, name: 'subscriptionStatusProvider')
class SubscriptionStatusController extends _$SubscriptionStatusController {
  SubscriptionService get _service => ref.read(subscriptionServiceProvider);
  UserEntitlementsRepository get _repo =>
      ref.read(userEntitlementsRepositoryProvider);

  /// The last status RevenueCat pushed through the listener this session,
  /// kept so a resolve that times out can still answer from it.
  SubscriptionStatus? _lastPush;

  @override
  FutureOr<SubscriptionStatus> build() async {
    // Rebuild on identity change (value unused — the repository reads the
    // live session). A new identity starts with no push on record.
    ref.watch(subscriptionAuthUserIdProvider);
    _lastPush = null;

    // Capture the service: `ref` may not be used inside an onDispose callback.
    final service = _service;
    service.setStatusListener(_onRevenueCatUpdate);
    ref.onDispose(() => service.setStatusListener(null));

    // Nobody signed in (sign-out, account deletion): the outgoing account's
    // reminder must not reach whoever signs in next on this phone.
    final userId = _repo.currentUserId;
    if (userId == null || userId.isEmpty) _cancelTrialReminder();

    try {
      final status = await _resolve();
      _settleTrialReminder(status);
      return status;
    } catch (e) {
      debugPrint('[SubscriptionStatus] build failed, locking: $e');
      return SubscriptionStatus.none;
    }
  }

  /// Re-resolve against RevenueCat. Called after configure/logIn at startup,
  /// after a purchase or restore, and on demand.
  Future<void> refresh() async {
    final next = await AsyncValue.guard(_resolve);
    // Never replace a known status with an error — stale beats broken for a
    // value that decides whether the app renders at all.
    if (next.hasError && state.hasValue) return;
    state = next;
    final status = next.value;
    if (status != null) _settleTrialReminder(status);
  }

  /// Forget everything for the outgoing user. The provider rebuilds on the
  /// auth change too; this makes the lock immediate.
  Future<void> clear() async {
    _lastPush = null;
    state = const AsyncData(SubscriptionStatus.none);
    _cancelTrialReminder();
  }

  /// RevenueCat pushed new CustomerInfo (purchase, renewal, expiry, restore,
  /// or the background refresh of a cached answer).
  void _onRevenueCatUpdate(SubscriptionStatus rc) {
    _lastPush = rc;
    state = AsyncData(rc);
    _settleTrialReminder(rc);
  }

  /// Cancel the day-five reminder once RevenueCat says the trial will not
  /// renew: the athlete cancelled, and a "your trial ends, then it's $X"
  /// notification would be wrong. Only an active trial counts — a locked
  /// status may just mean no answer yet, which says nothing about the
  /// reminder. Fire-and-forget: it never delays or fails the gate.
  void _settleTrialReminder(SubscriptionStatus status) {
    if (!status.active || !status.isTrial || status.willRenew) return;
    _cancelTrialReminder();
  }

  void _cancelTrialReminder() {
    final scheduler = ref.read(localNotificationSchedulerProvider);
    unawaited(
      scheduler.cancel(TrialReminder.notificationId).catchError((Object e) {
        debugPrint('[SubscriptionStatus] trial reminder not cancelled: $e');
      }),
    );
  }

  Future<SubscriptionStatus> _resolve() async {
    final userId = _repo.currentUserId;
    if (userId == null || userId.isEmpty) return SubscriptionStatus.none;

    final timeout = ref.read(entitlementAnswerTimeoutProvider);
    final answer = await _answerFor(
      userId,
    ).timeout(timeout, onTimeout: () => null);
    if (answer != null) return answer;
    // No answer in time: the last push (the cache, when the SDK announced
    // it) still counts; otherwise locked.
    return _lastPush ?? SubscriptionStatus.none;
  }

  /// RevenueCat's answer for [userId], or null when it has none. The
  /// identity is checked before the cache is trusted: the cache belongs to
  /// whichever app user id the SDK holds, and after a sign-in on this device
  /// that may still be the previous account (or an anonymous id) until
  /// `logIn` has run. `logIn` is a network call, so it is only made when
  /// needed — the cached path stays local and instant.
  Future<SubscriptionStatus?> _answerFor(String userId) async {
    final current = await _service.currentAppUserId();
    if (current != userId) {
      await _service.logIn(userId);
      final after = await _service.currentAppUserId();
      if (after != userId) {
        // Not identified (offline, or the SDK is unavailable). Whatever the
        // cache says is about someone else: locked, and Restore on the
        // paywall succeeds as soon as the network is back (mp-284 §2).
        return SubscriptionStatus.none;
      }
    }
    return _service.fetchStatus();
  }
}
