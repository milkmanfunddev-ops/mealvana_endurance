// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the RevenueCat `credits` offering.
///
/// Returns null when the SDK is not configured, the user has RC disabled, or
/// on any network error — the UI should render a disabled / coming-soon state
/// in that case.

@ProviderFor(aiCreditOffering)
const aiCreditOfferingProvider = AiCreditOfferingProvider._();

/// Provides the RevenueCat `credits` offering.
///
/// Returns null when the SDK is not configured, the user has RC disabled, or
/// on any network error — the UI should render a disabled / coming-soon state
/// in that case.

final class AiCreditOfferingProvider
    extends
        $FunctionalProvider<
          AsyncValue<Offering?>,
          Offering?,
          FutureOr<Offering?>
        >
    with $FutureModifier<Offering?>, $FutureProvider<Offering?> {
  /// Provides the RevenueCat `credits` offering.
  ///
  /// Returns null when the SDK is not configured, the user has RC disabled, or
  /// on any network error — the UI should render a disabled / coming-soon state
  /// in that case.
  const AiCreditOfferingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiCreditOfferingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiCreditOfferingHash();

  @$internal
  @override
  $FutureProviderElement<Offering?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Offering?> create(Ref ref) {
    return aiCreditOffering(ref);
  }
}

String _$aiCreditOfferingHash() => r'f80dc0b5e1feadd84936737e9626ec31c3c5e1e6';

/// The packages the current build is allowed to *display*, in offering order.
///
/// This is [aiCreditOffering] minus the tester-only SKUs
/// ([kTesterOnlyProductIds]): the $0.99 pipeline-test pack exists in the store
/// so the whole purchase path (StoreKit → RevenueCat → webhook → wallet) can
/// be exercised end to end, but only devices with tester mode ON (the 7-tap
/// switch, defaulting on for IS_INTERNAL/debug builds) may see it. Filtering
/// lives here — not in the sheet or the screen — so no future purchase
/// surface can forget it.

@ProviderFor(visibleCreditPackages)
const visibleCreditPackagesProvider = VisibleCreditPackagesProvider._();

/// The packages the current build is allowed to *display*, in offering order.
///
/// This is [aiCreditOffering] minus the tester-only SKUs
/// ([kTesterOnlyProductIds]): the $0.99 pipeline-test pack exists in the store
/// so the whole purchase path (StoreKit → RevenueCat → webhook → wallet) can
/// be exercised end to end, but only devices with tester mode ON (the 7-tap
/// switch, defaulting on for IS_INTERNAL/debug builds) may see it. Filtering
/// lives here — not in the sheet or the screen — so no future purchase
/// surface can forget it.

final class VisibleCreditPackagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Package>>,
          List<Package>,
          FutureOr<List<Package>>
        >
    with $FutureModifier<List<Package>>, $FutureProvider<List<Package>> {
  /// The packages the current build is allowed to *display*, in offering order.
  ///
  /// This is [aiCreditOffering] minus the tester-only SKUs
  /// ([kTesterOnlyProductIds]): the $0.99 pipeline-test pack exists in the store
  /// so the whole purchase path (StoreKit → RevenueCat → webhook → wallet) can
  /// be exercised end to end, but only devices with tester mode ON (the 7-tap
  /// switch, defaulting on for IS_INTERNAL/debug builds) may see it. Filtering
  /// lives here — not in the sheet or the screen — so no future purchase
  /// surface can forget it.
  const VisibleCreditPackagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'visibleCreditPackagesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$visibleCreditPackagesHash();

  @$internal
  @override
  $FutureProviderElement<List<Package>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Package>> create(Ref ref) {
    return visibleCreditPackages(ref);
  }
}

String _$visibleCreditPackagesHash() =>
    r'759acc2d0fc782b9745ffed843807c4cb35af405';

