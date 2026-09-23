// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pro_gate.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app gate, as the router reads it (mp-280: everything is behind it):
/// open or closed (mp-457).
///
/// Loading while the status is unresolved — the status controller bounds
/// that wait (mp-284), so awaiting `.future` here answers within a couple of
/// seconds. The admin read is consulted only for an inactive status and is
/// bounded by the same timeout, so a slow network still lands on the
/// paywall instead of hanging the redirect. keepAlive so the router's
/// `ref.read` sees the same value every screen watches.

@ProviderFor(AppGate)
const appGateProvider = AppGateProvider._();

/// The app gate, as the router reads it (mp-280: everything is behind it):
/// open or closed (mp-457).
///
/// Loading while the status is unresolved — the status controller bounds
/// that wait (mp-284), so awaiting `.future` here answers within a couple of
/// seconds. The admin read is consulted only for an inactive status and is
/// bounded by the same timeout, so a slow network still lands on the
/// paywall instead of hanging the redirect. keepAlive so the router's
/// `ref.read` sees the same value every screen watches.
final class AppGateProvider extends $AsyncNotifierProvider<AppGate, AppAccess> {
  /// The app gate, as the router reads it (mp-280: everything is behind it):
  /// open or closed (mp-457).
  ///
  /// Loading while the status is unresolved — the status controller bounds
  /// that wait (mp-284), so awaiting `.future` here answers within a couple of
  /// seconds. The admin read is consulted only for an inactive status and is
  /// bounded by the same timeout, so a slow network still lands on the
  /// paywall instead of hanging the redirect. keepAlive so the router's
  /// `ref.read` sees the same value every screen watches.
  const AppGateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appGateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appGateHash();

  @$internal
  @override
  AppGate create() => AppGate();
}

String _$appGateHash() => r'dd619469cc19934afee5b00d870c51181c7b1b78';

/// The app gate, as the router reads it (mp-280: everything is behind it):
/// open or closed (mp-457).
///
/// Loading while the status is unresolved — the status controller bounds
/// that wait (mp-284), so awaiting `.future` here answers within a couple of
/// seconds. The admin read is consulted only for an inactive status and is
/// bounded by the same timeout, so a slow network still lands on the
/// paywall instead of hanging the redirect. keepAlive so the router's
/// `ref.read` sees the same value every screen watches.

abstract class _$AppGate extends $AsyncNotifier<AppAccess> {
  FutureOr<AppAccess> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<AppAccess>, AppAccess>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppAccess>, AppAccess>,
              AsyncValue<AppAccess>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// The one write-access rule (mp-457 §4): whether this account may write or
/// call AI right now. True only when the gate is open; an unresolved gate
/// waits for the gate's bounded answer (an unknown answer is closed, so no).
/// A write controller awaits this before writing and opens the paywall
/// instead when it says no (ticket 20 removes the check).

@ProviderFor(writeAccess)
const writeAccessProvider = WriteAccessProvider._();

/// The one write-access rule (mp-457 §4): whether this account may write or
/// call AI right now. True only when the gate is open; an unresolved gate
/// waits for the gate's bounded answer (an unknown answer is closed, so no).
/// A write controller awaits this before writing and opens the paywall
/// instead when it says no (ticket 20 removes the check).

final class WriteAccessProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// The one write-access rule (mp-457 §4): whether this account may write or
  /// call AI right now. True only when the gate is open; an unresolved gate
  /// waits for the gate's bounded answer (an unknown answer is closed, so no).
  /// A write controller awaits this before writing and opens the paywall
  /// instead when it says no (ticket 20 removes the check).
  const WriteAccessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'writeAccessProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$writeAccessHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return writeAccess(ref);
  }
}

String _$writeAccessHash() => r'84d52de6ef4f79282609145ada359711caeacd76';
