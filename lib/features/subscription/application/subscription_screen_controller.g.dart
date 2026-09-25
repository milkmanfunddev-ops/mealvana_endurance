// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_screen_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The clock a Grant's days left are counted against. A provider so tests
/// can pin it; the app never overrides it.

@ProviderFor(subscriptionScreenClock)
const subscriptionScreenClockProvider = SubscriptionScreenClockProvider._();

/// The clock a Grant's days left are counted against. A provider so tests
/// can pin it; the app never overrides it.

final class SubscriptionScreenClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  /// The clock a Grant's days left are counted against. A provider so tests
  /// can pin it; the app never overrides it.
  const SubscriptionScreenClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionScreenClockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionScreenClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return subscriptionScreenClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$subscriptionScreenClockHash() =>
    r'918a74004f4b5e948667bd66e42640c19e29fbcd';

/// Whether this account has a store subscription that is running and will
/// renew, so deleting the account leaves it billing: both Delete account
/// confirms (Settings, the paywall's menu) say so and offer Manage
/// subscription only then (finding 02-004). Asked afresh on each open.

@ProviderFor(renewingStoreSubscription)
const renewingStoreSubscriptionProvider = RenewingStoreSubscriptionProvider._();

/// Whether this account has a store subscription that is running and will
/// renew, so deleting the account leaves it billing: both Delete account
/// confirms (Settings, the paywall's menu) say so and offer Manage
/// subscription only then (finding 02-004). Asked afresh on each open.

final class RenewingStoreSubscriptionProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether this account has a store subscription that is running and will
  /// renew, so deleting the account leaves it billing: both Delete account
  /// confirms (Settings, the paywall's menu) say so and offer Manage
  /// subscription only then (finding 02-004). Asked afresh on each open.
  const RenewingStoreSubscriptionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'renewingStoreSubscriptionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$renewingStoreSubscriptionHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return renewingStoreSubscription(ref);
  }
}

String _$renewingStoreSubscriptionHash() =>
    r'175e4e2d790f668f5223856e27e4ea39f83e230b';

/// Asks RevenueCat itself, past the SDK's saved copy, once per opening of
/// the Subscription screen (ticket 105, Finding 87-006): a plan in its last
/// period reads "Ends on {date}. It won't renew." (mp-558), never "Renews
/// on". Its own provider so the ask runs once per open, not on every status
/// change the screen rebuilds for; it goes with the screen. Bounded by the
/// status controller's wait; no answer keeps the saved copy.

@ProviderFor(subscriptionFreshOnOpen)
const subscriptionFreshOnOpenProvider = SubscriptionFreshOnOpenProvider._();

/// Asks RevenueCat itself, past the SDK's saved copy, once per opening of
/// the Subscription screen (ticket 105, Finding 87-006): a plan in its last
/// period reads "Ends on {date}. It won't renew." (mp-558), never "Renews
/// on". Its own provider so the ask runs once per open, not on every status
/// change the screen rebuilds for; it goes with the screen. Bounded by the
/// status controller's wait; no answer keeps the saved copy.

final class SubscriptionFreshOnOpenProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Asks RevenueCat itself, past the SDK's saved copy, once per opening of
  /// the Subscription screen (ticket 105, Finding 87-006): a plan in its last
  /// period reads "Ends on {date}. It won't renew." (mp-558), never "Renews
  /// on". Its own provider so the ask runs once per open, not on every status
  /// change the screen rebuilds for; it goes with the screen. Bounded by the
  /// status controller's wait; no answer keeps the saved copy.
  const SubscriptionFreshOnOpenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionFreshOnOpenProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionFreshOnOpenHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return subscriptionFreshOnOpen(ref);
  }
}

String _$subscriptionFreshOnOpenHash() =>
    r'ecb01e5c151be763e6347b97f7307290492d3d86';

/// The Subscription screen in Settings (mp-495): the plan's status from the
/// status provider (RevenueCat, mp-279), whether there is a store
/// subscription to manage, and where Manage subscription goes.
///
/// Rebuilds whenever the status does, so a Code redeemed on the screen
/// shows at once.

@ProviderFor(SubscriptionScreenController)
const subscriptionScreenControllerProvider =
    SubscriptionScreenControllerProvider._();

/// The Subscription screen in Settings (mp-495): the plan's status from the
/// status provider (RevenueCat, mp-279), whether there is a store
/// subscription to manage, and where Manage subscription goes.
///
/// Rebuilds whenever the status does, so a Code redeemed on the screen
/// shows at once.
final class SubscriptionScreenControllerProvider
    extends
        $AsyncNotifierProvider<
          SubscriptionScreenController,
          SubscriptionScreenState
        > {
  /// The Subscription screen in Settings (mp-495): the plan's status from the
  /// status provider (RevenueCat, mp-279), whether there is a store
  /// subscription to manage, and where Manage subscription goes.
  ///
  /// Rebuilds whenever the status does, so a Code redeemed on the screen
  /// shows at once.
  const SubscriptionScreenControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionScreenControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionScreenControllerHash();

  @$internal
  @override
  SubscriptionScreenController create() => SubscriptionScreenController();
}

String _$subscriptionScreenControllerHash() =>
    r'9f9c3ce1271829e88261bb7d5fd6a5e6c03a362c';

/// The Subscription screen in Settings (mp-495): the plan's status from the
/// status provider (RevenueCat, mp-279), whether there is a store
/// subscription to manage, and where Manage subscription goes.
///
/// Rebuilds whenever the status does, so a Code redeemed on the screen
/// shows at once.

abstract class _$SubscriptionScreenController
    extends $AsyncNotifier<SubscriptionScreenState> {
  FutureOr<SubscriptionScreenState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<
              AsyncValue<SubscriptionScreenState>,
              SubscriptionScreenState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SubscriptionScreenState>,
                SubscriptionScreenState
              >,
              AsyncValue<SubscriptionScreenState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
