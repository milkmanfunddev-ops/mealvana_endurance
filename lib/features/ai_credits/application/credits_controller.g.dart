// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credits_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Exposes the current user's credit [CreditWallet].
///
/// **This is the single in-memory cache of the balance for the whole session.**
/// It is `keepAlive` because several widgets watch it independently — the token
/// pill on both meal screens, the top-up sheet, the buy-credits screen — and
/// under autoDispose the provider was rebuilt from scratch every time the last
/// of them unmounted. Each rebuild meant another network round trip just to
/// re-learn a number that had not changed. Now it builds once and every watcher
/// reads the same cached value; use [refresh] when something may have changed
/// it (a purchase landing, an analysis spending a token).

@ProviderFor(CreditsController)
const creditsControllerProvider = CreditsControllerProvider._();

/// Exposes the current user's credit [CreditWallet].
///
/// **This is the single in-memory cache of the balance for the whole session.**
/// It is `keepAlive` because several widgets watch it independently — the token
/// pill on both meal screens, the top-up sheet, the buy-credits screen — and
/// under autoDispose the provider was rebuilt from scratch every time the last
/// of them unmounted. Each rebuild meant another network round trip just to
/// re-learn a number that had not changed. Now it builds once and every watcher
/// reads the same cached value; use [refresh] when something may have changed
/// it (a purchase landing, an analysis spending a token).
final class CreditsControllerProvider
    extends $AsyncNotifierProvider<CreditsController, CreditWallet> {
  /// Exposes the current user's credit [CreditWallet].
  ///
  /// **This is the single in-memory cache of the balance for the whole session.**
  /// It is `keepAlive` because several widgets watch it independently — the token
  /// pill on both meal screens, the top-up sheet, the buy-credits screen — and
  /// under autoDispose the provider was rebuilt from scratch every time the last
  /// of them unmounted. Each rebuild meant another network round trip just to
  /// re-learn a number that had not changed. Now it builds once and every watcher
  /// reads the same cached value; use [refresh] when something may have changed
  /// it (a purchase landing, an analysis spending a token).
  const CreditsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creditsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$creditsControllerHash();

  @$internal
  @override
  CreditsController create() => CreditsController();
}

String _$creditsControllerHash() => r'ce0067beb404d3a8d5a5ba4fcdc111cb2d07c47b';

/// Exposes the current user's credit [CreditWallet].
///
/// **This is the single in-memory cache of the balance for the whole session.**
/// It is `keepAlive` because several widgets watch it independently — the token
/// pill on both meal screens, the top-up sheet, the buy-credits screen — and
/// under autoDispose the provider was rebuilt from scratch every time the last
/// of them unmounted. Each rebuild meant another network round trip just to
/// re-learn a number that had not changed. Now it builds once and every watcher
/// reads the same cached value; use [refresh] when something may have changed
/// it (a purchase landing, an analysis spending a token).

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
