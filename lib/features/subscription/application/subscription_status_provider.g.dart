// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// How long the gate waits for RevenueCat before an unknown entitlement
/// counts as locked (mp-284: "no cache and no answer within a couple of
/// seconds"). A provider so tests can shorten it; the app never overrides it.

@ProviderFor(entitlementAnswerTimeout)
const entitlementAnswerTimeoutProvider = EntitlementAnswerTimeoutProvider._();

/// How long the gate waits for RevenueCat before an unknown entitlement
/// counts as locked (mp-284: "no cache and no answer within a couple of
/// seconds"). A provider so tests can shorten it; the app never overrides it.

final class EntitlementAnswerTimeoutProvider
    extends $FunctionalProvider<Duration, Duration, Duration>
    with $Provider<Duration> {
  /// How long the gate waits for RevenueCat before an unknown entitlement
  /// counts as locked (mp-284: "no cache and no answer within a couple of
  /// seconds"). A provider so tests can shorten it; the app never overrides it.
  const EntitlementAnswerTimeoutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'entitlementAnswerTimeoutProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$entitlementAnswerTimeoutHash();

  @$internal
  @override
  $ProviderElement<Duration> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Duration create(Ref ref) {
    return entitlementAnswerTimeout(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Duration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Duration>(value),
    );
  }
}

String _$entitlementAnswerTimeoutHash() =>
    r'bce41b6bb23f369a079a34f600da92902d3a1762';

/// Auth identity as a rebuild signal — see [creditsAuthUserId] for the
/// precedent. A session appearing, changing or ending rebuilds the status.

@ProviderFor(subscriptionAuthUserId)
const subscriptionAuthUserIdProvider = SubscriptionAuthUserIdProvider._();

/// Auth identity as a rebuild signal — see [creditsAuthUserId] for the
/// precedent. A session appearing, changing or ending rebuilds the status.

final class SubscriptionAuthUserIdProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, Stream<String?>>
    with $FutureModifier<String?>, $StreamProvider<String?> {
  /// Auth identity as a rebuild signal — see [creditsAuthUserId] for the
  /// precedent. A session appearing, changing or ending rebuilds the status.
  const SubscriptionAuthUserIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionAuthUserIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionAuthUserIdHash();

  @$internal
  @override
  $StreamProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<String?> create(Ref ref) {
    return subscriptionAuthUserId(ref);
  }
}

String _$subscriptionAuthUserIdHash() =>
    r'7ea3dc3ddfce16d5f2ac1c09e73eba3c846a6f5b';

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

@ProviderFor(SubscriptionStatusController)
const subscriptionStatusProvider = SubscriptionStatusControllerProvider._();

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
final class SubscriptionStatusControllerProvider
    extends
        $AsyncNotifierProvider<
          SubscriptionStatusController,
          SubscriptionStatus
        > {
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
  const SubscriptionStatusControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionStatusControllerHash();

  @$internal
  @override
  SubscriptionStatusController create() => SubscriptionStatusController();
}

String _$subscriptionStatusControllerHash() =>
    r'bd9c3a6141b82932bc799bbe317f1ab4b7138cf4';

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

abstract class _$SubscriptionStatusController
    extends $AsyncNotifier<SubscriptionStatus> {
  FutureOr<SubscriptionStatus> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<SubscriptionStatus>, SubscriptionStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SubscriptionStatus>, SubscriptionStatus>,
              AsyncValue<SubscriptionStatus>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
