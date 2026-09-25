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
/// seconds. The admin read is consulted only for an inactive status and
/// gets what is left of the same wait, so the Gate's first answer comes
/// within one timeout (mp-335: startup waits at most two seconds; ticket
/// 105, Finding 87-009) and a slow network lands on the paywall instead of
/// hanging the redirect. keepAlive so the router's `ref.read` sees the same
/// value every screen watches.

@ProviderFor(AppGate)
const appGateProvider = AppGateProvider._();

/// The app gate, as the router reads it (mp-280: everything is behind it):
/// open or closed (mp-457).
///
/// Loading while the status is unresolved — the status controller bounds
/// that wait (mp-284), so awaiting `.future` here answers within a couple of
/// seconds. The admin read is consulted only for an inactive status and
/// gets what is left of the same wait, so the Gate's first answer comes
/// within one timeout (mp-335: startup waits at most two seconds; ticket
/// 105, Finding 87-009) and a slow network lands on the paywall instead of
/// hanging the redirect. keepAlive so the router's `ref.read` sees the same
/// value every screen watches.
final class AppGateProvider extends $AsyncNotifierProvider<AppGate, AppAccess> {
  /// The app gate, as the router reads it (mp-280: everything is behind it):
  /// open or closed (mp-457).
  ///
  /// Loading while the status is unresolved — the status controller bounds
  /// that wait (mp-284), so awaiting `.future` here answers within a couple of
  /// seconds. The admin read is consulted only for an inactive status and
  /// gets what is left of the same wait, so the Gate's first answer comes
  /// within one timeout (mp-335: startup waits at most two seconds; ticket
  /// 105, Finding 87-009) and a slow network lands on the paywall instead of
  /// hanging the redirect. keepAlive so the router's `ref.read` sees the same
  /// value every screen watches.
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

String _$appGateHash() => r'8e49ebde13d5daa3f1a599803757bcb35254015e';

/// The app gate, as the router reads it (mp-280: everything is behind it):
/// open or closed (mp-457).
///
/// Loading while the status is unresolved — the status controller bounds
/// that wait (mp-284), so awaiting `.future` here answers within a couple of
/// seconds. The admin read is consulted only for an inactive status and
/// gets what is left of the same wait, so the Gate's first answer comes
/// within one timeout (mp-335: startup waits at most two seconds; ticket
/// 105, Finding 87-009) and a slow network lands on the paywall instead of
/// hanging the redirect. keepAlive so the router's `ref.read` sees the same
/// value every screen watches.

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

/// Whether this account may start an AI action right now: true only when
/// the gate is open; an unresolved gate waits for the gate's bounded answer
/// (an unknown answer is closed, so no). Read by the AI-action checks on
/// screens the router never sees (`aiActionAllowed`, the Vana launcher);
/// no write asks it (mp-457, ticket 20).

@ProviderFor(writeAccess)
const writeAccessProvider = WriteAccessProvider._();

/// Whether this account may start an AI action right now: true only when
/// the gate is open; an unresolved gate waits for the gate's bounded answer
/// (an unknown answer is closed, so no). Read by the AI-action checks on
/// screens the router never sees (`aiActionAllowed`, the Vana launcher);
/// no write asks it (mp-457, ticket 20).

final class WriteAccessProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether this account may start an AI action right now: true only when
  /// the gate is open; an unresolved gate waits for the gate's bounded answer
  /// (an unknown answer is closed, so no). Read by the AI-action checks on
  /// screens the router never sees (`aiActionAllowed`, the Vana launcher);
  /// no write asks it (mp-457, ticket 20).
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

String _$writeAccessHash() => r'c927de8de2037bd180644519393f934e718c71a4';
