// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credits_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Exposes the current user's credit [CreditWallet].
///
/// Starts with an async fetch from [CreditsRepository]. Use [refresh] to
/// re-fetch on demand (e.g. after a RevenueCat webhook may have credited the
/// wallet).

@ProviderFor(CreditsController)
const creditsControllerProvider = CreditsControllerProvider._();

/// Exposes the current user's credit [CreditWallet].
///
/// Starts with an async fetch from [CreditsRepository]. Use [refresh] to
/// re-fetch on demand (e.g. after a RevenueCat webhook may have credited the
/// wallet).
final class CreditsControllerProvider
    extends $AsyncNotifierProvider<CreditsController, CreditWallet> {
  /// Exposes the current user's credit [CreditWallet].
  ///
  /// Starts with an async fetch from [CreditsRepository]. Use [refresh] to
  /// re-fetch on demand (e.g. after a RevenueCat webhook may have credited the
  /// wallet).
  const CreditsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creditsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$creditsControllerHash();

  @$internal
  @override
  CreditsController create() => CreditsController();
}

String _$creditsControllerHash() => r'3c668cf6ea93ac3b9c50fb946dea9b0e57b05402';

/// Exposes the current user's credit [CreditWallet].
///
/// Starts with an async fetch from [CreditsRepository]. Use [refresh] to
/// re-fetch on demand (e.g. after a RevenueCat webhook may have credited the
/// wallet).

abstract class _$CreditsController extends $AsyncNotifier<CreditWallet> {
  FutureOr<CreditWallet> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<CreditWallet>, CreditWallet>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CreditWallet>, CreditWallet>,
              AsyncValue<CreditWallet>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
