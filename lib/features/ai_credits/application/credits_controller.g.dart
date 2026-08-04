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
///
/// **[build] must never throw.** With `keepAlive`, a provider whose initial
/// build errors leaves `creditsControllerProvider.future` permanently
/// uncompleted (the state sits at `AsyncLoading` carrying the error, even with
/// a listener attached). [PurchaseController] awaits that future while polling
/// for the post-purchase balance, so a throwing build would hang a purchase
/// forever instead of failing it. A wallet we cannot read is reported as a zero
/// balance, which is also the better user-facing outcome: a transient network
/// error should show a stale number, not put the whole credits UI in an error
/// state.

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
///
/// **[build] must never throw.** With `keepAlive`, a provider whose initial
/// build errors leaves `creditsControllerProvider.future` permanently
/// uncompleted (the state sits at `AsyncLoading` carrying the error, even with
/// a listener attached). [PurchaseController] awaits that future while polling
/// for the post-purchase balance, so a throwing build would hang a purchase
/// forever instead of failing it. A wallet we cannot read is reported as a zero
/// balance, which is also the better user-facing outcome: a transient network
/// error should show a stale number, not put the whole credits UI in an error
/// state.
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
  ///
  /// **[build] must never throw.** With `keepAlive`, a provider whose initial
  /// build errors leaves `creditsControllerProvider.future` permanently
  /// uncompleted (the state sits at `AsyncLoading` carrying the error, even with
  /// a listener attached). [PurchaseController] awaits that future while polling
  /// for the post-purchase balance, so a throwing build would hang a purchase
  /// forever instead of failing it. A wallet we cannot read is reported as a zero
  /// balance, which is also the better user-facing outcome: a transient network
  /// error should show a stale number, not put the whole credits UI in an error
  /// state.
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

String _$creditsControllerHash() => r'f0f2444ae166b81a37bd13d9d2c43a9d80ef09fb';

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
///
/// **[build] must never throw.** With `keepAlive`, a provider whose initial
/// build errors leaves `creditsControllerProvider.future` permanently
/// uncompleted (the state sits at `AsyncLoading` carrying the error, even with
/// a listener attached). [PurchaseController] awaits that future while polling
/// for the post-purchase balance, so a throwing build would hang a purchase
/// forever instead of failing it. A wallet we cannot read is reported as a zero
/// balance, which is also the better user-facing outcome: a transient network
/// error should show a stale number, not put the whole credits UI in an error
/// state.

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
