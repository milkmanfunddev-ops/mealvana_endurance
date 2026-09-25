// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carb_nudge_coordinator.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// G27: the open/resume sweep that keeps every event's scheduled nudges in
/// step with plan-existence and shows the at-most-one-per-day catch-up.
/// Called from the root widget on first frame and on every foreground
/// resume; every failure is swallowed — a nudge must never take the app
/// down (same fail-soft posture as the dashboard's carb watch).

@ProviderFor(CarbNudgeCoordinator)
const carbNudgeCoordinatorProvider = CarbNudgeCoordinatorProvider._();

/// G27: the open/resume sweep that keeps every event's scheduled nudges in
/// step with plan-existence and shows the at-most-one-per-day catch-up.
/// Called from the root widget on first frame and on every foreground
/// resume; every failure is swallowed — a nudge must never take the app
/// down (same fail-soft posture as the dashboard's carb watch).
final class CarbNudgeCoordinatorProvider
    extends $NotifierProvider<CarbNudgeCoordinator, void> {
  /// G27: the open/resume sweep that keeps every event's scheduled nudges in
  /// step with plan-existence and shows the at-most-one-per-day catch-up.
  /// Called from the root widget on first frame and on every foreground
  /// resume; every failure is swallowed — a nudge must never take the app
  /// down (same fail-soft posture as the dashboard's carb watch).
  const CarbNudgeCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'carbNudgeCoordinatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$carbNudgeCoordinatorHash();

  @$internal
  @override
  CarbNudgeCoordinator create() => CarbNudgeCoordinator();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$carbNudgeCoordinatorHash() =>
    r'10b65927d9accbdd89db3fc8759ae8d5dd80f5b4';

/// G27: the open/resume sweep that keeps every event's scheduled nudges in
/// step with plan-existence and shows the at-most-one-per-day catch-up.
/// Called from the root widget on first frame and on every foreground
/// resume; every failure is swallowed — a nudge must never take the app
/// down (same fail-soft posture as the dashboard's carb watch).

abstract class _$CarbNudgeCoordinator extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
