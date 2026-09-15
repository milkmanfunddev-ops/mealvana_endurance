// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pro_paywall_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The `default` offering's monthly and annual packages plus intro
/// eligibility, read once per paywall visit.

@ProviderFor(paywallPlans)
const paywallPlansProvider = PaywallPlansProvider._();

/// The `default` offering's monthly and annual packages plus intro
/// eligibility, read once per paywall visit.

final class PaywallPlansProvider
    extends
        $FunctionalProvider<
          AsyncValue<PaywallPlans>,
          PaywallPlans,
          FutureOr<PaywallPlans>
        >
    with $FutureModifier<PaywallPlans>, $FutureProvider<PaywallPlans> {
  /// The `default` offering's monthly and annual packages plus intro
  /// eligibility, read once per paywall visit.
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

String _$paywallPlansHash() => r'31a85e1e38d3abe4311c6dca793898d736801ff5';

/// Drives purchase, restore and "manage subscription" for the paywall.
///
/// State is `AsyncValue<void>`: loading while a store call is in flight,
/// data when idle, error when the last operation failed unexpectedly.
///
/// keepAlive for the same reason as [PurchaseController]: the screen only
/// `ref.read`s the notifier to call [buy], so under autoDispose the notifier
/// could be torn down at the first await and every later `ref` use would
/// throw — a purchase in flight must outlive the widget that started it.

@ProviderFor(ProPaywallController)
const proPaywallControllerProvider = ProPaywallControllerProvider._();

/// Drives purchase, restore and "manage subscription" for the paywall.
///
/// State is `AsyncValue<void>`: loading while a store call is in flight,
/// data when idle, error when the last operation failed unexpectedly.
///
/// keepAlive for the same reason as [PurchaseController]: the screen only
/// `ref.read`s the notifier to call [buy], so under autoDispose the notifier
/// could be torn down at the first await and every later `ref` use would
/// throw — a purchase in flight must outlive the widget that started it.
final class ProPaywallControllerProvider
    extends $AsyncNotifierProvider<ProPaywallController, void> {
  /// Drives purchase, restore and "manage subscription" for the paywall.
  ///
  /// State is `AsyncValue<void>`: loading while a store call is in flight,
  /// data when idle, error when the last operation failed unexpectedly.
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
    r'ca60377b6f19ec46da5015ce98202965edaa8abc';

/// Drives purchase, restore and "manage subscription" for the paywall.
///
/// State is `AsyncValue<void>`: loading while a store call is in flight,
/// data when idle, error when the last operation failed unexpectedly.
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
