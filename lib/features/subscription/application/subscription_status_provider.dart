import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/analytics/internal_user_service.dart';
import '../data/subscription_service.dart';
import '../data/user_entitlements_repository.dart';
import '../domain/entitlement.dart';

part 'subscription_status_provider.g.dart';

/// What the tester switch grants: Pro, client-side only, no expiry.
const SubscriptionStatus kInternalProStatus = SubscriptionStatus(
  active: true,
  source: SubscriptionSource.internal,
);

/// Auth identity as a rebuild signal — see [creditsAuthUserId] for the
/// precedent. A session appearing, changing or ending rebuilds the status.
@Riverpod(keepAlive: true)
Stream<String?> subscriptionAuthUserId(Ref ref) {
  return ref.watch(userEntitlementsRepositoryProvider).authUserIdChanges;
}

/// The current user's Pro status: RevenueCat ∪ server row ∪ tester flag.
///
/// Exposed as `subscriptionStatusProvider`. keepAlive because the router
/// redirect, the tabs screen and the Pro screen all read it independently and
/// the answer must survive between them; the CustomerInfo listener it owns
/// must also outlive any single widget.
///
/// **[build] never throws.** Like [CreditsController], a keepAlive provider
/// whose first build errors would leave `.future` uncompleted for anyone
/// awaiting it (startup priming, the paywall after a purchase). Every source
/// already swallows its own errors; anything unexpected degrades to "not
/// Pro" (or the tester grant) rather than an [AsyncError].
///
/// Resolution order in [SubscriptionStatus.merge]: RevenueCat first (it sees
/// the store directly and updates in real time), then the server row (the
/// paywall the edge functions enforce; also the offline answer via its Drift
/// cache), then the internal tester flag (client-only, never sent to the
/// server — `users.is_internal` is the server-side counterpart).
@Riverpod(keepAlive: true, name: 'subscriptionStatusProvider')
class SubscriptionStatusController extends _$SubscriptionStatusController {
  SubscriptionService get _service => ref.read(subscriptionServiceProvider);
  UserEntitlementsRepository get _repo =>
      ref.read(userEntitlementsRepositoryProvider);

  /// Last server-side answer, kept so a RevenueCat push can be merged without
  /// another network read.
  SubscriptionStatus? _lastServer;

  /// Last tester-flag value successfully mirrored onto `users.is_internal`
  /// (null = never mirrored this session). The mirror keeps the SERVER's Pro
  /// gate in step with the 7-tap switch — see
  /// [UserEntitlementsRepository.mirrorInternalFlag]. A failed write leaves
  /// this unset so the next resolve retries. Scoped to [_mirroredForUser]:
  /// a signed-in identity change must not inherit the previous account's
  /// mirror state, or the next tester to sign in on this device would never
  /// be mirrored.
  bool? _lastMirroredInternal;
  String? _mirroredForUser;

  @override
  FutureOr<SubscriptionStatus> build() async {
    // Rebuild on identity change (value unused — the repository reads the
    // live session) and whenever the tester switch flips.
    ref.watch(subscriptionAuthUserIdProvider);
    final internal = ref.watch(internalDeviceFlagProvider);

    // Capture the service: `ref` may not be used inside an onDispose callback.
    final service = _service;
    service.setStatusListener(_onRevenueCatUpdate);
    ref.onDispose(() => service.setStatusListener(null));

    try {
      return await _resolve(internal: internal);
    } catch (e) {
      debugPrint('[SubscriptionStatus] build failed, degrading: $e');
      return internal ? kInternalProStatus : SubscriptionStatus.none;
    }
  }

  /// Re-resolve every source. Called after RevenueCat configure/logIn at
  /// startup, after a purchase or restore, and on demand.
  Future<void> refresh() async {
    final internal = ref.read(internalDeviceFlagProvider);
    final next = await AsyncValue.guard(() => _resolve(internal: internal));
    // Never replace a known status with an error — stale beats broken for a
    // value that decides whether a whole tab exists.
    if (next.hasError && state.hasValue) return;
    state = next;
  }

  /// Forget everything for the outgoing user: Drift cache, server memo, and
  /// the in-memory status. The provider rebuilds on the auth change too, but
  /// the Drift row must be removed explicitly.
  Future<void> clear() async {
    _lastServer = null;
    _lastMirroredInternal = null;
    _mirroredForUser = null;
    await _repo.clearCache();
    final internal = ref.read(internalDeviceFlagProvider);
    state = AsyncData(internal ? kInternalProStatus : SubscriptionStatus.none);
  }

  /// RevenueCat pushed new CustomerInfo (purchase, renewal, expiry, restore).
  /// Merge with the last server answer so a still-valid server row is not
  /// lost when RevenueCat reports "none" for, say, a promo grant.
  void _onRevenueCatUpdate(SubscriptionStatus rc) {
    final internal = ref.read(internalDeviceFlagProvider);
    state = AsyncData(
      SubscriptionStatus.merge([
        rc,
        _lastServer,
        if (internal) kInternalProStatus,
      ]),
    );
  }

  Future<SubscriptionStatus> _resolve({required bool internal}) async {
    final userId = _repo.currentUserId;
    SubscriptionStatus? rc;
    SubscriptionStatus? server;
    if (userId != null && userId.isNotEmpty) {
      if (_mirroredForUser != userId) {
        _mirroredForUser = userId;
        _lastMirroredInternal = null;
      }
      // Keep the server-side gate in step with the tester switch before the
      // reads, so the very resolve that unlocks the tab also unlocks the
      // vana-* edge functions for this account.
      //
      // `false` is only written on an ON→OFF flip observed THIS session:
      // an unconditional false-mirror would fire for every ordinary user on
      // every cold start, and would clobber an `is_internal` an admin set
      // server-side for an account whose device never had the switch on.
      // (Corollary: flipping the switch off and never reopening the app
      // leaves the server flag standing — clear it in-session or by admin.)
      final shouldMirror = internal
          ? _lastMirroredInternal != true
          : _lastMirroredInternal == true;
      if (shouldMirror) {
        final mirrored = await _repo.mirrorInternalFlag(userId, internal);
        if (mirrored) _lastMirroredInternal = internal;
      }
      rc = await _service.fetchStatus();
      server =
          await _repo.fetchRemote(userId, Entitlement.pro) ??
          await _repo.readCached(userId, Entitlement.pro);
      _lastServer = server;
    } else {
      _lastServer = null;
    }
    return SubscriptionStatus.merge([
      rc,
      server,
      if (internal) kInternalProStatus,
    ]);
  }
}