/// Manages the purchase and restore flows for AI credit packs.
///
/// State is `AsyncValue<void>`:
/// - `AsyncData(null)` — idle / last operation succeeded.
/// - `AsyncLoading()` — purchase / restore in progress.
/// - `AsyncError(...)` — the last operation failed with a user-visible message.
///
/// The UI should watch state to show a loading indicator or surface errors.
///
/// **keepAlive is load-bearing, not an optimisation.** Under autoDispose this
/// controller was torn down the moment `buy()` hit its first await, because the
/// token top-up sheet only `ref.read`s the notifier — a read creates no
/// subscription. Every `ref` use after the store call then threw
/// `UnmountedRefException`, so a *successful* purchase crashed on the way to
/// the celebration screen. (`buy_credits_screen` watches the provider, which is
/// why the same code never failed there.) A purchase in flight must outlive any
/// widget that started it.

@ProviderFor(PurchaseController)
const purchaseControllerProvider = PurchaseControllerProvider._();

/// Manages the purchase and restore flows for AI credit packs.
///
/// State is `AsyncValue<void>`:
/// - `AsyncData(null)` — idle / last operation succeeded.
/// - `AsyncLoading()` — purchase / restore in progress.
/// - `AsyncError(...)` — the last operation failed with a user-visible message.
///
/// The UI should watch state to show a loading indicator or surface errors.
///
/// **keepAlive is load-bearing, not an optimisation.** Under autoDispose this
/// controller was torn down the moment `buy()` hit its first await, because the
/// token top-up sheet only `ref.read`s the notifier — a read creates no
/// subscription. Every `ref` use after the store call then threw
/// `UnmountedRefException`, so a *successful* purchase crashed on the way to
/// the celebration screen. (`buy_credits_screen` watches the provider, which is
/// why the same code never failed there.) A purchase in flight must outlive any
/// widget that started it.
final class PurchaseControllerProvider
    extends $AsyncNotifierProvider<PurchaseController, void> {
  /// Manages the purchase and restore flows for AI credit packs.
  ///
  /// State is `AsyncValue<void>`:
  /// - `AsyncData(null)` — idle / last operation succeeded.
  /// - `AsyncLoading()` — purchase / restore in progress.
  /// - `AsyncError(...)` — the last operation failed with a user-visible message.
  ///
  /// The UI should watch state to show a loading indicator or surface errors.
  ///
  /// **keepAlive is load-bearing, not an optimisation.** Under autoDispose this
  /// controller was torn down the moment `buy()` hit its first await, because the
  /// token top-up sheet only `ref.read`s the notifier — a read creates no
  /// subscription. Every `ref` use after the store call then threw
  /// `UnmountedRefException`, so a *successful* purchase crashed on the way to
  /// the celebration screen. (`buy_credits_screen` watches the provider, which is
  /// why the same code never failed there.) A purchase in flight must outlive any
  /// widget that started it.
  const PurchaseControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'purchaseControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$purchaseControllerHash();

  @$internal
  @override
  PurchaseController create() => PurchaseController();
}

String _$purchaseControllerHash() =>
    r'9830e199c03727d60cfc2c6ad4ca04b538976ee1';

/// Manages the purchase and restore flows for AI credit packs.
///
/// State is `AsyncValue<void>`:
/// - `AsyncData(null)` — idle / last operation succeeded.
/// - `AsyncLoading()` — purchase / restore in progress.
/// - `AsyncError(...)` — the last operation failed with a user-visible message.
///
/// The UI should watch state to show a loading indicator or surface errors.
///
/// **keepAlive is load-bearing, not an optimisation.** Under autoDispose this
/// controller was torn down the moment `buy()` hit its first await, because the
/// token top-up sheet only `ref.read`s the notifier — a read creates no
/// subscription. Every `ref` use after the store call then threw
/// `UnmountedRefException`, so a *successful* purchase crashed on the way to
/// the celebration screen. (`buy_credits_screen` watches the provider, which is
/// why the same code never failed there.) A purchase in flight must outlive any
/// widget that started it.

abstract class _$PurchaseController extends $AsyncNotifier<void> {
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
