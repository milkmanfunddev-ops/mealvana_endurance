// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pro_paywall_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Current Offering's monthly and annual packages plus intro
/// eligibility, read once per paywall visit. Falls back to `default` when no
/// offering is marked current. Which offering is current is RevenueCat's
/// call alone: 1 October to 30 November it is `founding`, with no release
/// (mp-453).

@ProviderFor(paywallPlans)
const paywallPlansProvider = PaywallPlansProvider._();

/// The Current Offering's monthly and annual packages plus intro
/// eligibility, read once per paywall visit. Falls back to `default` when no
/// offering is marked current. Which offering is current is RevenueCat's
/// call alone: 1 October to 30 November it is `founding`, with no release
/// (mp-453).

final class PaywallPlansProvider
    extends
        $FunctionalProvider<
          AsyncValue<PaywallPlans>,
          PaywallPlans,
          FutureOr<PaywallPlans>
        >
    with $FutureModifier<PaywallPlans>, $FutureProvider<PaywallPlans> {
  /// The Current Offering's monthly and annual packages plus intro
  /// eligibility, read once per paywall visit. Falls back to `default` when no
  /// offering is marked current. Which offering is current is RevenueCat's
  /// call alone: 1 October to 30 November it is `founding`, with no release
  /// (mp-453).
  const PaywallPlansProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paywallPlansProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paywallPlansHash();

  @$internal
  @override
  $FutureProviderElement<PaywallPlans> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PaywallPlans> create(Ref ref) {
    return paywallPlans(ref);
  }
}

String _$paywallPlansHash() => r'08216f2ec4e7357081fcac58680f8d2805f2b2e3';

/// Whether this account has a store subscription to manage, running or
/// ended: the paywall's ⋯ menu offers Manage subscription only then
/// (mp-494 §1). A restore asks again.

@ProviderFor(paywallHasSubscription)
const paywallHasSubscriptionProvider = PaywallHasSubscriptionProvider._();

/// Whether this account has a store subscription to manage, running or
/// ended: the paywall's ⋯ menu offers Manage subscription only then
/// (mp-494 §1). A restore asks again.

final class PaywallHasSubscriptionProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether this account has a store subscription to manage, running or
  /// ended: the paywall's ⋯ menu offers Manage subscription only then
  /// (mp-494 §1). A restore asks again.
  const PaywallHasSubscriptionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paywallHasSubscriptionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paywallHasSubscriptionHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return paywallHasSubscription(ref);
  }
}

String _$paywallHasSubscriptionHash() =>
    r'e226a2043769577791a30587530e06db5ccd4b81';

/// Drives purchase and restore for the paywall.
///
/// State is `AsyncValue<void>`: loading while a store call is in flight,
/// data when idle, error when the last operation failed unexpectedly.
///
/// Whatever opens the app leaves the state loading until the router has
/// moved on: a purchase (05-004), a restore, or a redeemed Code that grants
/// Pro (87-001). The Gate opens a moment before the router replaces the
/// paywall; an idle state there would bring Continue back live, and a tap
/// would start a purchase for an account that already has Pro. The hold
/// starts when the status reports the account open and ends when it reports
/// it closed again (a lapse, or another account signing in), so a paywall
/// shown later can sell.
///
/// keepAlive for the same reason as [PurchaseController]: the screen only
/// `ref.read`s the notifier to call [buy], so under autoDispose the notifier
/// could be torn down at the first await and every later `ref` use would
/// throw — a purchase in flight must outlive the widget that started it.

@ProviderFor(ProPaywallController)
const proPaywallControllerProvider = ProPaywallControllerProvider._();

/// Drives purchase and restore for the paywall.
///
/// State is `AsyncValue<void>`: loading while a store call is in flight,
/// data when idle, error when the last operation failed unexpectedly.
///
/// Whatever opens the app leaves the state loading until the router has
/// moved on: a purchase (05-004), a restore, or a redeemed Code that grants
/// Pro (87-001). The Gate opens a moment before the router replaces the
/// paywall; an idle state there would bring Continue back live, and a tap
/// would start a purchase for an account that already has Pro. The hold
/// starts when the status reports the account open and ends when it reports
/// it closed again (a lapse, or another account signing in), so a paywall
/// shown later can sell.
///
/// keepAlive for the same reason as [PurchaseController]: the screen only
/// `ref.read`s the notifier to call [buy], so under autoDispose the notifier
/// could be torn down at the first await and every later `ref` use would
/// throw — a purchase in flight must outlive the widget that started it.
final class ProPaywallControllerProvider
    extends $AsyncNotifierProvider<ProPaywallController, void> {
  /// Drives purchase and restore for the paywall.
  ///
  /// State is `AsyncValue<void>`: loading while a store call is in flight,
  /// data when idle, error when the last operation failed unexpectedly.
  ///
  /// Whatever opens the app leaves the state loading until the router has
  /// moved on: a purchase (05-004), a restore, or a redeemed Code that grants
  /// Pro (87-001). The Gate opens a moment before the router replaces the
  /// paywall; an idle state there would bring Continue back live, and a tap
  /// would start a purchase for an account that already has Pro. The hold
  /// starts when the status reports the account open and ends when it reports
  /// it closed again (a lapse, or another account signing in), so a paywall
  /// shown later can sell.
  ///
  /// keepAlive for the same reason as [PurchaseController]: the screen only
  /// `ref.read`s the notifier to call [buy], so under autoDispose the notifier
  /// could be torn down at the first await and every later `ref` use would
  /// throw — a purchase in flight must outlive the widget that started it.
  const ProPaywallControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'proPaywallControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$proPaywallControllerHash();

  @$internal
  @override
  ProPaywallController create() => ProPaywallController();
}

String _$proPaywallControllerHash() =>
    r'1703aac7ee1fc61c5fda9973729af516aba3306e';

/// Drives purchase and restore for the paywall.
///
/// State is `AsyncValue<void>`: loading while a store call is in flight,
/// data when idle, error when the last operation failed unexpectedly.
///
/// Whatever opens the app leaves the state loading until the router has
/// moved on: a purchase (05-004), a restore, or a redeemed Code that grants
/// Pro (87-001). The Gate opens a moment before the router replaces the
/// paywall; an idle state there would bring Continue back live, and a tap
/// would start a purchase for an account that already has Pro. The hold
/// starts when the status reports the account open and ends when it reports
/// it closed again (a lapse, or another account signing in), so a paywall
/// shown later can sell.
///
/// keepAlive for the same reason as [PurchaseController]: the screen only
/// `ref.read`s the notifier to call [buy], so under autoDispose the notifier
/// could be torn down at the first await and every later `ref` use would
/// throw — a purchase in flight must outlive the widget that started it.

abstract class _$ProPaywallController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
