// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(SubscriptionStatusController)
const subscriptionStatusProvider = SubscriptionStatusControllerProvider._();

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
final class SubscriptionStatusControllerProvider
    extends
        $AsyncNotifierProvider<
          SubscriptionStatusController,
          SubscriptionStatus
        > {
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
    r'2186b0ef2878f2102ba878b05d590e931f098df5';

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
