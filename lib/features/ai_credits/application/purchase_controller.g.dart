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

/// Manages the purchase and restore flows for AI credit packs.
///
/// State is `AsyncValue<void>`:
/// - `AsyncData(null)` — idle / last operation succeeded.
/// - `AsyncLoading()` — purchase / restore in progress.
/// - `AsyncError(...)` — the last operation failed with a user-visible message.
///
/// The UI should watch state to show a loading indicator or surface errors.

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
  const PurchaseControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'purchaseControllerProvider',
        isAutoDispose: true,
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
    r'629704e6872d391f137a4abc18f2e1245b29569d';

/// Manages the purchase and restore flows for AI credit packs.
///
/// State is `AsyncValue<void>`:
/// - `AsyncData(null)` — idle / last operation succeeded.
/// - `AsyncLoading()` — purchase / restore in progress.
/// - `AsyncError(...)` — the last operation failed with a user-visible message.
///
/// The UI should watch state to show a loading indicator or surface errors.

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
