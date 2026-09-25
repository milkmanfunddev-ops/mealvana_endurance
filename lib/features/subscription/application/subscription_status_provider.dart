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

/// The clock the status judges an answer's own expiry against (mp-679). A
/// provider so tests can pin it; the app never overrides it.
@Riverpod(keepAlive: true)
DateTime Function() subscriptionClock(Ref ref) => DateTime.now;

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
/// 5. An active answer counts for [kRenewalGrace] past its own expiry, then
///    as closed until a fresh answer arrives (mp-679, Finding 07-002).
/// 6. The grace is only for a plan that will renew, so before it is given
///    RevenueCat itself is asked: an answer in its grace
///    ([SubscriptionStatus.inRenewalGraceAt]) is followed by a fresh fetch
///    within the same wait, and the fresh answer wins. A cancel the saved
///    copy has not seen closes the Gate at the end, not 15 minutes later;
///    no fresh answer in time leaves the copy counting (ticket 105, Finding
///    87-006).
/// 7. While the controller lives, one timer waits for the next moment to
///    look again: a renewing answer's own expiry (to ask RevenueCat, rule 6),
///    else the moment it stops counting. It re-counts then (closed, unless
///    something fresher came) and re-fetches once, so an app left open lands
///    on the paywall on time, not on the next resume (mp-457, Finding
///    05-005).
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

  /// Resolves waiting for an answer, each taking the first push that comes
  /// while its fetch is out: the SDK announcing its saved copy is an answer
  /// at once, not only when the wait runs out (ticket 105, Finding 87-009).
  final _pushWaiters = <Completer<SubscriptionStatus?>>{};

  /// Fires at the next moment to look at the current answer (rule 7). One
  /// at a time:
  /// every answer taken replaces it.
  Timer? _recountTimer;

  /// The longest single wait. A browser fires a longer timer at once
  /// (setTimeout caps at about 24.8 days), so a far expiry waits in steps.
  static const _maxWait = Duration(days: 1);

  @override
  FutureOr<SubscriptionStatus> build() async {
    // Rebuild on identity change (value unused — the repository reads the
    // live session). A new identity starts with no push on record.
    ref.watch(subscriptionAuthUserIdProvider);
    _lastPush = null;
    // Riverpod keeps this notifier across a rebuild: the old answer's timer
    // must not outlive it.
    _cancelRecount();
    ref.onDispose(_cancelRecount);

    // Capture the service: `ref` may not be used inside an onDispose callback.
    final service = _service;
    // The listener is sync; the identity check awaits, so its future is
    // kept alive here and any failure is logged instead of going unhandled.
    service.setStatusListener(
      (rc) => unawaited(
        _onRevenueCatUpdate(rc).catchError((Object e) {
          debugPrint('[SubscriptionStatus] push not taken: $e');
        }),
      ),
    );
    ref.onDispose(() => service.setStatusListener(null));

    // Nobody signed in (sign-out, account deletion): the outgoing account's
    // reminder must not reach whoever signs in next on this phone.
    final userId = _repo.currentUserId;
    if (userId == null || userId.isEmpty) _cancelTrialReminder();

    try {
      final status = await _resolve();
      _settleTrialReminder(status);
      if (ref.mounted) _scheduleRecount(status);
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
    if (status != null) {
      _settleTrialReminder(status);
      _scheduleRecount(status);
    }
  }

  /// Ask RevenueCat itself, past the SDK's saved copy, and take its answer
  /// (the Subscription screen opening, ticket 105: a plan in its last period
  /// reads "Ends on", never "Renews on"). No answer in the wait (offline)
  /// keeps the current one: a failed look never closes the Gate.
  /// Never throws.
  Future<void> fetchFresh() async {
    try {
      await future;
      final userId = _repo.currentUserId;
      if (userId == null || userId.isEmpty || !ref.mounted) return;
      final fresh = await _freshAnswerFor(userId).timeout(
        ref.read(entitlementAnswerTimeoutProvider),
        onTimeout: () => null,
      );
      if (fresh == null || !ref.mounted) return;
      final counted = _counted(fresh);
      state = AsyncData(counted);
      _settleTrialReminder(counted);
      _scheduleRecount(counted);
    } catch (e) {
      debugPrint('[SubscriptionStatus] fresh fetch not taken: $e');
    }
  }

  /// Forget everything for the outgoing user (sign-out, account deletion):
  /// the lock is immediate, the reminder is cancelled, and the RevenueCat
  /// SDK returns to an anonymous customer with an empty cache, so a
  /// signed-out phone no longer fetches the last account's entitlement and
  /// the next account never reads it (Findings 03-002, 32-002). The
  /// provider rebuilds on the auth change too.
  Future<void> clear() async {
    _lastPush = null;
    _cancelRecount();
    state = const AsyncData(SubscriptionStatus.none);
    _cancelTrialReminder();
    await _service.logOut();
  }

  /// RevenueCat pushed new CustomerInfo (purchase, renewal, expiry, restore,
  /// or the background refresh of a cached answer).
  ///
  /// A push is only an answer for the signed-in user when the SDK's identity
  /// is theirs. Right after a sign-up on a phone that held another account,
  /// the SDK still pushes the cached customer of that account (or of the
  /// anonymous customer) until `logIn` has moved the identity; taking it
  /// showed a never-paid account as Pro for a moment (Finding 32-002).
  Future<void> _onRevenueCatUpdate(SubscriptionStatus rc) async {
    final userId = _repo.currentUserId;
    if (userId == null || userId.isEmpty) return;
    final current = await _service.currentAppUserId();
    if (!ref.mounted || current != userId) return;
    final counted = _counted(rc);
    _lastPush = counted;
    for (final waiter in _pushWaiters) {
      if (!waiter.isCompleted) waiter.complete(rc);
    }
    state = AsyncData(counted);
    _settleTrialReminder(counted);
    _scheduleRecount(counted);
  }

  /// Wait for the next moment to look at [status] (rule 7), replacing any
  /// earlier wait. Nothing to wait for when it is closed or open-ended.
  void _scheduleRecount(SubscriptionStatus status) {
    _cancelRecount();
    final now = ref.read(subscriptionClockProvider)();
    final next = status.nextLookAt(now);
    if (next == null) return;
    final wait = next.difference(now);
    _recountTimer = Timer(
      wait > _maxWait ? _maxWait : wait,
      () => unawaited(
        _recount().catchError((Object e) {
          debugPrint('[SubscriptionStatus] re-count failed: $e');
        }),
      ),
    );
  }

  void _cancelRecount() {
    _recountTimer?.cancel();
    _recountTimer = null;
  }

  /// The current answer's wait is over: count it again, then ask
  /// RevenueCat once for a fresher one. At a renewing answer's expiry that
  /// is the ask before the grace (rule 6): the answer still counts while
  /// the fetch runs. A step of a far wait that ended early just waits
  /// again. A fresh answer re-schedules.
  Future<void> _recount() async {
    _recountTimer = null;
    if (!ref.mounted) return;
    final status = state.value;
    if (status == null) return;
    final counted = _counted(status);
    if (counted.active) {
      if (counted.inRenewalGraceAt(ref.read(subscriptionClockProvider)())) {
        await refresh();
        return;
      }
      _scheduleRecount(counted);
      return;
    }
    state = AsyncData(counted);
    // The SDK's cached copy is what just ran out; ask RevenueCat itself.
    await _service.forgetCachedStatus();
    if (!ref.mounted) return;
    await refresh();
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

    final clock = ref.read(subscriptionClockProvider);
    final started = clock();
    final timeout = ref.read(entitlementAnswerTimeoutProvider);
    final pushed = Completer<SubscriptionStatus?>();
    _pushWaiters.add(pushed);
    final SubscriptionStatus? answer;
    try {
      answer = await Future.any([
        _answerFor(userId),
        pushed.future,
      ]).timeout(timeout, onTimeout: () => null);
    } finally {
      _pushWaiters.remove(pushed);
    }
    // No answer in time: the last push (the cache, when the SDK announced
    // it) still counts; otherwise locked.
    final taken = answer ?? _lastPush ?? SubscriptionStatus.none;
    if (!ref.mounted || !taken.inRenewalGraceAt(clock())) {
      return _counted(taken);
    }
    // In its grace (rule 6): ask RevenueCat before giving it, within what
    // is left of the same wait, so startup still waits at most [timeout]
    // (mp-335). No fresh answer in time: the copy counts as it is.
    final left = timeout - clock().difference(started);
    final fresh = left <= Duration.zero
        ? null
        : await _freshAnswerFor(userId).timeout(left, onTimeout: () => null);
    return _counted(fresh ?? taken);
  }

  /// RevenueCat's own answer for [userId], past the SDK's saved copy, or
  /// null when it has none (offline, SDK unavailable).
  Future<SubscriptionStatus?> _freshAnswerFor(String userId) async {
    await _service.forgetCachedStatus();
    return _answerFor(userId);
  }

  /// [status] as it counts now (mp-679): RevenueCat's saved copy judges
  /// itself against the time it was fetched, so it can still say active
  /// after its own expiry. It keeps the Gate open for [kRenewalGrace] past
  /// that expiry while the fetch runs, then counts as closed until a fresh
  /// answer, which carries the new period's expiry, replaces it.
  SubscriptionStatus _counted(SubscriptionStatus status) =>
      status.countedAt(ref.read(subscriptionClockProvider)());

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
