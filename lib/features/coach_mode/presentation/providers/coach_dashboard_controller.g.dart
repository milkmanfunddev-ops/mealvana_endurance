// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_dashboard_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CoachDashboardController)
const coachDashboardControllerProvider = CoachDashboardControllerProvider._();

final class CoachDashboardControllerProvider
    extends
        $AsyncNotifierProvider<CoachDashboardController, CoachDashboardState> {
  const CoachDashboardControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachDashboardControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachDashboardControllerHash();

  @$internal
  @override
  CoachDashboardController create() => CoachDashboardController();
}

String _$coachDashboardControllerHash() =>
    r'9d97db4f92acc643d11ee48606e6c4eaa7dfb8be';

abstract class _$CoachDashboardController
    extends $AsyncNotifier<CoachDashboardState> {
  FutureOr<CoachDashboardState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<CoachDashboardState>, CoachDashboardState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CoachDashboardState>, CoachDashboardState>,
              AsyncValue<CoachDashboardState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
