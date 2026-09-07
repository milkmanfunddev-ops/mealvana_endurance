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
/// The auth identity the wallet belongs to, as a rebuild signal.
///
/// [CreditsController.build] watches this so a session APPEARING (anonymous
/// sign-in at the end of onboarding), CHANGING (log out → log in) or ENDING
/// rebuilds the controller — which re-runs the monthly ensure/grant, rebinds
/// the realtime channel to the right user, and re-reads the wallet. Before
/// this existed the only thing that ever invalidated the controller was a
/// purchase, which is why balances "reappeared after buying".

@ProviderFor(creditsAuthUserId)
const creditsAuthUserIdProvider = CreditsAuthUserIdProvider._();

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
/// The auth identity the wallet belongs to, as a rebuild signal.
///
/// [CreditsController.build] watches this so a session APPEARING (anonymous
/// sign-in at the end of onboarding), CHANGING (log out → log in) or ENDING
/// rebuilds the controller — which re-runs the monthly ensure/grant, rebinds
/// the realtime channel to the right user, and re-reads the wallet. Before
/// this existed the only thing that ever invalidated the controller was a
/// purchase, which is why balances "reappeared after buying".

final class CreditsAuthUserIdProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, Stream<String?>>
    with $FutureModifier<String?>, $StreamProvider<String?> {
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
  /// The auth identity the wallet belongs to, as a rebuild signal.
  ///
  /// [CreditsController.build] watches this so a session APPEARING (anonymous
  /// sign-in at the end of onboarding), CHANGING (log out → log in) or ENDING
  /// rebuilds the controller — which re-runs the monthly ensure/grant, rebinds
  /// the realtime channel to the right user, and re-reads the wallet. Before
  /// this existed the only thing that ever invalidated the controller was a
  /// purchase, which is why balances "reappeared after buying".
  const CreditsAuthUserIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creditsAuthUserIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$creditsAuthUserIdHash();

  @$internal
  @override
  $StreamProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<String?> create(Ref ref) {
    return creditsAuthUserId(ref);
  }
}

String _$creditsAuthUserIdHash() => r'a7e6abb92531171055697f422cd104705ab71042';

@ProviderFor(CreditsController)
const creditsControllerProvider = CreditsControllerProvider._();

final class CreditsControllerProvider
    extends $AsyncNotifierProvider<CreditsController, CreditWallet> {
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

String _$creditsControllerHash() => r'06c4e15ac418796577d39f35f838e25d1fd7e5e4';

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
