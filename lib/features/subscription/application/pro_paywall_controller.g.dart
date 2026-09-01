// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pro_paywall_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The offering that carries `$rc_monthly` / `$rc_annual`. Null when the SDK
/// is unconfigured or the store served nothing — the screen renders its
/// "plans unavailable" state.

@ProviderFor(proOffering)
const proOfferingProvider = ProOfferingProvider._();

/// The offering that carries `$rc_monthly` / `$rc_annual`. Null when the SDK
/// is unconfigured or the store served nothing — the screen renders its
/// "plans unavailable" state.

final class ProOfferingProvider
    extends
        $FunctionalProvider<
          AsyncValue<Offering?>,
          Offering?,
          FutureOr<Offering?>
        >
    with $FutureModifier<Offering?>, $FutureProvider<Offering?> {
  /// The offering that carries `$rc_monthly` / `$rc_annual`. Null when the SDK
  /// is unconfigured or the store served nothing — the screen renders its
  /// "plans unavailable" state.
  const ProOfferingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'proOfferingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$proOfferingHash();

  @$internal
  @override
  $FutureProviderElement<Offering?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Offering?> create(Ref ref) {
    return proOffering(ref);
  }
}

String _$proOfferingHash() => r'6f2f80fc8626755f0116bb1c765d2efd1822b918';

/// Drives purchase and restore for the Pro subscription.
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

/// Drives purchase and restore for the Pro subscription.
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
  /// Drives purchase and restore for the Pro subscription.
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
    r'ced4b436a85b8eb0823b512ddef079d4264caf21';

/// Drives purchase and restore for the Pro subscription.
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
