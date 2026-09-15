// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pro_gate.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app gate, as the router reads it (mp-280: everything is behind it).
///
/// Loading while the status is unresolved — the status controller bounds
/// that wait (mp-284), so awaiting `.future` here answers within a couple of
/// seconds. keepAlive so the router's `ref.read` sees the same value every
/// screen watches.

@ProviderFor(AppGate)
const appGateProvider = AppGateProvider._();

/// The app gate, as the router reads it (mp-280: everything is behind it).
///
/// Loading while the status is unresolved — the status controller bounds
/// that wait (mp-284), so awaiting `.future` here answers within a couple of
/// seconds. keepAlive so the router's `ref.read` sees the same value every
/// screen watches.
final class AppGateProvider extends $AsyncNotifierProvider<AppGate, bool> {
  /// The app gate, as the router reads it (mp-280: everything is behind it).
  ///
  /// Loading while the status is unresolved — the status controller bounds
  /// that wait (mp-284), so awaiting `.future` here answers within a couple of
  /// seconds. keepAlive so the router's `ref.read` sees the same value every
  /// screen watches.
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

String _$appGateHash() => r'8ad711452018e7bf6ca4cd582a758e6a20870e2c';

/// The app gate, as the router reads it (mp-280: everything is behind it).
///
/// Loading while the status is unresolved — the status controller bounds
/// that wait (mp-284), so awaiting `.future` here answers within a couple of
/// seconds. keepAlive so the router's `ref.read` sees the same value every
/// screen watches.

abstract class _$AppGate extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
