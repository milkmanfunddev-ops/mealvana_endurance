// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'code_entry_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Our own Code entry (mp-458), reached from Redeem code in the paywall's ⋯
/// menu (mp-494) and on the Subscription screen (mp-495). Never the App
/// Store's offer-code sheet.
///
/// [redeem] sends the Code to `redeem-code`; the state holds what it did
/// ([CodeRedeemed]) or why it was refused ([CodeRefused]), and an
/// [AsyncError] carrying a [CodeRedeemFailure] when no answer came back.
///
/// A Code that grants `pro` (a coach's own, a giveaway) was granted on the
/// server, so the SDK's cached status still says locked: it is dropped and
/// the status provider asked again, which opens the gate and moves the
/// person into the app, as after the grace claim.
///
/// A Code that changes coaching (mp-600, card mp-598) updates the app at
/// once: a coach's own Code pulls the new `coaches` row, an athlete's coach
/// Code pulls the pending pairing, and coach mode (Settings) and both
/// pairing lists (the athlete's My Coaches, the coach's dashboard) are
/// rebuilt from it. The pull comes first because both lists sync only once
/// per notifier, and Riverpod keeps the notifier across an invalidate.
///
/// keepAlive for the same reason as [ProPaywallController]: the entry only
/// `ref.read`s the notifier, and a redemption in flight must finish its
/// status refresh even if the sheet is closed under it. [reset] clears the
/// last answer when the entry opens again.

@ProviderFor(CodeEntryController)
const codeEntryControllerProvider = CodeEntryControllerProvider._();

/// Our own Code entry (mp-458), reached from Redeem code in the paywall's ⋯
/// menu (mp-494) and on the Subscription screen (mp-495). Never the App
/// Store's offer-code sheet.
///
/// [redeem] sends the Code to `redeem-code`; the state holds what it did
/// ([CodeRedeemed]) or why it was refused ([CodeRefused]), and an
/// [AsyncError] carrying a [CodeRedeemFailure] when no answer came back.
///
/// A Code that grants `pro` (a coach's own, a giveaway) was granted on the
/// server, so the SDK's cached status still says locked: it is dropped and
/// the status provider asked again, which opens the gate and moves the
/// person into the app, as after the grace claim.
///
/// A Code that changes coaching (mp-600, card mp-598) updates the app at
/// once: a coach's own Code pulls the new `coaches` row, an athlete's coach
/// Code pulls the pending pairing, and coach mode (Settings) and both
/// pairing lists (the athlete's My Coaches, the coach's dashboard) are
/// rebuilt from it. The pull comes first because both lists sync only once
/// per notifier, and Riverpod keeps the notifier across an invalidate.
///
/// keepAlive for the same reason as [ProPaywallController]: the entry only
/// `ref.read`s the notifier, and a redemption in flight must finish its
/// status refresh even if the sheet is closed under it. [reset] clears the
/// last answer when the entry opens again.
final class CodeEntryControllerProvider
    extends $AsyncNotifierProvider<CodeEntryController, CodeRedemption?> {
  /// Our own Code entry (mp-458), reached from Redeem code in the paywall's ⋯
  /// menu (mp-494) and on the Subscription screen (mp-495). Never the App
  /// Store's offer-code sheet.
  ///
  /// [redeem] sends the Code to `redeem-code`; the state holds what it did
  /// ([CodeRedeemed]) or why it was refused ([CodeRefused]), and an
  /// [AsyncError] carrying a [CodeRedeemFailure] when no answer came back.
  ///
  /// A Code that grants `pro` (a coach's own, a giveaway) was granted on the
  /// server, so the SDK's cached status still says locked: it is dropped and
  /// the status provider asked again, which opens the gate and moves the
  /// person into the app, as after the grace claim.
  ///
  /// A Code that changes coaching (mp-600, card mp-598) updates the app at
  /// once: a coach's own Code pulls the new `coaches` row, an athlete's coach
  /// Code pulls the pending pairing, and coach mode (Settings) and both
  /// pairing lists (the athlete's My Coaches, the coach's dashboard) are
  /// rebuilt from it. The pull comes first because both lists sync only once
  /// per notifier, and Riverpod keeps the notifier across an invalidate.
  ///
  /// keepAlive for the same reason as [ProPaywallController]: the entry only
  /// `ref.read`s the notifier, and a redemption in flight must finish its
  /// status refresh even if the sheet is closed under it. [reset] clears the
  /// last answer when the entry opens again.
  const CodeEntryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'codeEntryControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$codeEntryControllerHash();

  @$internal
  @override
  CodeEntryController create() => CodeEntryController();
}

String _$codeEntryControllerHash() =>
    r'15e041e7088175bcaca8862b8970094c9bcadcce';

/// Our own Code entry (mp-458), reached from Redeem code in the paywall's ⋯
/// menu (mp-494) and on the Subscription screen (mp-495). Never the App
/// Store's offer-code sheet.
///
/// [redeem] sends the Code to `redeem-code`; the state holds what it did
/// ([CodeRedeemed]) or why it was refused ([CodeRefused]), and an
/// [AsyncError] carrying a [CodeRedeemFailure] when no answer came back.
///
/// A Code that grants `pro` (a coach's own, a giveaway) was granted on the
/// server, so the SDK's cached status still says locked: it is dropped and
/// the status provider asked again, which opens the gate and moves the
/// person into the app, as after the grace claim.
///
/// A Code that changes coaching (mp-600, card mp-598) updates the app at
/// once: a coach's own Code pulls the new `coaches` row, an athlete's coach
/// Code pulls the pending pairing, and coach mode (Settings) and both
/// pairing lists (the athlete's My Coaches, the coach's dashboard) are
/// rebuilt from it. The pull comes first because both lists sync only once
/// per notifier, and Riverpod keeps the notifier across an invalidate.
///
/// keepAlive for the same reason as [ProPaywallController]: the entry only
/// `ref.read`s the notifier, and a redemption in flight must finish its
/// status refresh even if the sheet is closed under it. [reset] clears the
/// last answer when the entry opens again.

abstract class _$CodeEntryController extends $AsyncNotifier<CodeRedemption?> {
  FutureOr<CodeRedemption?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<CodeRedemption?>, CodeRedemption?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CodeRedemption?>, CodeRedemption?>,
              AsyncValue<CodeRedemption?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
